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
    private let classificationLibrary: ClassificationLibrary
    private let workspaceStore: WorkspaceStore
    private let now: () -> Date

    public init(
        workspace: WorkspaceDocument = WorkspaceDocument.new(name: "Untitled"),
        selectedImageID: UUID? = nil,
        workspaceURL: URL? = nil,
        hasUnsavedChanges: Bool = false,
        idGenerator: @escaping () -> UUID = UUID.init,
        imageFileStatusProvider: ImageFileStatusProviding = FileManagerImageFileStatusProvider(),
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
        self.classificationLibrary = ClassificationLibrary()
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

        return imageLibrary.status(for: selectedImage)
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
}
