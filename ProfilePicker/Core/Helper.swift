import AppKit
import Observation

/// Profile Picker runs in the App Sandbox, which strips command-line arguments from apps it launches and
/// blocks reading other apps' data. Both are needed for browser profiles (`--profile-directory`).
///
/// The sanctioned way around this is a script in the app's own Application Scripts folder
/// (`~/Library/Application Scripts/<bundle id>/`): scripts there run outside the sandbox via
/// `NSUserUnixTask`, but only the *user* can put them there. Profile Picker asks the user to confirm that
/// folder in an open panel, then writes the script below into it.
@Observable
final class Helper {
    enum Status: Equatable {
        case notInstalled
        case outdated
        case installed
    }

    static let fileName = "profile-picker-helper.sh"
    static let version = 1

    static let script = """
    #!/bin/sh
    # Profile Picker helper, version \(version)
    #
    # Profile Picker runs in the macOS App Sandbox, which stops it from opening a browser in a
    # specific profile and from reading the browser's profile list. You installed this
    # script from Profile Picker's settings so it can do exactly two things on Profile Picker's behalf:
    #
    #   profiles <data dir> <output file>
    #       Copies the profile list (the "profile.info_cache" part of the browser's
    #       "Local State" file) to <output file>. Nothing else is read.
    #   open <browser app> <profile directory> <url>
    #       Opens <url> in <browser app> using that profile.
    #
    # Deleting this file is safe; Profile Picker then opens links without choosing a profile.
    set -eu

    case "${1:-}" in
      profiles)
        case "$2" in *..*) exit 64 ;; esac
        state="$HOME/Library/Application Support/$2/Local State"
        [ -f "$state" ] || exit 0
        exec /usr/bin/plutil -extract profile.info_cache json -o "$3" "$state"
        ;;
      open)
        exec /usr/bin/open -n -a "$2" --args "--profile-directory=$3" "$4"
        ;;
      version)
        echo \(version)
        ;;
      *)
        exit 64
        ;;
    esac

    """

    enum HelperError: LocalizedError {
        case notInstalled
        case wrongFolder

        var errorDescription: String? {
            switch self {
            case .notInstalled: "The Profile Picker helper is not installed."
            case .wrongFolder: "Please choose the folder Profile Picker preselected (its Application Scripts folder)."
            }
        }
    }

    private(set) var status: Status = .notInstalled

    var scriptsDirectory: URL? {
        try? FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true)
    }

    var scriptURL: URL? {
        scriptsDirectory?.appendingPathComponent(Self.fileName)
    }

    var isUsable: Bool { status != .notInstalled }

    func refreshStatus() {
        guard let url = scriptURL, let installed = try? String(contentsOf: url, encoding: .utf8) else {
            status = .notInstalled
            return
        }
        status = installed == Self.script ? .installed : .outdated
    }

    /// Shows an open panel pointed at the Application Scripts folder and writes the script there.
    @discardableResult
    func install() throws -> Bool {
        guard let directory = scriptsDirectory else { throw HelperError.notInstalled }

        let panel = NSOpenPanel()
        panel.directoryURL = directory
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Install Helper"
        panel.message = "To let Profile Picker open links in browser profiles, click “Install Helper”. "
            + "This puts a small script into Profile Picker’s own scripts folder."

        NSApp.activate()
        guard panel.runModal() == .OK, let chosen = panel.url else { return false }
        guard chosen.resolvingSymlinksInPath().standardizedFileURL.path
                == directory.resolvingSymlinksInPath().standardizedFileURL.path
        else { throw HelperError.wrongFolder }

        let destination = chosen.appendingPathComponent(Self.fileName)
        try Self.script.write(to: destination, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
        refreshStatus()
        return true
    }

    /// Reads the profiles of a Chromium browser. Returns `[]` if the browser has no profile data.
    func profiles(dataDirectory: String) async throws -> [BrowserProfile] {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("profiles-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: output) }

        try await run(["profiles", dataDirectory, output.path])
        guard let data = try? Data(contentsOf: output) else { return [] }
        return ProfileParser.parse(data)
    }

    /// Opens `url` in the browser at `appURL`, using the given profile directory.
    func open(_ url: URL, appURL: URL, profile: String) async throws {
        try await run(["open", appURL.path, profile, url.absoluteString])
    }

    private func run(_ arguments: [String]) async throws {
        guard isUsable, let scriptURL else { throw HelperError.notInstalled }
        let task = try NSUserUnixTask(url: scriptURL)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.execute(withArguments: arguments) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }
}
