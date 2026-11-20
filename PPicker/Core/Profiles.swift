import Foundation

/// Chromium-based browsers that accept `--profile-directory`, and where they keep their data.
nonisolated enum KnownBrowsers {
    /// Bundle identifier → user data directory, relative to `~/Library/Application Support`.
    /// Pull requests adding more browsers are welcome.
    static let chromiumDataDirectories: [String: String] = [
        "com.google.Chrome": "Google/Chrome",
        "com.google.Chrome.beta": "Google/Chrome Beta",
        "com.google.Chrome.dev": "Google/Chrome Dev",
        "com.google.Chrome.canary": "Google/Chrome Canary",
        "org.chromium.Chromium": "Chromium",
        "com.brave.Browser": "BraveSoftware/Brave-Browser",
        "com.brave.Browser.beta": "BraveSoftware/Brave-Browser-Beta",
        "com.brave.Browser.nightly": "BraveSoftware/Brave-Browser-Nightly",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.microsoft.edgemac.Beta": "Microsoft Edge Beta",
        "com.microsoft.edgemac.Dev": "Microsoft Edge Dev",
        "com.microsoft.edgemac.Canary": "Microsoft Edge Canary",
        "com.vivaldi.Vivaldi": "Vivaldi",
    ]

    static func dataDirectory(for bundleID: String) -> String? {
        chromiumDataDirectories[bundleID]
    }

    static func supportsProfiles(_ bundleID: String) -> Bool {
        chromiumDataDirectories[bundleID] != nil
    }
}

/// Reads the profile list from a Chromium `Local State` file.
nonisolated enum ProfileParser {
    /// Accepts either the whole `Local State` JSON or just its `profile.info_cache` object.
    static func parse(_ data: Data) -> [BrowserProfile] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let cache = ((root["profile"] as? [String: Any])?["info_cache"] as? [String: Any]) ?? root

        let profiles: [BrowserProfile] = cache.compactMap { directory, value in
            guard let info = value as? [String: Any] else { return nil }
            let name = nonEmpty(info["name"]) ?? nonEmpty(info["gaia_name"]) ?? directory
            let color = argb(info["profile_highlight_color"]) ?? argb(info["default_avatar_fill_color"])
            return BrowserProfile(directory: directory, name: name, email: nonEmpty(info["user_name"]), colorARGB: color)
        }
        return profiles.sorted { sortKey($0.directory) < sortKey($1.directory) }
    }

    /// `Default` first, then `Profile 1`, `Profile 2`, … in numeric order, then anything else.
    private static func sortKey(_ directory: String) -> (Int, Int, String) {
        if directory == "Default" { return (0, 0, directory) }
        if directory.hasPrefix("Profile "), let n = Int(directory.dropFirst("Profile ".count)) { return (1, n, directory) }
        return (2, 0, directory)
    }

    private static func nonEmpty(_ value: Any?) -> String? {
        guard let s = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    /// Chromium stores colors as signed 32-bit ARGB integers.
    private static func argb(_ value: Any?) -> UInt32? {
        guard let number = value as? NSNumber else { return nil }
        return UInt32(truncatingIfNeeded: number.int64Value)
    }
}
