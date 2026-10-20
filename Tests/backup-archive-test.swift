import AppleArchive
import Foundation
import System

/// Compiles the shipped bundle and archive layer, so a `.pipcast` can't quietly change shape.
@main
@MainActor
struct BackupArchiveTest {
    static var failures = 0

    static func check(_ description: String, _ condition: @autoclosure () -> Bool) {
        if condition() {
            print("PASS  \(description)")
        } else {
            print("FAIL  \(description)")
            failures += 1
        }
    }

    static func declaredBackupTypes() {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        do {
            let data = try Data(contentsOf: repo.appendingPathComponent("Pipcast/Info.plist"))
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            let source = try String(
                contentsOf: repo.appendingPathComponent("Pipcast/Features/Backup/Service/BackupActions.swift"),
                encoding: .utf8)
            for (key, constructor, identifier, ext) in [
                ("UTExportedTypeDeclarations", "exportedAs", "io.github.msarheed.pipcast.backup", "pipcast"),
                ("UTImportedTypeDeclarations", "importedAs", "com.tinycast.backup", "tinycast")
            ] {
                let declarations = plist?[key] as? [[String: Any]] ?? []
                let declaration = declarations.first { $0["UTTypeIdentifier"] as? String == identifier }
                let tags = declaration?["UTTypeTagSpecification"] as? [String: Any]
                check("\(ext) extension is registered", (tags?["public.filename-extension"] as? [String]) == [ext])
                check("\(ext) picker matches its declaration", source.contains("UTType(\(constructor): \"\(identifier)\")"))
            }
        } catch {
            check("backup type declarations are readable: \(error)", false)
        }
    }

    /// UUID-suffixed, per docs/testing.md: harnesses run in parallel against the real system.
    static func scratch() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-archive-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func main() async {
        let root = scratch()
        defer { try? FileManager.default.removeItem(at: root) }

        declaredBackupTypes()
        roundTrip(in: root)
        clipboardLines(in: root)
        noAbsolutePathsEscape(in: root)
        formatGuard(in: root)
        rejectsGarbage(in: root)
        refusesTraversal(in: root)
        refusesSymbolicLinks(in: root)
        categoriesAreComplete()
        staging()
        await overlappingImports()

        print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }

    // MARK: - Round trip

    static func roundTrip(in root: URL) {
        let source = root.appendingPathComponent("seal")
        let bundle = BackupBundle(root: source)
        try? bundle.prepare(BackupCategory.all)

        // A binary blob, so a wrong keyset or a text-only path shows up as corruption.
        let png = Data((0..<200_000).map { UInt8($0 % 251) })
        try? bundle.write(png, to: bundle.clipboardImagesDirectory.appendingPathComponent("a.png"))
        _ = try? bundle.writeDocument(
            title: "Café — notes/with:separators", extension: "md", contents: "héllo\nwörld",
            in: bundle.notesDirectory)
        try? bundle.write(Data(), to: bundle.snippetsDirectory.appendingPathComponent("empty.md"))
        let manifest = BackupManifest(
            appVersion: "1.2.3", createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            counts: ["clipboard": 1, "notes": 1])
        try? bundle.writeManifest(manifest)

        let archive = root.appendingPathComponent("out.pipcast")
        let opened = root.appendingPathComponent("open")
        do {
            try BackupArchive.seal(directory: source, into: archive)
            try BackupArchive.open(file: archive, into: opened)
            let legacy = root.appendingPathComponent("existing.tinycast")
            try FileManager.default.copyItem(at: archive, to: legacy)
            let legacyOpened = root.appendingPathComponent("legacy-open")
            try BackupArchive.open(file: legacy, into: legacyOpened)
            let legacyManifest = try BackupBundle(root: legacyOpened).readManifest()
            check("legacy backup filenames preserve their manifest", legacyManifest == manifest)

        } catch {
            check("seal and open succeed (\(error))", false)
            return
        }

        let reopened = BackupBundle(root: opened)
        check(
            "a binary blob survives the round trip",
            (try? Data(
                contentsOf: reopened.clipboardImagesDirectory.appendingPathComponent("a.png")))
                == png)
        let notes = reopened.documents(in: reopened.notesDirectory, extension: "md")
        check("a note with separators and non-ASCII survives", notes.first?.contents == "héllo\nwörld")
        check(
            "a title's path separators never become directories",
            notes.first.map { !$0.name.contains("/") } ?? false)
        check(
            "a zero-byte file survives",
            reopened.documents(
                in: reopened.snippetsDirectory, extension: "md"
            ).first?.contents == "")
        let decoded = try? reopened.readManifest()
        check("the manifest round trips", decoded == manifest)
        check("an absent category reads as absent", decoded?.categories == [.clipboard, .notes])
        check("a present category keeps its count", decoded?.count(.clipboard) == 1)
        check("an absent category counts zero", decoded?.count(.snippets) == 0)

        // Ownership must not travel: the extract belongs to whoever opened it.
        let attributes = try? FileManager.default.attributesOfItem(
            atPath: reopened.clipboardImagesDirectory.appendingPathComponent("a.png").path)
        check(
            "the extracted file is owned by the current user",
            (attributes?[.ownerAccountID] as? NSNumber)?.uint32Value == getuid())
    }

    // MARK: - Clipboard

    static func clipboardLines(in root: URL) {
        let bundle = BackupBundle(root: root.appendingPathComponent("clips"))
        try? bundle.prepare([.clipboard])
        let items = [
            BackupClipboardItem(
                kind: .text, text: "one\ntwo\nthree", imageName: nil,
                createdAt: Date(timeIntervalSince1970: 10), sourceBundleID: "com.apple.Safari",
                pinnedAt: nil),
            BackupClipboardItem(
                kind: .text, text: "carriage\r\nreturn", imageName: nil,
                createdAt: Date(timeIntervalSince1970: 20), sourceBundleID: nil,
                pinnedAt: Date(timeIntervalSince1970: 25)),
            BackupClipboardItem(
                kind: .image, text: nil, imageName: "b.png",
                createdAt: Date(timeIntervalSince1970: 30), sourceBundleID: nil, pinnedAt: nil)
        ]
        if let writer = try? bundle.clipboardWriter() {
            for item in items { try? writer.write(item) }
        }

        check("every clip round trips through JSONL", Array(bundle.clipboardItems()) == items)

        // The invariant the line splitting rests on: a newline in a clip is escaped, never raw.
        let raw = (try? Data(contentsOf: bundle.clipboardItemsURL)) ?? Data()
        check(
            "one line per clip, whatever the clip contains",
            raw.split(separator: 0x0A, omittingEmptySubsequences: true).count == items.count)
    }

    /// The analogue of settings-backup-test's `snippetsEnabled` check: this file leaves the Mac.
    static func noAbsolutePathsEscape(in root: URL) {
        let bundle = BackupBundle(root: root.appendingPathComponent("paths"))
        try? bundle.prepare([.clipboard])
        let item = BackupClipboardItem(
            kind: .image, text: nil, imageName: "c.png", createdAt: Date(), sourceBundleID: nil,
            pinnedAt: nil)
        if let writer = try? bundle.clipboardWriter() { try? writer.write(item) }
        let raw = (try? Data(contentsOf: bundle.clipboardItemsURL)) ?? Data()
        let text = String(bytes: raw, encoding: .utf8) ?? ""
        check("no home directory leaks into the file", !text.contains("/Users"))
        check("no image path leaks into the file", !text.contains("/Library"))
    }

    // MARK: - Guards

    static func formatGuard(in root: URL) {
        for offset in [-1, 1] {
            let bundle = BackupBundle(root: root.appendingPathComponent("format\(offset)"))
            try? bundle.prepare([])
            var manifest = BackupManifest(appVersion: "1", createdAt: Date(), counts: [:])
            manifest.format = BackupManifest.currentFormat + offset
            try? bundle.writeManifest(manifest)
            do {
                _ = try bundle.readManifest()
                check("a format of \(manifest.format) is refused", false)
            } catch {
                check(
                    "a format of \(manifest.format) is refused by the same error",
                    error == .unsupportedFormat(found: manifest.format))
                check(
                    "the refusal names the format it found",
                    error.errorDescription?.contains("\(manifest.format)") == true)
            }
        }
    }

    static func rejectsGarbage(in root: URL) {
        let file = root.appendingPathComponent("garbage.pipcast")
        try? Data("not an archive".utf8).write(to: file)
        let into = root.appendingPathComponent("garbage-out")
        do {
            try BackupArchive.open(file: file, into: into)
            check("a non-archive is refused", false)
        } catch {
            check("a non-archive is refused", true)
        }

        let empty = BackupBundle(root: root.appendingPathComponent("empty"))
        try? empty.prepare([])
        do {
            _ = try empty.readManifest()
            check("a bundle with no manifest is refused", false)
        } catch {
            check("a bundle with no manifest is refused", error == .unreadable)
        }
    }

    /// A hostile archive must not write outside the directory the caller chose.
    static func refusesTraversal(in root: URL) {
        // Header-by-header: `writeDirectoryContents` refuses to emit the `..` path we need here.
        let archive = root.appendingPathComponent("evil.pipcast")
        let payload = Data("escaped".utf8)
        guard
            let destination = ArchiveByteStream.fileStream(
                path: FilePath(archive.path), mode: .writeOnly, options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o600)),
            let compressor = ArchiveByteStream.compressionStream(
                using: .lzfse, writingTo: destination)
        else {
            check("the traversal fixture can be built", false)
            return
        }
        do {
            try ArchiveStream.withEncodeStream(writingTo: compressor) { encoder in
                let header = ArchiveHeader()
                header.append(
                    .uint(
                        key: ArchiveHeader.FieldKey("TYP"),
                        value: UInt64(ArchiveHeader.EntryType.regularFile.rawValue)))
                header.append(
                    .string(key: ArchiveHeader.FieldKey("PAT"), value: "../escape.txt"))
                header.append(.uint(key: ArchiveHeader.FieldKey("MOD"), value: 0o644))
                header.append(
                    .blob(key: ArchiveHeader.FieldKey("DAT"), size: UInt64(payload.count)))
                try encoder.writeHeader(header)
                try payload.withUnsafeBytes { buffer in
                    try encoder.writeBlob(key: ArchiveHeader.FieldKey("DAT"), from: buffer)
                }
            }
            try compressor.close()
            try destination.close()
        } catch {
            check("the traversal fixture can be built (\(error))", false)
            return
        }

        let into = root.appendingPathComponent("evil-out", isDirectory: true)
        try? BackupArchive.open(file: archive, into: into)
        let escaped = root.appendingPathComponent("escape.txt")
        check(
            "an entry naming `..` never lands outside the destination",
            !FileManager.default.fileExists(atPath: escaped.path))
    }

    /// A link entry names no `..` at all, and reading through it would leave the extract.
    static func refusesSymbolicLinks(in root: URL) {
        let archive = root.appendingPathComponent("linked.pipcast")
        guard
            let destination = ArchiveByteStream.fileStream(
                path: FilePath(archive.path), mode: .writeOnly, options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o600)),
            let compressor = ArchiveByteStream.compressionStream(
                using: .lzfse, writingTo: destination)
        else {
            check("the symlink fixture can be built", false)
            return
        }
        do {
            try ArchiveStream.withEncodeStream(writingTo: compressor) { encoder in
                let header = ArchiveHeader()
                // 76 is `L`; the Swift overlay names no symbolic-link case to spell it with.
                header.append(.uint(key: ArchiveHeader.FieldKey("TYP"), value: 76))
                header.append(.string(key: ArchiveHeader.FieldKey("PAT"), value: "notes"))
                header.append(
                    .string(key: ArchiveHeader.FieldKey("LNK"), value: root.path))
                header.append(.uint(key: ArchiveHeader.FieldKey("MOD"), value: 0o777))
                try encoder.writeHeader(header)
            }
            try compressor.close()
            try destination.close()
        } catch {
            check("the symlink fixture can be built (\(error))", false)
            return
        }

        let into = root.appendingPathComponent("linked-out", isDirectory: true)
        do {
            try BackupArchive.open(file: archive, into: into)
            check("an archive carrying a symlink is refused", false)
        } catch {
            check(
                "an archive carrying a symlink is refused",
                error as? BackupArchive.ArchiveError == .cannotRead)
        }
    }

    // MARK: - Declarations

    /// The tripwire for adding a case and forgetting the layout or the picker.
    static func categoriesAreComplete() {
        var subpaths: Set<String> = []
        for category in BackupCategory.allCases {
            let descriptor = category.descriptor
            check("\(category.rawValue) has a label", !descriptor.label.isEmpty)
            check("\(category.rawValue) has a symbol", !descriptor.symbol.isEmpty)
            if !descriptor.subpath.isEmpty {
                check(
                    "\(category.rawValue)'s subpath is its own",
                    subpaths.insert(descriptor.subpath)
                        .inserted)
            }
        }
        check("every case is offered", BackupCategory.all.count == BackupCategory.allCases.count)
        check(
            "ordering follows declaration order",
            BackupCategory.ordered(BackupCategory.all) == BackupCategory.allCases)
    }

    static func staging() {
        let base = scratch()
        defer { try? FileManager.default.removeItem(at: base) }
        guard let staging = try? BackupStaging(base: base) else {
            check("staging is created on init", false)
            return
        }
        check(
            "staging is created on init",
            FileManager.default.fileExists(atPath: staging.root.path))
        staging.discard()
        check(
            "discard removes the tree",
            !FileManager.default.fileExists(atPath: staging.root.path))
        staging.discard()
        check("discard is idempotent", true)
    }
    @MainActor
    final class OpenGate {
        var pending: [String: CheckedContinuation<(BackupStaging, BackupManifest), any Error>] = [:]

        func open(_ file: URL) async throws -> (BackupStaging, BackupManifest) {
            try await withCheckedThrowingContinuation { pending[file.lastPathComponent] = $0 }
        }

        func wait(for name: String) async {
            for _ in 0..<1_000 {
                if pending[name] != nil { return }
                await Task.yield()
            }
            fatalError("The extraction task did not start")
        }

        func finish(_ name: String, staging: BackupStaging) {
            pending.removeValue(forKey: name)?.resume(returning: (
                staging, BackupManifest(appVersion: name, createdAt: Date(), counts: [:])))
        }
    }

    static func overlappingImports() async {
        let base = scratch()
        defer { try? FileManager.default.removeItem(at: base) }
        do {
            let gate = OpenGate()
            let session = BackupImportSession()
            let first = try BackupStaging(base: base)
            let second = try BackupStaging(base: base)
            session.open(base.appendingPathComponent("A"), using: gate.open)
            await gate.wait(for: "A")
            session.open(base.appendingPathComponent("B"), using: gate.open)
            await gate.wait(for: "B")
            gate.finish("B", staging: second)
            for _ in 0..<1_000 where session.staging == nil { await Task.yield() }
            gate.finish("A", staging: first)
            for _ in 0..<1_000 where FileManager.default.fileExists(atPath: first.root.path) {
                await Task.yield()
            }
            check("late extraction cannot replace the selected archive", session.manifest?.appVersion == "B")
            check("selected filename matches the staged archive", session.file?.lastPathComponent == "B")
            check("stale extraction discards its files", !FileManager.default.fileExists(atPath: first.root.path))
            session.discard()
            check("discard removes the current staging", !FileManager.default.fileExists(atPath: second.root.path))
            let third = try BackupStaging(base: base)
            session.open(base.appendingPathComponent("C"), using: gate.open)
            await gate.wait(for: "C")
            session.discard()
            gate.finish("C", staging: third)
            for _ in 0..<1_000 where FileManager.default.fileExists(atPath: third.root.path) {
                await Task.yield()
            }
            check("leaving during extraction keeps the session empty", session.staging == nil)
            check("leaving during extraction removes late files", !FileManager.default.fileExists(atPath: third.root.path))
        } catch { check("overlapping import fixtures: \(error)", false) }
    }

}
