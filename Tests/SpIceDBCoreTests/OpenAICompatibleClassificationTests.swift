import XCTest
@testable import SpIceDBCore

final class OpenAICompatibleClassificationTests: XCTestCase {
    func testBuildsImageClassificationRequestForChatCompletionsEndpoint() throws {
        let provider = providerProfile(
            baseURL: URL(string: "https://api.example.com/v1")!,
            apiKeyRef: "keychain:sp-ice-db/provider",
            customHeaders: ["X-Workspace": "test"]
        )
        let service = OpenAICompatibleClassificationService()

        let request = try service.makeRequest(
            provider: provider,
            imageBase64: "aW1hZ2UtYnl0ZXM=",
            mimeType: "image/png"
        )

        XCTAssertEqual(request.url, URL(string: "https://api.example.com/v1/chat/completions")!)
        XCTAssertEqual(request.timeoutSeconds, 60)
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(request.headers["Authorization"], "Bearer ${keychain:sp-ice-db/provider}")
        XCTAssertEqual(request.headers["X-Workspace"], "test")
        XCTAssertEqual(request.body.model, "vision-model")
        XCTAssertEqual(request.body.responseFormat.type, "json_object")
        XCTAssertEqual(request.body.messages.map(\.role), ["system", "user"])
        XCTAssertTrue(request.body.messages[0].content.contains(.text(OpenAICompatibleClassificationService.systemPrompt)))
        XCTAssertTrue(
            request.body.messages[1].content.contains(
                .imageURL(OpenAIChatCompletionRequest.ImageURL(url: "data:image/png;base64,aW1hZ2UtYnl0ZXM="))
            )
        )
    }

    func testBuildsEndpointWhenBaseURLHasTrailingSlash() throws {
        let provider = providerProfile(baseURL: URL(string: "https://api.example.com/v1/")!)
        let service = OpenAICompatibleClassificationService()

        let request = try service.makeRequest(
            provider: provider,
            imageBase64: "aW1hZ2UtYnl0ZXM=",
            mimeType: "image/jpeg"
        )

        XCTAssertEqual(request.url, URL(string: "https://api.example.com/v1/chat/completions")!)
    }

    func testRejectsUnsupportedProviderAndInvalidImageInputs() {
        let service = OpenAICompatibleClassificationService()

        XCTAssertThrowsError(
            try service.makeRequest(
                provider: providerProfile(supportsImageInput: false),
                imageBase64: "aW1hZ2UtYnl0ZXM=",
                mimeType: "image/png"
            )
        ) { error in
            XCTAssertEqual(error as? OpenAICompatibleClassificationError, .providerDoesNotSupportImageInput)
        }

        XCTAssertThrowsError(
            try service.makeRequest(
                provider: providerProfile(),
                imageBase64: " ",
                mimeType: "image/png"
            )
        ) { error in
            XCTAssertEqual(error as? OpenAICompatibleClassificationError, .emptyImageData)
        }

        XCTAssertThrowsError(
            try service.makeRequest(
                provider: providerProfile(),
                imageBase64: "aW1hZ2UtYnl0ZXM=",
                mimeType: "application/octet-stream"
            )
        ) { error in
            XCTAssertEqual(error as? OpenAICompatibleClassificationError, .invalidMimeType)
        }
    }

    func testParsesClassificationResponseJSONContent() throws {
        let providerID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let provider = providerProfile(id: providerID, model: "vision-model")
        let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let service = OpenAICompatibleClassificationService()
        let response = """
        {
          "choices": [
            {
              "message": {
                "content": "{\\"sentence\\":\\"A bright studio portrait.\\",\\"tags\\":[\\"portrait\\",\\"studio light\\",\\"portrait\\"]}"
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let classification = try service.parseResponse(
            response,
            provider: provider,
            generatedAt: generatedAt
        )

        XCTAssertEqual(
            classification,
            AIClassificationContent(
                sentence: "A bright studio portrait.",
                tags: ["portrait", "studio light"],
                providerId: providerID,
                model: "vision-model",
                generatedAt: generatedAt
            )
        )
    }

    func testParsesClassificationResponseWrappedInMarkdownFence() throws {
        let service = OpenAICompatibleClassificationService()
        let response = """
        {
          "choices": [
            {
              "message": {
                "content": "```json\\n{\\"sentence\\":\\"A clean product image.\\",\\"tags\\":[\\"product\\",\\"white background\\"]}\\n```"
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let classification = try service.parseResponse(
            response,
            provider: providerProfile(),
            generatedAt: nil
        )

        XCTAssertEqual(classification.sentence, "A clean product image.")
        XCTAssertEqual(classification.tags, ["product", "white background"])
    }

    func testRejectsMalformedOrEmptyClassificationResponses() {
        let service = OpenAICompatibleClassificationService()

        XCTAssertThrowsError(
            try service.parseResponse("{}".data(using: .utf8)!, provider: providerProfile(), generatedAt: nil)
        ) { error in
            XCTAssertEqual(error as? OpenAICompatibleClassificationError, .missingContent)
        }

        let invalidJSONContent = """
        {"choices":[{"message":{"content":"not-json"}}]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(
            try service.parseResponse(invalidJSONContent, provider: providerProfile(), generatedAt: nil)
        ) { error in
            XCTAssertEqual(error as? OpenAICompatibleClassificationError, .invalidJSONContent)
        }

        let emptySentence = """
        {"choices":[{"message":{"content":"{\\"sentence\\":\\" \\",\\"tags\\":[\\"tag\\"]}"}}]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(
            try service.parseResponse(emptySentence, provider: providerProfile(), generatedAt: nil)
        ) { error in
            XCTAssertEqual(error as? OpenAICompatibleClassificationError, .emptySentence)
        }

        let emptyTags = """
        {"choices":[{"message":{"content":"{\\"sentence\\":\\"Caption.\\",\\"tags\\":[]}"}}]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(
            try service.parseResponse(emptyTags, provider: providerProfile(), generatedAt: nil)
        ) { error in
            XCTAssertEqual(error as? OpenAICompatibleClassificationError, .emptyTags)
        }
    }
}

private func providerProfile(
    id: UUID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
    baseURL: URL = URL(string: "https://api.example.com/v1")!,
    model: String = "vision-model",
    apiKeyRef: String? = nil,
    supportsImageInput: Bool = true,
    customHeaders: [String: String] = [:]
) -> AIProviderProfile {
    AIProviderProfile(
        id: id,
        name: "Provider",
        baseURL: baseURL,
        model: model,
        apiKeyRef: apiKeyRef,
        supportsImageInput: supportsImageInput,
        timeoutSeconds: 60,
        customHeaders: customHeaders
    )
}
