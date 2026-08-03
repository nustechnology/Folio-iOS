import XCTest
@testable import Folio

final class RemoteWorkspaceRepositoryTests: XCTestCase {
    func testCreateWorkspaceMapsRemoteDTOToDomainEntity() async throws {
        let service = RecordingNetworkService()
        let repository = RemoteWorkspaceRepository(networkService: service)

        let workspace = try await repository.createWorkspace(name: "Research", objective: "Objective")

        XCTAssertEqual(workspace.name, "Research")
        XCTAssertEqual(workspace.objective, "Objective")
        guard let endpoint = service.requestedEndpoints.first as? WorkspaceEndpoint else {
            return XCTFail("Expected a workspace endpoint")
        }
        guard case .create(let name, let objective) = endpoint else {
            return XCTFail("Expected a create workspace endpoint")
        }
        XCTAssertEqual(name, "Research")
        XCTAssertEqual(objective, "Objective")
    }

    func testDeleteWorkspaceUsesVoidRequest() async throws {
        let service = RecordingNetworkService()
        let repository = RemoteWorkspaceRepository(networkService: service)

        try await repository.deleteWorkspace(id: "workspace-id")

        XCTAssertEqual(service.requestedDeleteWorkspaceID, "workspace-id")
    }
}

private final class RecordingNetworkService: NetworkServiceProtocol {
    private let workspace = WorkspaceDTO(
        id: "workspace-id",
        name: "Research",
        objective: "Objective",
        sourceCount: 2,
        noteCount: 1,
        updatedAt: Date(timeIntervalSince1970: 0)
    )
    private(set) var requestedEndpoints: [APIEndpoint] = []
    private(set) var requestedDeleteWorkspaceID: String?

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        requestedEndpoints.append(endpoint)
        if T.self == WorkspaceDTO.self { return workspace as! T }
        if T.self == [WorkspaceDTO].self { return [workspace] as! T }
        fatalError("Unexpected response type")
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {
        requestedEndpoints.append(endpoint)
        if let workspaceEndpoint = endpoint as? WorkspaceEndpoint,
           case .delete(let id) = workspaceEndpoint {
            requestedDeleteWorkspaceID = id
        }
    }
}
