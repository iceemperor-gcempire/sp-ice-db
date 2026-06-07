import XCTest
@testable import SpIceDBCore

final class OpenAICompatibleImageGenerationClientTests: XCTestCase {
    func testSendsImageGenerationRequestWithResolvedAPIKeyAndParsesBase64Image() async throws {
        let generatedData = Data([0x89, 0x50, 0x4E, 0x47])
        let transport = ImageGenerationStubHTTPTransport(
            response: """
            {
              "created": 1713833628,
              "data": [{"b64_json": "\(generatedData.base64EncodedString())"}],
              "output_format": "png",
              "size": "1024x1024",
              "quality": "high"
            }
            """.data(using: .utf8)!
        )
        let client = OpenAICompatibleImageGenerationClient(
            apiKeyResolver: DictionaryAPIKeyResolver(keys: [
                "keychain:provider": "secret-token"
            ]),
            transport: transport
        )

        let asset = try await client.generateImage(
            request: imageGenerationRequest(
                settings: GenerationSettings(
                    id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                    name: "Studio",
                    providerId: nil,
                    parameters: [
                        "prompt": .string("A clean product photo of a glass bottle."),
                        "size": .string("1024x1024"),
                        "quality": .string("high"),
                        "output_format": .string("png")
                    ]
                )
            ),
            provider: providerProfile(apiKeyRef: "keychain:provider")
        )

        XCTAssertEqual(
            asset,
            GeneratedImageAsset(
                data: generatedData,
                suggestedFilename: "source_generated.png"
            )
        )
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests[0].url, URL(string: "https://api.example.com/v1/images/generations")!)
        XCTAssertEqual(transport.requests[0].method, "POST")
        XCTAssertEqual(transport.requests[0].headers["Authorization"], "Bearer secret-token")
        XCTAssertEqual(transport.requests[0].headers["Content-Type"], "application/json")

        let body = try JSONDecoder().decode(OpenAIImageGenerationRequestBody.self, from: transport.requests[0].body)
        XCTAssertEqual(body.model, "gpt-image-1")
        XCTAssertEqual(body.prompt, "A clean product photo of a glass bottle.")
        XCTAssertEqual(body.size, "1024x1024")
        XCTAssertEqual(body.quality, "high")
        XCTAssertEqual(body.outputFormat, "png")
        XCTAssertEqual(body.n, 1)
    }

    func testBuildsPromptFromClassificationWhenSettingsPromptIsMissing() async throws {
        let transport = ImageGenerationStubHTTPTransport(
            response: """
            {"data":[{"b64_json":"\(Data([1]).base64EncodedString())"}],"output_format":"webp"}
            """.data(using: .utf8)!
        )
        let client = OpenAICompatibleImageGenerationClient(
            apiKeyResolver: DictionaryAPIKeyResolver(keys: [:]),
            transport: transport
        )

        let asset = try await client.generateImage(
            request: imageGenerationRequest(
                notes: "Keep the background minimal.",
                classification: Classification(
                    user: ClassificationContent(
                        sentence: "A silver spoon on a black table.",
                        tags: ["silver spoon", "black table"]
                    )
                )
            ),
            provider: providerProfile(apiKeyRef: nil)
        )

        let body = try JSONDecoder().decode(OpenAIImageGenerationRequestBody.self, from: transport.requests[0].body)
        XCTAssertTrue(body.prompt.contains("A silver spoon on a black table."))
        XCTAssertTrue(body.prompt.contains("silver spoon, black table"))
        XCTAssertTrue(body.prompt.contains("Keep the background minimal."))
        XCTAssertEqual(asset.suggestedFilename, "source_generated.webp")
        XCTAssertNil(transport.requests[0].headers["Authorization"])
    }

    func testThrowsForMissingAPIKeyHTTPFailureAndMissingImageData() async {
        let missingKeyClient = OpenAICompatibleImageGenerationClient(
            apiKeyResolver: DictionaryAPIKeyResolver(keys: [:]),
            transport: ImageGenerationStubHTTPTransport(response: Data())
        )

        await XCTAssertThrowsErrorAsync(
            try await missingKeyClient.generateImage(
                request: imageGenerationRequest(),
                provider: providerProfile(apiKeyRef: "keychain:missing")
            )
        ) { error in
            XCTAssertEqual(error as? OpenAICompatibleImageGenerationClientError, .apiKeyNotFound("keychain:missing"))
        }

        let failingClient = OpenAICompatibleImageGenerationClient(
            apiKeyResolver: DictionaryAPIKeyResolver(keys: [:]),
            transport: ImageGenerationStubHTTPTransport(statusCode: 429, response: Data("rate limited".utf8))
        )

        await XCTAssertThrowsErrorAsync(
            try await failingClient.generateImage(
                request: imageGenerationRequest(),
                provider: providerProfile(apiKeyRef: nil)
            )
        ) { error in
            XCTAssertEqual(error as? OpenAICompatibleImageGenerationClientError, .httpFailure(statusCode: 429))
        }

        let emptyDataClient = OpenAICompatibleImageGenerationClient(
            apiKeyResolver: DictionaryAPIKeyResolver(keys: [:]),
            transport: ImageGenerationStubHTTPTransport(response: #"{"data":[{"b64_json":""}]}"#.data(using: .utf8)!)
        )

        await XCTAssertThrowsErrorAsync(
            try await emptyDataClient.generateImage(
                request: imageGenerationRequest(),
                provider: providerProfile(apiKeyRef: nil)
            )
        ) { error in
            XCTAssertEqual(error as? OpenAICompatibleImageGenerationError, .missingImageData)
        }
    }
}

private final class ImageGenerationStubHTTPTransport: HTTPTransport {
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

private func imageGenerationRequest(
    notes: String = "",
    classification: Classification = Classification(),
    settings: GenerationSettings? = nil
) -> ImageGenerationRequest {
    ImageGenerationRequest(
        imageID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        sourcePath: "/tmp/source.png",
        displayName: "source.png",
        notes: notes,
        classification: classification,
        settings: settings
    )
}

private func providerProfile(apiKeyRef: String?) -> AIProviderProfile {
    AIProviderProfile(
        id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
        name: "Provider",
        baseURL: URL(string: "https://api.example.com/v1")!,
        model: "gpt-image-1",
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
