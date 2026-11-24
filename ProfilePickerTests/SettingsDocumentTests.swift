import Foundation
import Testing
@testable import ProfilePicker

@Suite struct SettingsDocumentTests {
    private func sampleConfig() -> Config {
        var config = Config()
        config.fallback = .open(target: Target(bundleID: "com.brave.Browser", profile: "Profile 1"))
        config.rules = [
            Rule(
                name: "GitHub",
                conditions: [Condition(field: .host, pattern: "*.github.com")],
                action: .open(target: Target(bundleID: "com.google.Chrome"))
            ),
            Rule(
                name: "Slack",
                conditions: [Condition(field: .sourceApp, pattern: "com.tinyspeck.slackmacgap")],
                action: .showPicker
            ),
        ]
        config.hiddenTargets = [
            Target(bundleID: "com.brave.Browser", profile: "Profile 2"),
            Target(bundleID: "com.apple.Safari"),
        ]
        config.showMenuBarIcon = false
        config.systemBrowserID = "com.apple.Safari"
        return config
    }

    @Test func roundTripKeepsPortableSettings() throws {
        let config = sampleConfig()
        let data = try SettingsDocument.make(
            config: config,
            exportedAt: Date(timeIntervalSince1970: 0),
            generator: "Profile Picker test"
        ).encoded()

        let snapshot = try SettingsDocument.decode(data)
        #expect(snapshot.rules == config.rules)
        #expect(snapshot.fallback == config.fallback)
        #expect(Set(snapshot.hiddenTargets) == config.hiddenTargets)
        #expect(snapshot.showMenuBarIcon == false)
    }

    @Test func exportWritesAVersionedEnvelopeWithoutTheSystemBrowser() throws {
        let data = try SettingsDocument.make(config: sampleConfig()).encoded()
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["format"] as? String == SettingsDocument.format)
        #expect(object["version"] as? Int == SettingsDocument.currentVersion)
        #expect(!String(decoding: data, as: UTF8.self).contains("systemBrowserID"))
    }

    @Test func applyingKeepsTheCurrentSystemBrowser() {
        var current = Config()
        current.systemBrowserID = "com.apple.Safari"

        let applied = SettingsSnapshot(config: sampleConfig()).applied(to: current)
        #expect(applied.systemBrowserID == "com.apple.Safari")
    }

    @Test func applyingRegeneratesRuleAndConditionIdentities() {
        var config = Config()
        let duplicateID = UUID()
        var first = Rule(name: "One", conditions: [Condition(field: .host, pattern: "one.example")], action: .showPicker)
        first.id = duplicateID
        var second = Rule(name: "Two", conditions: [Condition(field: .host, pattern: "two.example")], action: .showPicker)
        second.id = duplicateID
        config.rules = [first, second]

        let applied = SettingsSnapshot(config: config).applied(to: Config())
        #expect(Set(applied.rules.map(\.id)).count == 2)
        let conditionIDs = applied.rules.flatMap(\.conditions).map(\.id)
        #expect(Set(conditionIDs).count == conditionIDs.count)
        #expect(applied.rules.map(\.name) == ["One", "Two"])
    }

    @Test func importTrimsIdentifiersAndPatterns() throws {
        let json = """
        {
          "format": "cz.ondralinek.ppicker.settings",
          "version": 1,
          "settings": {
            "fallback": {"open": {"target": {"bundleID": " com.brave.Browser ", "profile": " Profile 1 "}}},
            "rules": [{
              "name": "  Work  ",
              "conditions": [{"field": "host", "pattern": "  *.example.com  "}],
              "action": {"open": {"target": {"bundleID": " com.google.Chrome ", "profile": ""}}}
            }],
            "hiddenTargets": [{"bundleID": " com.apple.Safari "}]
          }
        }
        """

        let applied = try SettingsDocument.decode(Data(json.utf8)).applied(to: Config())
        #expect(applied.rules.first?.name == "Work")
        #expect(applied.rules.first?.conditions.first?.pattern == "*.example.com")
        #expect(applied.fallback == .open(target: Target(bundleID: "com.brave.Browser", profile: "Profile 1")))
        #expect(applied.rules.first?.action == .open(target: Target(bundleID: "com.google.Chrome")))
        #expect(applied.hiddenTargets == [Target(bundleID: "com.apple.Safari")])
    }

    @Test func acceptsMissingOptionalSettingsFields() throws {
        let json = """
        {
          "format": "cz.ondralinek.ppicker.settings",
          "version": 1,
          "settings": {}
        }
        """

        let snapshot = try SettingsDocument.decode(Data(json.utf8))
        #expect(snapshot.rules.isEmpty)
        #expect(snapshot.fallback == .showPicker)
        #expect(snapshot.hiddenTargets.isEmpty)
        #expect(snapshot.showMenuBarIcon)
    }

    @Test func rejectsMalformedJSON() {
        #expect(throws: SettingsDocumentError.invalidJSON) {
            _ = try SettingsDocument.decode(Data("not json".utf8))
        }
    }

    @Test func rejectsOtherJSON() {
        let data = Data(#"{"format":"something.else","version":1,"settings":{}}"#.utf8)
        #expect(throws: SettingsDocumentError.notSettingsFile) {
            _ = try SettingsDocument.decode(data)
        }
    }

    @Test func rejectsANewerVersion() throws {
        let data = try SettingsDocument.make(config: Config()).encoded()
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["version"] = SettingsDocument.currentVersion + 1
        let newer = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: SettingsDocumentError.unsupportedVersion(SettingsDocument.currentVersion + 1)) {
            _ = try SettingsDocument.decode(newer)
        }
    }

    @Test func rejectsANewerVersionBeforeDecodingItsSettings() {
        let json = """
        {
          "format": "cz.ondralinek.ppicker.settings",
          "version": 2,
          "settings": "a shape this build does not know"
        }
        """

        #expect(throws: SettingsDocumentError.unsupportedVersion(2)) {
            _ = try SettingsDocument.decode(Data(json.utf8))
        }
    }

    @Test func rejectsBlankTargets() {
        let json = """
        {
          "format": "cz.ondralinek.ppicker.settings",
          "version": 1,
          "settings": {
            "fallback": {"open": {"target": {"bundleID": "   "}}}
          }
        }
        """

        #expect(throws: SettingsDocumentError.invalidTarget) {
            _ = try SettingsDocument.decode(Data(json.utf8))
        }
    }
}
