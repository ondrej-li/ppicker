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

        // First run (or launched by hand): show settings so the user can make Profile Picker the default browser.
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
                if let icon = NSImage(named: "StatusIcon"), let copy = icon.copy() as? NSImage {
                    copy.isTemplate = true
                    copy.size = NSSize(width: 18, height: 18)
                    item.button?.image = copy
                } else {
                    item.button?.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: AppInfo.name)
                }
                item.button?.toolTip = AppInfo.name
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
        menu.addItem(withTitle: "About \(AppInfo.name)", action: #selector(showAbout), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "\(AppInfo.name) Help", action: #selector(showHelp), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Privacy Policy", action: #selector(showPrivacyPolicy), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit \(AppInfo.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .credits: NSAttributedString(
                string: "Open every link in the right browser profile.\nBuilt with SwiftUI and AppKit. No tracking, no account, no network access.",
                attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
            ),
        ])
    }

    @objc func showHelp() {
        openInSystemBrowser(AppInfo.helpURL)
    }

    @objc func showPrivacyPolicy() {
        openInSystemBrowser(AppInfo.privacyURL)
    }

    /// Opens a help or policy link without handing it back to Profile Picker, which is the default
    /// browser: NSWorkspace would send the link to us again and show the picker.
    private func openInSystemBrowser(_ url: URL) {
        guard let bundleID = state.systemBrowserID ?? state.catalog.browsers.first?.bundleID else {
            NSWorkspace.shared.open(url)
            return
        }
        Task { try? await Launcher.open(url, in: Target(bundleID: bundleID), helper: state.helper) }
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
            window.title = "Profile Picker Settings"
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            // Host SwiftUI in a plain container pinned to the window. A hosting controller lets the
            // content's ideal size drive the window, which made the Rules pane taller than the screen.
            let container = NSView()
            let hosting = NSHostingView(rootView: SettingsView(state: state))
            hosting.sizingOptions = []
            hosting.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.topAnchor.constraint(equalTo: container.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
            window.contentView = container
            window.setContentSize(NSSize(width: 760, height: 520))
            window.minSize = NSSize(width: 640, height: 420)
            window.maxSize = NSSize(width: 1400, height: 1000)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        // Show a Dock icon and menu bar while settings are open, like a normal app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        Task { await state.refreshBrowsers() }
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}

enum AppInfo {
    static let name = "Profile Picker"
    static let repositoryURL = URL(string: "https://github.com/ondrej-li/ppicker")!
    static let helpURL = repositoryURL
    static let privacyURL = URL(string: "https://github.com/ondrej-li/ppicker/blob/main/PRIVACY.md")!
}

/// A minimal main menu so standard shortcuts (⌘Q, ⌘W, copy & paste in text fields) work.
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About \(AppInfo.name)", action: #selector(AppDelegate.showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(AppDelegate.showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "\(AppInfo.name) Help", action: #selector(AppDelegate.showHelp), keyEquivalent: "?")
        appMenu.addItem(withTitle: "Privacy Policy", action: #selector(AppDelegate.showPrivacyPolicy), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(AppInfo.name)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit \(AppInfo.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
