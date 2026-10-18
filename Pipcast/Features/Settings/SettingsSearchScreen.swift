import SwiftUI

/// The launcher's `?` scope: `?extensions` lists the settings rows a search would find, and ↵
/// opens Settings on the row. The mode stays launcher, so Esc, history and the footer keep working.
struct SettingsSearchScreen: PaletteScreen {
    let core: AppCore
    let vm: PaletteState
    let openActions: () -> Void

    /// The settings scope: a leading `?` turns the launcher query into a settings search.
    static func scope(of query: String) -> String? {
        guard query.first == "?" else { return nil }
        return String(query.dropFirst())
    }

    var rows: [SettingsSearchEntry] {
        SettingsSearchCatalog.scopeResults(for: Self.scope(of: vm.query) ?? "")
    }

    var primaryActionTitle: String { String(localized: "Open in Settings") }

    private func entry(at selection: Int) -> SettingsSearchEntry? {
        let rows = rows
        return rows.indices.contains(selection) ? rows[selection] : nil
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard let entry = entry(at: selection) else { return nil }
        return PopoverMenuContent(
            header: entry.title,
            items: [
                PopoverMenuItem(
                    title: primaryActionTitle, systemImage: "gearshape", shortcut: "↵"
                ) {
                    open(entry)
                }
            ])
    }

    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        switch shortcut {
        case .numberSlot(let index): return activateSlot(at: index)
        default: return false
        }
    }

    func activate(at selection: Int) {
        guard let entry = entry(at: selection) else { return }
        open(entry)
    }

    /// No secondary action: one row opens one place.
    func secondary(at selection: Int) -> Bool { false }

    /// ⌘1…⌘0 — the Nth visible row, so pins-first browse answers the chords too.
    private func activateSlot(at index: Int) -> Bool {
        let rows = rows
        guard rows.indices.contains(index) else { return false }
        open(rows[index])
        return true
    }

    private func open(_ entry: SettingsSearchEntry) {
        core.paletteCoordinator.hidePalette(restoreFocus: false)
        core.settingsCoordinator.showSettings(tab: entry.tab, revealing: entry.target)
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        let rows = rows
        guard !rows.isEmpty else {
            return AnyView(EmptyResults(text: String(localized: "No results")))
        }
        let selectedID = rows.indices.contains(selection) ? rows[selection].id : nil
        return AnyView(
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { offset, entry in
                            SettingsSearchScreenRow(
                                entry: entry, selected: entry.id == selectedID,
                                slot: NumberSlots.digit(at: offset)
                            )
                            .selectionFrame(entry.id == selectedID)
                            .contentShape(Rectangle())
                            .onRightClick { select(entry); openActions() }
                            .onRowClick(
                                select: { select(entry) },
                                activate: { select(entry); activate(at: offset) }
                            )
                        }
                    }
                    .padding(.horizontal, metrics.spacing.md)
                    .padding(.top, metrics.spacing.xs)
                    .padding(.bottom, metrics.spacing.md)
                    .hideNativeScrollers()
                    .scrollOriginAnchor()
                }
                .edgeDissolve()
                .thinScrollbar()
                .scrollFollowsSelection(
                    scroll, row: selectedID, atOrigin: selection == 0, proxy: proxy)
            }
        )
    }

    private var metrics: InterfaceMetrics { core.settings.interfaceSize.metrics }

    private func select(_ entry: SettingsSearchEntry) {
        if let index = rows.firstIndex(of: entry) { vm.selection = index }
    }
}

private struct SettingsSearchScreenRow: View {
    @Environment(\.metrics) private var metrics
    let entry: SettingsSearchEntry
    let selected: Bool
    /// This row's ⌘-digit, or nil when it is not among the first ten visible rows.
    let slot: Character?
    @Environment(PaletteState.self) private var palette
    @State private var hovered = false

    /// Selection wins over hover when a row is both; otherwise hover shows its fainter layer.
    private var fill: Color {
        if selected { return Theme.Colors.selection }
        if hovered { return Theme.Colors.rowHover }
        return .clear
    }

    var body: some View {
        HStack(spacing: metrics.spacing.lg) {
            SettingsTabIcon(
                systemImage: entry.tab.systemImage, tint: .accentColor,
                size: metrics.size.resultRowIcon)
            VStack(alignment: .leading, spacing: metrics.spacing.xxs) {
                Text(entry.title)
                    .font(metrics.typography.menuRow)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(entry.breadcrumb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            if let slot, palette.commandHeld {
                HStack(spacing: metrics.spacing.xxs) {
                    KeyCapChip(text: "⌘", style: .outline)
                    KeyCapChip(text: String(slot), style: .outline)
                }
            }
        }
        .padding(.horizontal, metrics.spacing.md)
        .padding(.vertical, metrics.spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: metrics.radius.row, style: .continuous)
                .fill(fill)
        )
        .armedHover($hovered)
    }
}
