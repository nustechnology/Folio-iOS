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
                .fill(Color(red: 0.956, green: 0.906, blue: 0.8).opacity(0.36))
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
}
