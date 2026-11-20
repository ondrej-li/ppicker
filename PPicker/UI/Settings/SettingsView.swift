import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    @State private var section: Section? = .general

    enum Section: String, CaseIterable, Identifiable {
        case general, browsers, rules
        var id: Self { self }

        var title: String {
            switch self {
            case .general: "General"
            case .browsers: "Browsers"
            case .rules: "Rules"
            }
        }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .browsers: "globe"
            case .rules: "arrow.triangle.branch"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $section) { section in
                Label(section.title, systemImage: section.icon).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 220)
        } detail: {
            switch section ?? .general {
            case .general: GeneralSettingsView(state: state)
            case .browsers: BrowsersSettingsView(state: state)
            case .rules: RulesSettingsView(state: state)
            }
        }
    }
}

/// Menu items for choosing what to do with a link: "Show the picker" or any browser / profile.
struct ActionPickerItems: View {
    let catalog: BrowserCatalog
    /// The current selection; listed even if that browser or profile is not available right now.
    let current: LinkAction

    var body: some View {
        Text("Show the picker").tag(LinkAction.showPicker)
        if case .open(let target) = current, catalog.option(for: target) == nil {
            Text("\(catalog.displayName(for: target)) (not available)").tag(current)
        }
        ForEach(catalog.browsers) { browser in
            Divider()
            Text(browser.supportsProfiles && !browser.profiles.isEmpty
                 ? "\(browser.name) (last used profile)" : browser.name)
                .tag(LinkAction.open(target: Target(bundleID: browser.bundleID)))
            ForEach(browser.profiles) { profile in
                Text("\(browser.name) — \(profile.name)")
                    .tag(LinkAction.open(target: Target(bundleID: browser.bundleID, profile: profile.directory)))
            }
        }
    }
}

extension AppState {
    /// Short description of an action, e.g. "Brave Browser — work".
    func describe(_ action: LinkAction) -> String {
        switch action {
        case .showPicker: "Show the picker"
        case .open(let target): catalog.displayName(for: target)
        }
    }
}
