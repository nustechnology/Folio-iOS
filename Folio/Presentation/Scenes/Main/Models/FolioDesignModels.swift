import Foundation

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
    case papers
    case books
    case web

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .papers: return "Papers"
        case .books: return "Books"
        case .web: return "Web"
        }
    }

    var count: Int {
        switch self {
        case .all: return 128
        case .papers: return 86
        case .books: return 24
        case .web: return 18
        }
    }
}

enum FolioSourceKind: String, Equatable {
    case paper
    case book
    case web

    var badge: String {
        switch self {
        case .paper: return "PDF"
        case .book: return "BOOK"
        case .web: return "WEB"
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

struct FolioSpace: Identifiable, Equatable {
    let id: String
    let title: String
    let sourceCount: Int
    let noteCount: Int
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
}

enum FolioDesignFixtures {
    static let spaces: [FolioSpace] = [
        .init(id: "dissertation-research", title: "Dissertation Research", sourceCount: 128, noteCount: 32),
        .init(id: "public-policy-insights", title: "Public Policy Insights", sourceCount: 64, noteCount: 18),
        .init(id: "history-of-science", title: "History of Science", sourceCount: 42, noteCount: 12),
        .init(id: "teaching-prep", title: "Teaching Prep", sourceCount: 27, noteCount: 8)
    ]

    static let filters: [FolioSourceFilter] = [.all, .papers, .books, .web]

    static let sources: [FolioSource] = [
        .init(
            id: "alan-turing",
            workspaceID: "dissertation-research",
            kind: .paper,
            title: "Alan Turing: Computing Machinery",
            subtitle: "The Origins of Computation",
            addedText: "Added 2d ago",
            status: .ready,
            chapterTitle: "5. The Imitation Game",
            chapterText: "The original question, \"Can machines think?\" I believe to be too meaningless to deserve discussion.",
            calloutText: "I propose the question, \"Can machines do what we as thinking entities can do?\"",
            citationTitle: "Citation 1",
            citationDetail: "Alan Turing · p.28",
            citationText: "Can machines do what we can do?",
            pageLabel: "28 of 52"
        ),
        .init(
            id: "totalitarianism",
            workspaceID: "dissertation-research",
            kind: .paper,
            title: "The Origins of Totalitarianism",
            subtitle: "Political systems and control",
            addedText: "Added 2d ago",
            status: .ready,
            chapterTitle: "8. Social Atomization",
            chapterText: "A population can be controlled when its members are isolated from each other and from public life.",
            calloutText: "Isolation is the common condition that makes propaganda effective.",
            citationTitle: "Citation 2",
            citationDetail: "Hannah Arendt · p.115",
            citationText: "Isolation precedes domination.",
            pageLabel: "115 of 289"
        ),
        .init(
            id: "weapons-of-math-destruction",
            workspaceID: "public-policy-insights",
            kind: .book,
            title: "Weapons of Math Destruction",
            subtitle: "How algorithms shape society",
            addedText: "Added 2d ago",
            status: .processing,
            chapterTitle: "3. The Problem with Prediction",
            chapterText: "When a model is optimized for the wrong goal, it can amplify the very harm it was supposed to reduce.",
            calloutText: "Prediction systems often inherit the bias of the institutions that train them.",
            citationTitle: "Citation 3",
            citationDetail: "Cathy O'Neil · p.71",
            citationText: "Models are opinions embedded in math.",
            pageLabel: "71 of 317"
        ),
        .init(
            id: "surveillance-capitalism",
            workspaceID: "history-of-science",
            kind: .paper,
            title: "The Age of Surveillance Capitalism",
            subtitle: "Data extraction and behavior",
            addedText: "Added 2d ago",
            status: .failed,
            chapterTitle: "9. Instrumentarian Power",
            chapterText: "Behavioral prediction becomes a market once attention is treated as a resource to be purchased.",
            calloutText: "Extraction scales when friction is removed from every interaction.",
            citationTitle: "Citation 4",
            citationDetail: "Shoshana Zuboff · p.203",
            citationText: "The future is privatized before it is public.",
            pageLabel: "203 of 704"
        ),
        .init(
            id: "attention-is-all-you-need",
            workspaceID: "teaching-prep",
            kind: .web,
            title: "Attention Is All You Need",
            subtitle: "Transformer architectures",
            addedText: "Added 2d ago",
            status: .ready,
            chapterTitle: "7. Sequence Modeling",
            chapterText: "Attention allows a model to weigh the importance of each token against the rest of the sequence.",
            calloutText: "This architecture made long-range dependencies practical at scale.",
            citationTitle: "Citation 5",
            citationDetail: "Vaswani et al. · p.3",
            citationText: "Attention replaced recurrence as the core primitive.",
            pageLabel: "3 of 15"
        )
    ]
}
