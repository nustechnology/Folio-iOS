# My Space — Backend Integration Checklist

Use this document when the official My Space backend becomes available.

## Current architecture

```text
WorkspaceListView → WorkspaceListViewModel → Use Cases
                   → WorkspaceRepositoryProtocol
                   → InMemoryWorkspaceRepository (mock)
                   → RemoteWorkspaceRepository (API)
```

The Domain, Use Case, ViewModel, and UI layers do not depend directly on the
API or DTOs.

## Required updates

### Confirm the API contract

Confirm the following with the backend team:

- Base URL in `Configuration/Debug.xcconfig` and `Release.xcconfig`.
- Methods and paths for `GET`, `POST`, `PUT`, and `DELETE /api/v1/workspaces/{id}`.
- JSON fields: `id`, `name`, `objective`, `sourceCount`, `noteCount`, and `updatedAt`.
- Whether responses are direct arrays or envelopes such as `{ "data": [...] }`.
- `updatedAt` format: ISO8601 or Unix timestamp.
- Whether DELETE returns a body or `204 No Content`.
- Error envelope, status codes, and error codes.

If paths change, update only `Folio/Data/DataSources/Remote/WorkspaceEndpoint.swift`.
If the JSON shape changes, update only `Folio/Data/DTOs/WorkspaceDTO.swift` and
the mapping in the Data layer.

### Switch DI from mock to API

In `Folio/App/AppDIContainer.swift`, change `InMemoryWorkspaceRepository()` to
`remoteWorkspaceRepository`. Do not change the ViewModel, Use Cases, or Views.

### Verify authentication and errors

`RemoteWorkspaceRepository` reads `auth_session` and sends
`Authorization: Bearer <access_token>`. Confirm this contract with the backend.
If token refresh is required after a `401`, implement it in the Data/Network
layer, not Presentation.

Map `400`, `401`, `403`, `404`, `409`, `5xx`, and network failures to
appropriate domain errors. Failed create/update operations must preserve the
draft; failed deletes must preserve the workspace in the list.

### Integration checklist

- [ ] Successful fetch, empty state, and retry after a network failure.
- [ ] Search by name and objective.
- [ ] Successful and failed create/update/delete operations.
- [ ] DELETE with `204 No Content`.
- [ ] Correct token transmission and `401` handling.
- [ ] Home receives `workspaceID`; title is never used as identity.
- [ ] Deleting the currently open workspace returns to My Space.
- [ ] ViewModel and repository unit tests.
- [ ] Debug and Release builds.
- [ ] VoiceOver, Dynamic Type, and keyboard behavior in forms.
