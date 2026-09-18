import SwiftUI

struct WorkspaceEditorSubmission: Equatable {
    let name: String
    let objective: String
}

struct WorkspaceEditorDraft: Equatable {
    static let nameMaxLength = 100
    static let objectiveMaxLength = 500
    
    let name: String
    let objective: String
    
    var limited: WorkspaceEditorDraft {
        WorkspaceEditorDraft(
            name: String(name.prefix(Self.nameMaxLength)),
            objective: String(objective.prefix(Self.objectiveMaxLength))
        )
    }
    
    var submission: WorkspaceEditorSubmission? {
        let draft = limited
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return WorkspaceEditorSubmission(
            name: name,
            objective: draft.objective.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

struct WorkspaceEditorSheet: View {
    let title: String
    let subtitle: String
    let submitTitle: String
    let initialName: String
    let initialObjective: String
    let isMutating: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSubmit: (String, String) -> Void
    
    @State private var name: String
    @State private var objective: String
    @State private var nameError: String?
    @FocusState private var isNameFocused: Bool
    
    init(
        title: String,
        subtitle: String,
        submitTitle: String,
        initialName: String = "",
        initialObjective: String = "",
        isMutating: Bool,
        errorMessage: String?,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (String, String) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.submitTitle = submitTitle
        self.initialName = initialName
        self.initialObjective = initialObjective
        self.isMutating = isMutating
        self.errorMessage = errorMessage
        self.onCancel = onCancel
        self.onSubmit = onSubmit
        _name = State(initialValue: WorkspaceEditorDraft(name: initialName, objective: initialObjective).limited.name)
        _objective = State(initialValue: WorkspaceEditorDraft(name: initialName, objective: initialObjective).limited.objective)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            header
            formBody
            footer
        }
        .background(Color.folioSurfaceStrong)
        .onAppear { isNameFocused = true }
        .onChange(of: errorMessage) { _, message in
            if let message { nameError = message }
        }
        .presentationBackground(Color.folioSurfaceStrong)
        .presentationDetents([.height(460)])
    }
    
    private var dragHandle: some View {
        Capsule()
            .fill(Color.folioInkSoft.opacity(0.3))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.custom("CormorantGaramond-Medium", size: FolioFontSize.heading))
                    .foregroundStyle(Color.folioInk)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.folioInkSoft)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Close"))
            }
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Color.folioInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    private var formBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                FolioTextField(
                    label: String(localized: "Space name"),
                    placeholder: String(localized: "Q1 Market Research"),
                    text: $name,
                    maxLength: WorkspaceEditorDraft.nameMaxLength,
                    error: nameError,
                    focused: $isNameFocused
                )
                .onChange(of: name) { _, _ in
                    if nameError != nil { nameError = nil }
                }
                
                FolioTextField(
                    label: String(localized: "Research objective"),
                    placeholder: String(localized: "What should this space help you understand?"),
                    text: $objective,
                    style: .multiline(),
                    maxLength: WorkspaceEditorDraft.objectiveMaxLength
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text(String(localized: "Cancel"))
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(Color.folioInk)
                    .background(Color.folioSurfaceStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.folioFieldBorder, lineWidth: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            
            FolioPrimaryButton(
                title: submitTitle,
                isLoading: isMutating,
                isEnabled: !isSubmitDisabled,
                verticalPadding: 15,
                action: submitForm
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.folioSurfaceStrong)
    }
    
    private var isSubmitDisabled: Bool {
        WorkspaceEditorDraft(name: name, objective: objective).submission == nil || isMutating
    }
    
    private func submitForm() {
        guard let submission = WorkspaceEditorDraft(name: name, objective: objective).submission else {
            nameError = String(localized: "Enter a space name")
            isNameFocused = true
            return
        }
        onSubmit(submission.name, submission.objective)
    }
}
