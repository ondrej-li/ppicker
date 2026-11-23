import Foundation
import Testing
@testable import ProfilePicker

@Suite struct DirectBrowserAccessTests {
    private let fixture = """
    {
      "profile": {
        "info_cache": {
          "Profile 1": { "name": "Work" },
          "Default": { "name": "Personal", "user_name": "me@example.com" }
        }
      }
    }
    """

    @Test func readsLocalStateFromApplicationSupport() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("profile-picker-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }

        let dataDirectory = try #require(KnownBrowsers.dataDirectory(for: "com.brave.Browser"))
        let browserDirectory = base.appendingPathComponent(dataDirectory)
        try FileManager.default.createDirectory(at: browserDirectory, withIntermediateDirectories: true)
        try Data(fixture.utf8).write(to: browserDirectory.appendingPathComponent("Local State"))

        let profiles = DirectBrowserAccess.profiles(bundleID: "com.brave.Browser", applicationSupport: base)
        #expect(profiles.map(\.directory) == ["Default", "Profile 1"])
        #expect(profiles.map(\.name) == ["Personal", "Work"])
        #expect(profiles.first?.email == "me@example.com")
    }

    @Test func missingFileAndUnsupportedBrowserGiveNoProfiles() {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("profile-picker-test-\(UUID().uuidString)")
        #expect(DirectBrowserAccess.profiles(bundleID: "com.brave.Browser", applicationSupport: base).isEmpty)
        #expect(DirectBrowserAccess.profiles(bundleID: "com.apple.Safari", applicationSupport: base).isEmpty)
    }
}
