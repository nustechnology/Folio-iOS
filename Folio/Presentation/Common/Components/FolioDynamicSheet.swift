import SwiftUI

struct FolioDynamicSheetModifier: ViewModifier {
    let minHeight: CGFloat
    let maxHeight: CGFloat

    @State private var measuredHeight: CGFloat = 0

    private var sheetHeight: CGFloat {
        min(max(measuredHeight, minHeight), maxHeight)
    }

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FolioSheetHeightKey.self,
                        value: proxy.size.height
                    )
                }
            )
            .onPreferenceChange(FolioSheetHeightKey.self) { height in
                measuredHeight = height
            }
            .presentationDetents([.height(sheetHeight)])
    }
}

private struct FolioSheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func folioDynamicSheet(minHeight: CGFloat = FolioSize.sheetDefaultMin, maxHeight: CGFloat = FolioSize.sheetDefaultMax) -> some View {
        modifier(FolioDynamicSheetModifier(minHeight: minHeight, maxHeight: maxHeight))
    }
}
