import XCTest
@testable import SpIceDBCore

final class ClassificationLibraryTests: XCTestCase {
    func testUpdatesUserSentenceForImageEntry() throws {
        let imageId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        var document = workspaceWithImage(id: imageId)
        let library = ClassificationLibrary()

        try library.updateUserSentence(
            "  A portrait lit by a soft studio lamp.  ",
            forImageID: imageId,
            in: &document
        )

        XCTAssertEqual(
            document.images[0].classification.user.sentence,
            "A portrait lit by a soft studio lamp."
        )
    }

    func testUpdatesUserTagsFromCommaSeparatedInput() throws {
        let imageId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        var document = workspaceWithImage(id: imageId)
        let library = ClassificationLibrary()

        try library.updateUserTags(
            "portrait, soft light, portrait, , studio",
            forImageID: imageId,
            in: &document
        )

        XCTAssertEqual(document.images[0].classification.user.tags, ["portrait", "soft light", "studio"])
    }

    func testStoresAIClassificationWithProviderMetadata() throws {
        let imageId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let providerId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        var document = workspaceWithImage(id: imageId)
        let library = ClassificationLibrary()

        try library.updateAIClassification(
            sentence: "AI generated sentence.",
            tags: "ai tag, portrait, ai tag",
            providerId: providerId,
            model: "vision-model",
            generatedAt: generatedAt,
            forImageID: imageId,
            in: &document
        )

        XCTAssertEqual(
            document.images[0].classification.ai,
            AIClassificationContent(
                sentence: "AI generated sentence.",
                tags: ["ai tag", "portrait"],
                providerId: providerId,
                model: "vision-model",
                generatedAt: generatedAt
            )
        )
    }

    func testPromotesAIClassificationToUserClassification() throws {
        let imageId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        var document = workspaceWithImage(
            id: imageId,
            classification: Classification(
                user: ClassificationContent(sentence: "Old user sentence.", tags: ["old"]),
                ai: AIClassificationContent(sentence: "AI sentence.", tags: ["ai", "tag"])
            )
        )
        let library = ClassificationLibrary()

        try library.promoteAIClassificationToUser(forImageID: imageId, in: &document)

        XCTAssertEqual(
            document.images[0].classification.user,
            ClassificationContent(sentence: "AI sentence.", tags: ["ai", "tag"])
        )
        XCTAssertEqual(document.images[0].classification.ai?.sentence, "AI sentence.")
    }

    func testThrowsWhenImageIsMissing() {
        var document = WorkspaceDocument.new(name: "Empty")
        let library = ClassificationLibrary()

        XCTAssertThrowsError(
            try library.updateUserSentence(
                "No target",
                forImageID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                in: &document
            )
        ) { error in
            XCTAssertEqual(error as? ClassificationLibraryError, .imageNotFound)
        }
    }

    func testThrowsWhenPromotingWithoutAIClassification() {
        let imageId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        var document = workspaceWithImage(id: imageId)
        let library = ClassificationLibrary()

        XCTAssertThrowsError(
            try library.promoteAIClassificationToUser(forImageID: imageId, in: &document)
        ) { error in
            XCTAssertEqual(error as? ClassificationLibraryError, .aiClassificationMissing)
        }
    }
}

private func workspaceWithImage(
    id: UUID,
    classification: Classification = Classification()
) -> WorkspaceDocument {
    WorkspaceDocument(
        workspace: WorkspaceInfo(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Dataset",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            workingDirectory: nil
        ),
        images: [
            ImageEntry(
                id: id,
                sourcePath: "/tmp/source.png",
                displayName: "source.png",
                classification: classification
            )
        ]
    )
}

