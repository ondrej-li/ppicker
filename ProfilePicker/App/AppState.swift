import AppKit
import Observation
import ServiceManagement

/// Shared state: the user's configuration, installed browsers and helper status.
@Observable
final class AppState {
    var config: Config {
        didSet {
            guard config != oldValue else { return }
            save()
            onConfigChange?()
        }
    }

    let catalog = BrowserCatalog()
    let helper = Helper()
    private(set) var isDefaultBrowser = false
    /// Set when macOS refuses to make Profile Picker the default browser, or the user cancels.
    private(set) var defaultBrowserError: String?

    @ObservationIgnored var onConfigChange: (() -> Void)?

    private static let configURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("config.json")
    }()

    init() {
        if let data = try? Data(contentsOf: Self.configURL),
           let decoded = try? JSONDecoder().decode(Config.self, from: data) {
            config = decoded
        } else {
            config = Config()
        }
    }

    func start() {
        helper.refreshStatus()
        refreshDefaultBrowserStatus()
        Task { await refreshBrowsers() }
    }

    func refreshBrowsers() async {
        helper.refreshStatus()
        await catalog.refresh(helper: helper)
    }

    // MARK: - Default browser

    func refreshDefaultBrowserStatus() {
        guard let current = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) else {
            isDefaultBrowser = false
            return
        }
        let currentID = Bundle(url: current)?.bundleIdentifier
        isDefaultBrowser = currentID == Bundle.main.bundleIdentifier
            || current.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
        if isDefaultBrowser { defaultBrowserError = nil }
        // Remember the browser the user had before, for "open normally".
        if !isDefaultBrowser, let currentID {
            config.systemBrowserID = currentID
        }
    }

    func makeDefaultBrowser() async {
        refreshDefaultBrowserStatus()
        defaultBrowserError = nil
        let app = Bundle.main.bundleURL
        do {
            // macOS asks the user to confirm; this also covers https and HTML files.
            try await NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "http")
            if NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!)?.standardizedFileURL
                != app.standardizedFileURL {
                try await NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "https")
            }
        } catch {
            defaultBrowserError = "macOS could not change the default browser: \(error.localizedDescription)"
            logger.error("Could not become the default browser: \(error.localizedDescription, privacy: .public)")
        }
        refreshDefaultBrowserStatus()
        if !isDefaultBrowser, defaultBrowserError == nil {
            defaultBrowserError = "Profile Picker is still not the default browser. Try again and confirm the macOS prompt, "
                + "or choose it in System Settings › Desktop & Dock › Default web browser."
        }
    }

    /// The browser to use for "open normally": the previous system default, or the first one found.
    var systemBrowserID: String? {
        if let id = config.systemBrowserID, catalog.browser(id) != nil { return id }
        return catalog.browsers.first?.bundleID
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                logger.error("Launch at login: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(config).write(to: Self.configURL, options: .atomic)
        } catch {
            logger.error("Could not save settings: \(error.localizedDescription, privacy: .public)")
        }
    }
}
