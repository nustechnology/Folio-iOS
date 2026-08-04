import SwiftUI

struct CreateSpaceSheetView: View {
    let isMutating: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSubmit: (String, String) -> Void

    @State private var name = ""
    @State private var objective = ""
    @State private var nameError: String?
    @FocusState private var isNameFocused: Bool

    private let nameMaxLength = 100
    private let objectiveMaxLength = 500

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            header
            formBody
            footer
        }
        .background(Color.folioCanvas)
        .onAppear { isNameFocused = true }
        .onChange(of: errorMessage) { _, message in
            if let message { nameError = message }
        }
        .presentationDetents([.medium, .large])
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.folioInkSoft.opacity(0.3))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    private var header: some View {
        HStack {
            Text(String(localized: "New space"))
                .font(.custom("CormorantGaramond-SemiBold", size: 24))
                .foregroundStyle(Color.folioInk)
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.folioInkSoft)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var formBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Name"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.folioInkSoft)
                        .padding(.leading, 4)

                    TextField(String(localized: "e.g., Quantum Computing Basics"), text: $name)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.folioInk)
                        .focused($isNameFocused)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.folioSurfaceStrong)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(nameError != nil ? Color.folioDanger : Color.folioFieldBorder, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .onChange(of: name) { _, newValue in
                            if newValue.count > nameMaxLength {
                                name = String(newValue.prefix(nameMaxLength))
                            }
                            if nameError != nil { nameError = nil }
                        }

                    HStack {
                        Spacer()
                        Text("\(name.count)/\(nameMaxLength)")
                            .font(.system(size: 11))
                            .foregroundStyle(name.count >= nameMaxLength ? Color.folioDanger : Color.folioInkSoft)
                    }
                    .padding(.horizontal, 4)

                    if let error = nameError {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .padding(.leading, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Research Objective (Optional)"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.folioInkSoft)
                        .padding(.leading, 4)

                    ZStack(alignment: .topLeading) {
                        if objective.isEmpty {
                            Text(String(localized: "e.g., Collect key papers and draft literature review"))
                                .font(.system(size: 14))
                                .foregroundStyle(Color.folioInkSoft.opacity(0.6))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                        TextEditor(text: $objective)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.folioInk)
                            .scrollContentBackground(.hidden)
                            .background(Color.folioSurfaceStrong)
                            .frame(minHeight: 100, maxHeight: 160)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .onChange(of: objective) { _, newValue in
                                if newValue.count > objectiveMaxLength {
                                    objective = String(newValue.prefix(objectiveMaxLength))
                                }
                            }
                    }
                    .background(Color.folioSurfaceStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.folioFieldBorder, lineWidth: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    HStack {
                        Spacer()
                        Text("\(objective.count)/\(objectiveMaxLength)")
                            .font(.system(size: 11))
                            .foregroundStyle(objective.count >= objectiveMaxLength ? Color.folioDanger : Color.folioInkSoft)
                    }
                    .padding(.horizontal, 4)
                }
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

            Button(action: { submitForm() }) {
                HStack(spacing: 8) {
                    if isMutating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text(String(localized: "Create space"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(.white)
                .background(
                    isSubmitDisabled
                        ? Color.folioOlive.opacity(0.4)
                        : Color.folioOliveDark
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.folioGold.opacity(0.35), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitDisabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.folioCanvas)
    }

    private var isSubmitDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isMutating
    }

    private func submitForm() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            nameError = String(localized: "Enter a space name")
            isNameFocused = true
            return
        }
        onSubmit(trimmedName, objective.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
