import SwiftUI

struct BrowsersSettingsView: View {
    @Bindable var state: AppState
    @State private var installError: String?

    private var hasProfileBrowsers: Bool {
        state.catalog.browsers.contains(where: \.supportsProfiles)
    }

    var body: some View {
        Form {
            if hasProfileBrowsers {
                Section {
                    helperRow
                } header: {
                    Text("Browser profiles")
                } footer: {
                    Text("macOS doesn’t let App Store apps open a browser in a particular profile. A tiny helper script, "
                         + "which you install into Profile Picker’s own scripts folder, does this for Profile Picker. "
                         + "It can only read the browser’s list of profiles and open links.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(state.catalog.browsers) { browser in
                Section {
                    if browser.profiles.isEmpty {
                        visibilityToggle(TargetOption(target: Target(bundleID: browser.bundleID), title: "Show in picker"))
                    } else {
                        ForEach(browser.profiles) { profile in
                            visibilityToggle(TargetOption(
                                target: Target(bundleID: browser.bundleID, profile: profile.directory),
                                title: profile.name,
                                subtitle: profile.email,
                                colorARGB: profile.colorARGB
                            ))
                        }
                    }
                } header: {
                    HStack(spacing: 8) {
                        Image(nsImage: state.catalog.icon(for: browser.bundleID))
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(browser.name)
                    }
                }
            }

            if state.catalog.browsers.isEmpty && !state.catalog.isRefreshing {
                Text("No browsers found.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Browsers")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await state.refreshBrowsers() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Look for browsers and profiles again")
                .disabled(state.catalog.isRefreshing)
            }
        }
        .alert("Couldn’t install the helper", isPresented: Binding(
            get: { installError != nil },
            set: { if !$0 { installError = nil } }
        )) {
            Button("OK") { installError = nil }
        } message: {
            Text(installError ?? "")
        }
    }

    @ViewBuilder
    private var helperRow: some View {
        HStack {
            switch state.helper.status {
            case .installed:
                Label("Helper installed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .outdated:
                Label("A newer helper is available", systemImage: "arrow.down.circle")
                    .foregroundStyle(.orange)
            case .notInstalled:
                Label("Helper not installed: profiles aren’t available", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
            }
            Spacer()
            if state.helper.status != .installed {
                Button(state.helper.status == .outdated ? "Update Helper…" : "Install Helper…") {
                    installHelper()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func installHelper() {
        do {
            if try state.helper.install() {
                Task { await state.refreshBrowsers() }
            }
        } catch {
            installError = error.localizedDescription
        }
    }

    private func visibilityToggle(_ option: TargetOption) -> some View {
        Toggle(isOn: Binding(
            get: { !state.config.hiddenTargets.contains(option.target) },
            set: { visible in
                if visible {
                    state.config.hiddenTargets.remove(option.target)
                } else {
                    state.config.hiddenTargets.insert(option.target)
                }
            }
        )) {
            HStack(spacing: 10) {
                if option.target.profile != nil {
                    TargetAvatar(option: option, catalog: state.catalog, size: 24)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(option.title)
                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
