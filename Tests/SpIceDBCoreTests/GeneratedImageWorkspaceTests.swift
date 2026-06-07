import XCTest
@testable import SpIceDBCore

final class GeneratedImageWorkspaceTests: XCTestCase {
    func testCollectsSourceImageIntoWorkingDirectoryAndRecordsGeneratedOutput() throws {
        let directory = try GeneratedImageTemporaryDirectory()
        let sourceURL = directory.url.appendingPathComponent("source/image001.png")
        let workingURL = directory.url.appendingPathComponent("generated")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let sourceData = Data([0x89, 0x50, 0x4E, 0x47])
        try sourceData.write(to: sourceURL)
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let outputID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        var document = workspaceWithImage(
            id: imageID,
            sourcePath: sourceURL.path,
            workingDirectory: workingURL.path
        )
        let workspace = GeneratedImageWorkspace(
            idGenerator: { outputID },
            now: { createdAt }
        )

        let output = try workspace.collectSourceImage(
            imageID: imageID,
            in: &document
        )

        let expectedURL = workingURL.appendingPathComponent("image001.png")
        XCTAssertEqual(
            output,
            GeneratedOutput(
                id: outputID,
                path: expectedURL.path,
                status: .generated,
                createdAt: createdAt,
                settingsId: nil
            )
        )
        XCTAssertEqual(document.images[0].generatedOutputs, [output])
        XCTAssertEqual(try Data(contentsOf: expectedURL), sourceData)
        XCTAssertEqual(try Data(contentsOf: sourceURL), sourceData)
        let updatedAttributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        XCTAssertEqual(
            originalAttributes[FileAttributeKey.modificationDate] as? Date,
            updatedAttributes[FileAttributeKey.modificationDate] as? Date
        )
    }

    func testCollectsSourceImageWithUniqueNameWhenTargetExists() throws {
        let directory = try GeneratedImageTemporaryDirectory()
        let sourceURL = directory.url.appendingPathComponent("source/image001.png")
        let workingURL = directory.url.appendingPathComponent("generated")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workingURL, withIntermediateDirectories: true)
        try Data([1]).write(to: sourceURL)
        try Data([2]).write(to: workingURL.appendingPathComponent("image001.png"))
        var document = workspaceWithImage(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            sourcePath: sourceURL.path,
            workingDirectory: workingURL.path
        )
        let workspace = GeneratedImageWorkspace(
            idGenerator: { UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")! },
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )

        let output = try workspace.collectSourceImage(
            imageID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            in: &document
        )

        XCTAssertEqual(output.path, workingURL.appendingPathComponent("image001_001.png").path)
        XCTAssertEqual(try Data(contentsOf: workingURL.appendingPathComponent("image001.png")), Data([2]))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: output.path)), Data([1]))
    }

    func testCollectSourceImageValidatesWorkspaceImageAndSource() throws {
        let directory = try GeneratedImageTemporaryDirectory()
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        var missingWorkingDirectory = workspaceWithImage(
            id: imageID,
            sourcePath: directory.url.appendingPathComponent("source.png").path,
            workingDirectory: nil
        )
        let workspace = GeneratedImageWorkspace()

        XCTAssertThrowsError(
            try workspace.collectSourceImage(imageID: imageID, in: &missingWorkingDirectory)
        ) { error in
            XCTAssertEqual(error as? GeneratedImageWorkspaceError, .workingDirectoryMissing)
        }

        var missingImage = WorkspaceDocument.new(name: "Dataset")
        missingImage.workspace.workingDirectory = directory.url.path
        XCTAssertThrowsError(
            try workspace.collectSourceImage(imageID: imageID, in: &missingImage)
        ) { error in
            XCTAssertEqual(error as? GeneratedImageWorkspaceError, .imageNotFound)
        }

        var missingSource = workspaceWithImage(
            id: imageID,
            sourcePath: directory.url.appendingPathComponent("missing.png").path,
            workingDirectory: directory.url.appendingPathComponent("generated").path
        )
        XCTAssertThrowsError(
            try workspace.collectSourceImage(imageID: imageID, in: &missingSource)
        ) { error in
            XCTAssertEqual(error as? GeneratedImageWorkspaceError, .sourceFileMissing)
        }
    }
}

private func workspaceWithImage(
    id: UUID,
    sourcePath: String,
    workingDirectory: String?
) -> WorkspaceDocument {
    WorkspaceDocument(
        workspace: WorkspaceInfo(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Dataset",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            workingDirectory: workingDirectory
        ),
        images: [
            ImageEntry(
                id: id,
                sourcePath: sourcePath,
                displayName: URL(fileURLWithPath: sourcePath).lastPathComponent
            )
        ]
    )
}

private final class GeneratedImageTemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sp-ice-db-generated-image-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
