import Foundation

/// Whether the app is running inside the App Sandbox. Developer builds (Debug and Release) are not;
/// the App Store configuration is, because App Review requires the sandbox.
nonisolated enum AppSandbox {
    static let isEnabled: Bool = {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
            || FileManager.default.homeDirectoryForCurrentUser.path.contains("/Library/Containers/")
    }()
}

/// Direct profile support for builds that run outside the App Sandbox.
///
/// The App Store build cannot pass `--profile-directory` to a browser or read another app's data, so
/// it uses the installed helper script. A developer build can do both itself, which means it works
/// without installing anything.
nonisolated enum DirectBrowserAccess {
    static let defaultApplicationSupport = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support")

    static func profiles(bundleID: String, applicationSupport: URL = defaultApplicationSupport) -> [BrowserProfile] {
        guard let dataDirectory = KnownBrowsers.dataDirectory(for: bundleID) else { return [] }
        let file = applicationSupport
            .appendingPathComponent(dataDirectory)
            .appendingPathComponent("Local State")
        guard let data = try? Data(contentsOf: file) else { return [] }
        return ProfileParser.parse(data)
    }

    static func open(_ url: URL, appURL: URL, profile: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", "-a", appURL.path, "--args", "--profile-directory=\(profile)", url.absoluteString]
        try process.run()
    }
}
