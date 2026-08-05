import SwiftUI

struct WorkspaceCard: View {
    let workspace: Workspace
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Button(action: onSelect) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Text(String(workspace.name.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .regular, design: .serif))
                                .foregroundStyle(Color.folioInk)
                                .frame(width: 36, height: 36)
                                .background(Color.folioHomeTypeBadgeBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.folioLine, lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(workspace.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.folioInk)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(workspace.updatedAt.workspaceRelativeLabel)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.folioInkSoft)
                            }
                        }
                        .padding(.trailing, 36)
                        
                        if !workspace.objective.isEmpty {
                            Text(workspace.objective)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.folioInkMuted)
                                .lineLimit(3)
                        }
                        
                        Divider()
                            .background(Color.folioLine)
                        
                        Text(
                            String(
                                format: String(localized: "%lld sources · %lld notes"),
                                locale: .current,
                                workspace.sourceCount,
                                workspace.noteCount
                            )
                        )
                        .font(.system(size: 12))
                        .foregroundStyle(Color.folioInkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHint(String(localized: "Double tap to open"))
                
                Menu {
                    Button(String(localized: "Edit"), action: onEdit)
                    Button(
                        String(localized: "Delete"),
                        role: .destructive,
                        action: onDelete
                    )
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.folioInkMuted)
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel(
                    String(localized: "More options for \(workspace.name)")
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.folioSurfaceStrong)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.folioLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
    }
}
