import Foundation

public enum OpenAICompatibleClassificationClientError: Error, Equatable {
    case apiKeyNotFound(String)
    case httpFailure(statusCode: Int)
}

public struct HTTPRequest: Equatable {
    public var url: URL
    public var method: String
    public var headers: [String: String]
    public var timeoutSeconds: TimeInterval
    public var body: Data

    public init(
        url: URL,
        method: String,
        headers: [String: String],
        timeoutSeconds: TimeInterval,
        body: Data
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.timeoutSeconds = timeoutSeconds
        self.body = body
    }
}

public struct HTTPResponse: Equatable {
    public var statusCode: Int
    public var body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

public protocol HTTPTransport {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public protocol APIKeyResolving {
    func apiKey(for reference: String) throws -> String?
}

public struct DictionaryAPIKeyResolver: APIKeyResolving {
    private let keys: [String: String]

    public init(keys: [String: String]) {
        self.keys = keys
    }

    public func apiKey(for reference: String) throws -> String? {
        keys[reference]
    }
}

public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url, timeoutInterval: request.timeoutSeconds)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let (data, response) = try await session.data(for: urlRequest)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return HTTPResponse(statusCode: statusCode, body: data)
    }
}

public struct OpenAICompatibleClassificationClient {
    private let apiKeyResolver: APIKeyResolving
    private let transport: HTTPTransport
    private let service: OpenAICompatibleClassificationService
    private let encoder: JSONEncoder

    public init(
        apiKeyResolver: APIKeyResolving,
        transport: HTTPTransport = URLSessionHTTPTransport(),
        service: OpenAICompatibleClassificationService = OpenAICompatibleClassificationService(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.apiKeyResolver = apiKeyResolver
        self.transport = transport
        self.service = service
        self.encoder = encoder
    }

    public func classify(
        payload: ImagePayload,
        provider: AIProviderProfile,
        generatedAt: Date?
    ) async throws -> AIClassificationContent {
        let classificationRequest = try service.makeRequest(
            provider: provider,
            imageBase64: payload.base64,
            mimeType: payload.mimeType
        )
        let headers = try resolvedHeaders(for: classificationRequest.headers, provider: provider)
        let request = HTTPRequest(
            url: classificationRequest.url,
            method: "POST",
            headers: headers,
            timeoutSeconds: classificationRequest.timeoutSeconds,
            body: try encoder.encode(classificationRequest.body)
        )
        let response = try await transport.send(request)

        guard (200..<300).contains(response.statusCode) else {
            throw OpenAICompatibleClassificationClientError.httpFailure(statusCode: response.statusCode)
        }

        return try service.parseResponse(
            response.body,
            provider: provider,
            generatedAt: generatedAt
        )
    }

    private func resolvedHeaders(
        for headers: [String: String],
        provider: AIProviderProfile
    ) throws -> [String: String] {
        guard let apiKeyRef = provider.apiKeyRef else {
            var headers = headers
            headers.removeValue(forKey: "Authorization")
            return headers
        }

        guard let apiKey = try apiKeyResolver.apiKey(for: apiKeyRef),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAICompatibleClassificationClientError.apiKeyNotFound(apiKeyRef)
        }

        var headers = headers
        headers["Authorization"] = "Bearer \(apiKey)"
        return headers
    }
}
