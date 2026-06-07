import XCTest
@testable import SpIceDBCore

final class DatasetExporterTests: XCTestCase {
    func testExportsSentenceCaptionsForGeneratedOutputsUsingUserMetadata() throws {
        let directory = try DatasetExportTemporaryDirectory()
        let outputURL = directory.url.appendingPathComponent("generated/image001.png")
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1]).write(to: outputURL)
        let document = workspaceWithGeneratedOutput(
            outputPath: outputURL.path,
            user: ClassificationContent(
                sentence: "A bright glass bottle on a table.",
                tags: ["glass bottle", "table"]
            )
        )
        let exporter = DatasetExporter()

        let report = try exporter.exportCaptions(
            from: document,
            options: DatasetExportOptions(
                metadataSource: .user,
                captionFormat: .sentence
            )
        )

        let captionURL = outputURL.deletingPathExtension().appendingPathExtension("txt")
        XCTAssertEqual(report.writtenCaptionPaths, [captionURL.path])
        XCTAssertEqual(report.issues, [])
        XCTAssertEqual(
            try String(contentsOf: captionURL, encoding: .utf8),
            "A bright glass bottle on a table.\n"
        )
    }

    func testExportsTagCaptionsUsingAIWhenUserMetadataIsMissing() throws {
        let directory = try DatasetExportTemporaryDirectory()
        let outputURL = directory.url.appendingPathComponent("generated/image001.png")
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1]).write(to: outputURL)
        let document = workspaceWithGeneratedOutput(
            outputPath: outputURL.path,
            user: ClassificationContent(),
            ai: AIClassificationContent(
                sentence: "AI sentence.",
                tags: ["ice cream", "silver spoon"]
            )
        )
        let exporter = DatasetExporter()

        let report = try exporter.exportCaptions(
            from: document,
            options: DatasetExportOptions(
                metadataSource: .userWithAIFallback,
                captionFormat: .tags
            )
        )

        let captionURL = outputURL.deletingPathExtension().appendingPathExtension("txt")
        XCTAssertEqual(report.writtenCaptionPaths, [captionURL.path])
        XCTAssertEqual(report.issues, [])
        XCTAssertEqual(
            try String(contentsOf: captionURL, encoding: .utf8),
            "ice cream, silver spoon\n"
        )
    }

    func testReportsMissingFilesAndEmptyCaptionsWithoutWritingCaptions() throws {
        let directory = try DatasetExportTemporaryDirectory()
        let missingURL = directory.url.appendingPathComponent("generated/missing.png")
        let emptyCaptionURL = directory.url.appendingPathComponent("generated/empty.png")
        try FileManager.default.createDirectory(at: emptyCaptionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1]).write(to: emptyCaptionURL)
        let imageWithMissingFileID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let missingOutputID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let imageWithEmptyCaptionID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let emptyCaptionOutputID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let document = WorkspaceDocument(
            workspace: workspaceInfo(),
            images: [
                ImageEntry(
                    id: imageWithMissingFileID,
                    sourcePath: directory.url.appendingPathComponent("source1.png").path,
                    displayName: "source1.png",
                    classification: Classification(
                        user: ClassificationContent(sentence: "Missing file caption.")
                    ),
                    generatedOutputs: [
                        GeneratedOutput(
                            id: missingOutputID,
                            path: missingURL.path,
                            status: .generated,
                            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                            settingsId: nil
                        )
                    ]
                ),
                ImageEntry(
                    id: imageWithEmptyCaptionID,
                    sourcePath: directory.url.appendingPathComponent("source2.png").path,
                    displayName: "source2.png",
                    generatedOutputs: [
                        GeneratedOutput(
                            id: emptyCaptionOutputID,
                            path: emptyCaptionURL.path,
                            status: .generated,
                            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                            settingsId: nil
                        )
                    ]
                )
            ]
        )
        let exporter = DatasetExporter()

        let report = try exporter.exportCaptions(
            from: document,
            options: DatasetExportOptions(
                metadataSource: .user,
                captionFormat: .sentence
            )
        )

        XCTAssertEqual(report.writtenCaptionPaths, [])
        XCTAssertEqual(
            report.issues,
            [
                DatasetExportIssue.generatedFileMissing(
                    imageID: imageWithMissingFileID,
                    outputID: missingOutputID,
                    path: missingURL.path
                ),
                DatasetExportIssue.captionMissing(
                    imageID: imageWithEmptyCaptionID,
                    outputID: emptyCaptionOutputID
                )
            ]
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: emptyCaptionURL.deletingPathExtension().appendingPathExtension("txt").path
            )
        )
    }

    func testSkipsNonGeneratedOutputs() throws {
        let directory = try DatasetExportTemporaryDirectory()
        let pendingURL = directory.url.appendingPathComponent("generated/pending.png")
        let document = WorkspaceDocument(
            workspace: workspaceInfo(),
            images: [
                ImageEntry(
                    id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                    sourcePath: directory.url.appendingPathComponent("source.png").path,
                    displayName: "source.png",
                    classification: Classification(
                        user: ClassificationContent(sentence: "Pending caption.")
                    ),
                    generatedOutputs: [
                        GeneratedOutput(
                            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                            path: pendingURL.path,
                            status: .pending,
                            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                            settingsId: nil
                        )
                    ]
                )
            ]
        )
        let exporter = DatasetExporter()

        let report = try exporter.exportCaptions(
            from: document,
            options: DatasetExportOptions(
                metadataSource: .user,
                captionFormat: .sentence
            )
        )

        XCTAssertEqual(report.writtenCaptionPaths, [])
        XCTAssertEqual(report.issues, [])
    }
}

private func workspaceWithGeneratedOutput(
    outputPath: String,
    user: ClassificationContent,
    ai: AIClassificationContent? = nil
) -> WorkspaceDocument {
    WorkspaceDocument(
        workspace: workspaceInfo(),
        images: [
            ImageEntry(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                sourcePath: URL(fileURLWithPath: outputPath).deletingLastPathComponent().appendingPathComponent("source.png").path,
                displayName: "source.png",
                classification: Classification(user: user, ai: ai),
                generatedOutputs: [
                    GeneratedOutput(
                        id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                        path: outputPath,
                        status: .generated,
                        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                        settingsId: nil
                    )
                ]
            )
        ]
    )
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

private final class DatasetExportTemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sp-ice-db-dataset-export-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
