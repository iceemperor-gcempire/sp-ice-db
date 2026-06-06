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

    func testAddingDuplicateImageSelectsExistingEntryWithoutMarkingUnsavedChanges() throws {
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let model = AppModel(
            workspace: workspaceWithImage(id: imageID),
            hasUnsavedChanges: false
        )

        let entry = try model.addImage(path: "/tmp/source/image001.png")

        XCTAssertEqual(entry.id, imageID)
        XCTAssertEqual(model.workspace.images.map(\.id), [imageID])
        XCTAssertEqual(model.selectedImageID, imageID)
        XCTAssertFalse(model.hasUnsavedChanges)
    }

    func testAddImagesAddsMultiplePathsSelectsLastEntryAndMarksUnsavedChanges() throws {
        let ids = DeterministicUUIDGenerator([
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        ])
        let model = AppModel(idGenerator: ids.next)

        let entries = try model.addImages(paths: [
            "/tmp/source/image001.png",
            "/tmp/source/image002.png"
        ])

        XCTAssertEqual(entries.map(\.sourcePath), ["/tmp/source/image001.png", "/tmp/source/image002.png"])
        XCTAssertEqual(model.workspace.images.map(\.sourcePath), ["/tmp/source/image001.png", "/tmp/source/image002.png"])
        XCTAssertEqual(model.selectedImageID, entries.last?.id)
        XCTAssertTrue(model.hasUnsavedChanges)
    }

    func testAddImagesIgnoresDuplicatePathsWithoutExtraEntries() throws {
        let ids = DeterministicUUIDGenerator([
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        ])
        let model = AppModel(idGenerator: ids.next)

        let entries = try model.addImages(paths: [
            "/tmp/source/image001.png",
            "/tmp/source/image001.png"
        ])

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0], entries[1])
        XCTAssertEqual(model.workspace.images.count, 1)
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

    func testRemoveSelectedImageOnlyUnregistersEntrySelectsNextAvailableImageAndMarksUnsavedChanges() {
        let firstID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let secondID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let model = AppModel(
            workspace: workspaceWithImages([
                imageEntry(id: firstID, filename: "image001.png"),
                imageEntry(id: secondID, filename: "image002.png")
            ]),
            selectedImageID: firstID
        )

        let removed = model.removeSelectedImage()

        XCTAssertEqual(removed?.id, firstID)
        XCTAssertEqual(model.workspace.images.map(\.id), [secondID])
        XCTAssertEqual(model.selectedImageID, secondID)
        XCTAssertTrue(model.hasUnsavedChanges)
    }

    func testRemoveSelectedImageDoesNotMarkUnsavedChangesWhenNothingIsSelected() {
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let model = AppModel(
            workspace: workspaceWithImage(id: imageID),
            hasUnsavedChanges: false
        )

        let removed = model.removeSelectedImage()

        XCTAssertNil(removed)
        XCTAssertEqual(model.workspace.images.map(\.id), [imageID])
        XCTAssertFalse(model.hasUnsavedChanges)
    }

    func testSaveWorkspaceWritesFileStoresURLAndClearsUnsavedChanges() throws {
        let directory = try TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("dataset.spicedb")
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let savedAt = Date(timeIntervalSince1970: 1_800_000_500)
        let model = AppModel(
            workspace: workspaceWithImage(id: imageID),
            selectedImageID: imageID,
            hasUnsavedChanges: true,
            now: { savedAt }
        )

        try model.saveWorkspace(to: fileURL)

        XCTAssertEqual(model.workspaceURL, fileURL)
        XCTAssertFalse(model.hasUnsavedChanges)
        XCTAssertEqual(model.workspace.workspace.updatedAt, savedAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testOpenWorkspaceLoadsDocumentSelectsFirstImageAndClearsUnsavedChanges() throws {
        let directory = try TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("dataset.spicedb")
        let firstID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let secondID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        var document = workspaceWithImages([
            imageEntry(id: firstID, filename: "image001.png"),
            imageEntry(id: secondID, filename: "image002.png")
        ])
        try WorkspaceStore(now: { Date(timeIntervalSince1970: 1_800_000_100) }).save(&document, to: fileURL)
        let model = AppModel(hasUnsavedChanges: true)

        try model.openWorkspace(from: fileURL)

        XCTAssertEqual(model.workspace.images.map(\.id), [firstID, secondID])
        XCTAssertEqual(model.workspaceURL, fileURL)
        XCTAssertEqual(model.selectedImageID, firstID)
        XCTAssertFalse(model.hasUnsavedChanges)
    }

    func testSaveWorkspaceWithoutURLThrows() {
        let model = AppModel()

        XCTAssertThrowsError(try model.saveWorkspace()) { error in
            XCTAssertEqual(error as? AppModelError, .workspaceURLRequired)
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

private func workspaceWithImage(id: UUID) -> WorkspaceDocument {
    workspaceWithImages([
        imageEntry(id: id, filename: "image001.png")
    ])
}

private func workspaceWithImages(_ images: [ImageEntry]) -> WorkspaceDocument {
    WorkspaceDocument(
        workspace: WorkspaceInfo(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Dataset",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            workingDirectory: nil
        ),
        images: images
    )
}

private func imageEntry(id: UUID, filename: String) -> ImageEntry {
    ImageEntry(
        id: id,
        sourcePath: "/tmp/source/\(filename)",
        displayName: filename
    )
}

private struct StubFileStatusProvider: ImageFileStatusProviding {
    var statuses: [String: ImageFileStatus]

    func status(forPath path: String) -> ImageFileStatus {
        statuses[path] ?? .missing
    }
}

private final class TemporaryDirectory {
    let url: URL

    init() throws {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sp-ice-db-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
