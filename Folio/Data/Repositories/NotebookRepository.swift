import Foundation

final class NotebookRepository: NotebookRepositoryProtocol {
    private let localStorage: LocalStorageProtocol
    private let networkService: NetworkServiceProtocol

    init(localStorage: LocalStorageProtocol, networkService: NetworkServiceProtocol) {
        self.localStorage = localStorage
        self.networkService = networkService
    }

    func fetchNotebook(spaceId: String) async throws -> NotebookFetchResult {
        let storageKey = notebookStorageKey(spaceId)
        do {
            let response: NotebookResponseDTO = try await networkService.request(
                NotebookEndpoint.fetch(spaceId: spaceId))
            let serverNotebook = response.data.notebook
            if let pending = pendingUnsyncedEntry(for: storageKey) {
                // The draft recorded which server version it was based on
                // (baseServerUpdatedAt, server clock). Only a real remote change —
                // server now newer than that baseline — is a conflict. This avoids
                // comparing the device clock against the server clock.
                let remoteChanged = pending.baseServerUpdatedAt
                    .map { serverNotebook.updatedAt > $0 } ?? true
                if !remoteChanged {
                    await replayPendingSave(pending, spaceId: spaceId)
                    return NotebookFetchResult(entry: pending.toDomain(), preservedOfflineDraft: false)
                }
                // Genuine conflict: preserve the offline draft and surface it to the
                // user instead of silently overwriting.
                backupUnsyncedEntry(pending, for: storageKey)
                try? localStorage.save(syncedServerCopy(serverNotebook), forKey: storageKey)
                return NotebookFetchResult(entry: serverNotebook.toDomain(), preservedOfflineDraft: true)
            }
            try? localStorage.save(syncedServerCopy(serverNotebook), forKey: storageKey)
            return NotebookFetchResult(entry: serverNotebook.toDomain(), preservedOfflineDraft: false)
        } catch {
            guard isTransportError(error),
                  let cached: NotebookDTO = try? localStorage.load(forKey: storageKey)
            else {
                throw error
            }
            return NotebookFetchResult(entry: cached.toDomain(), preservedOfflineDraft: false)
        }
    }

    func saveNotebook(entry: NotebookEntry) async throws {
        let storageKey = notebookStorageKey(entry.researchSpaceId)
        let existing: NotebookDTO? = try? localStorage.load(forKey: storageKey)
        var pending = makeDTO(from: entry, needsSync: true)
        pending.baseServerUpdatedAt = existing?.baseServerUpdatedAt
        try? localStorage.save(pending, forKey: storageKey)

        let response: NotebookResponseDTO = try await networkService.request(
            NotebookEndpoint.save(spaceId: entry.researchSpaceId, content: entry.content))
        let server = response.data.notebook
        var synced = makeDTO(from: entry, needsSync: false)
        synced.updatedAt = server.updatedAt
        synced.baseServerUpdatedAt = server.updatedAt
        try? localStorage.save(synced, forKey: storageKey)
    }

    private func pendingUnsyncedEntry(for storageKey: String) -> NotebookDTO? {
        guard let cached: NotebookDTO = try? localStorage.load(forKey: storageKey), cached.needsSync else {
            return nil
        }
        return cached
    }

    private func backupUnsyncedEntry(_ entry: NotebookDTO, for storageKey: String) {
        Logger.error("Preserving unsynced offline notebook edit for \(storageKey)")
        try? localStorage.save(entry, forKey: recoveryStorageKey(storageKey))
    }

    private func replayPendingSave(_ entry: NotebookDTO, spaceId: String) async {
        do {
            let response: NotebookResponseDTO = try await networkService.request(
                NotebookEndpoint.save(spaceId: spaceId, content: entry.content))
            var synced = entry
            synced.needsSync = false
            synced.updatedAt = response.data.notebook.updatedAt
            synced.baseServerUpdatedAt = response.data.notebook.updatedAt
            try? localStorage.save(synced, forKey: notebookStorageKey(spaceId))
        } catch {
            Logger.error("Notebook pending-sync replay failed: \(error)")
        }
    }

    private func makeDTO(from entry: NotebookEntry, needsSync: Bool) -> NotebookDTO {
        NotebookDTO(
            id: entry.id,
            researchSpaceId: entry.researchSpaceId,
            content: entry.content,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
            needsSync: needsSync
        )
    }

    private func syncedServerCopy(_ server: NotebookDTO) -> NotebookDTO {
        var copy = server
        copy.needsSync = false
        copy.baseServerUpdatedAt = server.updatedAt
        return copy
    }

    private func isTransportError(_ error: Error) -> Bool {
        if error is URLError { return true }
        if let networkError = error as? NetworkError {
            switch networkError {
            case .invalidResponse, .circuitBreakerOpen:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func notebookStorageKey(_ spaceId: String) -> String {
        "notebook_\(spaceId)"
    }

    private func recoveryStorageKey(_ storageKey: String) -> String {
        "\(storageKey)_recovery"
    }
}
