import Foundation
import Observation

@MainActor
@Observable
final class BackupImportSession {
    private(set) var file: URL?
    private(set) var manifest: BackupManifest?
    private(set) var staging: BackupStaging?
    private(set) var error: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var operation: UUID?

    isolated deinit {
        task?.cancel()
        staging?.discard()
    }

    func open(
        _ file: URL,
        using open: @escaping @MainActor (URL) async throws -> (BackupStaging, BackupManifest)
    ) {
        discard()
        self.file = file
        error = nil
        let identity = UUID()
        operation = identity
        task = Task { [weak self] in
            do {
                let (staging, manifest) = try await open(file)
                guard !Task.isCancelled, let self, self.operation == identity else {
                    staging.discard()
                    return
                }
                self.staging = staging
                self.manifest = manifest
                self.task = nil
            } catch {
                guard !Task.isCancelled, let self, self.operation == identity else { return }
                self.error = error.localizedDescription
                self.task = nil
            }
        }
    }

    func discard() {
        task?.cancel()
        task = nil
        operation = nil
        staging?.discard()
        staging = nil
        manifest = nil
        file = nil
        error = nil
    }
}
