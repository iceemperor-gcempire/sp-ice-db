import XCTest
@testable import SpIceDBCore

final class ImageLibraryTests: XCTestCase {
    func testAddingImagePathCreatesEntryWithDisplayName() throws {
        var document = WorkspaceDocument.new(name: "Library")
        let ids = DeterministicUUIDGenerator([
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        ])
        let library = ImageLibrary(idGenerator: ids.next)

        let entry = try library.addImage(path: "/tmp/source/image001.png", to: &document)

        XCTAssertEqual(document.images, [entry])
        XCTAssertEqual(entry.id, UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!)
        XCTAssertEqual(entry.sourcePath, "/tmp/source/image001.png")
        XCTAssertEqual(entry.displayName, "image001.png")
        XCTAssertEqual(entry.classification, Classification())
        XCTAssertTrue(entry.generatedOutputs.isEmpty)
    }

    func testAddingDuplicatePathReturnsExistingEntry() throws {
        var document = WorkspaceDocument.new(name: "Library")
        let ids = DeterministicUUIDGenerator([
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        ])
        let library = ImageLibrary(idGenerator: ids.next)

        let first = try library.addImage(path: "/tmp/source/image001.png", to: &document)
        let second = try library.addImage(path: "/tmp/source/image001.png", to: &document)

        XCTAssertEqual(first, second)
        XCTAssertEqual(document.images.count, 1)
    }

    func testRemovingImageByIdReturnsRemovedEntry() throws {
        var document = WorkspaceDocument.new(name: "Library")
        let ids = DeterministicUUIDGenerator([
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        ])
        let library = ImageLibrary(idGenerator: ids.next)

        let first = try library.addImage(path: "/tmp/source/image001.png", to: &document)
        let second = try library.addImage(path: "/tmp/source/image002.png", to: &document)

        let removed = library.removeImage(id: first.id, from: &document)

        XCTAssertEqual(removed, first)
        XCTAssertEqual(document.images, [second])
        XCTAssertNil(library.removeImage(id: first.id, from: &document))
    }

    func testImagePathValidationUsesInjectedFileStatusProvider() {
        let existing = ImageEntry(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            sourcePath: "/tmp/source/existing.png",
            displayName: "existing.png"
        )
        let missing = ImageEntry(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            sourcePath: "/tmp/source/missing.png",
            displayName: "missing.png"
        )
        let unreadable = ImageEntry(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            sourcePath: "/tmp/source/unreadable.png",
            displayName: "unreadable.png"
        )
        let library = ImageLibrary(fileStatusProvider: StubFileStatusProvider(statuses: [
            existing.sourcePath: .readable,
            missing.sourcePath: .missing,
            unreadable.sourcePath: .unreadable
        ]))

        XCTAssertEqual(library.status(for: existing), .readable)
        XCTAssertEqual(library.status(for: missing), .missing)
        XCTAssertEqual(library.status(for: unreadable), .unreadable)
    }

    func testDefaultFileStatusProviderDetectsReadableAndMissingFiles() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sp-ice-db-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let file = directory.appendingPathComponent("source.png")
        try Data("image".utf8).write(to: file)

        let provider = FileManagerImageFileStatusProvider()

        XCTAssertEqual(provider.status(forPath: file.path), .readable)
        XCTAssertEqual(provider.status(forPath: directory.appendingPathComponent("missing.png").path), .missing)
    }

    func testDefaultImageFileMetadataProviderReadsModificationDateAndFileSize() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sp-ice-db-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let file = directory.appendingPathComponent("source.png")
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        try data.write(to: file)
        let modifiedAt = Date(timeIntervalSince1970: 1_800_000_000)
        try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: file.path)
        let provider = FileManagerImageFileMetadataProvider()

        let metadata = provider.metadata(forPath: file.path)

        XCTAssertEqual(metadata, ImageFileMetadata(modifiedAt: modifiedAt, fileSizeBytes: Int64(data.count)))
        XCTAssertNil(provider.metadata(forPath: directory.appendingPathComponent("missing.png").path))
    }

    func testAddingEmptyPathThrows() {
        var document = WorkspaceDocument.new(name: "Library")
        let library = ImageLibrary()

        XCTAssertThrowsError(try library.addImage(path: "  ", to: &document)) { error in
            XCTAssertEqual(error as? ImageLibraryError, .emptyPath)
        }
        XCTAssertTrue(document.images.isEmpty)
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

private struct StubFileStatusProvider: ImageFileStatusProviding {
    var statuses: [String: ImageFileStatus]

    func status(forPath path: String) -> ImageFileStatus {
        statuses[path] ?? .missing
    }
}
