import AppKit
import Observation
import UniformTypeIdentifiers

/// An installed web browser.
struct Browser: Identifiable, Hashable {
    var id: String { bundleID }
    var bundleID: String
    var name: String
    var appURL: URL
    /// Profiles, for Chromium browsers when the helper is installed. Empty otherwise.
    var profiles: [BrowserProfile]

    var supportsProfiles: Bool { KnownBrowsers.supportsProfiles(bundleID) }
}

/// One choice in the picker, or in a "Open in" menu.
struct TargetOption: Identifiable, Hashable {
    var id: Target { target }
    var target: Target
    /// "work" for a profile, "Brave Browser" for a plain browser.
    var title: String
    /// "Brave Browser" for a profile, `nil` for a plain browser.
    var subtitle: String?
    var colorARGB: UInt32?
}

/// Finds installed browsers and their profiles.
@Observable
final class BrowserCatalog {
    private(set) var browsers: [Browser] = []
    private(set) var isRefreshing = false

    @ObservationIgnored private var iconCache: [String: NSImage] = [:]
    @ObservationIgnored private var appNameCache: [String: String] = [:]

    func refresh(helper: Helper) async {
        isRefreshing = true
        defer { isRefreshing = false }

        var found = Self.installedBrowsers()
        if helper.isUsable {
            for index in found.indices {
                guard let dataDirectory = KnownBrowsers.dataDirectory(for: found[index].bundleID) else { continue }
                found[index].profiles = (try? await helper.profiles(dataDirectory: dataDirectory)) ?? []
            }
        }
        browsers = found
    }

    func browser(_ bundleID: String) -> Browser? {
        browsers.first { $0.bundleID == bundleID }
    }

    /// Every target the user can choose: each browser, plus each profile of a Chromium browser.
    /// Ordered with `firstBrowserID` (usually the previous system browser) first.
    func allOptions(firstBrowserID: String?) -> [TargetOption] {
        ordered(firstBrowserID: firstBrowserID).flatMap { browser -> [TargetOption] in
            let plain = TargetOption(target: Target(bundleID: browser.bundleID), title: browser.name)
            let profiles = browser.profiles.map {
                TargetOption(target: Target(bundleID: browser.bundleID, profile: $0.directory),
                             title: $0.name, subtitle: browser.name, colorARGB: $0.colorARGB)
            }
            return [plain] + profiles
        }
    }

    /// What the picker shows: profiles instead of the plain browser when a browser has profiles.
    func pickerOptions(firstBrowserID: String?, hidden: Set<Target>) -> [TargetOption] {
        allOptions(firstBrowserID: firstBrowserID).filter { option in
            if hidden.contains(option.target) { return false }
            if option.target.profile == nil, let browser = browser(option.target.bundleID), !browser.profiles.isEmpty {
                return false
            }
            return true
        }
    }

    func option(for target: Target) -> TargetOption? {
        allOptions(firstBrowserID: nil).first { $0.target == target }
    }

    /// Human readable name, e.g. "Brave Browser — work". Works for browsers that are not installed.
    func displayName(for target: Target) -> String {
        let browserName = browser(target.bundleID)?.name ?? appName(for: target.bundleID)
        guard let directory = target.profile else { return browserName }
        let profileName = browser(target.bundleID)?.profiles.first { $0.directory == directory }?.name ?? directory
        return "\(browserName) — \(profileName)"
    }

    func icon(for bundleID: String) -> NSImage {
        if let cached = iconCache[bundleID] { return cached }
        let icon: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSWorkspace.shared.icon(for: .applicationBundle)
        }
        iconCache[bundleID] = icon
        return icon
    }

    /// Name of any app by bundle identifier (falls back to the identifier itself).
    func appName(for bundleID: String) -> String {
        if let cached = appNameCache[bundleID] { return cached }
        var name = bundleID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            name = Self.displayName(of: url)
        }
        appNameCache[bundleID] = name
        return name
    }

    private func ordered(firstBrowserID: String?) -> [Browser] {
        guard let firstBrowserID, let first = browsers.firstIndex(where: { $0.bundleID == firstBrowserID }) else {
            return browsers
        }
        var result = browsers
        result.insert(result.remove(at: first), at: 0)
        return result
    }

    // MARK: - Discovery

    /// Apps that open both `https` links and HTML files, i.e. real browsers (not every app that
    /// happens to claim `https`), excluding Profile Picker itself and copies in caches or hidden folders.
    /// Apps that register for web links and HTML files but aren't browsers.
    static let notBrowsers: Set<String> = [
        "com.googlecode.iterm2",
    ]

    static func installedBrowsers() -> [Browser] {
        let workspace = NSWorkspace.shared
        let httpsHandlers = workspace.urlsForApplications(toOpen: URL(string: "https://example.com")!)
        let htmlHandlers = Set(workspace.urlsForApplications(toOpen: .html).map(\.standardizedFileURL))
        let ownID = Bundle.main.bundleIdentifier

        var seen = Set<String>()
        var result: [Browser] = []
        for url in httpsHandlers {
            guard htmlHandlers.contains(url.standardizedFileURL),
                  !url.pathComponents.contains(where: { $0.hasPrefix(".") || $0 == "Caches" }),
                  let bundleID = Bundle(url: url)?.bundleIdentifier,
                  bundleID != ownID,
                  !notBrowsers.contains(bundleID),
                  seen.insert(bundleID).inserted
            else { continue }
            // Prefer the copy Launch Services itself would use.
            let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) ?? url
            result.append(Browser(bundleID: bundleID, name: displayName(of: appURL), appURL: appURL, profiles: []))
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func displayName(of appURL: URL) -> String {
        let name = FileManager.default.displayName(atPath: appURL.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}
