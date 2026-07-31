import SwiftUI

struct FolioSourceReaderView: View {
    let source: FolioSource
    let onBack: () -> Void
    let onOpenAccountSettings: () -> Void
    let userInitial: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FolioTopBar(
                    title: source.title,
                    subtitle: source.subtitle,
                    leading: AnyView(backButton),
                    trailing: [AnyView(FolioAccountAvatarButton(initial: userInitial, size: 36, action: onOpenAccountSettings))]
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(source.chapterTitle)
                        .font(.system(size: 30, weight: .regular, design: .serif))
                        .foregroundStyle(Color.folioInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(source.chapterText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.folioInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 18)

                FolioCard(
                    content: VStack(alignment: .leading, spacing: 12) {
                        Text(source.calloutText)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color.folioInk)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            FolioPill(title: "1", isSelected: true, tint: .folioGold)
                            Spacer()
                        }
                    }
                )
                .padding(.horizontal, 18)

                FolioCard(
                    content: VStack(alignment: .leading, spacing: 10) {
                        Text(source.citationTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.folioInk)

                        Text(source.citationDetail)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.folioInkSoft)

                        Text(source.citationText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.folioInk)
                    }
                )
                .padding(.horizontal, 18)

                HStack {
                    Spacer()
                    Text(source.pageLabel)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.folioInkSoft)
                    Spacer()
                }
                .padding(.top, 2)
                .padding(.bottom, 24)
            }
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Back")
    }
}

#Preview {
    FolioSourceReaderView(source: FolioDesignFixtures.sources[0], onBack: {}, onOpenAccountSettings: {}, userInitial: "A")
}