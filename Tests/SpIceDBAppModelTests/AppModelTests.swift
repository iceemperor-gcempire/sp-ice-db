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

    func testAddAIProviderStoresProfileSelectsNoImageAndMarksUnsavedChanges() throws {
        let ids = DeterministicUUIDGenerator([
            UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        ])
        let model = AppModel(
            hasUnsavedChanges: false,
            idGenerator: ids.next
        )

        let provider = try model.addAIProvider(
            name: " OpenAI Compatible ",
            baseURL: " https://api.example.com/v1 ",
            model: " vision-model ",
            apiKeyRef: " keychain:sp-ice-db/provider "
        )

        XCTAssertEqual(model.workspace.aiProviders, [provider])
        XCTAssertEqual(provider.id, UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!)
        XCTAssertEqual(provider.name, "OpenAI Compatible")
        XCTAssertEqual(provider.baseURL, URL(string: "https://api.example.com/v1")!)
        XCTAssertEqual(provider.model, "vision-model")
        XCTAssertEqual(provider.apiKeyRef, "keychain:sp-ice-db/provider")
        XCTAssertTrue(model.hasUnsavedChanges)
    }

    func testUpdateAIProviderReplacesExistingProfileAndMarksUnsavedChangesOnlyWhenChanged() throws {
        let providerID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let model = AppModel(
            workspace: workspaceWithImages([], aiProviders: [providerProfile(id: providerID)]),
            hasUnsavedChanges: false
        )

        try model.updateAIProvider(
            id: providerID,
            name: " Provider ",
            baseURL: " https://api.example.com/v1 ",
            model: " vision-model ",
            apiKeyRef: nil
        )

        XCTAssertFalse(model.hasUnsavedChanges)

        let updated = try model.updateAIProvider(
            id: providerID,
            name: "Updated",
            baseURL: "https://api.updated.example/v1",
            model: "updated-model",
            apiKeyRef: nil,
            supportsImageInput: false,
            timeoutSeconds: 30
        )

        XCTAssertEqual(model.workspace.aiProviders, [updated])
        XCTAssertEqual(updated.name, "Updated")
        XCTAssertEqual(updated.baseURL, URL(string: "https://api.updated.example/v1")!)
        XCTAssertEqual(updated.model, "updated-model")
        XCTAssertFalse(updated.supportsImageInput)
        XCTAssertEqual(updated.timeoutSeconds, 30)
        XCTAssertTrue(model.hasUnsavedChanges)
    }

    func testRemoveAIProviderDeletesProfileReferenceOnlyAndMarksUnsavedChanges() {
        let providerID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let model = AppModel(
            workspace: workspaceWithImages([], aiProviders: [providerProfile(id: providerID)]),
            hasUnsavedChanges: false
        )

        let removed = model.removeAIProvider(id: providerID)

        XCTAssertEqual(removed?.id, providerID)
        XCTAssertTrue(model.workspace.aiProviders.isEmpty)
        XCTAssertTrue(model.hasUnsavedChanges)
        XCTAssertNil(model.removeAIProvider(id: providerID))
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

    @MainActor
    func testClassifySelectedImageStoresAIClassificationAndMarksUnsavedChanges() async throws {
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let providerID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let generatedAt = Date(timeIntervalSince1970: 1_800_000_500)
        let classifier = StubAIClassificationProvider(
            result: AIClassificationContent(
                sentence: "AI generated caption.",
                tags: ["portrait", "studio"],
                providerId: providerID,
                model: "vision-model",
                generatedAt: generatedAt
            )
        )
        let model = AppModel(
            workspace: workspaceWithImages(
                [imageEntry(id: imageID, filename: "image001.png")],
                aiProviders: [providerProfile(id: providerID)]
            ),
            selectedImageID: imageID,
            hasUnsavedChanges: false,
            imageFileReader: StubImageFileReader(files: [
                "/tmp/source/image001.png": Data([0x89, 0x50, 0x4E, 0x47])
            ]),
            aiClassificationProvider: classifier,
            now: { generatedAt }
        )

        try await model.classifySelectedImage(providerID: providerID)

        XCTAssertEqual(
            model.workspace.images[0].classification.ai,
            AIClassificationContent(
                sentence: "AI generated caption.",
                tags: ["portrait", "studio"],
                providerId: providerID,
                model: "vision-model",
                generatedAt: generatedAt
            )
        )
        XCTAssertEqual(classifier.requests.count, 1)
        XCTAssertEqual(classifier.requests[0].payload.mimeType, "image/png")
        XCTAssertEqual(classifier.requests[0].payload.base64, Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString())
        XCTAssertEqual(classifier.requests[0].provider.id, providerID)
        XCTAssertEqual(classifier.requests[0].generatedAt, generatedAt)
        XCTAssertTrue(model.hasUnsavedChanges)
        XCTAssertFalse(model.isClassifyingSelectedImage)
    }

    @MainActor
    func testClassifySelectedImageDoesNotMarkUnsavedChangesForEquivalentAIClassification() async throws {
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let providerID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let generatedAt = Date(timeIntervalSince1970: 1_800_000_500)
        let classification = AIClassificationContent(
            sentence: "AI generated caption.",
            tags: ["portrait", "studio"],
            providerId: providerID,
            model: "vision-model",
            generatedAt: generatedAt
        )
        let model = AppModel(
            workspace: workspaceWithImages(
                [
                    imageEntry(
                        id: imageID,
                        filename: "image001.png",
                        classification: Classification(ai: classification)
                    )
                ],
                aiProviders: [providerProfile(id: providerID)]
            ),
            selectedImageID: imageID,
            hasUnsavedChanges: false,
            imageFileReader: StubImageFileReader(files: [
                "/tmp/source/image001.png": Data([0x89, 0x50, 0x4E, 0x47])
            ]),
            aiClassificationProvider: StubAIClassificationProvider(result: classification),
            now: { generatedAt }
        )

        try await model.classifySelectedImage(providerID: providerID)

        XCTAssertFalse(model.hasUnsavedChanges)
        XCTAssertFalse(model.isClassifyingSelectedImage)
    }

    @MainActor
    func testClassifySelectedImageRequiresSelectionAndProvider() async {
        let providerID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

        await XCTAssertThrowsErrorAsync(
            try await AppModel().classifySelectedImage(providerID: providerID)
        ) { error in
            XCTAssertEqual(error as? AppModelError, .imageSelectionRequired)
        }

        let model = AppModel(
            workspace: workspaceWithImage(id: imageID),
            selectedImageID: imageID
        )
        await XCTAssertThrowsErrorAsync(
            try await model.classifySelectedImage(providerID: providerID)
        ) { error in
            XCTAssertEqual(error as? AppModelError, .aiProviderNotFound)
        }
    }

    func testPromoteSelectedAIClassificationToUserMarksUnsavedChangesOnlyWhenChanged() throws {
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let model = AppModel(
            workspace: workspaceWithImages([
                imageEntry(
                    id: imageID,
                    filename: "image001.png",
                    classification: Classification(
                        user: ClassificationContent(sentence: "Old.", tags: ["old"]),
                        ai: AIClassificationContent(sentence: "AI caption.", tags: ["ai", "tag"])
                    )
                )
            ]),
            selectedImageID: imageID,
            hasUnsavedChanges: false
        )

        try model.promoteSelectedAIClassificationToUser()

        XCTAssertEqual(
            model.workspace.images[0].classification.user,
            ClassificationContent(sentence: "AI caption.", tags: ["ai", "tag"])
        )
        XCTAssertTrue(model.hasUnsavedChanges)

        model.hasUnsavedChanges = false
        try model.promoteSelectedAIClassificationToUser()

        XCTAssertFalse(model.hasUnsavedChanges)
    }

    @MainActor
    func testClassifySelectedImageSetsRunningStateDuringProviderCall() async throws {
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let providerID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let generatedAt = Date(timeIntervalSince1970: 1_800_000_500)
        let probe = RunningStateProbe()
        let model = AppModel(
            workspace: workspaceWithImages(
                [imageEntry(id: imageID, filename: "image001.png")],
                aiProviders: [providerProfile(id: providerID)]
            ),
            selectedImageID: imageID,
            imageFileReader: StubImageFileReader(files: [
                "/tmp/source/image001.png": Data([0x89, 0x50, 0x4E, 0x47])
            ]),
            aiClassificationProvider: StubAIClassificationProvider(
                result: AIClassificationContent(
                    sentence: "AI generated caption.",
                    tags: ["portrait"],
                    providerId: providerID,
                    model: "vision-model",
                    generatedAt: generatedAt
                ),
                onClassify: { probe.check() }
            ),
            now: { generatedAt }
        )
        probe.check = {
            XCTAssertTrue(model.isClassifyingSelectedImage)
        }

        try await model.classifySelectedImage(providerID: providerID)

        XCTAssertFalse(model.isClassifyingSelectedImage)
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

    func testImageStatusForEntryUsesInjectedProvider() {
        let image = imageEntry(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            filename: "image001.png"
        )
        let model = AppModel(
            workspace: workspaceWithImages([image]),
            imageFileStatusProvider: StubFileStatusProvider(statuses: [
                image.sourcePath: .unreadable
            ])
        )

        XCTAssertEqual(model.imageStatus(for: image), .unreadable)
    }

    func testImageStatusSummaryCountsAllWorkspaceImages() {
        let readable = imageEntry(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            filename: "readable.png"
        )
        let missing = imageEntry(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            filename: "missing.png"
        )
        let unreadable = imageEntry(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            filename: "unreadable.png"
        )
        let model = AppModel(
            workspace: workspaceWithImages([readable, missing, unreadable]),
            imageFileStatusProvider: StubFileStatusProvider(statuses: [
                readable.sourcePath: .readable,
                missing.sourcePath: .missing,
                unreadable.sourcePath: .unreadable
            ])
        )

        XCTAssertEqual(
            model.imageStatusSummary,
            ImageStatusSummary(readable: 1, missing: 1, unreadable: 1)
        )
    }

    func testCollectSelectedImageToWorkingDirectoryCopiesFileRecordsOutputAndMarksUnsavedChanges() throws {
        let directory = try TemporaryDirectory()
        let sourceURL = directory.url.appendingPathComponent("source/image001.png")
        let workingURL = directory.url.appendingPathComponent("generated")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let sourceData = Data([0x89, 0x50, 0x4E, 0x47])
        try sourceData.write(to: sourceURL)
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let outputID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let generatedAt = Date(timeIntervalSince1970: 1_800_000_700)
        let ids = DeterministicUUIDGenerator([outputID])
        let model = AppModel(
            workspace: workspaceWithImages(
                [
                    ImageEntry(
                        id: imageID,
                        sourcePath: sourceURL.path,
                        displayName: "image001.png"
                    )
                ],
                workingDirectory: workingURL.path
            ),
            selectedImageID: imageID,
            hasUnsavedChanges: false,
            idGenerator: ids.next,
            now: { generatedAt }
        )

        let output = try model.collectSelectedImageToWorkingDirectory()

        let expectedURL = workingURL.appendingPathComponent("image001.png")
        XCTAssertEqual(
            output,
            GeneratedOutput(
                id: outputID,
                path: expectedURL.path,
                status: .generated,
                createdAt: generatedAt,
                settingsId: nil
            )
        )
        XCTAssertEqual(model.workspace.images[0].generatedOutputs, [output])
        XCTAssertEqual(try Data(contentsOf: expectedURL), sourceData)
        XCTAssertEqual(try Data(contentsOf: sourceURL), sourceData)
        XCTAssertTrue(model.hasUnsavedChanges)
    }

    func testCollectSelectedImageRequiresSelection() {
        let model = AppModel(hasUnsavedChanges: false)

        XCTAssertThrowsError(
            try model.collectSelectedImageToWorkingDirectory()
        ) { error in
            XCTAssertEqual(error as? AppModelError, .imageSelectionRequired)
        }
        XCTAssertFalse(model.hasUnsavedChanges)
    }

    func testExportDatasetCaptionsWritesSidecarFilesStoresReportAndDoesNotMarkUnsavedChanges() throws {
        let directory = try TemporaryDirectory()
        let outputURL = directory.url.appendingPathComponent("generated/image001.png")
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1]).write(to: outputURL)
        let imageID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let outputID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let model = AppModel(
            workspace: workspaceWithImages([
                ImageEntry(
                    id: imageID,
                    sourcePath: directory.url.appendingPathComponent("source.png").path,
                    displayName: "source.png",
                    classification: Classification(
                        user: ClassificationContent(
                            sentence: "A polished silver spoon.",
                            tags: ["silver spoon", "tabletop"]
                        )
                    ),
                    generatedOutputs: [
                        GeneratedOutput(
                            id: outputID,
                            path: outputURL.path,
                            status: .generated,
                            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                            settingsId: nil
                        )
                    ]
                )
            ]),
            hasUnsavedChanges: false
        )

        let report = try model.exportDatasetCaptions(
            options: DatasetExportOptions(
                metadataSource: .user,
                captionFormat: .tags
            )
        )

        let captionURL = outputURL.deletingPathExtension().appendingPathExtension("txt")
        XCTAssertEqual(report.writtenCaptionPaths, [captionURL.path])
        XCTAssertEqual(model.latestDatasetExportReport, report)
        XCTAssertEqual(try String(contentsOf: captionURL, encoding: .utf8), "silver spoon, tabletop\n")
        XCTAssertFalse(model.hasUnsavedChanges)
    }

    func testNewAndOpenWorkspaceClearLatestDatasetExportReport() throws {
        let directory = try TemporaryDirectory()
        let fileURL = directory.url.appendingPathComponent("dataset.spicedb")
        var document = workspaceWithImage(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!)
        try WorkspaceStore(now: { Date(timeIntervalSince1970: 1_800_000_100) }).save(&document, to: fileURL)
        let model = AppModel()
        model.latestDatasetExportReport = DatasetExportReport(
            issues: [
                .captionMissing(
                    imageID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                    outputID: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
                )
            ]
        )

        model.newWorkspace()

        XCTAssertNil(model.latestDatasetExportReport)

        model.latestDatasetExportReport = DatasetExportReport(writtenCaptionPaths: ["/tmp/image001.txt"])

        try model.openWorkspace(from: fileURL)

        XCTAssertNil(model.latestDatasetExportReport)
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

private func workspaceWithImages(
    _ images: [ImageEntry],
    aiProviders: [AIProviderProfile] = [],
    workingDirectory: String? = nil
) -> WorkspaceDocument {
    WorkspaceDocument(
        workspace: WorkspaceInfo(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Dataset",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            workingDirectory: workingDirectory
        ),
        aiProviders: aiProviders,
        images: images
    )
}

private func providerProfile(id: UUID) -> AIProviderProfile {
    AIProviderProfile(
        id: id,
        name: "Provider",
        baseURL: URL(string: "https://api.example.com/v1")!,
        model: "vision-model",
        apiKeyRef: nil,
        supportsImageInput: true,
        timeoutSeconds: 60
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

private struct StubImageFileReader: ImageFileReading {
    var files: [String: Data]

    func readData(atPath path: String) throws -> Data {
        guard let data = files[path] else {
            throw ImagePayloadReaderError.fileMissing
        }
        return data
    }
}

private final class StubAIClassificationProvider: AIClassificationProviding, @unchecked Sendable {
    struct Request: Equatable {
        var payload: ImagePayload
        var provider: AIProviderProfile
        var generatedAt: Date?
    }

    private let result: AIClassificationContent
    private let onClassify: @Sendable () -> Void
    private(set) var requests: [Request] = []

    init(result: AIClassificationContent, onClassify: @escaping @Sendable () -> Void = {}) {
        self.result = result
        self.onClassify = onClassify
    }

    func classify(
        payload: ImagePayload,
        provider: AIProviderProfile,
        generatedAt: Date?
    ) async throws -> AIClassificationContent {
        onClassify()
        requests.append(Request(payload: payload, provider: provider, generatedAt: generatedAt))
        return result
    }
}

private final class RunningStateProbe: @unchecked Sendable {
    var check: () -> Void = {}
}

@MainActor
private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        errorHandler(error)
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
