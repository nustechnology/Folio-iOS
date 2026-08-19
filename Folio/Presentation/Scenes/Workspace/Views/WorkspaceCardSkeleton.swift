import SwiftUI

struct WorkspaceCardSkeleton: View {
    private let placeholderColor = Color.folioBorderLight.opacity(0.5)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(placeholderColor)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(placeholderColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 18)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(placeholderColor)
                        .frame(width: 86, height: 11)
                }

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(placeholderColor)
                    .frame(width: 24, height: 24)
            }

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(placeholderColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 14)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(placeholderColor)
                .frame(width: 180, height: 14)

            Divider()

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(placeholderColor)
                .frame(width: 132, height: 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.folioSurfaceStrong)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.folioLine, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shimmer()
        .accessibilityHidden(true)
    }
}
