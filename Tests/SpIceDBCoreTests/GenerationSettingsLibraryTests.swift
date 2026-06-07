import XCTest
@testable import SpIceDBCore

final class GenerationSettingsLibraryTests: XCTestCase {
    func testAddsGenerationSettingsWithNormalizedFields() throws {
        let settingsID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let providerID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let library = GenerationSettingsLibrary(idGenerator: { settingsID })
        var document = WorkspaceDocument.new(name: "Dataset")

        let settings = try library.addSettings(
            name: "  Product Prompt  ",
            providerId: providerID,
            parameters: [
                "prompt": .string("  A clean studio product image.  "),
                "size": .string(" 1024x1024 "),
                "quality": .string("high"),
                "n": .number(1)
            ],
            to: &document
        )

        XCTAssertEqual(
            settings,
            GenerationSettings(
                id: settingsID,
                name: "Product Prompt",
                providerId: providerID,
                parameters: [
                    "prompt": .string("A clean studio product image."),
                    "size": .string("1024x1024"),
                    "quality": .string("high"),
                    "n": .number(1)
                ]
            )
        )
        XCTAssertEqual(document.generationSettings, [settings])
    }

    func testUpdatesExistingGenerationSettings() throws {
        let settingsID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let providerID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let library = GenerationSettingsLibrary()
        var document = WorkspaceDocument(
            workspace: workspaceInfo(),
            generationSettings: [
                GenerationSettings(
                    id: settingsID,
                    name: "Old",
                    providerId: nil,
                    parameters: ["prompt": .string("old")]
                )
            ]
        )

        let settings = try library.updateSettings(
            id: settingsID,
            name: "New",
            providerId: providerID,
            parameters: ["prompt": .string("new")],
            in: &document
        )

        XCTAssertEqual(settings.name, "New")
        XCTAssertEqual(settings.providerId, providerID)
        XCTAssertEqual(settings.parameters, ["prompt": .string("new")])
        XCTAssertEqual(document.generationSettings, [settings])
    }

    func testRemovesGenerationSettingsAndClearsOutputReferences() {
        let settingsID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let outputID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let library = GenerationSettingsLibrary()
        var document = WorkspaceDocument(
            workspace: workspaceInfo(),
            images: [
                ImageEntry(
                    id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                    sourcePath: "/tmp/source.png",
                    displayName: "source.png",
                    generatedOutputs: [
                        GeneratedOutput(
                            id: outputID,
                            path: "/tmp/generated.png",
                            status: .generated,
                            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                            settingsId: settingsID
                        )
                    ]
                )
            ],
            generationSettings: [
                GenerationSettings(
                    id: settingsID,
                    name: "Preset",
                    providerId: nil
                )
            ]
        )

        let removed = library.removeSettings(id: settingsID, from: &document)

        XCTAssertEqual(removed?.id, settingsID)
        XCTAssertEqual(document.generationSettings, [])
        XCTAssertNil(document.images[0].generatedOutputs[0].settingsId)
    }

    func testValidatesGenerationSettingsFields() {
        let settingsID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let library = GenerationSettingsLibrary(idGenerator: { settingsID })
        var document = WorkspaceDocument.new(name: "Dataset")

        XCTAssertThrowsError(
            try library.addSettings(name: "   ", providerId: nil, parameters: [:], to: &document)
        ) { error in
            XCTAssertEqual(error as? GenerationSettingsLibraryError, .emptyName)
        }

        XCTAssertThrowsError(
            try library.updateSettings(
                id: settingsID,
                name: "Missing",
                providerId: nil,
                parameters: [:],
                in: &document
            )
        ) { error in
            XCTAssertEqual(error as? GenerationSettingsLibraryError, .settingsNotFound)
        }
    }
}

private func workspaceInfo() -> WorkspaceInfo {
    WorkspaceInfo(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Dataset",
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
        workingDirectory: nil
    )
}
