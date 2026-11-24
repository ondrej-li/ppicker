import AppKit
import SwiftUI
import UniformTypeIdentifiers

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

            Section {
                HStack(spacing: 8) {
                    Button("Export Settings…") { exportSettings() }
                    Button("Import Settings…") { importSettings() }
                    Spacer()
                }
            } header: {
                Text("Settings file")
            } footer: {
                Text("Export your rules, fallback, hidden browsers and menu bar setting as JSON. "
                     + "Import replaces those settings. Profile names, emails and the previous default browser are not included.")
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

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"
        return "\(AppInfo.name) \(version) (\(build))"
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.title = "Export Settings"
        panel.prompt = "Export"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Profile Picker Settings.json"
        panel.isExtensionHidden = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let document = SettingsDocument.make(config: state.config, generator: appVersion)
            try document.encoded().write(to: url, options: .atomic)
        } catch {
            present(error, title: "Could not export settings")
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.title = "Import Settings"
        panel.prompt = "Import"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let snapshot = try SettingsDocument.decode(Data(contentsOf: url))
            let alert = NSAlert()
            alert.messageText = "Replace your current settings?"
            alert.informativeText = "This imports \(snapshot.rules.count) "
                + "rule\(snapshot.rules.count == 1 ? "" : "s") from “\(url.lastPathComponent)” and replaces "
                + "your current rules, fallback, hidden browsers and menu bar setting."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Import")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            state.config = snapshot.applied(to: state.config)
        } catch {
            present(error, title: "Could not import settings")
        }
    }

    private func present(_ error: Error, title: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
