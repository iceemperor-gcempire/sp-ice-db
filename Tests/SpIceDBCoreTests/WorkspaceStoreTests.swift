import XCTest
@testable import SpIceDBCore

final class WorkspaceStoreTests: XCTestCase {
    func testSaveWritesWorkspaceFileAndLoadReadsItBack() throws {
        let directory = try TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("dataset.spicedb")
        var document = WorkspaceDocument(
            workspace: WorkspaceInfo(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "Dataset",
                createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
                workingDirectory: "/tmp/generated"
            ),
            images: [
                ImageEntry(
                    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    sourcePath: "/tmp/source.png",
                    displayName: "source.png"
                )
            ]
        )
        let savedAt = Date(timeIntervalSince1970: 1_800_000_500)
        let store = WorkspaceStore(now: { savedAt })

        try store.save(&document, to: fileURL)
        let loaded = try store.load(from: fileURL)

        XCTAssertEqual(document.workspace.updatedAt, savedAt)
        XCTAssertEqual(loaded, document)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testSaveCreatesParentDirectoryWhenNeeded() throws {
        let directory = try TemporaryDirectory()
        let fileURL = directory.url
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("dataset.spicedb")
        var document = WorkspaceDocument.new(
            name: "Dataset",
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let store = WorkspaceStore(now: { Date(timeIntervalSince1970: 1_800_000_100) })

        try store.save(&document, to: fileURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testLoadingUnsupportedFutureSchemaThrows() throws {
        let directory = try TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("future.spicedb")
        let json = """
        {
          "schemaVersion": 999,
          "workspace": {
            "id": "11111111-1111-1111-1111-111111111111",
            "name": "Future",
            "createdAt": "2026-06-06T00:00:00Z",
            "updatedAt": "2026-06-06T00:00:00Z",
            "workingDirectory": null
          },
          "aiProviders": [],
          "images": [],
          "generationSettings": []
        }
        """
        try Data(json.utf8).write(to: fileURL)

        XCTAssertThrowsError(try WorkspaceStore().load(from: fileURL)) { error in
            XCTAssertEqual(error as? WorkspaceStoreError, .unsupportedSchemaVersion(999))
        }
    }

    func testLoadingInvalidJSONThrowsDecodeFailure() throws {
        let directory = try TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("broken.spicedb")
        try Data("{".utf8).write(to: fileURL)

        XCTAssertThrowsError(try WorkspaceStore().load(from: fileURL)) { error in
            guard case WorkspaceStoreError.decodeFailed = error else {
                return XCTFail("Expected decodeFailed, got \(error)")
            }
        }
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
