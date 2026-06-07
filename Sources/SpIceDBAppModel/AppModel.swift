import Foundation
import Observation
import SpIceDBCore

@Observable
public final class AppModel {
    public var workspace: WorkspaceDocument
    public var selectedImageID: UUID?
    public var workspaceURL: URL?
    public var hasUnsavedChanges: Bool

    private let imageLibrary: ImageLibrary
    private let imagePayloadReader: ImagePayloadReader
    private let classificationLibrary: ClassificationLibrary
    private let aiClassificationProvider: any AIClassificationProviding
    private let workspaceStore: WorkspaceStore
    private let now: () -> Date

    public init(
        workspace: WorkspaceDocument = WorkspaceDocument.new(name: "Untitled"),
        selectedImageID: UUID? = nil,
        workspaceURL: URL? = nil,
        hasUnsavedChanges: Bool = false,
        idGenerator: @escaping () -> UUID = UUID.init,
        imageFileStatusProvider: ImageFileStatusProviding = FileManagerImageFileStatusProvider(),
        imageFileReader: ImageFileReading = FileManagerImageFileReader(),
        aiClassificationProvider: any AIClassificationProviding = UnavailableAIClassificationProvider(),
        now: @escaping () -> Date = Date.init
    ) {
        self.workspace = workspace
        self.selectedImageID = selectedImageID
        self.workspaceURL = workspaceURL
        self.hasUnsavedChanges = hasUnsavedChanges
        self.imageLibrary = ImageLibrary(
            idGenerator: idGenerator,
            fileStatusProvider: imageFileStatusProvider
        )
        self.imagePayloadReader = ImagePayloadReader(fileReader: imageFileReader)
        self.classificationLibrary = ClassificationLibrary()
        self.aiClassificationProvider = aiClassificationProvider
        self.workspaceStore = WorkspaceStore(now: now)
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

    public func classifySelectedImage(providerID: UUID) throws {
        let imageID = try requireSelectedImageID()
        guard let provider = workspace.aiProviders.first(where: { $0.id == providerID }) else {
            throw AppModelError.aiProviderNotFound
        }
        guard let imageIndex = workspace.images.firstIndex(where: { $0.id == imageID }) else {
            throw AppModelError.imageSelectionRequired
        }

        let payload = try imagePayloadReader.payload(for: workspace.images[imageIndex])
        let generatedAt = now()
        let classification = try aiClassificationProvider.classify(
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

    public func openWorkspace(from url: URL) throws {
        workspace = try workspaceStore.load(from: url)
        workspaceURL = url
        selectedImageID = workspace.images.first?.id
        hasUnsavedChanges = false
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

public protocol AIClassificationProviding {
    func classify(
        payload: ImagePayload,
        provider: AIProviderProfile,
        generatedAt: Date?
    ) throws -> AIClassificationContent
}

public struct UnavailableAIClassificationProvider: AIClassificationProviding {
    public init() {}

    public func classify(
        payload: ImagePayload,
        provider: AIProviderProfile,
        generatedAt: Date?
    ) throws -> AIClassificationContent {
        throw AppModelError.aiClassificationProviderUnavailable
    }
}
