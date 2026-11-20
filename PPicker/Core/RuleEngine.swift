import Foundation

/// Decides what to do with a link. Pure logic, no UI, no side effects.
nonisolated enum RuleEngine {
    struct Decision: Equatable {
        var action: LinkAction
        /// The rule that matched, or `nil` when the fallback was used.
        var rule: Rule?
    }

    static func decide(url: URL, sourceBundleID: String?, config: Config) -> Decision {
        if let rule = firstMatch(url: url, sourceBundleID: sourceBundleID, rules: config.rules) {
            return Decision(action: rule.action, rule: rule)
        }
        return Decision(action: config.fallback, rule: nil)
    }

    static func firstMatch(url: URL, sourceBundleID: String?, rules: [Rule]) -> Rule? {
        rules.first { rule in
            rule.isEnabled
                && !rule.conditions.isEmpty   // a rule without conditions never matches
                && rule.conditions.allSatisfy { matches($0, url: url, sourceBundleID: sourceBundleID) }
        }
    }

    static func matches(_ condition: Condition, url: URL, sourceBundleID: String?) -> Bool {
        let alternatives = condition.pattern
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !alternatives.isEmpty else { return false }

        switch condition.field {
        case .sourceApp:
            guard let sourceBundleID else { return false }
            return alternatives.contains { Glob.matches($0, sourceBundleID) }
        case .host:
            guard let host = url.host(percentEncoded: false), !host.isEmpty else { return false }
            return alternatives.contains { Glob.matchesHost($0, host) }
        case .url:
            let key = urlKey(url)
            return alternatives.contains { Glob.matches(stripScheme($0), key) }
        }
    }

    /// The URL without its scheme, e.g. `github.com/org/repo?tab=1`.
    static func urlKey(_ url: URL) -> String {
        stripScheme(url.absoluteString)
    }

    private static func stripScheme(_ string: String) -> String {
        guard let range = string.range(of: "://"),
              string[string.startIndex..<range.lowerBound].allSatisfy({ $0.isLetter || $0.isNumber || "+-.".contains($0) })
        else { return string }
        return String(string[range.upperBound...])
    }
}

/// Case-insensitive wildcard matching: `*` matches any run of characters, `?` matches one.
nonisolated enum Glob {
    static func matches(_ pattern: String, _ text: String) -> Bool {
        let p = Array(pattern.lowercased())
        let t = Array(text.lowercased())
        var pi = 0, ti = 0
        var starIndex = -1, starMatch = 0

        while ti < t.count {
            if pi < p.count, p[pi] == "*" {
                starIndex = pi
                starMatch = ti
                pi += 1
            } else if pi < p.count, p[pi] == "?" || p[pi] == t[ti] {
                pi += 1
                ti += 1
            } else if starIndex >= 0 {
                pi = starIndex + 1
                starMatch += 1
                ti = starMatch
            } else {
                return false
            }
        }
        while pi < p.count, p[pi] == "*" { pi += 1 }
        return pi == p.count
    }

    /// Like `matches`, but `*.example.com` also matches `example.com` itself.
    static func matchesHost(_ pattern: String, _ host: String) -> Bool {
        if pattern.hasPrefix("*."), host.lowercased() == pattern.dropFirst(2).lowercased() {
            return true
        }
        return matches(pattern, host)
    }
}
