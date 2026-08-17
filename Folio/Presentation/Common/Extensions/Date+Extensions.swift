import Foundation

extension Date {
    var noteListDisplayLabel: String {
        let calendar = Calendar.current
        let format = calendar.component(.year, from: self) == calendar.component(.year, from: Date())
            ? "MMM dd, HH:mm"
            : "MMM dd, yyyy"

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = calendar
        formatter.dateFormat = format
        return formatter.string(from: self)
    }

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

    var miniRelativeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension Int {
    var noteCitationDisplayLabel: String {
        switch self {
        case 0:
            String(localized: "None")
        case 1:
            String(localized: "1 Citation")
        default:
            String.localizedStringWithFormat(String(localized: "%lld Citations"), Int64(self))
        }
    }
}

private extension DateFormatter {
    static let workspaceWeekday: DateFormatter = { let formatter = DateFormatter(); formatter.dateFormat = "EEEE"; return formatter }()
    static let workspaceDate: DateFormatter = { let formatter = DateFormatter(); formatter.dateFormat = "MMM dd, yyyy"; return formatter }()
}
