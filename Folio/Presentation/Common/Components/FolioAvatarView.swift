import SwiftUI

struct FolioAvatarView: View {
    let initial: String
    var size: CGFloat = 36
    var fillColor: Color = .folioHomeHeader

    var body: some View {
        Text(initial.uppercased())
            .font(.system(size: size * 0.38, weight: .medium, design: .serif))
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .background(fillColor)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
    }
}
