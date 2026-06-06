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
        now: @escaping () -> Date = Date.init
    ) {
        self.workspace = workspace
        self.selectedImageID = selectedImageID
        self.workspaceURL = workspaceURL
        self.hasUnsavedChanges = hasUnsavedChanges
        self.imageLibrary = ImageLibrary(idGenerator: idGenerator)
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

    public func newWorkspace(named name: String = "Untitled") {
        workspace = WorkspaceDocument.new(name: name, now: now())
        selectedImageID = nil
        workspaceURL = nil
        hasUnsavedChanges = false
    }

    @discardableResult
    public func addImage(path: String) throws -> ImageEntry {
        let entry = try imageLibrary.addImage(path: path, to: &workspace)
        selectedImageID = entry.id
        hasUnsavedChanges = true
        return entry
    }

    public func removeSelectedImage() {
        guard let selectedImageID else {
            return
        }

        _ = imageLibrary.removeImage(id: selectedImageID, from: &workspace)
        self.selectedImageID = workspace.images.first?.id
        hasUnsavedChanges = true
    }

    public func updateSelectedUserSentence(_ sentence: String) throws {
        let imageID = try requireSelectedImageID()
        try classificationLibrary.updateUserSentence(sentence, forImageID: imageID, in: &workspace)
        hasUnsavedChanges = true
    }

    public func updateSelectedUserTags(_ tags: String) throws {
        let imageID = try requireSelectedImageID()
        try classificationLibrary.updateUserTags(tags, forImageID: imageID, in: &workspace)
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

