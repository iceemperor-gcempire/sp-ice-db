import Foundation

public enum ClassificationLibraryError: Error, Equatable {
    case imageNotFound
    case aiClassificationMissing
}

public struct ClassificationLibrary {
    public init() {}

    public func updateUserSentence(
        _ sentence: String,
        forImageID imageID: UUID,
        in document: inout WorkspaceDocument
    ) throws {
        let index = try imageIndex(for: imageID, in: document)
        document.images[index].classification.user.sentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func updateUserTags(
        _ tags: String,
        forImageID imageID: UUID,
        in document: inout WorkspaceDocument
    ) throws {
        let index = try imageIndex(for: imageID, in: document)
        document.images[index].classification.user.tags = TagList.parse(tags)
    }

    public func updateAIClassification(
        sentence: String,
        tags: String,
        providerId: UUID?,
        model: String?,
        generatedAt: Date?,
        forImageID imageID: UUID,
        in document: inout WorkspaceDocument
    ) throws {
        let index = try imageIndex(for: imageID, in: document)
        document.images[index].classification.ai = AIClassificationContent(
            sentence: sentence.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: TagList.parse(tags),
            providerId: providerId,
            model: model?.trimmingCharacters(in: .whitespacesAndNewlines),
            generatedAt: generatedAt
        )
    }

    public func promoteAIClassificationToUser(
        forImageID imageID: UUID,
        in document: inout WorkspaceDocument
    ) throws {
        let index = try imageIndex(for: imageID, in: document)
        guard let ai = document.images[index].classification.ai else {
            throw ClassificationLibraryError.aiClassificationMissing
        }

        document.images[index].classification.user = ClassificationContent(
            sentence: ai.sentence,
            tags: ai.tags
        )
    }

    private func imageIndex(for imageID: UUID, in document: WorkspaceDocument) throws -> Int {
        guard let index = document.images.firstIndex(where: { $0.id == imageID }) else {
            throw ClassificationLibraryError.imageNotFound
        }

        return index
    }
}

