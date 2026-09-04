import Foundation
import SwiftUI

enum FolioTab: String, CaseIterable, Identifiable, Equatable {
    case sources
    case ask
    case notes
    case notebook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sources: return String(localized: "Sources")
        case .ask: return String(localized: "Ask")
        case .notes: return String(localized: "Notes")
        case .notebook: return String(localized: "Notebook")
        }
    }

    var iconName: String {
        switch self {
        case .sources: return "doc.text"
        case .ask: return "sparkle"
        case .notes: return "note.text"
        case .notebook: return "book"
        }
    }
}

enum FolioSourcesMode: String, Equatable {
    case spaces
    case library
}

enum FolioSourceFilter: String, CaseIterable, Identifiable, Equatable {
    case all
    case files
    case web
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return String(localized: "All")
        case .files: return String(localized: "Files")
        case .web: return String(localized: "Web")
        case .text: return String(localized: "Text")
        }
    }

    var apiValue: String? {
        switch self {
        case .all: return nil
        case .files: return "File"
        case .web: return "Web"
        case .text: return "Manual"
        }
    }
}

enum FolioSourceKind: String, Equatable {
    case file
    case web
    case text

    var badge: String {
        switch self {
        case .file: return "FILE"
        case .web: return "WEB"
        case .text: return "TEXT"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .file: return .folioHomeTypeFileBackground
        case .web: return .folioHomeTypeWebBackground
        case .text: return .folioHomeTypeTextBackground
        }
    }

    var textColor: Color {
        switch self {
        case .file: return .folioHomeTypeFileText
        case .web: return .folioHomeTypeWebText
        case .text: return .folioHomeTypeTextText
        }
    }
}

enum FolioSourceStatus: String, Equatable {
    case ready
    case processing
    case failed

    var title: String {
        switch self {
        case .ready: return "Ready"
        case .processing: return "Processing"
        case .failed: return "Failed"
        }
    }
}

struct FolioCredential {
    let email: String
    let password: String
}

struct AuthSession: Codable, Equatable {
    let token: String
    let expiresAt: Date

    var isValid: Bool { expiresAt > Date() }
}

struct FolioSource: Identifiable, Equatable {
    let id: String
    let workspaceID: String?
    let kind: FolioSourceKind
    let title: String
    let subtitle: String
    let addedText: String
    let status: FolioSourceStatus
    let chapterTitle: String
    let chapterText: String
    let calloutText: String
    let citationTitle: String
    let citationDetail: String
    let citationText: String
    let pageLabel: String

    init(
        id: String, workspaceID: String?, kind: FolioSourceKind, title: String,
        subtitle: String, addedText: String, status: FolioSourceStatus,
        chapterTitle: String, chapterText: String, calloutText: String,
        citationTitle: String, citationDetail: String, citationText: String, pageLabel: String
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.addedText = addedText
        self.status = status
        self.chapterTitle = chapterTitle
        self.chapterText = chapterText
        self.calloutText = calloutText
        self.citationTitle = citationTitle
        self.citationDetail = citationDetail
        self.citationText = citationText
        self.pageLabel = pageLabel
    }
}

extension FolioSource {
    init(from source: Source, workspaceID: String?) {
        self.id = source.id
        self.workspaceID = workspaceID
        self.kind = {
            switch source.sourceType {
            case .file: return .file
            case .web: return .web
            case .manual: return .text
            }
        }()
        self.title = source.title
        self.subtitle = source.author
        self.addedText = source.createdAt.addedRelativeLabel
        self.status = {
            switch source.processingState {
            case .ready: return .ready
            case .failed: return .failed
            default: return .processing
            }
        }()
        self.chapterTitle = ""
        self.chapterText = source.content
        self.calloutText = ""
        self.citationTitle = ""
        self.citationDetail = ""
        self.citationText = ""
        self.pageLabel = "1 of 1"
    }

    var badgeText: String {
        switch kind {
        case .file: return "FILE"
        case .web: return "WEB"
        case .text: return "TEXT"
        }
    }
}

enum FolioDesignFixtures {
    static let filters: [FolioSourceFilter] = [.all, .files, .web, .text]

    static let sources: [FolioSource] = [
        .init(
            id: "alan-turing",
            workspaceID: "dissertation-research",
            kind: .file,
            title: "Alan Turing: Computing Machinery",
            subtitle: "The Origins of Computation",
            addedText: "Added 2d ago",
            status: .ready,
            chapterTitle: "",
            chapterText: "",
            calloutText: "",
            citationTitle: "",
            citationDetail: "",
            citationText: "",
            pageLabel: "1 of 1"
        ),
        .init(
            id: "totalitarianism",
            workspaceID: "dissertation-research",
            kind: .file,
            title: "The Origins of Totalitarianism",
            subtitle: "Political systems and control",
            addedText: "Added 2d ago",
            status: .ready,
            chapterTitle: "",
            chapterText: "",
            calloutText: "",
            citationTitle: "",
            citationDetail: "",
            citationText: "",
            pageLabel: "1 of 1"
        ),
        .init(
            id: "weapons-of-math-destruction",
            workspaceID: "public-policy-insights",
            kind: .file,
            title: "Weapons of Math Destruction",
            subtitle: "How algorithms shape society",
            addedText: "Added 2d ago",
            status: .processing,
            chapterTitle: "",
            chapterText: "",
            calloutText: "",
            citationTitle: "",
            citationDetail: "",
            citationText: "",
            pageLabel: "1 of 1"
        ),
        .init(
            id: "surveillance-capitalism",
            workspaceID: "history-of-science",
            kind: .web,
            title: "The Age of Surveillance Capitalism",
            subtitle: "Data extraction and behavior",
            addedText: "Added 2d ago",
            status: .failed,
            chapterTitle: "",
            chapterText: "",
            calloutText: "",
            citationTitle: "",
            citationDetail: "",
            citationText: "",
            pageLabel: "1 of 1"
        ),
        .init(
            id: "attention-is-all-you-need",
            workspaceID: "teaching-prep",
            kind: .text,
            title: "Attention Is All You Need",
            subtitle: "Transformer architectures",
            addedText: "Added 2d ago",
            status: .ready,
            chapterTitle: "",
            chapterText: "",
            calloutText: "",
            citationTitle: "",
            citationDetail: "",
            citationText: "",
            pageLabel: "1 of 1"
        )
    ]
}
