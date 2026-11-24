import Foundation

/// A portable snapshot of the settings that can be moved between Macs.
///
/// `Config.systemBrowserID` is deliberately absent: it records the browser that was the system
/// default on *this* Mac, not a preference. `applied(to:)` keeps the current value.
nonisolated struct SettingsSnapshot: Codable, Equatable, Sendable {
    var rules: [Rule]
    var fallback: LinkAction
    var hiddenTargets: [Target]
    var showMenuBarIcon: Bool

    init(config: Config) {
        rules = config.rules
        fallback = config.fallback
        hiddenTargets = config.hiddenTargets.sorted {
            if $0.bundleID != $1.bundleID { return $0.bundleID < $1.bundleID }
            return ($0.profile ?? "") < ($1.profile ?? "")
        }
        showMenuBarIcon = config.showMenuBarIcon
    }

    init(
        rules: [Rule] = [],
        fallback: LinkAction = .showPicker,
        hiddenTargets: [Target] = [],
        showMenuBarIcon: Bool = true
    ) {
        self.rules = rules
        self.fallback = fallback
        self.hiddenTargets = hiddenTargets
        self.showMenuBarIcon = showMenuBarIcon
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rules = try c.decodeIfPresent([Rule].self, forKey: .rules) ?? []
        fallback = try c.decodeIfPresent(LinkAction.self, forKey: .fallback) ?? .showPicker
        hiddenTargets = try c.decodeIfPresent([Target].self, forKey: .hiddenTargets) ?? []
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
    }

    func validate() throws {
        if case .open(let target) = fallback, Self.isBlank(target) {
            throw SettingsDocumentError.invalidTarget
        }
        for rule in rules {
            if case .open(let target) = rule.action, Self.isBlank(target) {
                throw SettingsDocumentError.invalidTarget
            }
        }
        if hiddenTargets.contains(where: Self.isBlank) {
            throw SettingsDocumentError.invalidTarget
        }
    }

    /// Applies the portable fields to `config` and keeps the machine-local previous default browser.
    ///
    /// Rule and condition identities are regenerated so a hand-edited file with duplicate IDs cannot
    /// confuse SwiftUI's `ForEach`.
    func applied(to config: Config) -> Config {
        var result = config
        result.rules = rules.map { Self.imported($0) }
        result.fallback = Self.normalized(fallback)
        result.hiddenTargets = Set(hiddenTargets.map { Self.normalized($0) })
        result.showMenuBarIcon = showMenuBarIcon
        return result
    }

    private static func isBlank(_ target: Target) -> Bool {
        target.bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func imported(_ rule: Rule) -> Rule {
        var copy = rule
        copy.id = UUID()
        copy.name = rule.name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.action = normalized(rule.action)
        copy.conditions = rule.conditions.map { condition in
            var copy = condition
            copy.id = UUID()
            copy.pattern = condition.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
            return copy
        }
        return copy
    }

    private static func normalized(_ action: LinkAction) -> LinkAction {
        switch action {
        case .showPicker:
            return .showPicker
        case .open(let target):
            return .open(target: normalized(target))
        }
    }

    private static func normalized(_ target: Target) -> Target {
        let profile = target.profile?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Target(
            bundleID: target.bundleID.trimmingCharacters(in: .whitespacesAndNewlines),
            profile: profile?.isEmpty == true ? nil : profile
        )
    }
}

/// The JSON envelope written by “Export Settings…”.
///
/// The envelope lets an import tell a settings file from arbitrary JSON and reject files from a
/// future version instead of silently dropping fields it does not understand.
nonisolated struct SettingsDocument: Codable, Equatable, Sendable {
    static let format = "cz.ondralinek.ppicker.settings"
    static let currentVersion = 1

    var format: String
    var version: Int
    var exportedAt: Date
    var generator: String?
    var settings: SettingsSnapshot

    init(
        settings: SettingsSnapshot,
        exportedAt: Date = Date(),
        generator: String? = nil
    ) {
        self.format = Self.format
        self.version = Self.currentVersion
        self.exportedAt = exportedAt
        self.generator = generator
        self.settings = settings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decode(String.self, forKey: .format)
        version = try c.decode(Int.self, forKey: .version)
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        generator = try c.decodeIfPresent(String.self, forKey: .generator)
        settings = try c.decode(SettingsSnapshot.self, forKey: .settings)
    }

    static func make(
        config: Config,
        exportedAt: Date = Date(),
        generator: String? = nil
    ) -> SettingsDocument {
        SettingsDocument(
            settings: SettingsSnapshot(config: config),
            exportedAt: exportedAt,
            generator: generator
        )
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(self)
        data.append(0x0A)
        return data
    }

    static func decode(_ data: Data) throws -> SettingsSnapshot {
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw SettingsDocumentError.invalidJSON
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Read the envelope before the settings: a file from a newer version may use a shape this
        // build cannot decode, and “update the app” is a more useful message than “not a settings file”.
        let header: Header
        do {
            header = try decoder.decode(Header.self, from: data)
        } catch {
            throw SettingsDocumentError.notSettingsFile
        }
        guard header.format == Self.format else {
            throw SettingsDocumentError.notSettingsFile
        }
        guard header.version == Self.currentVersion else {
            throw SettingsDocumentError.unsupportedVersion(header.version)
        }

        let document: SettingsDocument
        do {
            document = try decoder.decode(SettingsDocument.self, from: data)
        } catch {
            throw SettingsDocumentError.notSettingsFile
        }
        try document.settings.validate()
        return document.settings
    }

    private struct Header: Decodable {
        var format: String
        var version: Int
    }
}

nonisolated enum SettingsDocumentError: LocalizedError, Equatable, Sendable {
    case invalidJSON
    case notSettingsFile
    case unsupportedVersion(Int)
    case invalidTarget

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "The file is not valid JSON."
        case .notSettingsFile:
            "The file is not a Profile Picker settings file."
        case .unsupportedVersion(let version):
            "This settings file uses format version \(version), but this build understands version "
                + "\(SettingsDocument.currentVersion). Update Profile Picker and try again."
        case .invalidTarget:
            "The settings file contains a rule or fallback without a browser."
        }
    }
}
