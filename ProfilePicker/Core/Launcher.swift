import AppKit

enum Launcher {
    enum LaunchError: LocalizedError {
        case browserNotFound(String)

        var errorDescription: String? {
            switch self {
            case .browserNotFound(let id): "The browser “\(id)” is not installed."
            }
        }
    }

    /// Opens `url` in the target browser, in the target profile when possible.
    static func open(_ url: URL, in target: Target, helper: Helper) async throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleID) else {
            throw LaunchError.browserNotFound(target.bundleID)
        }

        if let profile = target.profile, KnownBrowsers.supportsProfiles(target.bundleID), helper.isUsable {
            do {
                try await helper.open(url, appURL: appURL, profile: profile)
                return
            } catch {
                logger.error("Helper failed (\(error.localizedDescription, privacy: .public)), opening without a profile")
            }
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        try await NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
    }
}

enum SourceAppResolver {
    /// `'spid'`: the process ID of the app that sent the Apple Event.
    private static let senderPIDAttribute: AEKeyword = 0x7370_6964

    /// Works out which app a link was clicked in.
    static func resolve(_ event: NSAppleEventDescriptor) -> SourceApp? {
        let pid = event.attributeDescriptor(forKeyword: senderPIDAttribute)?.int32Value ?? 0
        if pid > 0, let app = NSRunningApplication(processIdentifier: pid), let source = source(for: app) {
            return source
        }
        // e.g. `open https://…` in a terminal: the sender is the `open` tool, not an app.
        return frontmostApp()
    }

    static func frontmostApp() -> SourceApp? {
        guard let app = NSWorkspace.shared.frontmostApplication, app != .current else { return nil }
        return source(for: app)
    }

    /// Maps helper processes (e.g. `Slack Helper.app` inside `Slack.app`) to their main app.
    static func source(for app: NSRunningApplication) -> SourceApp? {
        if let bundleURL = app.bundleURL?.standardizedFileURL,
           let outer = outermostAppBundle(bundleURL), outer != bundleURL {
            if let main = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL?.standardizedFileURL == outer }),
               let id = main.bundleIdentifier {
                return SourceApp(bundleID: id, name: main.localizedName ?? id)
            }
            if let id = Bundle(url: outer)?.bundleIdentifier {
                return SourceApp(bundleID: id, name: BrowserCatalog.displayName(of: outer))
            }
        }
        guard let id = app.bundleIdentifier else { return nil }
        return SourceApp(bundleID: id, name: app.localizedName ?? id)
    }

    private static func outermostAppBundle(_ url: URL) -> URL? {
        var result = URL(fileURLWithPath: "/")
        for component in url.standardizedFileURL.pathComponents.dropFirst() {
            result.appendPathComponent(component)
            if component.hasSuffix(".app") { return result.standardizedFileURL }
        }
        return nil
    }
}
