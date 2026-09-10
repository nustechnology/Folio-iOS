import SwiftUI

struct FolioAccountAvatarButton: View {
    let initial: String
    var size: CGFloat = 36
    var fillColor: Color = .folioHomeHeader
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FolioAvatarView(initial: initial, size: size, fillColor: fillColor)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(String(localized: "Account"))
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: 1)
        )
    }
}
