import CoreGraphics

enum SheetHeightMeasurement {
    private static let tolerance: CGFloat = 0.5

    static func needsUpdate(current: CGFloat, measured: CGFloat) -> Bool {
        abs(current - measured) > tolerance
    }
}
