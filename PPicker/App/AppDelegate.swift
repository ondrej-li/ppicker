import AppKit
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    let state = AppState()
    private lazy var picker = PickerController(state: state)
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var receivedLinkAtLaunch = false

    // MARK: - Lifecycle

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Registered before launch finishes so the link that launched the app is not missed.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        NSApp.mainMenu = MainMenu.make()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests are hosted in the app; don't show any UI then.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }

        state.onConfigChange = { [weak self] in self?.updateStatusItem() }
        state.start()
        updateStatusItem()

        // First run (or launched by hand): show settings so the user can make PPicker the default browser.
        DispatchQueue.main.async { [self] in
            if !receivedLinkAtLaunch && !state.isDefaultBrowser { showSettings() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        state.refreshDefaultBrowserStatus()
    }

    // MARK: - Incoming links

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string) else { return }
        receivedLinkAtLaunch = true
        let request = LinkRequest(
            url: url,
            source: SourceAppResolver.resolve(event),
            forcePicker: NSEvent.modifierFlags.contains(.option)
        )
        route(request)
    }

    /// HTML files opened from Finder etc.
    func application(_ application: NSApplication, open urls: [URL]) {
        receivedLinkAtLaunch = true
        let source = SourceAppResolver.frontmostApp()
        let forcePicker = NSEvent.modifierFlags.contains(.option)
        for url in urls {
            route(LinkRequest(url: url, source: source, forcePicker: forcePicker))
        }
    }

    func route(_ request: LinkRequest) {
        let action: LinkAction = request.forcePicker
            ? .showPicker
            : RuleEngine.decide(url: request.url, sourceBundleID: request.source?.bundleID, config: state.config).action
        logger.notice("Link \(request.url.absoluteString, privacy: .private) from \(request.source?.bundleID ?? "unknown app", privacy: .public) → \(String(describing: action), privacy: .public)")

        switch action {
        case .showPicker:
            picker.show(request)
        case .open(let target):
            Task {
                do {
                    try await Launcher.open(request.url, in: target, helper: state.helper)
                } catch {
                    picker.show(request)
                }
            }
        }
    }

    // MARK: - Menu bar item

    private func updateStatusItem() {
        if state.config.showMenuBarIcon {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                item.button?.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "PPicker")
                item.menu = makeStatusMenu()
                statusItem = item
            }
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit PPicker", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    // MARK: - Settings window

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "PPicker Settings"
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.contentViewController = NSHostingController(rootView: SettingsView(state: state))
            window.setContentSize(NSSize(width: 760, height: 520))
            window.minSize = NSSize(width: 640, height: 420)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        // Show a Dock icon and menu bar while settings are open, like a normal app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
        Task { await state.refreshBrowsers() }
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}

/// A minimal main menu so standard shortcuts (⌘Q, ⌘W, copy & paste in text fields) work.
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About PPicker", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(AppDelegate.showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide PPicker", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit PPicker", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(submenu(appMenu))

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenu(edit))

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(submenu(window))
        NSApp.windowsMenu = window

        return main
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
}
