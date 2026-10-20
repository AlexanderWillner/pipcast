import Foundation

/// Staged bundle → live stores. Everything merges except Launcher Learning, which replaces.
@MainActor
enum BackupApplier {
    struct Summary: Sendable {
        var settings: SettingsBackup.ApplySummary?
        var clipboard = 0
        var snippets = 0
        var snippetsNeedEnabling = false
        var notes = 0
        var learning = 0
        /// Reported rather than thrown: a failure here must not abort the categories after it.
        var problems: [String] = []
    }

    static func apply(
        _ categories: Set<BackupCategory>, from bundle: BackupBundle, to core: AppCore
    ) async -> Summary {
        var summary = Summary()
        var snippetBindings: [String: HotKeyBinding] = [:]
        var snippetIDs: [String: String] = [:]
        if categories.contains(.configuration), let data = try? Data(contentsOf: bundle.settingsURL),
            var backup = try? SettingsBackup(json: data)
        {
            snippetBindings = backup.hotkeys?.snippets ?? [:]
            backup.hotkeys?.snippets = nil
            summary.settings = backup.apply(to: core)
        }
        if categories.contains(.clipboard) {
            summary.clipboard = await importClipboard(bundle, into: core.clipboardStore)
            if summary.clipboard > 0 { core.clipboardStore.load() }
        }
        if categories.contains(.snippets) {
            do {
                let imported = try await applySnippets(bundle, to: core)
                summary.snippets = imported.count
                snippetIDs = imported.ids
                summary.snippetsNeedEnabling =
                    summary.snippets > 0 && !core.settings.snippetsEnabled
            } catch {
                summary.problems.append(
                    String(localized: "Couldn't import snippets: \(error.localizedDescription)"))
            }
        }
        for (name, binding) in snippetBindings where BackupBundle.isSafeName(name) {
            let id: String
            if categories.contains(.snippets) {
                guard let importedID = snippetIDs[name] else { continue }
                id = importedID
            } else {
                id = core.snippetsStore.snippetsDirectory.appendingPathComponent(name).standardizedFileURL.path
            }
            let action = HotKeyAction.snippet(id: id)
            guard core.hotKeys.conflictOwner(of: binding, excluding: action) == nil else { continue }
            core.hotKeys.setBinding(binding, for: action)
            summary.settings?.hotkeys += 1
        }
        if categories.contains(.notes) {
            summary.notes = await applyNotes(bundle, to: core)
        }
        if categories.contains(.learning) {
            summary.learning = applyLearning(bundle, to: core)
        }
        return summary
    }

    // MARK: - Parts

    /// Off-main and streamed: a restored history runs to hundreds of thousands of clips.
    private nonisolated static func importClipboard(
        _ bundle: BackupBundle, into store: ClipboardStore
    ) async -> Int {
        ClipboardStore.importStoredItems(
            inDatabaseAt: store.dbURL, adoptingImagesInto: store.imagesDir,
            bundle.clipboardItems().lazy.compactMap { staged($0, in: bundle) })
    }

    /// The row still points into staging; the store adopts the blob once it accepts the clip.
    private nonisolated static func staged(
        _ item: BackupClipboardItem, in bundle: BackupBundle
    ) -> ClipboardItem? {
        switch item.kind {
        case .text:
            guard let text = item.text else { return nil }
            return ClipboardItem(
                id: UUID(), kind: .text, text: text, imagePath: nil, createdAt: item.createdAt,
                sourceBundleID: item.sourceBundleID, pinnedAt: item.pinnedAt)
        case .image:
            guard let name = item.imageName, let url = bundle.clipboardImageURL(named: name) else {
                return nil
            }
            return ClipboardItem(
                id: UUID(), kind: .image, text: nil, imagePath: url.path,
                createdAt: item.createdAt, sourceBundleID: item.sourceBundleID,
                pinnedAt: item.pinnedAt)
        case .file:
            // A path from another Mac names nothing here, so the row is dropped rather than dead.
            guard let path = item.text, FileManager.default.fileExists(atPath: path) else {
                return nil
            }
            return ClipboardItem(
                id: UUID(), kind: .file, text: path, imagePath: nil, createdAt: item.createdAt,
                sourceBundleID: item.sourceBundleID, pinnedAt: item.pinnedAt)
        }
    }

    private static func applySnippets(
        _ bundle: BackupBundle, to core: AppCore
    ) async throws -> BackupSnippetImporter.Result {
        let documents = bundle.documents(in: bundle.snippetsDirectory, extension: "md")
        guard !documents.isEmpty else { return .init() }
        if core.settings.snippetsEnabled { await core.snippetsStore.start() }
        let incoming = documents.compactMap { document -> (String, Snippet)? in
            guard let snippet = try? SnippetMarkdownSerializer.parse(
                content: document.contents,
                fileURL: bundle.snippetsDirectory.appendingPathComponent(document.name))
            else { return nil }
            return (document.name, snippet)
        }
        return try await BackupSnippetImporter.apply(incoming, to: core.snippetsStore)
    }

    private static func applyNotes(_ bundle: BackupBundle, to core: AppCore) async -> Int {
        let documents = bundle.documents(in: bundle.notesDirectory, extension: "md")
        guard !documents.isEmpty else { return 0 }
        return await core.notesStore.importNotes(
            documents.map {
                NotesRepository.Incoming(
                    title: ($0.name as NSString).deletingPathExtension, source: $0.contents)
            })
    }

    private static func applyLearning(_ bundle: BackupBundle, to core: AppCore) -> Int {
        var applied = 0
        if let visits = bundle.decodeLearning(.ranking, as: [String: LauncherVisit].self) {
            core.launcherRanking.replace(visits)
            applied += visits.count
        }
        if let records = bundle.decodeLearning(.emoji, as: [FrequentEmoji].self) {
            core.frequentEmoji.replace(records)
            applied += records.count
        }
        if let entries = bundle.decodeLearning(.calculator, as: [CalcHistoryEntry].self) {
            core.calcHistory.replace(entries)
            applied += entries.count
        }
        return applied
    }

}
