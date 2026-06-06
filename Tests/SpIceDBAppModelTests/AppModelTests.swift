import XCTest
import SpIceDBCore
@testable import SpIceDBAppModel

final class AppModelTests: XCTestCase {
    func testNewWorkspaceCreatesUntitledDocumentAndClearsSelection() {
        let model = AppModel(now: { Date(timeIntervalSince1970: 1_800_000_000) })

        model.newWorkspace(named: "Dataset")

        XCTAssertEqual(model.workspace.workspace.name, "Dataset")
        XCTAssertEqual(model.workspace.workspace.createdAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertNil(model.selectedImageID)
        XCTAssertFalse(model.hasUnsavedChanges)
    }

    func testAddImageSelectsNewEntryAndMarksUnsavedChanges() throws {
        let ids = DeterministicUUIDGenerator([
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        ])
        let model = AppModel(idGenerator: ids.next)

        let entry = try model.addImage(path: "/tmp/source/image001.png")

        XCTAssertEqual(model.workspace.images, [entry])
        XCTAssertEqual(model.selectedImageID, entry.id)
        XCTAssertTrue(model.hasUnsavedChanges)
    }

    func testEditingSelectedImageUpdatesUserClassification() throws {
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let model = AppModel(
            workspace: workspaceWithImage(id: imageID),
            selectedImageID: imageID
        )

        try model.updateSelectedUserSentence("  A clean portrait.  ")
        try model.updateSelectedUserTags("portrait, clean, portrait")

        XCTAssertEqual(model.workspace.images[0].classification.user.sentence, "A clean portrait.")
        XCTAssertEqual(model.workspace.images[0].classification.user.tags, ["portrait", "clean"])
        XCTAssertTrue(model.hasUnsavedChanges)
    }

    func testSelectedImageReturnsCurrentImageEntry() {
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let model = AppModel(
            workspace: workspaceWithImage(id: imageID),
            selectedImageID: imageID
        )

        XCTAssertEqual(model.selectedImage?.id, imageID)
    }

    func testSelectedImageStatusUsesInjectedProvider() {
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let model = AppModel(
            workspace: workspaceWithImage(id: imageID),
            selectedImageID: imageID,
            imageFileStatusProvider: StubFileStatusProvider(statuses: [
                "/tmp/source/image001.png": .missing
            ])
        )

        XCTAssertEqual(model.selectedImageStatus, .missing)
    }

    func testSelectedImageStatusIsNilWhenNoImageIsSelected() {
        let model = AppModel(
            workspace: workspaceWithImage(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!)
        )

        XCTAssertNil(model.selectedImageStatus)
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

private func workspaceWithImage(id: UUID) -> WorkspaceDocument {
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
                sourcePath: "/tmp/source/image001.png",
                displayName: "image001.png"
            )
        ]
    )
}

private struct StubFileStatusProvider: ImageFileStatusProviding {
    var statuses: [String: ImageFileStatus]

    func status(forPath path: String) -> ImageFileStatus {
        statuses[path] ?? .missing
    }
}
