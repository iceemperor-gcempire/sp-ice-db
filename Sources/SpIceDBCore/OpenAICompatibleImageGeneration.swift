import Foundation

public enum OpenAICompatibleImageGenerationError: Error, Equatable {
    case emptyPrompt
    case missingImageData
    case invalidImageData
}

public enum OpenAICompatibleImageGenerationClientError: Error, Equatable {
    case apiKeyNotFound(String)
    case httpFailure(statusCode: Int)
}

public struct OpenAIImageGenerationRequestBody: Codable, Equatable {
    public var model: String
    public var prompt: String
    public var n: Int
    public var size: String?
    public var quality: String?
    public var background: String?
    public var outputFormat: String?

    private enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case n
        case size
        case quality
        case background
        case outputFormat = "output_format"
    }

    public init(
        model: String,
        prompt: String,
        n: Int = 1,
        size: String? = nil,
        quality: String? = nil,
        background: String? = nil,
        outputFormat: String? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.n = n
        self.size = size
        self.quality = quality
        self.background = background
        self.outputFormat = outputFormat
    }
}

public struct OpenAICompatibleImageGenerationClient {
    private let apiKeyResolver: APIKeyResolving
    private let transport: HTTPTransport
    private let encoder: JSONEncoder

    public init(
        apiKeyResolver: APIKeyResolving,
        transport: HTTPTransport = URLSessionHTTPTransport(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.apiKeyResolver = apiKeyResolver
        self.transport = transport
        self.encoder = encoder
    }

    public func generateImage(
        request generationRequest: ImageGenerationRequest,
        provider: AIProviderProfile
    ) async throws -> GeneratedImageAsset {
        let body = try requestBody(for: generationRequest, provider: provider)
        let request = HTTPRequest(
            url: imageGenerationsURL(for: provider.baseURL),
            method: "POST",
            headers: try resolvedHeaders(for: provider),
            timeoutSeconds: provider.timeoutSeconds,
            body: try encoder.encode(body)
        )
        let response = try await transport.send(request)

        guard (200..<300).contains(response.statusCode) else {
            throw OpenAICompatibleImageGenerationClientError.httpFailure(statusCode: response.statusCode)
        }

        let parsed = try parseResponse(response.body)
        return GeneratedImageAsset(
            data: parsed.data,
            suggestedFilename: suggestedFilename(
                sourcePath: generationRequest.sourcePath,
                outputFormat: parsed.outputFormat
            )
        )
    }

    private func requestBody(
        for request: ImageGenerationRequest,
        provider: AIProviderProfile
    ) throws -> OpenAIImageGenerationRequestBody {
        let prompt = try prompt(for: request)

        return OpenAIImageGenerationRequestBody(
            model: provider.model,
            prompt: prompt,
            n: integerParameter("n", from: request.settings?.parameters) ?? 1,
            size: stringParameter("size", from: request.settings?.parameters),
            quality: stringParameter("quality", from: request.settings?.parameters),
            background: stringParameter("background", from: request.settings?.parameters),
            outputFormat: stringParameter("output_format", from: request.settings?.parameters)
        )
    }

    private func prompt(for request: ImageGenerationRequest) throws -> String {
        if let prompt = stringParameter("prompt", from: request.settings?.parameters) {
            return prompt
        }

        var parts = ["Generate a high-quality image for generative AI image training."]
        let sentence = request.classification.user.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sentence.isEmpty {
            parts.append("Description: \(sentence)")
        }
        if !request.classification.user.tags.isEmpty {
            parts.append("Tags: \(request.classification.user.tags.joined(separator: ", "))")
        }
        let notes = request.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            parts.append("Notes: \(notes)")
        }
        if sentence.isEmpty, request.classification.user.tags.isEmpty, notes.isEmpty {
            let name = request.displayName ?? URL(fileURLWithPath: request.sourcePath).lastPathComponent
            parts.append("Reference entry: \(name)")
        }

        let prompt = parts.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw OpenAICompatibleImageGenerationError.emptyPrompt
        }
        return prompt
    }

    private func parseResponse(_ data: Data) throws -> ParsedImageGenerationResponse {
        guard let response = try? JSONDecoder().decode(ImageGenerationResponse.self, from: data),
              let image = response.data.first,
              let imageBase64 = image.b64JSON?.trimmingCharacters(in: .whitespacesAndNewlines),
              !imageBase64.isEmpty else {
            throw OpenAICompatibleImageGenerationError.missingImageData
        }

        guard let imageData = Data(base64Encoded: imageBase64), !imageData.isEmpty else {
            throw OpenAICompatibleImageGenerationError.invalidImageData
        }

        return ParsedImageGenerationResponse(
            data: imageData,
            outputFormat: response.outputFormat
        )
    }

    private func resolvedHeaders(for provider: AIProviderProfile) throws -> [String: String] {
        var headers = provider.customHeaders
        headers["Content-Type"] = "application/json"

        guard let apiKeyRef = provider.apiKeyRef else {
            return headers
        }

        guard let apiKey = try apiKeyResolver.apiKey(for: apiKeyRef),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAICompatibleImageGenerationClientError.apiKeyNotFound(apiKeyRef)
        }

        headers["Authorization"] = "Bearer \(apiKey)"
        return headers
    }

    private func imageGenerationsURL(for baseURL: URL) -> URL {
        baseURL
            .appendingPathComponent("images")
            .appendingPathComponent("generations")
    }

    private func suggestedFilename(sourcePath: String, outputFormat: String?) -> String {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = normalizedOutputFormat(outputFormat)
        return "\(baseName)_generated.\(fileExtension)"
    }

    private func normalizedOutputFormat(_ outputFormat: String?) -> String {
        let value = outputFormat?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        switch value {
        case "jpeg", "jpg":
            return "jpg"
        case "webp":
            return "webp"
        default:
            return "png"
        }
    }

    private func stringParameter(_ key: String, from parameters: [String: JSONValue]?) -> String? {
        guard case .string(let value)? = parameters?[key] else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func integerParameter(_ key: String, from parameters: [String: JSONValue]?) -> Int? {
        switch parameters?[key] {
        case .number(let value):
            return Int(value)
        case .string(let value):
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }
}

public struct OpenAICompatibleImageGenerationProvider: ImageGenerationProviding, @unchecked Sendable {
    private let provider: AIProviderProfile
    private let client: OpenAICompatibleImageGenerationClient

    public init(
        provider: AIProviderProfile,
        client: OpenAICompatibleImageGenerationClient
    ) {
        self.provider = provider
        self.client = client
    }

    public func generateImage(request: ImageGenerationRequest) async throws -> GeneratedImageAsset {
        try await client.generateImage(request: request, provider: provider)
    }
}

private struct ImageGenerationResponse: Decodable {
    struct Image: Decodable {
        var b64JSON: String?

        private enum CodingKeys: String, CodingKey {
            case b64JSON = "b64_json"
        }
    }

    var data: [Image]
    var outputFormat: String?

    private enum CodingKeys: String, CodingKey {
        case data
        case outputFormat = "output_format"
    }
}

private struct ParsedImageGenerationResponse {
    var data: Data
    var outputFormat: String?
}
