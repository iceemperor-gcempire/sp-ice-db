import XCTest
@testable import SpIceDBCore

@MainActor
final class ImageGenerationRunnerTests: XCTestCase {
    func testGeneratesImageIntoWorkingDirectoryAndRecordsOutput() async throws {
        let directory = try ImageGenerationTemporaryDirectory()
        let sourceURL = directory.url.appendingPathComponent("source/image001.png")
        let workingURL = directory.url.appendingPathComponent("generated")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: sourceURL)
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let outputID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let settingsID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let createdAt = Date(timeIntervalSince1970: 1_800_001_000)
        var document = imageGenerationWorkspace(
            imageID: imageID,
            sourcePath: sourceURL.path,
            workingDirectory: workingURL.path,
            settings: [
                GenerationSettings(
                    id: settingsID,
                    name: "Default",
                    providerId: nil
                )
            ]
        )
        let provider = StubImageGenerationProvider(
            asset: GeneratedImageAsset(
                data: Data([9, 8, 7]),
                suggestedFilename: "image001_variant.png"
            )
        )
        let runner = ImageGenerationRunner(
            provider: provider,
            idGenerator: { outputID },
            now: { createdAt }
        )

        let output = try await runner.generateImage(
            imageID: imageID,
            settingsID: settingsID,
            in: &document
        )

        let expectedURL = workingURL.appendingPathComponent("image001_variant.png")
        XCTAssertEqual(
            output,
            GeneratedOutput(
                id: outputID,
                path: expectedURL.path,
                status: .generated,
                createdAt: createdAt,
                settingsId: settingsID
            )
        )
        XCTAssertEqual(document.images[0].generatedOutputs, [output])
        XCTAssertEqual(try Data(contentsOf: expectedURL), Data([9, 8, 7]))
        XCTAssertEqual(provider.requests.map(\.sourcePath), [sourceURL.path])
        XCTAssertEqual(provider.requests.map(\.settings?.id), [settingsID])
    }

    func testGeneratesUniqueFilenameWhenSuggestedNameExists() async throws {
        let directory = try ImageGenerationTemporaryDirectory()
        let sourceURL = directory.url.appendingPathComponent("source/image001.png")
        let workingURL = directory.url.appendingPathComponent("generated")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workingURL, withIntermediateDirectories: true)
        try Data([1]).write(to: sourceURL)
        try Data([2]).write(to: workingURL.appendingPathComponent("variant.png"))
        var document = imageGenerationWorkspace(
            imageID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            sourcePath: sourceURL.path,
            workingDirectory: workingURL.path
        )
        let provider = StubImageGenerationProvider(
            asset: GeneratedImageAsset(data: Data([3]), suggestedFilename: "variant.png")
        )
        let runner = ImageGenerationRunner(
            provider: provider,
            idGenerator: { UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")! },
            now: { Date(timeIntervalSince1970: 1_800_001_000) }
        )

        let output = try await runner.generateImage(
            imageID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            in: &document
        )

        XCTAssertEqual(output.path, workingURL.appendingPathComponent("variant_001.png").path)
        XCTAssertEqual(try Data(contentsOf: workingURL.appendingPathComponent("variant.png")), Data([2]))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: output.path)), Data([3]))
    }

    func testGenerationValidatesWorkspaceSourceAndProviderResult() async throws {
        let directory = try ImageGenerationTemporaryDirectory()
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let runner = ImageGenerationRunner(
            provider: StubImageGenerationProvider(
                asset: GeneratedImageAsset(data: Data([1]), suggestedFilename: "out.png")
            )
        )
        var missingWorkingDirectory = imageGenerationWorkspace(
            imageID: imageID,
            sourcePath: directory.url.appendingPathComponent("source.png").path,
            workingDirectory: nil
        )

        do {
            _ = try await runner.generateImage(imageID: imageID, in: &missingWorkingDirectory)
            XCTFail("Expected working directory validation to fail.")
        } catch {
            XCTAssertEqual(error as? ImageGenerationRunnerError, .workingDirectoryMissing)
        }

        var missingImage = WorkspaceDocument.new(name: "Dataset")
        missingImage.workspace.workingDirectory = directory.url.path
        do {
            _ = try await runner.generateImage(imageID: imageID, in: &missingImage)
            XCTFail("Expected image validation to fail.")
        } catch {
            XCTAssertEqual(error as? ImageGenerationRunnerError, .imageNotFound)
        }

        var missingSource = imageGenerationWorkspace(
            imageID: imageID,
            sourcePath: directory.url.appendingPathComponent("missing.png").path,
            workingDirectory: directory.url.path
        )
        do {
            _ = try await runner.generateImage(imageID: imageID, in: &missingSource)
            XCTFail("Expected source validation to fail.")
        } catch {
            XCTAssertEqual(error as? ImageGenerationRunnerError, .sourceFileMissing)
        }

        let sourceURL = directory.url.appendingPathComponent("source.png")
        try Data([1]).write(to: sourceURL)
        var emptyGeneratedData = imageGenerationWorkspace(
            imageID: imageID,
            sourcePath: sourceURL.path,
            workingDirectory: directory.url.path
        )
        let emptyRunner = ImageGenerationRunner(
            provider: StubImageGenerationProvider(
                asset: GeneratedImageAsset(data: Data(), suggestedFilename: "out.png")
            )
        )

        do {
            _ = try await emptyRunner.generateImage(imageID: imageID, in: &emptyGeneratedData)
            XCTFail("Expected empty generated data validation to fail.")
        } catch {
            XCTAssertEqual(error as? ImageGenerationRunnerError, .generatedDataEmpty)
        }
    }
}

private final class StubImageGenerationProvider: ImageGenerationProviding, @unchecked Sendable {
    private let asset: GeneratedImageAsset
    private(set) var requests: [ImageGenerationRequest] = []

    init(asset: GeneratedImageAsset) {
        self.asset = asset
    }

    func generateImage(request: ImageGenerationRequest) async throws -> GeneratedImageAsset {
        requests.append(request)
        return asset
    }
}

private func imageGenerationWorkspace(
    imageID: UUID,
    sourcePath: String,
    workingDirectory: String?,
    settings: [GenerationSettings] = []
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
                id: imageID,
                sourcePath: sourcePath,
                displayName: URL(fileURLWithPath: sourcePath).lastPathComponent
            )
        ],
        generationSettings: settings
    )
}

private final class ImageGenerationTemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sp-ice-db-image-generation-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
