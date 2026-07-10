import Foundation

struct MurmurState: Codable {
    var widget: WidgetState
    var content: ContentState
    var cover: CoverState
    var pet: PetState

    static let defaultValue = MurmurState(
        widget: WidgetState(
            frame: StoredFrame(x: 160, y: 420, width: 360, height: 300),
            isBlurred: true,
            theme: ThemeState(transparency: 0.72, blurStrength: 0.82, cornerRadius: 26)
        ),
        content: ContentState(
            mainPhrase: "Make room for the day.",
            privateNote: "A softer place for the things I want to remember.",
            tasks: [
                TaskItem(text: "Write one honest note"),
                TaskItem(text: "Finish the tiny brave thing"),
                TaskItem(text: "Drink water", completed: true)
            ]
        ),
        cover: CoverState(mode: .text, text: "soft focus", imagePath: nil),
        pet: PetState(kind: .builtIn, imagePath: nil, edge: .topRight, pose: .catDefault)
    )
}

struct WidgetState: Codable {
    var frame: StoredFrame
    var isBlurred: Bool
    var isExpanded: Bool
    var theme: ThemeState

    init(frame: StoredFrame, isBlurred: Bool, isExpanded: Bool = false, theme: ThemeState) {
        self.frame = frame
        self.isBlurred = isBlurred
        self.isExpanded = isExpanded
        self.theme = theme
    }

    private enum CodingKeys: String, CodingKey {
        case frame
        case isBlurred
        case isExpanded
        case theme
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frame = try container.decode(StoredFrame.self, forKey: .frame)
        isBlurred = try container.decode(Bool.self, forKey: .isBlurred)
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? false
        theme = try container.decode(ThemeState.self, forKey: .theme)
    }
}

struct StoredFrame: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct ThemeState: Codable {
    var transparency: Double
    var blurStrength: Double
    var cornerRadius: Double
}

struct ContentState: Codable {
    var mainPhrase: String
    var privateNote: String
    var showMainPhrase: Bool
    var showPrivateNote: Bool
    var showTasks: Bool
    var tasks: [TaskItem]

    init(mainPhrase: String, privateNote: String, showMainPhrase: Bool = true, showPrivateNote: Bool = true, showTasks: Bool = true, tasks: [TaskItem]) {
        self.mainPhrase = mainPhrase
        self.privateNote = privateNote
        self.showMainPhrase = showMainPhrase
        self.showPrivateNote = showPrivateNote
        self.showTasks = showTasks
        self.tasks = tasks
    }

    private enum CodingKeys: String, CodingKey {
        case mainPhrase
        case privateNote
        case showMainPhrase
        case showPrivateNote
        case showTasks
        case tasks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mainPhrase = try container.decode(String.self, forKey: .mainPhrase)
        privateNote = try container.decode(String.self, forKey: .privateNote)
        showMainPhrase = try container.decodeIfPresent(Bool.self, forKey: .showMainPhrase) ?? true
        showPrivateNote = try container.decodeIfPresent(Bool.self, forKey: .showPrivateNote) ?? true
        showTasks = try container.decodeIfPresent(Bool.self, forKey: .showTasks) ?? true
        tasks = try container.decode([TaskItem].self, forKey: .tasks)
    }
}

struct TaskItem: Codable, Identifiable {
    var id: UUID
    var text: String
    var completed: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), text: String, completed: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.completed = completed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct CoverState: Codable {
    var mode: CoverMode
    var text: String
    var imagePath: String?
}

enum CoverMode: String, Codable, CaseIterable {
    case text
    case image
}

struct PetState: Codable {
    var kind: PetKind
    var imagePath: String?
    var edge: PetEdge
    var pose: PetPose

    init(kind: PetKind, imagePath: String?, edge: PetEdge, pose: PetPose = .catDefault) {
        self.kind = kind
        self.imagePath = imagePath
        self.edge = edge
        self.pose = pose
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case imagePath
        case edge
        case pose
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(PetKind.self, forKey: .kind)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        edge = try container.decode(PetEdge.self, forKey: .edge)
        pose = try container.decodeIfPresent(PetPose.self, forKey: .pose) ?? .catDefault
    }
}

enum PetKind: String, Codable, CaseIterable {
    case builtIn
    case customImage
}

enum PetPose: String, Codable, CaseIterable {
    case catDefault
    case catSit
    case catSleep
    case catYarn
    case catBox
    case catAngry

    var resourceName: String {
        switch self {
        case .catDefault:
            return "cat_default"
        case .catSit:
            return "cat_sit"
        case .catSleep:
            return "cat_sleep"
        case .catYarn:
            return "cat_yarn"
        case .catBox:
            return "cat_box"
        case .catAngry:
            return "cat_angry"
        }
    }
}

enum PetEdge: String, Codable, CaseIterable {
    case topRight
    case topLeft
    case bottomRight
}
