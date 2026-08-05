import Foundation

extension Date {
    var workspaceRelativeLabel: String {
        let minutes = max(0, Int(Date().timeIntervalSince(self) / 60))
        if minutes < 1 { return String(localized: "Updated just now") }
        if minutes < 60 {
            return minutes == 1
                ? String(localized: "Updated 1 min ago")
                : String(localized: "Updated \(minutes) mins ago")
        }
        let hours = minutes / 60
        if hours < 24 {
            return hours == 1
                ? String(localized: "Updated 1 hour ago")
                : String(localized: "Updated \(hours) hours ago")
        }
        if hours < 48 { return String(localized: "Updated Yesterday") }
        if hours < 24 * 7 { return String(localized: "Updated \(DateFormatter.workspaceWeekday.string(from: self))") }
        return String(localized: "Updated \(DateFormatter.workspaceDate.string(from: self))")
    }
}

private extension DateFormatter {
    static let workspaceWeekday: DateFormatter = { let formatter = DateFormatter(); formatter.dateFormat = "EEEE"; return formatter }()
    static let workspaceDate: DateFormatter = { let formatter = DateFormatter(); formatter.dateFormat = "MMM dd, yyyy"; return formatter }()
}
