import SwiftUI

struct FolioSourceReaderSkeletonView: View {
    private let onBack: () -> Void

    init(onBack: @escaping () -> Void) {
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            FolioSourceReaderSkeletonHeader(onBack: onBack)
            FolioSourceReaderSkeletonContent()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FolioSourceReaderSkeletonHeader: View {
    var onBack: (() -> Void)?

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.folioInk)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel(String(localized: "Back"))
                } else {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.folioInk)
                        .frame(width: 22, height: 22)
                        .frame(width: 44, height: 44)
                }

                SkeletonPlaceholder(height: 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shimmer()

                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .rotationEffect(.degrees(90))
                    .foregroundStyle(Color.folioInk)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(Color.folioFieldBorder, lineWidth: 0.5)
                    )
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    SkeletonPlaceholder(width: 44, height: 37, cornerRadius: FolioRadius.sm)
                    SkeletonPlaceholder(width: 66, height: 37, cornerRadius: FolioRadius.sm)
                }
                .shimmer()
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text(String(localized: "Ask source"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.folioHomeHeader)
                    .clipShape(RoundedRectangle(cornerRadius: FolioRadius.sm, style: .continuous))

                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.folioInk)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(Color.folioFieldBorder, lineWidth: 0.5)
                        )
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .allowsHitTesting(false)

            HStack(spacing: 6) {
                SkeletonPlaceholder(width: 68, height: 13)
                SkeletonPlaceholder(width: 4, height: 13)
                SkeletonPlaceholder(width: 112, height: 13)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .shimmer()
        }
        .accessibilityHidden(onBack == nil)
    }
}

struct FolioSourceReaderSkeletonContent: View {
    var body: some View {
        GeometryReader { _ in
            Color.folioSurfaceStrong
        }
        .frame(maxWidth: .infinity)
        .background(Color.folioSurfaceStrong)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 16
        ))
        .padding(.horizontal, 18)
        .ignoresSafeArea(edges: .bottom)
        .accessibilityHidden(true)
    }
}

private struct SkeletonPlaceholder: View {
    private let width: CGFloat?
    private let height: CGFloat
    private let cornerRadius: CGFloat

    init(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat = 4) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.folioBorderLight.opacity(0.5))
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .frame(width: width, height: height, alignment: .leading)
    }
}
