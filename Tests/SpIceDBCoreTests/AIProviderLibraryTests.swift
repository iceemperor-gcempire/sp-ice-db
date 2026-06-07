import XCTest
@testable import SpIceDBCore

final class AIProviderLibraryTests: XCTestCase {
    func testAddsOpenAICompatibleProviderProfile() throws {
        var document = WorkspaceDocument.new(name: "Dataset")
        let ids = DeterministicUUIDGenerator([
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        ])
        let library = AIProviderLibrary(idGenerator: ids.next)

        let provider = try library.addProvider(
            name: " OpenAI Compatible ",
            baseURL: " https://api.example.com/v1 ",
            model: " vision-model ",
            apiKeyRef: " keychain:sp-ice-db/provider ",
            supportsImageInput: true,
            timeoutSeconds: 45,
            customHeaders: ["X-Test": "enabled"],
            to: &document
        )

        XCTAssertEqual(document.aiProviders, [provider])
        XCTAssertEqual(provider.id, UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!)
        XCTAssertEqual(provider.name, "OpenAI Compatible")
        XCTAssertEqual(provider.baseURL, URL(string: "https://api.example.com/v1")!)
        XCTAssertEqual(provider.model, "vision-model")
        XCTAssertEqual(provider.apiKeyRef, "keychain:sp-ice-db/provider")
        XCTAssertTrue(provider.supportsImageInput)
        XCTAssertEqual(provider.timeoutSeconds, 45)
        XCTAssertEqual(provider.customHeaders, ["X-Test": "enabled"])
    }

    func testRejectsInvalidProviderFields() {
        var document = WorkspaceDocument.new(name: "Dataset")
        let library = AIProviderLibrary()

        XCTAssertThrowsError(
            try library.addProvider(
                name: " ",
                baseURL: "https://api.example.com/v1",
                model: "vision-model",
                apiKeyRef: nil,
                to: &document
            )
        ) { error in
            XCTAssertEqual(error as? AIProviderLibraryError, .emptyName)
        }

        XCTAssertThrowsError(
            try library.addProvider(
                name: "Provider",
                baseURL: "not a url",
                model: "vision-model",
                apiKeyRef: nil,
                to: &document
            )
        ) { error in
            XCTAssertEqual(error as? AIProviderLibraryError, .invalidBaseURL)
        }

        XCTAssertThrowsError(
            try library.addProvider(
                name: "Provider",
                baseURL: "https://api.example.com/v1",
                model: " ",
                apiKeyRef: nil,
                to: &document
            )
        ) { error in
            XCTAssertEqual(error as? AIProviderLibraryError, .emptyModel)
        }

        XCTAssertTrue(document.aiProviders.isEmpty)
    }

    func testUpdatesExistingProviderProfile() throws {
        let providerID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        var document = workspaceWithProvider(id: providerID)
        let library = AIProviderLibrary()

        let updated = try library.updateProvider(
            id: providerID,
            name: "Updated",
            baseURL: "https://api.updated.example/v1",
            model: "updated-model",
            apiKeyRef: nil,
            supportsImageInput: false,
            timeoutSeconds: 30,
            customHeaders: [:],
            in: &document
        )

        XCTAssertEqual(document.aiProviders, [updated])
        XCTAssertEqual(updated.id, providerID)
        XCTAssertEqual(updated.name, "Updated")
        XCTAssertEqual(updated.baseURL, URL(string: "https://api.updated.example/v1")!)
        XCTAssertEqual(updated.model, "updated-model")
        XCTAssertNil(updated.apiKeyRef)
        XCTAssertFalse(updated.supportsImageInput)
        XCTAssertEqual(updated.timeoutSeconds, 30)
    }

    func testRemovesProviderProfileByID() throws {
        let firstID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let secondID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        var document = WorkspaceDocument(
            workspace: WorkspaceInfo(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "Dataset",
                createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
                workingDirectory: nil
            ),
            aiProviders: [
                provider(id: firstID),
                provider(id: secondID)
            ]
        )
        let library = AIProviderLibrary()

        let removed = library.removeProvider(id: firstID, from: &document)

        XCTAssertEqual(removed, provider(id: firstID))
        XCTAssertEqual(document.aiProviders, [provider(id: secondID)])
        XCTAssertNil(library.removeProvider(id: firstID, from: &document))
    }

    func testUpdatingMissingProviderThrows() {
        var document = WorkspaceDocument.new(name: "Dataset")
        let library = AIProviderLibrary()

        XCTAssertThrowsError(
            try library.updateProvider(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                name: "Provider",
                baseURL: "https://api.example.com/v1",
                model: "vision-model",
                apiKeyRef: nil,
                in: &document
            )
        ) { error in
            XCTAssertEqual(error as? AIProviderLibraryError, .providerNotFound)
        }
    }
}

private final class DeterministicUUIDGenerator {
    private var ids: [UUID]

    init(_ ids: [UUID]) {
        self.ids = ids
    }

    func next() -> UUID {
        ids.removeFirst()
    }
}

private func workspaceWithProvider(id: UUID) -> WorkspaceDocument {
    WorkspaceDocument(
        workspace: WorkspaceInfo(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Dataset",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            workingDirectory: nil
        ),
        aiProviders: [
            provider(id: id)
        ]
    )
}

private func provider(id: UUID) -> AIProviderProfile {
    AIProviderProfile(
        id: id,
        name: "Provider",
        baseURL: URL(string: "https://api.example.com/v1")!,
        model: "vision-model",
        apiKeyRef: "keychain:sp-ice-db/provider",
        supportsImageInput: true,
        timeoutSeconds: 60
    )
}

