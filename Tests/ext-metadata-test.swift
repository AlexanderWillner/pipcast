import Foundation

@main
@MainActor
struct ExtensionCommandMetadataTests {
    static var failures = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            failures += 1
            print("FAIL: \(message)")
        } else {
            print("PASS  \(message)")
        }
    }

    /// Scratch state of its own, never the machine's extension files.
    static func makeFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ext-metadata-test-\(UUID().uuidString).json")
    }

    // MARK: - Cases

    /// Writes round-trip through a second store over the same file.
    static func writesRoundTrip() {
        let file = makeFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let first = ExtensionCommandMetadataStore(fileURL: file)
        first.setSubtitle("Tick 1", extension: "ticklab", command: "tick")
        first.setBackgroundEnabled(true, extension: "ticklab", command: "tick")
        first.flush()

        let second = ExtensionCommandMetadataStore(fileURL: file)
        let metadata = second.metadata(extension: "ticklab", command: "tick")
        expect(metadata.subtitle == "Tick 1", "the subtitle round-trips")
        expect(metadata.backgroundEnabled, "the flag round-trips")
        expect(
            second.metadata(extension: "ticklab", command: "other") == ExtensionCommandMetadata(),
            "an unwritten command reads as defaults")
    }

    /// A failure counts up so the policy can back off; a success retires the error with the count.
    static func resultsTrackTheFailureRun() {
        let file = makeFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = ExtensionCommandMetadataStore(fileURL: file)
        let now = Date()
        store.recordBackgroundResult(
            extension: "ticklab", command: "tick", success: false, error: "Boom.", now: now)
        store.recordBackgroundResult(
            extension: "ticklab", command: "tick", success: false, error: "Boom.", now: now)
        var metadata = store.metadata(extension: "ticklab", command: "tick")
        expect(metadata.consecutiveFailures == 2, "consecutive failures accumulate")
        expect(metadata.lastError == "Boom.", "the last error is kept")

        store.recordBackgroundResult(
            extension: "ticklab", command: "tick", success: true, error: nil, now: now)
        metadata = store.metadata(extension: "ticklab", command: "tick")
        expect(metadata.consecutiveFailures == 0, "a success resets the count")
        expect(metadata.lastError == nil, "a success clears the error")
        expect(metadata.lastRun == now, "the run is stamped")
    }

    /// Disabling retires the warning, so it cannot outlive the schedule that caused it.
    static func clearingTheErrorRetiresTheBackoff() {
        let file = makeFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = ExtensionCommandMetadataStore(fileURL: file)
        store.recordBackgroundResult(
            extension: "ticklab", command: "tick", success: false, error: "Boom.", now: Date())
        store.clearBackgroundError(extension: "ticklab", command: "tick")
        let metadata = store.metadata(extension: "ticklab", command: "tick")
        expect(metadata.lastError == nil, "the error is gone")
        expect(metadata.consecutiveFailures == 0, "the backoff is gone with it")
    }

    /// Uninstalling takes the extension's records with it, and only its own.
    static func removeAllDropsOneExtension() {
        let file = makeFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = ExtensionCommandMetadataStore(fileURL: file)
        store.activateBackgroundRefresh(extension: "ticklab", command: "tick", now: Date())
        store.activateBackgroundRefresh(extension: "coffee", command: "status", now: Date())
        store.removeAll(extension: "ticklab")
        store.flush()

        let reloaded = ExtensionCommandMetadataStore(fileURL: file)
        expect(
            !reloaded.metadata(extension: "ticklab", command: "tick").backgroundEnabled,
            "the uninstalled extension's record is gone")
        expect(
            reloaded.metadata(extension: "coffee", command: "status").backgroundEnabled,
            "the other extension keeps its own")
    }

    /// Garbage stays a fresh store rather than a crash; the next flush heals the file.
    static func garbageStaysSafe() {
        let file = makeFile()
        defer { try? FileManager.default.removeItem(at: file) }
        try? "not json at all".write(to: file, atomically: true, encoding: .utf8)

        let store = ExtensionCommandMetadataStore(fileURL: file)
        expect(
            store.metadata(extension: "broken", command: "x") == ExtensionCommandMetadata(),
            "a corrupt file reads as defaults")
    }

    static func main() async {
        writesRoundTrip()
        resultsTrackTheFailureRun()
        clearingTheErrorRetiresTheBackoff()
        removeAllDropsOneExtension()
        garbageStaysSafe()
        await externalMetadata()
        await metadataWriteFailure()

        print(failures == 0 ? "Extension command metadata tests passed" : "\(failures) tests failed")
        exit(failures == 0 ? 0 : 1)
    }
    static func externalMetadata() async {
        let file = makeFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let store = ExtensionCommandMetadataStore(fileURL: file)
        var incoming = ExtensionCommandMetadata()
        incoming.backgroundEnabled = true
        incoming.subtitle = "Imported"
        store.setSubtitle("Local", extension: "used", command: "first")
        do {
            let skipped = try await store.prepareExternalMetadata(["second": incoming], for: "used")
            expect(skipped == nil, "using one command protects the whole extension's metadata")
            guard let prepared = try await store.prepareExternalMetadata(["first": incoming], for: "fresh") else {
                expect(false, "untouched extension metadata prepares")
                return
            }
            defer { try? FileManager.default.removeItem(at: prepared.staged) }
            try store.adoptPreparedMetadata(prepared)
            expect(store.metadata(extension: "fresh", command: "first").backgroundEnabled,
                   "untouched extension metadata is adopted")
            let read = try await ExtensionCommandMetadataStore.readExternal(file: file)
            expect(read["fresh"]?["first"]?.subtitle == "Imported", "imported metadata persists")
            try Data("broken".utf8).write(to: file)
            do {
                _ = try await ExtensionCommandMetadataStore.readExternal(file: file)
                expect(false, "corrupt external metadata reports failure")
            } catch { expect(true, "corrupt external metadata reports failure") }
        } catch { expect(false, "external metadata fixtures: \(error)") }
    }

    static func metadataWriteFailure() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = root.appendingPathComponent("metadata.json")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }
        let store = ExtensionCommandMetadataStore(fileURL: file)
        store.setSubtitle("Local", extension: "local", command: "first")
        store.flush()
        var incoming = ExtensionCommandMetadata()
        incoming.subtitle = "Imported"
        do {
            guard let prepared = try await store.prepareExternalMetadata(["first": incoming], for: "fresh") else {
                expect(false, "metadata write fixture prepares")
                return
            }
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: root.path)
            do {
                try store.adoptPreparedMetadata(prepared)
                expect(false, "destination write failure reaches the importer")
            } catch { expect(true, "destination write failure reaches the importer") }
            expect(store.isUntouched("fresh"), "failed persistence keeps the import retryable")
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: prepared.staged)
            guard let retry = try await store.prepareExternalMetadata(["first": incoming], for: "fresh") else {
                expect(false, "failed import can prepare again")
                return
            }
            defer { try? FileManager.default.removeItem(at: retry.staged) }
            try store.adoptPreparedMetadata(retry)
            let reloaded = ExtensionCommandMetadataStore(fileURL: file)
            expect(reloaded.metadata(extension: "fresh", command: "first").subtitle == "Imported",
                   "retry persists imported metadata")
            expect(reloaded.metadata(extension: "local", command: "first").subtitle == "Local",
                   "retry preserves existing metadata")
        } catch { expect(false, "metadata write failure fixtures: \(error)") }
    }

}
