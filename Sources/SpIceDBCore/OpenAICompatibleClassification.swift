import Foundation

public enum OpenAICompatibleClassificationError: Error, Equatable {
    case providerDoesNotSupportImageInput
    case emptyImageData
    case invalidMimeType
    case missingContent
    case invalidJSONContent
    case emptySentence
    case emptyTags
}

public struct OpenAICompatibleClassificationRequest: Equatable {
    public var url: URL
    public var headers: [String: String]
    public var timeoutSeconds: TimeInterval
    public var body: OpenAIChatCompletionRequest

    public init(
        url: URL,
        headers: [String: String],
        timeoutSeconds: TimeInterval,
        body: OpenAIChatCompletionRequest
    ) {
        self.url = url
        self.headers = headers
        self.timeoutSeconds = timeoutSeconds
        self.body = body
    }
}

public struct OpenAIChatCompletionRequest: Codable, Equatable {
    public struct Message: Codable, Equatable {
        public var role: String
        public var content: [ContentPart]

        public init(role: String, content: [ContentPart]) {
            self.role = role
            self.content = content
        }
    }

    public enum ContentPart: Codable, Equatable {
        case text(String)
        case imageURL(ImageURL)

        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }

        private enum PartType: String, Codable {
            case text
            case imageURL = "image_url"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(PartType.self, forKey: .type)

            switch type {
            case .text:
                self = .text(try container.decode(String.self, forKey: .text))
            case .imageURL:
                self = .imageURL(try container.decode(ImageURL.self, forKey: .imageURL))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .text(let text):
                try container.encode(PartType.text, forKey: .type)
                try container.encode(text, forKey: .text)
            case .imageURL(let imageURL):
                try container.encode(PartType.imageURL, forKey: .type)
                try container.encode(imageURL, forKey: .imageURL)
            }
        }
    }

    public struct ImageURL: Codable, Equatable {
        public var url: String

        public init(url: String) {
            self.url = url
        }
    }

    public struct ResponseFormat: Codable, Equatable {
        public var type: String

        public init(type: String) {
            self.type = type
        }
    }

    public var model: String
    public var messages: [Message]
    public var temperature: Double
    public var responseFormat: ResponseFormat

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }

    public init(
        model: String,
        messages: [Message],
        temperature: Double = 0.2,
        responseFormat: ResponseFormat = ResponseFormat(type: "json_object")
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.responseFormat = responseFormat
    }
}

public struct OpenAICompatibleClassificationService {
    public static let systemPrompt = """
    Classify the provided image for generative AI image training metadata. Return only a JSON object with keys "sentence" and "tags". The sentence must be a concise natural-language caption. Tags must be a short array of concrete visual tags suitable for SDXL-style datasets.
    """

    public init() {}

    public func makeRequest(
        provider: AIProviderProfile,
        imageBase64: String,
        mimeType: String
    ) throws -> OpenAICompatibleClassificationRequest {
        guard provider.supportsImageInput else {
            throw OpenAICompatibleClassificationError.providerDoesNotSupportImageInput
        }

        let trimmedImageBase64 = imageBase64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedImageBase64.isEmpty else {
            throw OpenAICompatibleClassificationError.emptyImageData
        }

        let trimmedMimeType = mimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmedMimeType.hasPrefix("image/") else {
            throw OpenAICompatibleClassificationError.invalidMimeType
        }

        var headers = provider.customHeaders
        headers["Content-Type"] = "application/json"
        if let apiKeyRef = provider.apiKeyRef {
            headers["Authorization"] = "Bearer ${\(apiKeyRef)}"
        }

        return OpenAICompatibleClassificationRequest(
            url: chatCompletionsURL(for: provider.baseURL),
            headers: headers,
            timeoutSeconds: provider.timeoutSeconds,
            body: OpenAIChatCompletionRequest(
                model: provider.model,
                messages: [
                    OpenAIChatCompletionRequest.Message(
                        role: "system",
                        content: [.text(Self.systemPrompt)]
                    ),
                    OpenAIChatCompletionRequest.Message(
                        role: "user",
                        content: [
                            .text("Classify this image and return JSON only."),
                            .imageURL(
                                OpenAIChatCompletionRequest.ImageURL(
                                    url: "data:\(trimmedMimeType);base64,\(trimmedImageBase64)"
                                )
                            )
                        ]
                    )
                ]
            )
        )
    }

    public func parseResponse(
        _ data: Data,
        provider: AIProviderProfile,
        generatedAt: Date?
    ) throws -> AIClassificationContent {
        guard let response = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data) else {
            throw OpenAICompatibleClassificationError.missingContent
        }
        guard let content = response.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAICompatibleClassificationError.missingContent
        }

        let payload = stripMarkdownJSONFence(from: content)
        guard let payloadData = payload.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ClassificationPayload.self, from: payloadData) else {
            throw OpenAICompatibleClassificationError.invalidJSONContent
        }

        let sentence = parsed.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sentence.isEmpty else {
            throw OpenAICompatibleClassificationError.emptySentence
        }

        let tags = normalizeTags(parsed.tags)
        guard !tags.isEmpty else {
            throw OpenAICompatibleClassificationError.emptyTags
        }

        return AIClassificationContent(
            sentence: sentence,
            tags: tags,
            providerId: provider.id,
            model: provider.model,
            generatedAt: generatedAt
        )
    }

    private func chatCompletionsURL(for baseURL: URL) -> URL {
        baseURL
            .appendingPathComponent("chat")
            .appendingPathComponent("completions")
    }

    private func stripMarkdownJSONFence(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else {
            return trimmed
        }

        var lines = trimmed.components(separatedBy: .newlines)
        if !lines.isEmpty {
            lines.removeFirst()
        }
        if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
            lines.removeLast()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()

        return tags
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

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            var content: String?
        }

        var message: Message
    }

    var choices: [Choice]
}

private struct ClassificationPayload: Decodable {
    var sentence: String
    var tags: [String]
}
