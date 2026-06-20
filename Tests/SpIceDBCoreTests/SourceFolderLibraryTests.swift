import XCTest
@testable import SpIceDBCore

final class SourceFolderLibraryTests: XCTestCase {
    func testAddsSourceFolderWithNormalizedPathAndDisplayName() throws {
        var document = WorkspaceDocument.new(name: "Library")
        let ids = DeterministicUUIDGenerator([
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        ])
        let library = SourceFolderLibrary(idGenerator: ids.next)

        let folder = try library.addSourceFolder(
            path: "  /tmp/dataset/source  ",
            recursive: true,
            to: &document
        )

        XCTAssertEqual(
            folder,
            SourceFolder(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                path: "/tmp/dataset/source",
                displayName: "source",
                recursive: true,
                lastScannedAt: nil
            )
        )
        XCTAssertEqual(document.sourceFolders, [folder])
    }

    func testAddingDuplicateSourceFolderReturnsExistingFolder() throws {
        let folderID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        var document = WorkspaceDocument(
            workspace: workspaceInfo(),
            sourceFolders: [
                SourceFolder(
                    id: folderID,
                    path: "/tmp/source",
                    displayName: "source",
                    recursive: true
                )
            ]
        )
        let library = SourceFolderLibrary()

        let folder = try library.addSourceFolder(path: "/tmp/source", recursive: false, to: &document)

        XCTAssertEqual(folder.id, folderID)
        XCTAssertEqual(document.sourceFolders.count, 1)
        XCTAssertTrue(document.sourceFolders[0].recursive)
    }

    func testRemovesSourceFolderByID() throws {
        let firstID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let secondID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        var document = WorkspaceDocument(
            workspace: workspaceInfo(),
            sourceFolders: [
                SourceFolder(id: firstID, path: "/tmp/first", displayName: "first", recursive: true),
                SourceFolder(id: secondID, path: "/tmp/second", displayName: "second", recursive: true)
            ]
        )
        let library = SourceFolderLibrary()

        let removed = library.removeSourceFolder(id: firstID, from: &document)

        XCTAssertEqual(removed?.id, firstID)
        XCTAssertEqual(document.sourceFolders.map(\.id), [secondID])
        XCTAssertNil(library.removeSourceFolder(id: firstID, from: &document))
    }

    func testScansSourceFolderForSupportedImagesRecursivelyInSortedOrder() throws {
        let directory = try SourceFolderTemporaryDirectory()
        let root = directory.url.appendingPathComponent("root")
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data([1]).write(to: root.appendingPathComponent("b.JPG"))
        try Data([2]).write(to: nested.appendingPathComponent("a.png"))
        try Data([3]).write(to: nested.appendingPathComponent("ignored.txt"))
        let scanner = SourceFolderScanner()

        let paths = try scanner.imagePaths(in: SourceFolder(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            path: root.path,
            displayName: "root",
            recursive: true
        ))

        XCTAssertEqual(paths, [
            nested.appendingPathComponent("a.png").path,
            root.appendingPathComponent("b.JPG").path
        ])
    }

    func testNonRecursiveScanOnlyIncludesImagesDirectlyUnderFolder() throws {
        let directory = try SourceFolderTemporaryDirectory()
        let root = directory.url.appendingPathComponent("root")
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data([1]).write(to: root.appendingPathComponent("root.webp"))
        try Data([2]).write(to: nested.appendingPathComponent("nested.png"))
        let scanner = SourceFolderScanner()

        let paths = try scanner.imagePaths(in: SourceFolder(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            path: root.path,
            displayName: "root",
            recursive: false
        ))

        XCTAssertEqual(paths, [root.appendingPathComponent("root.webp").path])
    }

    func testScanningMissingSourceFolderThrows() {
        let scanner = SourceFolderScanner()

        XCTAssertThrowsError(
            try scanner.imagePaths(in: SourceFolder(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                path: "/tmp/missing-source-folder",
                displayName: "missing",
                recursive: true
            ))
        ) { error in
            XCTAssertEqual(error as? SourceFolderScannerError, .folderMissing)
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

private final class SourceFolderTemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sp-ice-db-source-folder-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
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
