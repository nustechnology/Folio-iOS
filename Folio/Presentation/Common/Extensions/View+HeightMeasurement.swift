import SwiftUI

private struct HeightMeasurementModifier: ViewModifier {
    @Binding var height: CGFloat

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.height, initial: true) { _, newHeight in
                        guard SheetHeightMeasurement.needsUpdate(
                            current: height,
                            measured: newHeight
                        ) else {
                            return
                        }

                        height = newHeight
                    }
            }
        }
    }
}

extension View {
    func measureHeight(_ height: Binding<CGFloat>) -> some View {
        modifier(HeightMeasurementModifier(height: height))
    }
}
