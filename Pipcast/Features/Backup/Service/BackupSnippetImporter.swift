import Foundation

@MainActor
enum BackupSnippetImporter {
    struct Result {
        var count = 0
        var ids: [String: String] = [:]
    }

    static func apply(
        _ incoming: [(name: String, snippet: Snippet)], to store: SnippetsStore
    ) async throws -> Result {
        let destination = store.snippetsDirectory
        let repository = SnippetRepository(snippetsDirectory: destination)
        let snapshot = try await load(repository)
        try Task.checkCancellation()
        guard destination == store.snippetsDirectory else { throw CancellationError() }
        var result = Result()
        var fresh: [Snippet] = []
        var destinations: [String: Int] = [:]
        for (name, snippet) in incoming {
            if let match = snapshot.records.first(where: {
                $0.snippet.name == snippet.name && $0.snippet.text == snippet.text
            }) {
                result.ids[name] = match.id
            } else if let index = fresh.firstIndex(where: {
                $0.name == snippet.name && $0.text == snippet.text
            }) {
                destinations[name] = index
            } else {
                destinations[name] = fresh.count
                fresh.append(snippet)
            }
        }
        try Task.checkCancellation()
        guard destination == store.snippetsDirectory else { throw CancellationError() }
        let created = try await store.importSnippets(fresh)
        guard destination == store.snippetsDirectory else { throw CancellationError() }
        for (name, index) in destinations { result.ids[name] = created[index].id }
        result.count = created.count
        return result
    }

    @concurrent
    private static func load(_ repository: SnippetRepository) async throws -> SnippetRepository.Snapshot {
        try Task.checkCancellation()
        return try repository.load()
    }
}
