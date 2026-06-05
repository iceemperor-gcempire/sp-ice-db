import XCTest
@testable import SpIceDBCore

final class WorkspaceTests: XCTestCase {
    func testWorkspaceRoundTripsAsJSON() throws {
        let workspace = WorkspaceDocument(
            workspace: WorkspaceInfo(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "Training Set",
                createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_000_100),
                workingDirectory: "/tmp/generated"
            ),
            aiProviders: [
                AIProviderProfile(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    name: "OpenAI Compatible",
                    baseURL: URL(string: "https://api.example.com/v1")!,
                    model: "vision-model",
                    apiKeyRef: "keychain:sp-ice-db/example",
                    supportsImageInput: true,
                    timeoutSeconds: 60,
                    customHeaders: ["X-Test": "enabled"]
                )
            ],
            images: [
                ImageEntry(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    sourcePath: "/tmp/source.png",
                    displayName: "source.png",
                    notes: "sample",
                    classification: Classification(
                        user: ClassificationContent(sentence: "User sentence.", tags: ["portrait", "soft light"]),
                        ai: AIClassificationContent(
                            sentence: "AI sentence.",
                            tags: ["portrait", "studio"],
                            providerId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                            model: "vision-model",
                            generatedAt: Date(timeIntervalSince1970: 1_800_000_200)
                        )
                    ),
                    generatedOutputs: [
                        GeneratedOutput(
                            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                            path: "/tmp/generated/source_variant.png",
                            status: .generated,
                            createdAt: Date(timeIntervalSince1970: 1_800_000_300),
                            settingsId: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
                        )
                    ]
                )
            ],
            generationSettings: [
                GenerationSettings(
                    id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                    name: "Default",
                    providerId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    parameters: ["steps": .number(20), "style": .string("clean")]
                )
            ]
        )

        let data = try WorkspaceJSONCodec.encode(workspace)
        let decoded = try WorkspaceJSONCodec.decode(data)

        XCTAssertEqual(decoded, workspace)
    }

    func testTagListNormalizesCommaSeparatedInput() {
        let tags = TagList.parse(" portrait, soft light, portrait, ,studio ")

        XCTAssertEqual(tags, ["portrait", "soft light", "studio"])
    }

    func testNewWorkspaceUsesSchemaVersionOne() {
        let workspace = WorkspaceDocument.new(name: "Untitled")

        XCTAssertEqual(workspace.schemaVersion, 1)
        XCTAssertEqual(workspace.workspace.name, "Untitled")
        XCTAssertTrue(workspace.images.isEmpty)
        XCTAssertTrue(workspace.aiProviders.isEmpty)
    }
}

