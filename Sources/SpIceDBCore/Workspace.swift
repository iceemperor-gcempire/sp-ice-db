import Foundation

public struct WorkspaceDocument: Codable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var workspace: WorkspaceInfo
    public var aiProviders: [AIProviderProfile]
    public var sourceFolders: [SourceFolder]
    public var images: [ImageEntry]
    public var generationSettings: [GenerationSettings]

    public init(
        schemaVersion: Int = WorkspaceDocument.currentSchemaVersion,
        workspace: WorkspaceInfo,
        aiProviders: [AIProviderProfile] = [],
        sourceFolders: [SourceFolder] = [],
        images: [ImageEntry] = [],
        generationSettings: [GenerationSettings] = []
    ) {
        self.schemaVersion = schemaVersion
        self.workspace = workspace
        self.aiProviders = aiProviders
        self.sourceFolders = sourceFolders
        self.images = images
        self.generationSettings = generationSettings
    }

    public static func new(name: String, now: Date = Date()) -> WorkspaceDocument {
        WorkspaceDocument(
            workspace: WorkspaceInfo(
                id: UUID(),
                name: name,
                createdAt: now,
                updatedAt: now,
                workingDirectory: nil
            )
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case workspace
        case aiProviders
        case sourceFolders
        case images
        case generationSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        workspace = try container.decode(WorkspaceInfo.self, forKey: .workspace)
        aiProviders = try container.decodeIfPresent([AIProviderProfile].self, forKey: .aiProviders) ?? []
        sourceFolders = try container.decodeIfPresent([SourceFolder].self, forKey: .sourceFolders) ?? []
        images = try container.decodeIfPresent([ImageEntry].self, forKey: .images) ?? []
        generationSettings = try container.decodeIfPresent([GenerationSettings].self, forKey: .generationSettings) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(workspace, forKey: .workspace)
        try container.encode(aiProviders, forKey: .aiProviders)
        try container.encode(sourceFolders, forKey: .sourceFolders)
        try container.encode(images, forKey: .images)
        try container.encode(generationSettings, forKey: .generationSettings)
    }
}

public struct WorkspaceInfo: Codable, Equatable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date
    public var workingDirectory: String?

    public init(id: UUID, name: String, createdAt: Date, updatedAt: Date, workingDirectory: String?) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.workingDirectory = workingDirectory
    }
}

public struct AIProviderProfile: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var baseURL: URL
    public var model: String
    public var apiKeyRef: String?
    public var supportsImageInput: Bool
    public var timeoutSeconds: TimeInterval
    public var customHeaders: [String: String]

    public init(
        id: UUID,
        name: String,
        baseURL: URL,
        model: String,
        apiKeyRef: String?,
        supportsImageInput: Bool,
        timeoutSeconds: TimeInterval,
        customHeaders: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.model = model
        self.apiKeyRef = apiKeyRef
        self.supportsImageInput = supportsImageInput
        self.timeoutSeconds = timeoutSeconds
        self.customHeaders = customHeaders
    }
}

public struct SourceFolder: Codable, Equatable, Sendable {
    public var id: UUID
    public var path: String
    public var displayName: String?
    public var recursive: Bool
    public var lastScannedAt: Date?

    public init(
        id: UUID,
        path: String,
        displayName: String?,
        recursive: Bool,
        lastScannedAt: Date? = nil
    ) {
        self.id = id
        self.path = path
        self.displayName = displayName
        self.recursive = recursive
        self.lastScannedAt = lastScannedAt
    }
}

public struct ImageEntry: Codable, Equatable, Identifiable {
    public var id: UUID
    public var sourcePath: String
    public var displayName: String?
    public var notes: String
    public var classification: Classification
    public var generatedOutputs: [GeneratedOutput]

    public init(
        id: UUID,
        sourcePath: String,
        displayName: String?,
        notes: String = "",
        classification: Classification = Classification(),
        generatedOutputs: [GeneratedOutput] = []
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.displayName = displayName
        self.notes = notes
        self.classification = classification
        self.generatedOutputs = generatedOutputs
    }
}

public struct Classification: Codable, Equatable, Sendable {
    public var user: ClassificationContent
    public var ai: AIClassificationContent?

    public init(user: ClassificationContent = ClassificationContent(), ai: AIClassificationContent? = nil) {
        self.user = user
        self.ai = ai
    }
}

public struct ClassificationContent: Codable, Equatable, Sendable {
    public var sentence: String
    public var tags: [String]

    public init(sentence: String = "", tags: [String] = []) {
        self.sentence = sentence
        self.tags = tags
    }
}

public struct AIClassificationContent: Codable, Equatable, Sendable {
    public var sentence: String
    public var tags: [String]
    public var providerId: UUID?
    public var model: String?
    public var generatedAt: Date?

    public init(
        sentence: String = "",
        tags: [String] = [],
        providerId: UUID? = nil,
        model: String? = nil,
        generatedAt: Date? = nil
    ) {
        self.sentence = sentence
        self.tags = tags
        self.providerId = providerId
        self.model = model
        self.generatedAt = generatedAt
    }
}

public struct GeneratedOutput: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Equatable, Sendable {
        case pending
        case generated
        case failed
        case removed
    }

    public var id: UUID
    public var path: String
    public var status: Status
    public var createdAt: Date
    public var settingsId: UUID?

    public init(id: UUID, path: String, status: Status, createdAt: Date, settingsId: UUID?) {
        self.id = id
        self.path = path
        self.status = status
        self.createdAt = createdAt
        self.settingsId = settingsId
    }
}

public struct GenerationSettings: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var providerId: UUID?
    public var parameters: [String: JSONValue]

    public init(id: UUID, name: String, providerId: UUID?, parameters: [String: JSONValue] = [:]) {
        self.id = id
        self.name = name
        self.providerId = providerId
        self.parameters = parameters
    }
}

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public enum TagList {
    public static func parse(_ input: String) -> [String] {
        var seen = Set<String>()

        return input
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { tag in
                let normalized = tag.lowercased()
                guard !seen.contains(normalized) else { return false }
                seen.insert(normalized)
                return true
            }
    }
}

public enum WorkspaceJSONCodec {
    public static func encode(_ document: WorkspaceDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    public static func decode(_ data: Data) throws -> WorkspaceDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WorkspaceDocument.self, from: data)
    }
}
