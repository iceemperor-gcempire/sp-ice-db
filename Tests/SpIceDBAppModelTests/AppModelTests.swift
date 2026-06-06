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

    func testUpdateWorkspaceNameTrimsNameAndMarksUnsavedChanges() {
        let model = AppModel()

        model.updateWorkspaceName("  Dataset A  ")

        XCTAssertEqual(model.workspace.workspace.name, "Dataset A")
        XCTAssertTrue(model.hasUnsavedChanges)
    }

    func testUpdateWorkspaceNameIgnoresBlankNamesAndEquivalentNames() {
        let model = AppModel(
            workspace: workspaceInfo(name: "Dataset A"),
            hasUnsavedChanges: false
        )

        model.updateWorkspaceName("   ")
        model.updateWorkspaceName(" Dataset A ")

        XCTAssertEqual(model.workspace.workspace.name, "Dataset A")
        XCTAssertFalse(model.hasUnsavedChanges)
    }

    func testSetWorkingDirectoryTrimsPathAndMarksUnsavedChanges() {
        let model = AppModel()

        model.setWorkingDirectory("  /tmp/generated  ")

        XCTAssertEqual(model.workspace.workspace.workingDirectory, "/tmp/generated")
        XCTAssertTrue(model.hasUnsavedChanges)
    }

    func testSetWorkingDirectoryClearsBlankPathAndDoesNotMarkEquivalentValueDirty() {
        let model = AppModel(
            workspace: workspaceInfo(name: "Dataset", workingDirectory: "/tmp/generated"),
            hasUnsavedChanges: false
        )

        model.setWorkingDirectory(" /tmp/generated ")
        XCTAssertFalse(model.hasUnsavedChanges)

        model.setWorkingDirectory("   ")
        XCTAssertNil(model.workspace.workspace.workingDirectory)
        XCTAssertTrue(model.hasUnsavedChanges)
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

    func testEditingSelectedImageWithEquivalentUserClassificationDoesNotMarkUnsavedChanges() throws {
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let model = AppModel(
            workspace: workspaceWithImages([
                imageEntry(
                    id: imageID,
                    filename: "image001.png",
                    classification: Classification(
                        user: ClassificationContent(
                            sentence: "A clean portrait.",
                            tags: ["portrait", "clean"]
                        )
                    )
                )
            ]),
            selectedImageID: imageID,
            hasUnsavedChanges: false
        )

        try model.updateSelectedUserSentence("  A clean portrait.  ")
        try model.updateSelectedUserTags("portrait, clean")

        XCTAssertFalse(model.hasUnsavedChanges)
    }

    func testUpdateSelectedImageNotesTrimsNotesAndMarksUnsavedChanges() throws {
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let model = AppModel(
            workspace: workspaceWithImage(id: imageID),
            selectedImageID: imageID
        )

        try model.updateSelectedImageNotes("  keep for review  ")

        XCTAssertEqual(model.workspace.images[0].notes, "keep for review")
        XCTAssertTrue(model.hasUnsavedChanges)
    }

    func testUpdateSelectedImageNotesDoesNotMarkEquivalentNotesDirty() throws {
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let model = AppModel(
            workspace: workspaceWithImages([
                imageEntry(id: imageID, filename: "image001.png", notes: "keep for review")
            ]),
            selectedImageID: imageID,
            hasUnsavedChanges: false
        )

        try model.updateSelectedImageNotes(" keep for review ")

        XCTAssertEqual(model.workspace.images[0].notes, "keep for review")
        XCTAssertFalse(model.hasUnsavedChanges)
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

private func workspaceInfo(name: String, workingDirectory: String? = nil) -> WorkspaceDocument {
    WorkspaceDocument(
        workspace: WorkspaceInfo(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: name,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            workingDirectory: workingDirectory
        )
    )
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

private func imageEntry(
    id: UUID,
    filename: String,
    notes: String = "",
    classification: Classification = Classification()
) -> ImageEntry {
    ImageEntry(
        id: id,
        sourcePath: "/tmp/source/\(filename)",
        displayName: filename,
        notes: notes,
        classification: classification
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
