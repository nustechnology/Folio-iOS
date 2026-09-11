import SwiftUI

struct AskConversationListView: View {
    @ObservedObject var viewModel: AskConversationListViewModel
    let workspaceTitle: String?
    let onBackToSpaces: () -> Void
    let onNewConversation: () -> Void
    let onSelectConversation: (AskConversation) -> Void
    @State private var showNewConversationSheet = false
    @State private var actionSheetTarget: AskConversation?
    @State private var renameTarget: AskConversation?
    @State private var deleteTarget: AskConversation?

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Color.folioCanvas)
        .task { viewModel.handle(.onAppear) }
        .sheet(isPresented: $showNewConversationSheet) {
            newConversationSheet
        }
        .sheet(item: $actionSheetTarget) { conversation in
            conversationActionSheet(conversation: conversation)
        }
        .sheet(item: $renameTarget) { conversation in
            RenameConversationSheet(
                conversation: conversation,
                onSubmit: { title in
                    viewModel.handle(.renameConversation(conversation, title: title))
                },
                onCancel: { renameTarget = nil }
            )
        }
        .sheet(item: $deleteTarget) { conversation in
            ConfirmationBottomSheet(
                title: String(localized: "Delete conversation?"),
                message: String(localized: "This permanently removes the conversation and its messages."),
                confirmTitle: String(localized: "Delete"),
                onCancel: { deleteTarget = nil },
                onConfirm: {
                    viewModel.handle(.deleteConversation(conversation))
                    deleteTarget = nil
                }
            )
        }
        .folioToast(message: $viewModel.toastMessage)
    }

    private var header: some View {
        FolioContentHeader(
            title: String(localized: "Ask"),
            subtitle: workspaceTitle?.isEmpty == false ? workspaceTitle! : String(localized: "Private research assistant"),
            onBackToSpaces: onBackToSpaces,
            onPlusTapped: { showNewConversationSheet = true },
            searchPlaceholder: String(localized: "Search conversations..."),
            searchText: Binding(
                get: { viewModel.state.searchQuery },
                set: { query in
                    Task { @MainActor in
                        viewModel.handle(.searchQueryChanged(query))
                    }
                }
            ),
            onClearSearch: { viewModel.handle(.searchQueryChanged("")) }
        )
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FolioSpacing.sm) {
                if viewModel.state.isLoading && viewModel.state.conversations.isEmpty {
                    ForEach(0..<5, id: \.self) { _ in
                        AskConversationRowSkeleton()
                    }
                } else if let error = viewModel.state.errorMessage, viewModel.state.conversations.isEmpty {
                    ErrorView(message: error, retryAction: { viewModel.handle(.retry) })
                        .padding(.top, FolioSpacing.xl2)
                } else if viewModel.state.conversations.isEmpty {
                    emptyState
                } else if viewModel.filteredConversations.isEmpty {
                    noSearchResults
                } else {
                    ForEach(Array(viewModel.filteredConversations.enumerated()), id: \.element.id) { index, conversation in
                        AskConversationRow(
                            conversation: conversation,
                            onOpen: { onSelectConversation(conversation) },
                            onMenu: { actionSheetTarget = conversation }
                        )
                        .onAppear {
                            if index == viewModel.filteredConversations.count - 1 {
                                viewModel.handle(.loadMore)
                            }
                        }
                    }

                    if viewModel.state.isLoadingNextPage {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FolioSpacing.lg)
                    } else if let error = viewModel.state.paginationErrorMessage {
                        VStack(spacing: 6) {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(Color.folioDanger)
                                .multilineTextAlignment(.center)
                            Button(String(localized: "Retry")) {
                                viewModel.handle(.loadMore)
                            }
                            .tint(Color.folioOlive)
                        }
                        .padding(.vertical, FolioSpacing.lg)
                    }
                }
            }
            .padding(FolioSpacing.xl2)
        }
        .refreshable { await viewModel.refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: FolioSpacing.xl) {
            Image(systemName: "sparkles")
                .font(.system(size: FolioFontSize.bodyLarge, weight: .medium))
                .foregroundStyle(Color.folioInkSoft)
                .frame(width: FolioSize.fieldHeightSm, height: FolioSize.fieldHeightSm)
                .background(Color.folioSurfaceStrong)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.folioLine.opacity(0.65), lineWidth: 1)
                )

            VStack(spacing: FolioSpacing.sm) {
                Text(String(localized: "No conversations yet"))
                    .font(.system(size: FolioFontSize.body, weight: .semibold))
                    .foregroundStyle(Color.folioInk)
                Text(String(localized: "Ask a question to start a grounded conversation."))
                    .font(.system(size: FolioFontSize.bodySmall, weight: .regular))
                    .foregroundStyle(Color.folioInkSoft)
                    .multilineTextAlignment(.center)
            }

            Button(action: onNewConversation) {
                Text(String(localized: "New conversation"))
                    .font(.system(size: FolioFontSize.bodySmall, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(height: 35)
                    .padding(.horizontal, FolioSpacing.lg)
                    .background(Color.folioOliveDark)
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerRelativeFrame(.vertical)
    }

    private var noSearchResults: some View {
        VStack(spacing: FolioSpacing.xl) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: FolioFontSize.subheadline, weight: .medium))
                .foregroundStyle(Color.folioInkSoft)
                .frame(width: FolioSize.fieldHeightSm, height: FolioSize.fieldHeightSm)
                .background(Color.folioSurfaceStrong)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.folioLine.opacity(0.65), lineWidth: 1)
                )

            VStack(spacing: FolioSpacing.sm) {
                Text(String(localized: "No conversations found"))
                    .font(.system(size: FolioFontSize.body, weight: .semibold))
                    .foregroundStyle(Color.folioInk)
                Text(String(localized: "Try a different search term."))
                    .font(.system(size: FolioFontSize.bodySmall, weight: .regular))
                    .foregroundStyle(Color.folioInkSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FolioSpacing.xl4)
    }

    private var newConversationSheet: some View {
        VStack(spacing: 0) {
            Text(String(localized: "Conversation"))
                .font(.custom("CormorantGaramond-SemiBold", size: 26))
                .foregroundStyle(Color.folioTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.top, FolioSpacing.xl)
                .padding(.bottom, FolioSpacing.xl)

            FolioPrimaryButton(
                title: String(localized: "New conversation"),
                verticalPadding: FolioSpacing.xl,
                action: {
                    showNewConversationSheet = false
                    onNewConversation()
                }
            )
            .padding(.horizontal, FolioSpacing.xl3)
        }
        .frame(maxWidth: .infinity)
        .background(Color.folioSurfaceStrong)
        .presentationBackground(Color.folioSurfaceStrong)
        .presentationDetents([.height(140)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func conversationActionSheet(conversation: AskConversation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(conversation.title)
                .font(.custom("CormorantGaramond-SemiBold", size: 28))
                .foregroundStyle(Color.folioTextPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.top, FolioSpacing.xl4)
                .padding(.bottom, FolioSpacing.xl3)

            VStack(spacing: FolioSpacing.md) {
                Button {
                    actionSheetTarget = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        renameTarget = conversation
                    }
                } label: {
                    Text(String(localized: "Rename"))
                        .font(.system(size: FolioFontSize.bodyLarge, weight: .semibold))
                        .foregroundStyle(Color.folioTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.folioHomeSheetBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: FolioRadius.md)
                                .stroke(Color.folioBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                }
                .buttonStyle(.plain)

                Button {
                    actionSheetTarget = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        deleteTarget = conversation
                    }
                } label: {
                    Text(String(localized: "Delete conversation"))
                        .font(.system(size: FolioFontSize.bodyLarge, weight: .bold))
                        .foregroundStyle(Color.folioDanger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.folioDanger.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: FolioRadius.md)
                                .stroke(Color.folioDanger, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.md))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FolioSpacing.xl3)
            .padding(.bottom, FolioSpacing.xl3)
        }
        .frame(maxWidth: .infinity)
        .presentationBackground(Color.folioHomeSheetBackground)
        .presentationDetents([.height(236)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Rename sheet

private struct RenameConversationSheet: View {
    let conversation: AskConversation
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @FocusState private var isFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private static let maxLength = 255
    private var titleTooLong: Bool { title.count > Self.maxLength }
    private var canSave: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !titleTooLong && trimmed != conversation.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Rename conversation"))
                .font(.custom("CormorantGaramond-SemiBold", size: 26))
                .foregroundStyle(Color.folioTextPrimary)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.top, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.sm)

            Text(String(localized: "Conversations are titled with their opening question. Give this one a name that will be easier to find."))
                .font(.system(size: 14))
                .foregroundStyle(Color.folioInkMuted)
                .lineSpacing(6)
                .lineLimit(2)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl)

            Text(String(localized: "Title"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.folioFieldBorder)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.sm)

            PlaceholderUITextField(
                placeholder: String(localized: "Untitled"),
                placeholderColor: UIColor(Color.folioInkSoft),
                font: .systemFont(ofSize: 15, weight: .regular),
                textColor: UIColor(Color.folioInk),
                keyboardType: .default,
                isSecureTextEntry: false,
                text: $title
            )
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color.folioSurfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(titleTooLong ? Color.folioDanger : Color.folioFieldBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .focused($isFieldFocused)
                .padding(.horizontal, FolioSpacing.xl3)
                .padding(.bottom, FolioSpacing.xl)

            if titleTooLong {
                Text(String(localized: "Title cannot exceed 255 characters"))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.folioDanger)
                    .padding(.horizontal, FolioSpacing.xl3)
                    .padding(.bottom, FolioSpacing.xl)
            }

            HStack(spacing: 10) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onCancel()
                    }
                } label: {
                    Text(String(localized: "Cancel"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.folioTextPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.folioSurfaceStrong)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.folioRowBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                FolioPrimaryButton(
                    title: String(localized: "Save"),
                    isEnabled: canSave,
                    verticalPadding: FolioSpacing.xl,
                    action: {
                        onSubmit(title.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                )
            }
            .padding(.horizontal, FolioSpacing.xl3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.folioSurfaceStrong)
        .presentationBackground(Color.folioSurfaceStrong)
        .presentationDetents([.fraction(0.3)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(FolioRadius.xl2)
        .onAppear {
            title = conversation.title
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFieldFocused = true
            }
        }
    }
}

private struct AskConversationRow: View {
    let conversation: AskConversation
    let onOpen: () -> Void
    let onMenu: () -> Void

    var body: some View {
        Button(action: onOpen) {
            FolioCard(content: cardContent)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        HStack(alignment: .top, spacing: FolioSpacing.lg) {
            Image(systemName: "sparkles")
                .font(.system(size: FolioFontSize.body, weight: .semibold))
                .foregroundStyle(Color.folioOliveDark)
                .frame(width: FolioSize.chipHeight, height: FolioSize.chipHeight)
                .background(Color.folioOlive.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(conversation.title)
                    .font(.system(size: FolioFontSize.subheadline, design: .serif))
                    .foregroundStyle(Color.folioInk)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(conversation.updatedAt.noteListDisplayLabel)
                    .font(.system(size: FolioFontSize.caption2, weight: .regular))
                    .foregroundStyle(Color.folioInkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onMenu) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.folioInkMuted)
                    .rotationEffect(.degrees(90))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct AskConversationRowSkeleton: View {
    var body: some View {
        FolioCard(
            content: HStack(alignment: .top, spacing: FolioSpacing.lg) {
                Color.folioBorderLight.opacity(0.35)
                    .frame(width: FolioSize.chipHeight, height: FolioSize.chipHeight)
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Color.folioBorderLight.opacity(0.35)
                        .frame(width: 160, height: FolioSpacing.xl)
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xs, style: .continuous))
                    Color.folioBorderLight.opacity(0.35)
                        .frame(width: 90, height: FolioSpacing.lg)
                        .clipShape(RoundedRectangle(cornerRadius: FolioRadius.xs, style: .continuous))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        )
    }
}

#Preview {
    AskConversationListView(
        viewModel: AskConversationListViewModel(
            spaceId: "preview-space",
            fetchAskConversationsUseCase: PreviewFetchAskConversationsUseCase(),
            deleteConversationUseCase: PreviewDeleteConversationUseCase(),
            renameConversationUseCase: PreviewRenameConversationUseCase()
        ),
        workspaceTitle: "Research",
        onBackToSpaces: {},
        onNewConversation: {},
        onSelectConversation: { _ in }
    )
}

private struct PreviewFetchAskConversationsUseCase: FetchAskConversationsUseCaseProtocol {
    func execute(query: AskConversationListQuery) async throws -> AskConversationListResult {
        AskConversationListResult(conversations: [], pagination: nil)
    }
}

private struct PreviewDeleteConversationUseCase: DeleteConversationUseCaseProtocol {
    func execute(spaceId: String, conversationId: String) async throws {}
}

private struct PreviewRenameConversationUseCase: RenameConversationUseCaseProtocol {
    func execute(spaceId: String, conversationId: String, title: String) async throws {}
}
