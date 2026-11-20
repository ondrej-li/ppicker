import Foundation

/// Where a link should be opened: a browser, optionally in a specific profile.
nonisolated struct Target: Codable, Hashable, Sendable {
    /// Bundle identifier of the browser, e.g. `com.brave.Browser`.
    var bundleID: String
    /// Chromium profile directory, e.g. `Default` or `Profile 1`.
    /// `nil` opens the link the way the browser normally would (its last used profile).
    var profile: String?

    init(bundleID: String, profile: String? = nil) {
        self.bundleID = bundleID
        self.profile = profile
    }
}

/// What to do with a link.
nonisolated enum LinkAction: Codable, Hashable, Sendable {
    case showPicker
    case open(target: Target)
}

/// A single check a link must pass for a rule to apply.
nonisolated struct Condition: Codable, Hashable, Identifiable, Sendable {
    enum Field: String, Codable, CaseIterable, Sendable {
        /// Bundle identifier of the app the link was clicked in, e.g. `com.tinyspeck.slackmacgap`.
        case sourceApp
        /// Host name, e.g. `*.example.com` (also matches `example.com`).
        case host
        /// Whole URL without the scheme, e.g. `github.com/my-org/*`.
        case url
    }

    var id = UUID()
    var field: Field
    /// Wildcard pattern (`*` and `?`). Separate alternatives with commas.
    var pattern: String

    init(field: Field, pattern: String) {
        self.field = field
        self.pattern = pattern
    }
}

/// "When all of these conditions match, do this."
nonisolated struct Rule: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var isEnabled: Bool = true
    var conditions: [Condition]
    var action: LinkAction

    init(name: String, isEnabled: Bool = true, conditions: [Condition], action: LinkAction) {
        self.name = name
        self.isEnabled = isEnabled
        self.conditions = conditions
        self.action = action
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        conditions = try c.decodeIfPresent([Condition].self, forKey: .conditions) ?? []
        action = try c.decodeIfPresent(LinkAction.self, forKey: .action) ?? .showPicker
    }
}

/// Everything the user configures. Persisted as JSON.
nonisolated struct Config: Codable, Equatable, Sendable {
    /// Checked top to bottom; the first enabled rule whose conditions all match wins.
    var rules: [Rule] = []
    /// What happens when no rule matches.
    var fallback: LinkAction = .showPicker
    /// Browsers / profiles not shown in the picker.
    var hiddenTargets: Set<Target> = []
    /// The browser that was the system default before Profile Picker took over.
    var systemBrowserID: String?
    var showMenuBarIcon: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rules = try c.decodeIfPresent([Rule].self, forKey: .rules) ?? []
        fallback = try c.decodeIfPresent(LinkAction.self, forKey: .fallback) ?? .showPicker
        hiddenTargets = try c.decodeIfPresent(Set<Target>.self, forKey: .hiddenTargets) ?? []
        systemBrowserID = try c.decodeIfPresent(String.self, forKey: .systemBrowserID)
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
    }
}

/// The app a link was clicked in.
nonisolated struct SourceApp: Hashable, Sendable {
    var bundleID: String
    var name: String
}

/// A link Profile Picker has been asked to open.
nonisolated struct LinkRequest: Sendable {
    var url: URL
    var source: SourceApp?
    /// The user held ⌥ Option while clicking: always show the picker.
    var forcePicker: Bool = false
}

/// A browser profile, read from the browser's `Local State` file.
nonisolated struct BrowserProfile: Hashable, Identifiable, Sendable {
    var id: String { directory }
    /// Directory name inside the browser's data folder, e.g. `Profile 1`. Stable across renames.
    var directory: String
    /// Name shown in the browser, e.g. `Work`.
    var name: String
    var email: String?
    /// Profile color as 0xAARRGGBB, when the browser stores one.
    var colorARGB: UInt32?
}
