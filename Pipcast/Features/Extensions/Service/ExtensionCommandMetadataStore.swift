import Foundation

/// Every command's row metadata in one small file, deliberately not in `extension-data`: drawing a
/// launcher row must never fault in an extension's whole `LocalStorage` and `Cache`.
@MainActor
@Observable
final class ExtensionCommandMetadataStore {
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var isDirty = false
    @ObservationIgnored private var flushTask: Task<Void, Never>?

    private var records: [String: [String: ExtensionCommandMetadata]]

    init(fileURL: URL) {
        self.fileURL = fileURL
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        records =
            (try? Data(contentsOf: fileURL))
            .flatMap {
                try? JSONDecoder().decode(
                    [String: [String: ExtensionCommandMetadata]].self, from: $0)
            } ?? [:]
    }

    func metadata(extension name: String, command: String) -> ExtensionCommandMetadata {
        records[name]?[command] ?? ExtensionCommandMetadata()
    }

    func setSubtitle(_ subtitle: String?, extension name: String, command: String) {
        mutate(name, command) { $0.subtitle = subtitle }
    }

    func setBackgroundEnabled(_ enabled: Bool, extension name: String, command: String) {
        mutate(name, command) { $0.backgroundEnabled = enabled }
    }

    func menuBarCommands() -> [(extension: String, command: String)] {
        records.flatMap { name, commands in
            commands.filter(\.value.menuBarEnabled).keys.map { (extension: name, command: $0) }
        }
    }

    /// Switching the item off drops its render too: a stale one would come back at next launch.
    func setMenuBarEnabled(_ enabled: Bool, extension name: String, command: String) {
        mutate(name, command) {
            $0.menuBarEnabled = enabled
            if !enabled { $0.menuBarSnapshot = nil }
        }
    }

    func setMenuBarSnapshot(
        _ snapshot: ExtensionMenuBarSnapshot?, extension name: String, command: String
    ) {
        mutate(name, command) { $0.menuBarSnapshot = snapshot }
    }

    /// A menu-bar run is its own refresh, so the next one is measured from the launch.
    func recordMenuBarRun(extension name: String, command: String, now: Date) {
        mutate(name, command) {
            $0.menuBarEnabled = true
            $0.lastRun = now
        }
    }

    /// Disabling retires the last error with the schedule; a stale warning would outlive its cause.
    func clearBackgroundError(extension name: String, command: String) {
        mutate(name, command) {
            $0.lastError = nil
            $0.consecutiveFailures = 0
        }
    }

    /// A manual run counts as a refresh, so the scheduler doesn't re-fire right behind it.
    func activateBackgroundRefresh(extension name: String, command: String, now: Date) {
        mutate(name, command) {
            $0.backgroundEnabled = true
            $0.lastRun = now
        }
    }

    func recordBackgroundResult(
        extension name: String, command: String, success: Bool, error: String?, now: Date
    ) {
        mutate(name, command) {
            $0.lastRun = now
            $0.lastError = success ? nil : error
            $0.consecutiveFailures = success ? 0 : $0.consecutiveFailures + 1
        }
    }

    func removeAll(extension name: String) {
        guard records.removeValue(forKey: name) != nil else { return }
        scheduleFlush()
    }

    func isUntouched(_ name: String) -> Bool { records[name] == nil }

    struct PreparedImport {
        let staged: URL
        fileprivate let original: [String: [String: ExtensionCommandMetadata]]
        fileprivate let updated: [String: [String: ExtensionCommandMetadata]]
    }

    func prepareExternalMetadata(
        _ incoming: [String: ExtensionCommandMetadata], for name: String
    ) async throws -> PreparedImport? {
        guard isUntouched(name), !incoming.isEmpty else { return nil }
        let original = records
        var updated = original
        updated[name] = incoming
        let staged = try await Self.stage(updated, beside: fileURL)
        return PreparedImport(staged: staged, original: original, updated: updated)
    }

    func isCurrent(_ prepared: PreparedImport) -> Bool { records == prepared.original }

    func adoptPreparedMetadata(_ prepared: PreparedImport) throws {
        guard isCurrent(prepared) else { throw CancellationError() }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: prepared.staged)
        } else {
            try FileManager.default.moveItem(at: prepared.staged, to: fileURL)
        }
        flushTask?.cancel()
        flushTask = nil
        isDirty = false
        records = prepared.updated
    }

    @concurrent
    private static func stage(
        _ records: [String: [String: ExtensionCommandMetadata]], beside file: URL
    ) async throws -> URL {
        let data = try JSONEncoder().encode(records)
        try Task.checkCancellation()
        let staged = file.deletingLastPathComponent().appendingPathComponent(".metadata-import-\(UUID()).json")
        try data.write(to: staged, options: .atomic)
        return staged
    }

    @concurrent
    static func readExternal(file: URL) async throws -> [String: [String: ExtensionCommandMetadata]] {
        let data: Data
        do { data = try Data(contentsOf: file) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return [:] }
        try Task.checkCancellation()
        return try JSONDecoder().decode([String: [String: ExtensionCommandMetadata]].self, from: data)
    }

    func flush() {
        flushTask?.cancel()
        flushTask = nil
        guard isDirty, let data = try? JSONEncoder().encode(records) else { return }
        isDirty = false
        try? data.write(to: fileURL, options: .atomic)
    }

    private func mutate(
        _ name: String, _ command: String, _ body: (inout ExtensionCommandMetadata) -> Void
    ) {
        var record = records[name]?[command] ?? ExtensionCommandMetadata()
        body(&record)
        // A menu redraws its rows on every commit; an unchanged one must not cost a write.
        guard records[name]?[command] != record else { return }
        records[name, default: [:]][command] = record
        scheduleFlush()
    }

    /// Ticks write on a timer, so the file is coalesced the way `ExtensionStorage` coalesces its own.
    private func scheduleFlush() {
        isDirty = true
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            self?.flush()
        }
    }
}
