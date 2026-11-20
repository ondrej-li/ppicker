import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var state: AppState
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Default browser") {
                HStack {
                    if state.isDefaultBrowser {
                        Label("Profile Picker is your default browser", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Profile Picker is not your default browser yet", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    if !state.isDefaultBrowser {
                        Button("Make Default Browser") {
                            Task { await state.makeDefaultBrowser() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Text("Links you click in other apps go to Profile Picker, which opens them according to your rules.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let error = state.defaultBrowserError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Picker("Open links with", selection: $state.config.fallback) {
                    ActionPickerItems(catalog: state.catalog, current: state.config.fallback)
                }
            } header: {
                Text("When no rule matches")
            } footer: {
                Text("Choose a browser without a profile to open links the way that browser normally would. "
                     + "Hold ⌥ Option while clicking a link to always show the picker.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        state.launchAtLogin = newValue
                        launchAtLogin = state.launchAtLogin
                    }
                Toggle("Show in menu bar", isOn: $state.config.showMenuBarIcon)
            } header: {
                Text("App")
            } footer: {
                Text("Profile Picker starts by itself when you click a link, so opening at login only makes the first link a little faster. "
                     + "Without the menu bar icon, open Profile Picker from your Applications folder to get back to these settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .onAppear {
            launchAtLogin = state.launchAtLogin
            state.refreshDefaultBrowserStatus()
        }
    }
}
