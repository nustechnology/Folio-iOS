import SwiftUI

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum FolioTheme {
    static let canvas = Color(hex: 0xF6F1E5)
    static let surface = Color(hex: 0xFCF9F0)
    static let surfaceStrong = Color(hex: 0xFEFCF6)
    static let ink = Color(hex: 0x0C241E)
    static let inkMuted = Color(hex: 0x5B5244)
    static let inkSoft = Color(hex: 0x8F8570)
    static let olive = Color(hex: 0x13332A)
    static let oliveDark = Color(hex: 0x051B16)
    static let line = Color(hex: 0xD6C29C)
    static let rowBorder = Color(hex: 0xD8CCB8)
    static let fieldBorder = Color(hex: 0xC4A87D)
    static let gold = Color(hex: 0xC28D3E)
    static let goldSoft = Color(hex: 0xEBD6A8)
    static let success = Color(hex: 0xC6D2AC)
    static let successStrong = Color(hex: 0x2E7D32)
    static let warning = Color(hex: 0xEAD8A3)
    static let danger = Color(hex: 0xC0392B)

    static let border = Color(hex: 0xDED7C8)
    static let borderLight = Color(hex: 0xE5DED1)
    static let handle = Color(hex: 0xD1C9BB)
    static let textPrimary = Color(hex: 0x222222)
    static let textSecondary = Color(hex: 0x2B2B2B)
    static let accent = Color(hex: 0x5D86B3)
    static let accentLight = Color(hex: 0xE8F1FB)
    static let accentBg = Color(hex: 0xE7EEF8)
    static let accentBorder = Color(hex: 0xC8D7EC)
    static let amber = Color(hex: 0x8B6F2E)
    static let amberBg = Color(hex: 0xF5E6C8)
    static let successLight = Color(hex: 0xDDF0DD)
    static let successText = Color(hex: 0x3F7A4A)
    static let cardBg = Color(hex: 0xFBFAF7)

    static let backdropWarm = Color(red: 0.956, green: 0.906, blue: 0.8)
}

enum FolioRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 10
    static let lg: CGFloat = 12
    static let xl: CGFloat = 14
    static let xl2: CGFloat = 18
    static let chip: CGFloat = 20
    static let tabBar: CGFloat = 28
    static let handle: CGFloat = 2.5
}

enum FolioSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 10
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xl2: CGFloat = 18
    static let xl3: CGFloat = 20
    static let xl4: CGFloat = 24
    static let xl5: CGFloat = 28
    static let xl6: CGFloat = 32
}

enum FolioDuration {
    static let fast: Double = 0.25
    static let normal: Double = 0.3
    static let toastDismiss: UInt64 = 3_000_000_000
    static let askMockDelay: UInt64 = 1_200_000_000
}

enum FolioSize {
    static let iconSm: CGFloat = 14
    static let iconMd: CGFloat = 20
    static let iconLg: CGFloat = 22
    static let iconXl: CGFloat = 24
    static let iconXl2: CGFloat = 28
    static let iconXl3: CGFloat = 32
    static let iconXl4: CGFloat = 36

    static let buttonSm: CGFloat = 22
    static let buttonMd: CGFloat = 36
    static let tapTarget: CGFloat = 44
    static let avatarSm: CGFloat = 36
    static let avatarLg: CGFloat = 104
    static let cardImage: CGFloat = 44
    static let cardImageLg: CGFloat = 48
    static let cardIcon: CGFloat = 68

    static let fieldHeight: CGFloat = 52
    static let fieldHeightSm: CGFloat = 48
    static let fieldHeightXs: CGFloat = 46
    static let searchHeight: CGFloat = 38
    static let chipHeight: CGFloat = 40
    static let badgeHeight: CGFloat = 26
    static let skeletonBarHeight: CGFloat = 14
    static let skeletonBarSm: CGFloat = 10
    static let progressBarHeight: CGFloat = 8
    static let tabIndicatorW: CGFloat = 34
    static let tabIndicatorH: CGFloat = 3
    static let dragHandleW: CGFloat = 36
    static let dragHandleH: CGFloat = 5
}

enum FolioFontSize {
    static let caption: CGFloat = 10
    static let caption2: CGFloat = 11
    static let small: CGFloat = 12
    static let bodySmall: CGFloat = 13
    static let body: CGFloat = 14
    static let bodyLarge: CGFloat = 15
    static let subheadline: CGFloat = 16
    static let headline: CGFloat = 17
    static let title3: CGFloat = 18
    static let title2: CGFloat = 20
    static let title: CGFloat = 22
    static let heading: CGFloat = 24
    static let headingLarge: CGFloat = 28
    static let displaySmall: CGFloat = 30
    static let display: CGFloat = 32
    static let displayMedium: CGFloat = 34
    static let displayLarge: CGFloat = 40
}

struct FolioBackdrop: View {
    var body: some View {
        ZStack {
            FolioTheme.canvas

            LinearGradient(
                colors: [Color.white.opacity(0.42), Color.clear],
                startPoint: .top,
                endPoint: .center
            )

            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 320, height: 320)
                .blur(radius: 45)
                .offset(x: -140, y: -280)

            Circle()
                .fill(FolioTheme.backdropWarm.opacity(0.36))
                .frame(width: 260, height: 260)
                .blur(radius: 38)
                .offset(x: 170, y: -150)
        }
        .ignoresSafeArea()
    }
}

extension Color {
    static let folioCanvas = FolioTheme.canvas
    static let folioSurface = FolioTheme.surface
    static let folioSurfaceStrong = FolioTheme.surfaceStrong
    static let folioInk = FolioTheme.ink
    static let folioInkMuted = FolioTheme.inkMuted
    static let folioInkSoft = FolioTheme.inkSoft
    static let folioOlive = FolioTheme.olive
    static let folioOliveDark = FolioTheme.oliveDark
    static let folioLine = FolioTheme.line
    static let folioRowBorder = FolioTheme.rowBorder
    static let folioFieldBorder = FolioTheme.fieldBorder
    static let folioGold = FolioTheme.gold
    static let folioGoldSoft = FolioTheme.goldSoft
    static let folioSuccess = FolioTheme.success
    static let folioSuccessStrong = FolioTheme.successStrong
    static let folioWarning = FolioTheme.warning
    static let folioDanger = FolioTheme.danger
    static let folioBorder = FolioTheme.border
    static let folioBorderLight = FolioTheme.borderLight
    static let folioHandle = FolioTheme.handle
    static let folioTextPrimary = FolioTheme.textPrimary
    static let folioTextSecondary = FolioTheme.textSecondary
    static let folioAccent = FolioTheme.accent
    static let folioAccentLight = FolioTheme.accentLight
    static let folioAccentBg = FolioTheme.accentBg
    static let folioAccentBorder = FolioTheme.accentBorder
    static let folioAmber = FolioTheme.amber
    static let folioAmberBg = FolioTheme.amberBg
    static let folioSuccessLight = FolioTheme.successLight
    static let folioSuccessText = FolioTheme.successText
    static let folioCardBg = FolioTheme.cardBg
}
