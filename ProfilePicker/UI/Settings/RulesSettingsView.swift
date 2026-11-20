import AppKit
import SwiftUI

struct RulesSettingsView: View {
    @Bindable var state: AppState
    @State private var selection: Rule.ID?
    @State private var editing: Rule?
    @State private var isNewRule = false
    @State private var testURL = ""
    @State private var testSource: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rules are checked from top to bottom; the first match wins. Drag to reorder. "
                 + "When nothing matches: \(state.describe(state.config.fallback)) (change this in General).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List(selection: $selection) {
                ForEach($state.config.rules) { $rule in
                    RuleRow(rule: $rule, summary: summary(of: rule))
                        .tag(rule.id)
                }
                .onMove { state.config.rules.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.bordered)
            .alternatingRowBackgrounds()
            .overlay {
                if state.config.rules.isEmpty {
                    Text("No rules yet. Add one with +, or choose “Always…” in the picker.")
                        .foregroundStyle(.secondary)
                }
            }
            .contextMenu(forSelectionType: Rule.ID.self) { ids in
                if let id = ids.first, let rule = rule(id) {
                    Button("Edit…") { edit(rule) }
                    Button("Duplicate") { duplicate(rule) }
                    Divider()
                    Button("Delete", role: .destructive) { delete(id) }
                }
            } primaryAction: { ids in
                if let id = ids.first, let rule = rule(id) { edit(rule) }
            }

            HStack(spacing: 6) {
                Button { addRule() } label: { Image(systemName: "plus").frame(width: 16) }
                    .help("Add a rule")
                Button {
                    if let selection { delete(selection) }
                } label: { Image(systemName: "minus").frame(width: 16) }
                    .help("Delete the selected rule")
                    .disabled(selection == nil)
                Spacer()
                Button("Edit…") {
                    if let selection, let rule = rule(selection) { edit(rule) }
                }
                .disabled(selection == nil)
            }

            GroupBox("Test a link") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Link").gridColumnAlignment(.trailing)
                        TextField("Link", text: $testURL, prompt: Text("https://example.com/page"))
                            .labelsHidden()
                    }
                    GridRow {
                        Text("Clicked in")
                        SourceAppField(title: nil, bundleID: $testSource, catalog: state.catalog, allowsAny: true)
                            .fixedSize()
                    }
                    GridRow {
                        Text("Result")
                        testResult
                    }
                }
                .padding(6)
            }
        }
        .padding(20)
        .navigationTitle("Rules")
        .sheet(item: $editing) { rule in
            RuleEditorView(rule: rule, state: state, isNew: isNewRule) { saved in
                if let index = state.config.rules.firstIndex(where: { $0.id == saved.id }) {
                    state.config.rules[index] = saved
                } else {
                    state.config.rules.append(saved)
                }
                selection = saved.id
            }
        }
    }

    @ViewBuilder
    private var testResult: some View {
        let trimmed = testURL.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let url = URL(string: trimmed.contains("://") ? trimmed : "https://\(trimmed)") {
            let decision = RuleEngine.decide(url: url, sourceBundleID: testSource, config: state.config)
            HStack(spacing: 6) {
                Text(state.describe(decision.action)).fontWeight(.medium)
                Text(decision.rule.map { "(rule “\($0.name)”)" } ?? "(no rule matches)")
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Type a link to see where it would open.")
                .foregroundStyle(.secondary)
        }
    }

    private func rule(_ id: Rule.ID) -> Rule? {
        state.config.rules.first { $0.id == id }
    }

    private func summary(of rule: Rule) -> String {
        let conditions = rule.conditions.map { condition -> String in
            switch condition.field {
            case .sourceApp:
                let names = condition.pattern.split(separator: ",").map {
                    state.catalog.appName(for: $0.trimmingCharacters(in: .whitespaces))
                }
                return "from \(names.joined(separator: " or "))"
            case .host: return "host \(condition.pattern)"
            case .url: return "URL \(condition.pattern)"
            }
        }
        let when = conditions.isEmpty ? "No conditions (never matches)" : conditions.joined(separator: " and ")
        return "\(when) → \(state.describe(rule.action))"
    }

    private func addRule() {
        isNewRule = true
        let target: LinkAction = state.catalog.browsers.first.map { .open(target: Target(bundleID: $0.bundleID)) } ?? .showPicker
        editing = Rule(name: "", conditions: [Condition(field: .host, pattern: "")], action: target)
    }

    private func edit(_ rule: Rule) {
        isNewRule = false
        editing = rule
    }

    private func duplicate(_ rule: Rule) {
        var copy = rule
        copy.id = UUID()
        copy.name += " copy"
        copy.conditions = copy.conditions.map { Condition(field: $0.field, pattern: $0.pattern) }
        if let index = state.config.rules.firstIndex(where: { $0.id == rule.id }) {
            state.config.rules.insert(copy, at: index + 1)
        }
    }

    private func delete(_ id: Rule.ID) {
        state.config.rules.removeAll { $0.id == id }
        if selection == id { selection = nil }
    }
}

private struct RuleRow: View {
    @Binding var rule: Rule
    let summary: String

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Enabled", isOn: $rule.isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name.isEmpty ? "Untitled rule" : rule.name)
                    .fontWeight(.medium)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .opacity(rule.isEnabled ? 1 : 0.5)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Editor

struct RuleEditorView: View {
    @State var rule: Rule
    let state: AppState
    let isNew: Bool
    let onSave: (Rule) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $rule.name, prompt: Text("e.g. Work links"))
                }

                Section {
                    ForEach($rule.conditions) { $condition in
                        ConditionRow(condition: $condition, catalog: state.catalog) {
                            rule.conditions.removeAll { $0.id == condition.id }
                        }
                    }
                    Button {
                        rule.conditions.append(Condition(field: .host, pattern: ""))
                    } label: {
                        Label("Add Condition", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                } header: {
                    Text("When all of these match")
                } footer: {
                    Text("Use * as a wildcard and commas for alternatives, e.g. *.example.com, *.example.org")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Then") {
                    Picker("Open with", selection: $rule.action) {
                        ActionPickerItems(catalog: state.catalog, current: rule.action)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add Rule" : "Save") {
                    if rule.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        rule.name = defaultName
                    }
                    onSave(rule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 560, height: 480)
    }

    private var isValid: Bool {
        !rule.conditions.isEmpty
            && rule.conditions.allSatisfy { !$0.pattern.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var defaultName: String {
        guard let first = rule.conditions.first else { return "Rule" }
        switch first.field {
        case .sourceApp: return "Links from \(state.catalog.appName(for: first.pattern))"
        case .host, .url: return first.pattern
        }
    }
}

private struct ConditionRow: View {
    @Binding var condition: Condition
    let catalog: BrowserCatalog
    let remove: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Picker("Field", selection: $condition.field) {
                Text("Clicked in app").tag(Condition.Field.sourceApp)
                Text("Host").tag(Condition.Field.host)
                Text("URL").tag(Condition.Field.url)
            }
            .labelsHidden()
            .fixedSize()

            if condition.field == .sourceApp {
                SourceAppField(title: nil, bundleID: Binding(
                    get: { condition.pattern.isEmpty ? nil : condition.pattern },
                    set: { condition.pattern = $0 ?? "" }
                ), catalog: catalog, allowsAny: false)
            } else {
                TextField("Pattern", text: $condition.pattern, prompt: Text(placeholder))
                    .labelsHidden()
            }

            Button(action: remove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove condition")
        }
    }

    private var placeholder: String {
        switch condition.field {
        case .sourceApp: ""
        case .host: "*.example.com"
        case .url: "github.com/my-org/*"
        }
    }
}

/// Choose an app: from the running apps, or any app via an open panel.
struct SourceAppField: View {
    let title: String?
    @Binding var bundleID: String?
    let catalog: BrowserCatalog
    let allowsAny: Bool

    var body: some View {
        let menu = Menu {
            if allowsAny {
                Button("Any app") { bundleID = nil }
                Divider()
            }
            ForEach(runningApps, id: \.bundleID) { app in
                Button {
                    bundleID = app.bundleID
                } label: {
                    Label { Text(app.name) } icon: { Image(nsImage: catalog.icon(for: app.bundleID)) }
                }
            }
            Divider()
            Button("Choose Application…") { chooseApplication() }
        } label: {
            if let bundleID {
                Label { Text(catalog.appName(for: bundleID)) } icon: { Image(nsImage: catalog.icon(for: bundleID)) }
            } else {
                Text(allowsAny ? "Any app" : "Choose an app")
            }
        }

        if let title {
            LabeledContent(title) { menu.fixedSize() }
        } else {
            menu
        }
    }

    private var runningApps: [SourceApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0 != .current }
            .compactMap { app in app.bundleIdentifier.map { SourceApp(bundleID: $0, name: app.localizedName ?? $0) } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier {
            bundleID = id
        }
    }
}
