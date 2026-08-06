import SwiftUI

struct CreateSpaceSheetView: View {
    let isMutating: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSubmit: (String, String) -> Void
    
    var body: some View {
        WorkspaceEditorSheet(
            title: String(localized: "New space"),
            subtitle: String(localized: "Create a focused archive for sources, notes and grounded answers."),
            submitTitle: String(localized: "Create"),
            isMutating: isMutating,
            errorMessage: errorMessage,
            onCancel: onCancel,
            onSubmit: onSubmit
        )
    }
}
