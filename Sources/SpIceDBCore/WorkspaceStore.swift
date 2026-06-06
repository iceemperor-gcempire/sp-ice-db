import Foundation

public enum WorkspaceStoreError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case decodeFailed
}

public struct WorkspaceStore {
    private let fileManager: FileManager
    private let now: () -> Date

    public init(fileManager: FileManager = .default, now: @escaping () -> Date = Date.init) {
        self.fileManager = fileManager
        self.now = now
    }

    public func load(from url: URL) throws -> WorkspaceDocument {
        let data = try Data(contentsOf: url)
        let document: WorkspaceDocument

        do {
            document = try WorkspaceJSONCodec.decode(data)
        } catch {
            throw WorkspaceStoreError.decodeFailed
        }

        guard document.schemaVersion <= WorkspaceDocument.currentSchemaVersion else {
            throw WorkspaceStoreError.unsupportedSchemaVersion(document.schemaVersion)
        }

        return document
    }

    public func save(_ document: inout WorkspaceDocument, to url: URL) throws {
        document.workspace.updatedAt = now()

        let parentDirectory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)

        let data = try WorkspaceJSONCodec.encode(document)
        let temporaryURL = parentDirectory.appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        try data.write(to: temporaryURL, options: [.atomic])

        do {
            _ = try fileManager.replaceItemAt(url, withItemAt: temporaryURL)
        } catch {
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: temporaryURL)
                throw error
            }

            try fileManager.moveItem(at: temporaryURL, to: url)
        }
    }
}

