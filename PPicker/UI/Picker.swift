import AppKit
import Observation
import SwiftUI

/// "Remember this choice" options in the picker.
enum RememberChoice: Hashable {
    case justOnce
    case site
    case app
    case siteFromApp
}

@Observable
final class PickerModel {
    var request: LinkRequest?
    var options: [TargetOption] = []
    var selection = 0
    var remember: RememberChoice = .justOnce

    var host: String {
        guard let url = request?.url else { return "" }
        if url.isFileURL { return url.lastPathComponent }
        return (url.host(percentEncoded: false) ?? url.absoluteString).replacingOccurrences(of: "www.", with: "", options: .anchored)
    }

    /// Host without `www.`, used for "Always for this site" rules.
    var siteHost: String? {
        guard let url = request?.url, !url.isFileURL, let host = url.host(percentEncoded: false), !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

/// A borderless floating panel that takes keyboard input without activating PPicker,
/// so the app you clicked the link in stays in front if you cancel.
final class PickerPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let onKeyDown, onKeyDown(event) { return }
        super.sendEvent(event)
    }
}

final class PickerController: NSObject, NSWindowDelegate {
    private let state: AppState
    private let model = PickerModel()
    private var panel: PickerPanel?

    init(state: AppState) {
        self.state = state
    }

    func show(_ request: LinkRequest) {
        let options = state.catalog.pickerOptions(firstBrowserID: state.systemBrowserID, hidden: state.config.hiddenTargets)
        guard !options.isEmpty else {
            // Nothing to choose from (e.g. browsers still loading): let the system open it.
            NSWorkspace.shared.open(request.url)
            return
        }

        model.request = request
        model.options = options
        model.selection = 0
        model.remember = .justOnce

        let panel = self.panel ?? makePanel()
        self.panel = panel
        if let content = panel.contentView {
            content.layoutSubtreeIfNeeded()
            panel.setContentSize(content.fittingSize)
        }
        position(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    private func makePanel() -> PickerPanel {
        let panel = PickerPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The window shadow (and its hairline border) follows the rectangular window bounds, not the
        // rounded glass, so it would show as a frame around the picker. The glass draws its own edge.
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let view = PickerView(
            model: model,
            catalog: state.catalog,
            choose: { [weak self] index in self?.choose(index) },
            copyLink: { [weak self] in self?.copyLink() }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hosting
        panel.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }
        return panel
    }

    /// Places the panel just below and to the right of the mouse, kept on screen.
    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let size = panel.frame.size
        // The window has a transparent margin around the glass; place the glass itself, not the window.
        let inset = PickerView.margin - 8
        var origin = NSPoint(x: mouse.x - 24 - PickerView.margin, y: mouse.y - size.height + 12 + PickerView.margin)
        origin.x = min(max(origin.x, visible.minX - inset), visible.maxX - size.width + inset)
        origin.y = min(max(origin.y, visible.minY - inset), visible.maxY - size.height + inset)
        panel.setFrameOrigin(origin)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) {
            if event.charactersIgnoringModifiers == "c" { copyLink(); return true }
            return false
        }
        switch event.keyCode {
        case 53: dismiss(); return true                                       // Esc
        case 36, 76: choose(model.selection); return true                     // Return, Enter
        case 125, 124: move(by: 1); return true                               // Down, Right
        case 126, 123: move(by: -1); return true                              // Up, Left
        default: break
        }
        if let digit = event.charactersIgnoringModifiers.flatMap(Int.init), (1...9).contains(digit) {
            choose(digit - 1)
            return true
        }
        return false
    }

    private func move(by delta: Int) {
        guard !model.options.isEmpty else { return }
        model.selection = (model.selection + delta + model.options.count) % model.options.count
    }

    private func choose(_ index: Int) {
        guard let request = model.request, model.options.indices.contains(index) else { return }
        let target = model.options[index].target
        rememberIfAsked(target)
        dismiss()
        Task {
            do {
                try await Launcher.open(request.url, in: target, helper: state.helper)
            } catch {
                logger.error("Could not open link: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func copyLink() {
        guard let url = model.request?.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        dismiss()
    }

    private func rememberIfAsked(_ target: Target) {
        let source = model.request?.source
        var conditions: [Condition] = []
        var name = ""
        switch model.remember {
        case .justOnce:
            return
        case .site:
            guard let host = model.siteHost else { return }
            conditions = [Condition(field: .host, pattern: "*.\(host)")]
            name = host
        case .app:
            guard let source else { return }
            conditions = [Condition(field: .sourceApp, pattern: source.bundleID)]
            name = "Links from \(source.name)"
        case .siteFromApp:
            guard let host = model.siteHost, let source else { return }
            conditions = [Condition(field: .sourceApp, pattern: source.bundleID),
                          Condition(field: .host, pattern: "*.\(host)")]
            name = "\(host) from \(source.name)"
        }
        state.config.rules.insert(Rule(name: name, conditions: conditions, action: .open(target: target)), at: 0)
    }

    private func dismiss() {
        panel?.orderOut(nil)
        model.request = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }
}

// MARK: - View

struct PickerView: View {
    @Bindable var model: PickerModel
    let catalog: BrowserCatalog
    let choose: (Int) -> Void
    let copyLink: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(spacing: 2) {
                ForEach(Array(model.options.enumerated()), id: \.element.id) { index, option in
                    row(option, index: index)
                }
            }
            footer
        }
        .padding(14)
        .frame(width: 360)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(Self.margin)
    }

    /// Transparent space around the glass so its edge and depth effects aren't clipped by the window.
    static let margin: CGFloat = 20

    private var header: some View {
        HStack(spacing: 10) {
            if let source = model.request?.source {
                Image(nsImage: catalog.icon(for: source.bundleID))
                    .resizable()
                    .frame(width: 28, height: 28)
                    .help("From \(source.name)")
            } else {
                Image(systemName: "link")
                    .font(.title3)
                    .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(model.host)
                    .font(.headline)
                    .lineLimit(1)
                Text(model.request?.url.absoluteString ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            Image(systemName: "doc.on.doc")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(.rect)
                .onTapGesture(perform: copyLink)
                .help("Copy link (⌘C)")
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Copy link")
        }
        .padding(.horizontal, 4)
    }

    private func row(_ option: TargetOption, index: Int) -> some View {
        let selected = index == model.selection
        return HStack(spacing: 10) {
            TargetAvatar(option: option, catalog: catalog, size: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(option.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if let subtitle = option.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if index < 9 {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(.quaternary, in: .rect(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(selected ? Color.accentColor.opacity(0.22) : .clear, in: .rect(cornerRadius: 12))
        .contentShape(.rect)
        .onHover { if $0 { model.selection = index } }
        .onTapGesture { choose(index) }
    }

    private var footer: some View {
        HStack {
            Menu {
                Picker("Remember", selection: $model.remember) {
                    ForEach(rememberChoices, id: \.self) { choice in
                        Text(title(for: choice)).tag(choice)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Label(title(for: model.remember), systemImage: model.remember == .justOnce ? "pin" : "pin.fill")
                    .lineLimit(1)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .font(.callout)
            .layoutPriority(-1)
            Spacer(minLength: 8)
            Text("esc to cancel")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize()
        }
        .padding(.horizontal, 4)
    }

    private var rememberChoices: [RememberChoice] {
        var choices: [RememberChoice] = [.justOnce]
        if model.siteHost != nil { choices.append(.site) }
        if model.request?.source != nil { choices.append(.app) }
        if model.siteHost != nil, model.request?.source != nil { choices.append(.siteFromApp) }
        return choices
    }

    private func title(for choice: RememberChoice) -> String {
        let host = model.siteHost ?? ""
        let app = model.request?.source?.name ?? ""
        switch choice {
        case .justOnce: return "Just this once"
        case .site: return "Always for \(host)"
        case .app: return "Always for links from \(app)"
        case .siteFromApp: return "Always for \(host) from \(app)"
        }
    }
}

/// A browser icon, or for a profile a colored circle with its initial and a small browser badge.
struct TargetAvatar: View {
    let option: TargetOption
    let catalog: BrowserCatalog
    var size: CGFloat = 28

    var body: some View {
        let icon = Image(nsImage: catalog.icon(for: option.target.bundleID)).resizable()
        if option.target.profile == nil {
            icon.frame(width: size, height: size)
        } else {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(profileColor)
                    .frame(width: size, height: size)
                    .overlay {
                        Text(option.title.prefix(1).uppercased())
                            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                icon
                    .frame(width: size * 0.5, height: size * 0.5)
                    .offset(x: size * 0.12, y: size * 0.12)
            }
            .frame(width: size, height: size)
        }
    }

    private var profileColor: Color {
        guard let argb = option.colorARGB else { return .gray }
        return Color(
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255
        )
    }
}
