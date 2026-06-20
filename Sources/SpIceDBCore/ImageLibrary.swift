import Foundation

public enum ImageLibraryError: Error, Equatable {
    case emptyPath
}

public enum ImageFileStatus: Equatable {
    case readable
    case missing
    case unreadable
}

public protocol ImageFileStatusProviding {
    func status(forPath path: String) -> ImageFileStatus
}

public struct ImageFileMetadata: Equatable, Sendable {
    public var modifiedAt: Date?
    public var fileSizeBytes: Int64?

    public init(modifiedAt: Date?, fileSizeBytes: Int64?) {
        self.modifiedAt = modifiedAt
        self.fileSizeBytes = fileSizeBytes
    }
}

public protocol ImageFileMetadataProviding {
    func metadata(forPath path: String) -> ImageFileMetadata?
}

public struct FileManagerImageFileStatusProvider: ImageFileStatusProviding {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func status(forPath path: String) -> ImageFileStatus {
        guard fileManager.fileExists(atPath: path) else {
            return .missing
        }

        return fileManager.isReadableFile(atPath: path) ? .readable : .unreadable
    }
}

public struct FileManagerImageFileMetadataProvider: ImageFileMetadataProviding {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func metadata(forPath path: String) -> ImageFileMetadata? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: path) else {
            return nil
        }

        return ImageFileMetadata(
            modifiedAt: attributes[.modificationDate] as? Date,
            fileSizeBytes: (attributes[.size] as? NSNumber)?.int64Value
        )
    }
}

public struct ImageLibrary {
    private let idGenerator: () -> UUID
    private let fileStatusProvider: ImageFileStatusProviding

    public init(
        idGenerator: @escaping () -> UUID = UUID.init,
        fileStatusProvider: ImageFileStatusProviding = FileManagerImageFileStatusProvider()
    ) {
        self.idGenerator = idGenerator
        self.fileStatusProvider = fileStatusProvider
    }

    @discardableResult
    public func addImage(path: String, to document: inout WorkspaceDocument) throws -> ImageEntry {
        let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPath.isEmpty else {
            throw ImageLibraryError.emptyPath
        }

        if let existing = document.images.first(where: { $0.sourcePath == normalizedPath }) {
            return existing
        }

        let entry = ImageEntry(
            id: idGenerator(),
            sourcePath: normalizedPath,
            displayName: URL(fileURLWithPath: normalizedPath).lastPathComponent
        )
        document.images.append(entry)
        return entry
    }

    @discardableResult
    public func removeImage(id: UUID, from document: inout WorkspaceDocument) -> ImageEntry? {
        guard let index = document.images.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        return document.images.remove(at: index)
    }

    public func status(for entry: ImageEntry) -> ImageFileStatus {
        fileStatusProvider.status(forPath: entry.sourcePath)
    }
}
