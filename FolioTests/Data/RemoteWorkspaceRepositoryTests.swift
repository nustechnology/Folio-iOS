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

    func testUpdateWorkspaceMapsRemoteDTOToDomainEntity() async throws {
        let service = RecordingNetworkService()
        let repository = RemoteWorkspaceRepository(networkService: service)

        let workspace = try await repository.updateWorkspace(id: "workspace-id", name: "Research", objective: "Objective")

        XCTAssertEqual(workspace.name, "Research")
        XCTAssertEqual(workspace.objective, "Objective")
        guard let endpoint = service.requestedEndpoints.first as? WorkspaceEndpoint else {
            return XCTFail("Expected a workspace endpoint")
        }
        guard case .update(let id, let name, let objective) = endpoint else {
            return XCTFail("Expected an update workspace endpoint")
        }
        XCTAssertEqual(id, "workspace-id")
        XCTAssertEqual(name, "Research")
        XCTAssertEqual(objective, "Objective")
    }

    func testDeleteWorkspaceUsesVoidRequest() async throws {
        let service = RecordingNetworkService()
        let repository = RemoteWorkspaceRepository(networkService: service)

        try await repository.deleteWorkspace(id: "workspace-id")

        XCTAssertEqual(service.requestedDeleteWorkspaceID, "workspace-id")
    }

    func testFetchWorkspacesMapsPaginatedResponse() async throws {
        let service = RecordingNetworkService()
        let repository = RemoteWorkspaceRepository(networkService: service)

        let result = try await repository.fetchWorkspaces(query: WorkspaceListQuery(sort: nil, page: 2, limit: 10))

        XCTAssertEqual(result.workspaces.first?.objective, "Research objective")
        XCTAssertEqual(result.pagination?.page, 2)
        XCTAssertEqual(result.pagination?.totalPages, 4)
        guard let endpoint = service.requestedEndpoints.first as? WorkspaceEndpoint else {
            return XCTFail("Expected a workspace endpoint")
        }
        guard case .list(let query) = endpoint else {
            return XCTFail("Expected a list workspace endpoint")
        }
        XCTAssertEqual(query.page, 2)
        XCTAssertEqual(query.limit, 10)
    }

    func testFetchWorkspacesMapsResponseWithoutPagination() async throws {
        let service = RecordingNetworkService(includePagination: false)
        let repository = RemoteWorkspaceRepository(networkService: service)

        let result = try await repository.fetchWorkspaces(query: .initial)

        XCTAssertEqual(result.workspaces.count, 1)
        XCTAssertNil(result.pagination)
    }
}

private final class RecordingNetworkService: NetworkServiceProtocol {
    private let workspace = SpaceDTO(
        id: "workspace-id",
        name: "Research",
        researchObjective: "Research objective",
        sourceCount: 2,
        noteCount: 1,
        updatedAt: Date(timeIntervalSince1970: 0)
    )
    private let mutationSpace = SpaceDTO(
        id: "workspace-id",
        name: "Research",
        researchObjective: "Objective",
        sourceCount: 2,
        noteCount: 1,
        updatedAt: Date(timeIntervalSince1970: 0)
    )
    private let includePagination: Bool
    private(set) var requestedEndpoints: [APIEndpoint] = []
    private(set) var requestedDeleteWorkspaceID: String?

    init(includePagination: Bool = true) {
        self.includePagination = includePagination
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        requestedEndpoints.append(endpoint)
        if T.self == WorkspaceResponseDTO.self {
            return WorkspaceResponseDTO(status: "success", data: WorkspaceResponseDataDTO(
                spaces: [workspace],
                pagination: includePagination ? PaginationDTO(page: 2, limit: 10, totalCount: 31, totalPages: 4) : nil
            )) as! T
        }
        if T.self == CreateSpaceResponseDTO.self {
            return CreateSpaceResponseDTO(status: "success", data: CreateSpaceResponseDTO.CreateSpaceDataDTO(space: mutationSpace)) as! T
        }
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
