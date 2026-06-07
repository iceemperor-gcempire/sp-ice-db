import XCTest
@testable import SpIceDBCore

final class OpenAICompatibleClassificationClientTests: XCTestCase {
    func testSendsClassificationRequestWithResolvedAPIKeyAndParsesResponse() async throws {
        let providerID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let generatedAt = Date(timeIntervalSince1970: 1_800_000_500)
        let transport = StubHTTPTransport(
            response: """
            {"choices":[{"message":{"content":"{\\"sentence\\":\\"A studio portrait.\\",\\"tags\\":[\\"portrait\\",\\"studio\\"]}"}}]}
            """.data(using: .utf8)!
        )
        let client = OpenAICompatibleClassificationClient(
            apiKeyResolver: DictionaryAPIKeyResolver(keys: [
                "keychain:provider": "secret-token"
            ]),
            transport: transport
        )

        let classification = try await client.classify(
            payload: ImagePayload(
                sourcePath: "/tmp/source.png",
                mimeType: "image/png",
                base64: "aW1hZ2U="
            ),
            provider: providerProfile(id: providerID, apiKeyRef: "keychain:provider"),
            generatedAt: generatedAt
        )

        XCTAssertEqual(
            classification,
            AIClassificationContent(
                sentence: "A studio portrait.",
                tags: ["portrait", "studio"],
                providerId: providerID,
                model: "vision-model",
                generatedAt: generatedAt
            )
        )
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests[0].url, URL(string: "https://api.example.com/v1/chat/completions")!)
        XCTAssertEqual(transport.requests[0].method, "POST")
        XCTAssertEqual(transport.requests[0].headers["Authorization"], "Bearer secret-token")
        XCTAssertEqual(transport.requests[0].headers["Content-Type"], "application/json")

        let decodedBody = try JSONDecoder().decode(OpenAIChatCompletionRequest.self, from: transport.requests[0].body)
        XCTAssertEqual(decodedBody.model, "vision-model")
        XCTAssertEqual(decodedBody.messages.count, 2)
    }

    func testSendsClassificationRequestWithoutAuthorizationWhenProviderHasNoKeyReference() async throws {
        let transport = StubHTTPTransport(
            response: """
            {"choices":[{"message":{"content":"{\\"sentence\\":\\"Caption.\\",\\"tags\\":[\\"tag\\"]}"}}]}
            """.data(using: .utf8)!
        )
        let client = OpenAICompatibleClassificationClient(
            apiKeyResolver: DictionaryAPIKeyResolver(keys: [:]),
            transport: transport
        )

        _ = try await client.classify(
            payload: ImagePayload(sourcePath: "/tmp/source.png", mimeType: "image/png", base64: "aW1hZ2U="),
            provider: providerProfile(apiKeyRef: nil),
            generatedAt: nil
        )

        XCTAssertNil(transport.requests[0].headers["Authorization"])
    }

    func testThrowsWhenAPIKeyReferenceCannotBeResolved() async {
        let client = OpenAICompatibleClassificationClient(
            apiKeyResolver: DictionaryAPIKeyResolver(keys: [:]),
            transport: StubHTTPTransport(response: Data())
        )

        await XCTAssertThrowsErrorAsync(
            try await client.classify(
                payload: ImagePayload(sourcePath: "/tmp/source.png", mimeType: "image/png", base64: "aW1hZ2U="),
                provider: providerProfile(apiKeyRef: "keychain:missing"),
                generatedAt: nil
            )
        ) { error in
            XCTAssertEqual(error as? OpenAICompatibleClassificationClientError, .apiKeyNotFound("keychain:missing"))
        }
    }

    func testPropagatesNonSuccessHTTPStatus() async {
        let client = OpenAICompatibleClassificationClient(
            apiKeyResolver: DictionaryAPIKeyResolver(keys: [:]),
            transport: StubHTTPTransport(statusCode: 500, response: Data("server error".utf8))
        )

        await XCTAssertThrowsErrorAsync(
            try await client.classify(
                payload: ImagePayload(sourcePath: "/tmp/source.png", mimeType: "image/png", base64: "aW1hZ2U="),
                provider: providerProfile(apiKeyRef: nil),
                generatedAt: nil
            )
        ) { error in
            XCTAssertEqual(error as? OpenAICompatibleClassificationClientError, .httpFailure(statusCode: 500))
        }
    }
}

private final class StubHTTPTransport: HTTPTransport {
    private let statusCode: Int
    private let response: Data
    private(set) var requests: [HTTPRequest] = []

    init(statusCode: Int = 200, response: Data) {
        self.statusCode = statusCode
        self.response = response
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        return HTTPResponse(statusCode: statusCode, body: response)
    }
}

private func providerProfile(
    id: UUID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
    apiKeyRef: String?
) -> AIProviderProfile {
    AIProviderProfile(
        id: id,
        name: "Provider",
        baseURL: URL(string: "https://api.example.com/v1")!,
        model: "vision-model",
        apiKeyRef: apiKeyRef,
        supportsImageInput: true,
        timeoutSeconds: 60
    )
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
