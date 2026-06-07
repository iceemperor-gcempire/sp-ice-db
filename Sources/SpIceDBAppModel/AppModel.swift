import Foundation
import Observation
import SpIceDBCore

@Observable
public final class AppModel {
    public var workspace: WorkspaceDocument
    public var selectedImageID: UUID?
    public var workspaceURL: URL?
    public var hasUnsavedChanges: Bool
    public var isClassifyingSelectedImage: Bool
    public var isGeneratingSelectedImage: Bool
    public var latestDatasetExportReport: DatasetExportReport?

    private let imageLibrary: ImageLibrary
    private let imagePayloadReader: ImagePayloadReader
    private let classificationLibrary: ClassificationLibrary
    private let aiProviderLibrary: AIProviderLibrary
    private let generationSettingsLibrary: GenerationSettingsLibrary
    private let aiClassificationProvider: any AIClassificationProviding
    private let generatedImageWorkspace: GeneratedImageWorkspace
    private let imageGenerationRunner: ImageGenerationRunner
    private let imageGenerationProviderFactory: (AIProviderProfile) -> any ImageGenerationProviding
    private let datasetExporter: DatasetExporter
    private let workspaceStore: WorkspaceStore
    private let idGenerator: () -> UUID
    private let now: () -> Date

    public init(
        workspace: WorkspaceDocument = WorkspaceDocument.new(name: "Untitled"),
        selectedImageID: UUID? = nil,
        workspaceURL: URL? = nil,
        hasUnsavedChanges: Bool = false,
        isClassifyingSelectedImage: Bool = false,
        isGeneratingSelectedImage: Bool = false,
        idGenerator: @escaping () -> UUID = UUID.init,
        imageFileStatusProvider: ImageFileStatusProviding = FileManagerImageFileStatusProvider(),
        imageFileReader: ImageFileReading = FileManagerImageFileReader(),
        aiClassificationProvider: any AIClassificationProviding = OpenAICompatibleAIClassificationProvider(),
        imageGenerationProvider: any ImageGenerationProviding = UnavailableImageGenerationProvider(),
        imageGenerationProviderFactory: @escaping (AIProviderProfile) -> any ImageGenerationProviding = { provider in
            OpenAICompatibleImageGenerationProvider(
                provider: provider,
                client: OpenAICompatibleImageGenerationClient(
                    apiKeyResolver: EnvironmentAPIKeyResolver(),
                    transport: URLSessionHTTPTransport()
                )
            )
        },
        now: @escaping () -> Date = Date.init
    ) {
        self.workspace = workspace
        self.selectedImageID = selectedImageID
        self.workspaceURL = workspaceURL
        self.hasUnsavedChanges = hasUnsavedChanges
        self.isClassifyingSelectedImage = isClassifyingSelectedImage
        self.isGeneratingSelectedImage = isGeneratingSelectedImage
        self.imageLibrary = ImageLibrary(
            idGenerator: idGenerator,
            fileStatusProvider: imageFileStatusProvider
        )
        self.imagePayloadReader = ImagePayloadReader(fileReader: imageFileReader)
        self.classificationLibrary = ClassificationLibrary()
        self.aiProviderLibrary = AIProviderLibrary(idGenerator: idGenerator)
        self.generationSettingsLibrary = GenerationSettingsLibrary(idGenerator: idGenerator)
        self.aiClassificationProvider = aiClassificationProvider
        self.generatedImageWorkspace = GeneratedImageWorkspace(idGenerator: idGenerator, now: now)
        self.imageGenerationRunner = ImageGenerationRunner(
            provider: imageGenerationProvider,
            idGenerator: idGenerator,
            now: now
        )
        self.imageGenerationProviderFactory = imageGenerationProviderFactory
        self.datasetExporter = DatasetExporter()
        self.workspaceStore = WorkspaceStore(now: now)
        self.idGenerator = idGenerator
        self.now = now
    }

    public var selectedImage: ImageEntry? {
        guard let selectedImageID else {
            return nil
        }

        return workspace.images.first(where: { $0.id == selectedImageID })
    }

    public var selectedImageStatus: ImageFileStatus? {
        guard let selectedImage else {
            return nil
        }

        return imageStatus(for: selectedImage)
    }

    public var imageStatusSummary: ImageStatusSummary {
        workspace.images.reduce(into: ImageStatusSummary()) { summary, image in
            switch imageStatus(for: image) {
            case .readable:
                summary.readable += 1
            case .missing:
                summary.missing += 1
            case .unreadable:
                summary.unreadable += 1
            }
        }
    }

    public func imageStatus(for image: ImageEntry) -> ImageFileStatus {
        imageLibrary.status(for: image)
    }

    public func newWorkspace(named name: String = "Untitled") {
        workspace = WorkspaceDocument.new(name: name, now: now())
        selectedImageID = nil
        workspaceURL = nil
        hasUnsavedChanges = false
        isClassifyingSelectedImage = false
        isGeneratingSelectedImage = false
        latestDatasetExportReport = nil
    }

    public func updateWorkspaceName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName != workspace.workspace.name else {
            return
        }

        workspace.workspace.name = trimmedName
        hasUnsavedChanges = true
    }

    public func setWorkingDirectory(_ path: String?) {
        let trimmedPath = path?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let workingDirectory = trimmedPath.isEmpty ? nil : trimmedPath
        guard workingDirectory != workspace.workspace.workingDirectory else {
            return
        }

        workspace.workspace.workingDirectory = workingDirectory
        hasUnsavedChanges = true
    }

    @discardableResult
    public func addAIProvider(
        name: String,
        baseURL: String,
        model: String,
        apiKeyRef: String?,
        supportsImageInput: Bool = true,
        timeoutSeconds: TimeInterval = 60,
        customHeaders: [String: String] = [:]
    ) throws -> AIProviderProfile {
        let provider = try aiProviderLibrary.addProvider(
            name: name,
            baseURL: baseURL,
            model: model,
            apiKeyRef: apiKeyRef,
            supportsImageInput: supportsImageInput,
            timeoutSeconds: timeoutSeconds,
            customHeaders: customHeaders,
            to: &workspace
        )
        hasUnsavedChanges = true
        return provider
    }

    @discardableResult
    public func updateAIProvider(
        id: UUID,
        name: String,
        baseURL: String,
        model: String,
        apiKeyRef: String?,
        supportsImageInput: Bool = true,
        timeoutSeconds: TimeInterval = 60,
        customHeaders: [String: String] = [:]
    ) throws -> AIProviderProfile {
        let previous = workspace.aiProviders.first(where: { $0.id == id })
        let provider = try aiProviderLibrary.updateProvider(
            id: id,
            name: name,
            baseURL: baseURL,
            model: model,
            apiKeyRef: apiKeyRef,
            supportsImageInput: supportsImageInput,
            timeoutSeconds: timeoutSeconds,
            customHeaders: customHeaders,
            in: &workspace
        )
        if previous != provider {
            hasUnsavedChanges = true
        }
        return provider
    }

    @discardableResult
    public func removeAIProvider(id: UUID) -> AIProviderProfile? {
        guard let removed = aiProviderLibrary.removeProvider(id: id, from: &workspace) else {
            return nil
        }

        hasUnsavedChanges = true
        return removed
    }

    @discardableResult
    public func addGenerationSettings(
        name: String,
        providerId: UUID?,
        parameters: [String: JSONValue]
    ) throws -> GenerationSettings {
        let settings = try generationSettingsLibrary.addSettings(
            name: name,
            providerId: providerId,
            parameters: parameters,
            to: &workspace
        )
        hasUnsavedChanges = true
        return settings
    }

    @discardableResult
    public func updateGenerationSettings(
        id: UUID,
        name: String,
        providerId: UUID?,
        parameters: [String: JSONValue]
    ) throws -> GenerationSettings {
        let previous = workspace.generationSettings.first(where: { $0.id == id })
        let settings = try generationSettingsLibrary.updateSettings(
            id: id,
            name: name,
            providerId: providerId,
            parameters: parameters,
            in: &workspace
        )
        if previous != settings {
            hasUnsavedChanges = true
        }
        return settings
    }

    @discardableResult
    public func removeGenerationSettings(id: UUID) -> GenerationSettings? {
        guard let removed = generationSettingsLibrary.removeSettings(id: id, from: &workspace) else {
            return nil
        }

        hasUnsavedChanges = true
        return removed
    }

    @discardableResult
    public func addImage(path: String) throws -> ImageEntry {
        let imageCount = workspace.images.count
        let entry = try imageLibrary.addImage(path: path, to: &workspace)
        selectedImageID = entry.id
        if workspace.images.count != imageCount {
            hasUnsavedChanges = true
        }
        return entry
    }

    @discardableResult
    public func addImages(paths: [String]) throws -> [ImageEntry] {
        var entries: [ImageEntry] = []

        for path in paths {
            entries.append(try addImage(path: path))
        }

        return entries
    }

    @discardableResult
    public func removeSelectedImage() -> ImageEntry? {
        guard let selectedImageID else {
            return nil
        }

        guard let removed = imageLibrary.removeImage(id: selectedImageID, from: &workspace) else {
            return nil
        }

        self.selectedImageID = workspace.images.first?.id
        hasUnsavedChanges = true
        return removed
    }

    public func updateSelectedUserSentence(_ sentence: String) throws {
        let imageID = try requireSelectedImageID()
        let previous = selectedImage?.classification.user
        try classificationLibrary.updateUserSentence(sentence, forImageID: imageID, in: &workspace)
        if selectedImage?.classification.user != previous {
            hasUnsavedChanges = true
        }
    }

    public func updateSelectedUserTags(_ tags: String) throws {
        let imageID = try requireSelectedImageID()
        let previous = selectedImage?.classification.user
        try classificationLibrary.updateUserTags(tags, forImageID: imageID, in: &workspace)
        if selectedImage?.classification.user != previous {
            hasUnsavedChanges = true
        }
    }

    public func updateSelectedImageNotes(_ notes: String) throws {
        let imageID = try requireSelectedImageID()
        guard let index = workspace.images.firstIndex(where: { $0.id == imageID }) else {
            throw AppModelError.imageSelectionRequired
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard workspace.images[index].notes != trimmedNotes else {
            return
        }

        workspace.images[index].notes = trimmedNotes
        hasUnsavedChanges = true
    }

    @MainActor
    public func classifySelectedImage(providerID: UUID) async throws {
        let imageID = try requireSelectedImageID()
        guard let provider = workspace.aiProviders.first(where: { $0.id == providerID }) else {
            throw AppModelError.aiProviderNotFound
        }
        guard let imageIndex = workspace.images.firstIndex(where: { $0.id == imageID }) else {
            throw AppModelError.imageSelectionRequired
        }

        let payload = try imagePayloadReader.payload(for: workspace.images[imageIndex])
        let generatedAt = now()
        isClassifyingSelectedImage = true
        defer {
            isClassifyingSelectedImage = false
        }
        let classification = try await aiClassificationProvider.classify(
            payload: payload,
            provider: provider,
            generatedAt: generatedAt
        )
        let previous = workspace.images[imageIndex].classification.ai

        workspace.images[imageIndex].classification.ai = classification
        if previous != classification {
            hasUnsavedChanges = true
        }
    }

    @MainActor
    public func classifyAllImages(providerID: UUID) async throws {
        guard let provider = workspace.aiProviders.first(where: { $0.id == providerID }) else {
            throw AppModelError.aiProviderNotFound
        }

        isClassifyingSelectedImage = true
        defer {
            isClassifyingSelectedImage = false
        }

        var changed = false
        for imageIndex in workspace.images.indices {
            let payload = try imagePayloadReader.payload(for: workspace.images[imageIndex])
            let generatedAt = now()
            let classification = try await aiClassificationProvider.classify(
                payload: payload,
                provider: provider,
                generatedAt: generatedAt
            )

            if workspace.images[imageIndex].classification.ai != classification {
                workspace.images[imageIndex].classification.ai = classification
                changed = true
            }
        }

        if changed {
            hasUnsavedChanges = true
        }
    }

    public func promoteSelectedAIClassificationToUser() throws {
        let imageID = try requireSelectedImageID()
        let previous = selectedImage?.classification.user
        try classificationLibrary.promoteAIClassificationToUser(forImageID: imageID, in: &workspace)
        if selectedImage?.classification.user != previous {
            hasUnsavedChanges = true
        }
    }

    @discardableResult
    public func collectSelectedImageToWorkingDirectory() throws -> GeneratedOutput {
        let imageID = try requireSelectedImageID()
        let output = try generatedImageWorkspace.collectSourceImage(
            imageID: imageID,
            in: &workspace
        )
        hasUnsavedChanges = true
        return output
    }

    @MainActor
    @discardableResult
    public func generateSelectedImage(
        providerID: UUID? = nil,
        settingsID: UUID? = nil
    ) async throws -> GeneratedOutput {
        let imageID = try requireSelectedImageID()
        isGeneratingSelectedImage = true
        defer {
            isGeneratingSelectedImage = false
        }
        var document = workspace
        let runner = try imageGenerationRunner(for: providerID)
        let output = try await runner.generateImage(
            imageID: imageID,
            settingsID: settingsID,
            in: &document
        )
        workspace = document
        hasUnsavedChanges = true
        return output
    }

    @MainActor
    @discardableResult
    public func generateAllImages(
        providerID: UUID? = nil,
        settingsID: UUID? = nil
    ) async throws -> [GeneratedOutput] {
        let imageIDs = workspace.images.map(\.id)
        let runner = try imageGenerationRunner(for: providerID)
        isGeneratingSelectedImage = true
        defer {
            isGeneratingSelectedImage = false
        }

        var document = workspace
        var outputs: [GeneratedOutput] = []
        for imageID in imageIDs {
            let output = try await runner.generateImage(
                imageID: imageID,
                settingsID: settingsID,
                in: &document
            )
            outputs.append(output)
        }

        workspace = document
        if !outputs.isEmpty {
            hasUnsavedChanges = true
        }
        return outputs
    }

    private func imageGenerationRunner(for providerID: UUID?) throws -> ImageGenerationRunner {
        guard let providerID else {
            return imageGenerationRunner
        }

        guard let provider = workspace.aiProviders.first(where: { $0.id == providerID }) else {
            throw AppModelError.aiProviderNotFound
        }

        return ImageGenerationRunner(
            provider: imageGenerationProviderFactory(provider),
            idGenerator: idGenerator,
            now: now
        )
    }

    @discardableResult
    public func exportDatasetCaptions(options: DatasetExportOptions) throws -> DatasetExportReport {
        let report = try datasetExporter.exportCaptions(from: workspace, options: options)
        latestDatasetExportReport = report
        return report
    }

    public func openWorkspace(from url: URL) throws {
        workspace = try workspaceStore.load(from: url)
        workspaceURL = url
        selectedImageID = workspace.images.first?.id
        hasUnsavedChanges = false
        isGeneratingSelectedImage = false
        latestDatasetExportReport = nil
    }

    public func saveWorkspace(to url: URL? = nil) throws {
        let targetURL = try url ?? requireWorkspaceURL()
        try workspaceStore.save(&workspace, to: targetURL)
        workspaceURL = targetURL
        hasUnsavedChanges = false
    }

    private func requireSelectedImageID() throws -> UUID {
        guard let selectedImageID else {
            throw AppModelError.imageSelectionRequired
        }

        return selectedImageID
    }

    private func requireWorkspaceURL() throws -> URL {
        guard let workspaceURL else {
            throw AppModelError.workspaceURLRequired
        }

        return workspaceURL
    }
}

public enum AppModelError: Error, Equatable {
    case imageSelectionRequired
    case workspaceURLRequired
    case aiProviderNotFound
    case aiClassificationProviderUnavailable
    case imageGenerationProviderUnavailable
}

public struct ImageStatusSummary: Equatable {
    public var readable: Int
    public var missing: Int
    public var unreadable: Int

    public init(readable: Int = 0, missing: Int = 0, unreadable: Int = 0) {
        self.readable = readable
        self.missing = missing
        self.unreadable = unreadable
    }
}

public protocol AIClassificationProviding: Sendable {
    func classify(
        payload: ImagePayload,
        provider: AIProviderProfile,
        generatedAt: Date?
    ) async throws -> AIClassificationContent
}

public struct UnavailableAIClassificationProvider: AIClassificationProviding {
    public init() {}

    public func classify(
        payload: ImagePayload,
        provider: AIProviderProfile,
        generatedAt: Date?
    ) async throws -> AIClassificationContent {
        throw AppModelError.aiClassificationProviderUnavailable
    }
}

public struct UnavailableImageGenerationProvider: ImageGenerationProviding {
    public init() {}

    public func generateImage(request: ImageGenerationRequest) async throws -> GeneratedImageAsset {
        throw AppModelError.imageGenerationProviderUnavailable
    }
}

public struct OpenAICompatibleAIClassificationProvider: AIClassificationProviding, @unchecked Sendable {
    private let client: OpenAICompatibleClassificationClient

    public init(
        apiKeyResolver: APIKeyResolving = EnvironmentAPIKeyResolver(),
        transport: HTTPTransport = URLSessionHTTPTransport()
    ) {
        self.client = OpenAICompatibleClassificationClient(
            apiKeyResolver: apiKeyResolver,
            transport: transport
        )
    }

    public func classify(
        payload: ImagePayload,
        provider: AIProviderProfile,
        generatedAt: Date?
    ) async throws -> AIClassificationContent {
        try await client.classify(
            payload: payload,
            provider: provider,
            generatedAt: generatedAt
        )
    }
}
