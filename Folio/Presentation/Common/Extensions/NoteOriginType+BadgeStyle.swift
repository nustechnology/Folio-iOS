import SwiftUI

extension NoteOriginType {
    var badgeBackgroundColor: Color {
        switch self {
        case .userCreated:
            .folioHomeTypeFileBackground
        case .savedAssistantAnswer:
            .folioHomeTypeWebBackground
        }
    }

    var badgeTextColor: Color {
        switch self {
        case .userCreated:
            .folioHomeTypeFileText
        case .savedAssistantAnswer:
            .folioHomeTypeWebText
        }
    }
}
