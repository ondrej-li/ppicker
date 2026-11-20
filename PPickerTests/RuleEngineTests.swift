import Foundation
import Testing
@testable import PPicker

@Suite struct GlobTests {
    @Test func wildcards() {
        #expect(Glob.matches("*", "anything"))
        #expect(Glob.matches("github.com/org/*", "github.com/org/repo/pull/1"))
        #expect(!Glob.matches("github.com/org/*", "github.com/other/repo"))
        #expect(Glob.matches("a?c", "abc"))
        #expect(!Glob.matches("a?c", "ac"))
        #expect(Glob.matches("*.example.com", "docs.example.com"))
        #expect(!Glob.matches("*.example.com", "example.org"))
        #expect(Glob.matches("*mid*", "has-mid-in-it"))
    }

    @Test func caseInsensitive() {
        #expect(Glob.matches("GitHub.com", "github.COM"))
    }

    @Test func wildcardSubdomainAlsoMatchesApex() {
        #expect(Glob.matchesHost("*.example.com", "example.com"))
        #expect(Glob.matchesHost("*.example.com", "a.b.example.com"))
        #expect(!Glob.matchesHost("*.example.com", "notexample.com"))
    }
}

@Suite struct RuleEngineTests {
    let brave = Target(bundleID: "com.brave.Browser", profile: "Profile 1")
    let chrome = Target(bundleID: "com.google.Chrome")

    func rule(_ name: String, _ conditions: [Condition], _ target: Target, enabled: Bool = true) -> Rule {
        Rule(name: name, isEnabled: enabled, conditions: conditions, action: .open(target: target))
    }

    @Test func urlKeyDropsScheme() {
        #expect(RuleEngine.urlKey(URL(string: "https://github.com/org/repo?x=1")!) == "github.com/org/repo?x=1")
    }

    @Test func fallbackWhenNothingMatches() {
        var config = Config()
        config.fallback = .open(target: chrome)
        let decision = RuleEngine.decide(url: URL(string: "https://example.com")!, sourceBundleID: nil, config: config)
        #expect(decision.action == .open(target: chrome))
        #expect(decision.rule == nil)
    }

    @Test func firstMatchingRuleWins() {
        var config = Config()
        config.rules = [
            rule("disabled", [Condition(field: .host, pattern: "*")], chrome, enabled: false),
            rule("work", [Condition(field: .host, pattern: "*.corp.com")], brave),
            rule("all", [Condition(field: .host, pattern: "*")], chrome),
        ]
        #expect(RuleEngine.decide(url: URL(string: "https://wiki.corp.com/x")!, sourceBundleID: nil, config: config).rule?.name == "work")
        #expect(RuleEngine.decide(url: URL(string: "https://other.com")!, sourceBundleID: nil, config: config).rule?.name == "all")
    }

    @Test func allConditionsMustMatch() {
        let slackWork = rule("slack work", [
            Condition(field: .sourceApp, pattern: "com.tinyspeck.slackmacgap"),
            Condition(field: .url, pattern: "https://github.com/corp/*"),
        ], brave)
        let rules = [slackWork]
        let url = URL(string: "https://github.com/corp/repo")!
        #expect(RuleEngine.firstMatch(url: url, sourceBundleID: "com.tinyspeck.slackmacgap", rules: rules) != nil)
        #expect(RuleEngine.firstMatch(url: url, sourceBundleID: "com.apple.mail", rules: rules) == nil)
        #expect(RuleEngine.firstMatch(url: url, sourceBundleID: nil, rules: rules) == nil)
        #expect(RuleEngine.firstMatch(url: URL(string: "https://github.com/me/repo")!,
                                      sourceBundleID: "com.tinyspeck.slackmacgap", rules: rules) == nil)
    }

    @Test func commaSeparatedAlternatives() {
        let rules = [rule("apps", [Condition(field: .sourceApp, pattern: "com.a, com.b")], brave)]
        let url = URL(string: "https://x.com")!
        #expect(RuleEngine.firstMatch(url: url, sourceBundleID: "com.b", rules: rules) != nil)
        #expect(RuleEngine.firstMatch(url: url, sourceBundleID: "com.c", rules: rules) == nil)
    }

    @Test func emptyRulesAndPatternsNeverMatch() {
        let url = URL(string: "https://x.com")!
        #expect(RuleEngine.firstMatch(url: url, sourceBundleID: "a", rules: [rule("none", [], brave)]) == nil)
        #expect(RuleEngine.firstMatch(url: url, sourceBundleID: "a",
                                      rules: [rule("blank", [Condition(field: .host, pattern: " ")], brave)]) == nil)
    }
}

@Suite struct ProfileParserTests {
    let fixture = """
    {
      "profile": {
        "last_used": "Default",
        "info_cache": {
          "Profile 10": { "name": "Ten" },
          "Profile 2": { "name": "", "gaia_name": "Gaia Two" },
          "Default": { "name": "def", "user_name": "me@example.com", "profile_highlight_color": -15326446 },
          "Profile 1": { "name": "work", "default_avatar_fill_color": -16777216 }
        }
      }
    }
    """

    @Test func parsesFullLocalState() {
        let profiles = ProfileParser.parse(Data(fixture.utf8))
        #expect(profiles.map(\.directory) == ["Default", "Profile 1", "Profile 2", "Profile 10"])
        #expect(profiles[0].name == "def")
        #expect(profiles[0].email == "me@example.com")
        #expect(profiles[0].colorARGB == UInt32(truncatingIfNeeded: Int64(-15326446)))
        #expect(profiles[1].colorARGB == 0xFF00_0000)
        #expect(profiles[2].name == "Gaia Two")
        #expect(profiles[3].email == nil)
    }

    @Test func parsesInfoCacheOnly() {
        let data = Data(#"{ "Default": { "name": "solo" } }"#.utf8)
        #expect(ProfileParser.parse(data).map(\.name) == ["solo"])
    }

    @Test func garbageGivesNoProfiles() {
        #expect(ProfileParser.parse(Data("not json".utf8)).isEmpty)
    }
}

@Suite struct ConfigTests {
    @Test func roundTrip() throws {
        var config = Config()
        config.fallback = .open(target: Target(bundleID: "com.brave.Browser", profile: "Profile 1"))
        config.rules = [Rule(name: "r", conditions: [Condition(field: .host, pattern: "*.x.com")], action: .showPicker)]
        config.hiddenTargets = [Target(bundleID: "com.apple.Safari")]
        let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        #expect(decoded == config)
    }

    @Test func missingKeysUseDefaults() throws {
        let decoded = try JSONDecoder().decode(Config.self, from: Data(#"{ "rules": [] }"#.utf8))
        #expect(decoded.fallback == .showPicker)
        #expect(decoded.showMenuBarIcon)
    }
}
