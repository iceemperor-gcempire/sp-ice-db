import Foundation

public enum SourceFolderLibraryError: Error, Equatable {
    case emptyPath
}

public struct SourceFolderLibrary {
    private let idGenerator: () -> UUID

    public init(idGenerator: @escaping () -> UUID = UUID.init) {
        self.idGenerator = idGenerator
    }

    @discardableResult
    public func addSourceFolder(
        path: String,
        recursive: Bool,
        to document: inout WorkspaceDocument
    ) throws -> SourceFolder {
        let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPath.isEmpty else {
            throw SourceFolderLibraryError.emptyPath
        }

        if let existing = document.sourceFolders.first(where: { $0.path == normalizedPath }) {
            return existing
        }

        let folder = SourceFolder(
            id: idGenerator(),
            path: normalizedPath,
            displayName: URL(fileURLWithPath: normalizedPath, isDirectory: true).lastPathComponent,
            recursive: recursive
        )
        document.sourceFolders.append(folder)
        return folder
    }

    @discardableResult
    public func removeSourceFolder(id: UUID, from document: inout WorkspaceDocument) -> SourceFolder? {
        guard let index = document.sourceFolders.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        return document.sourceFolders.remove(at: index)
    }

    public func markScanned(folderID: UUID, at date: Date, in document: inout WorkspaceDocument) {
        guard let index = document.sourceFolders.firstIndex(where: { $0.id == folderID }) else {
            return
        }

        document.sourceFolders[index].lastScannedAt = date
    }
}

public enum SourceFolderScannerError: Error, Equatable {
    case folderMissing
    case folderUnreadable
}

public struct SourceFolderScanner {
    private let fileManager: FileManager
    private let supportedExtensions: Set<String>

    public init(
        fileManager: FileManager = .default,
        supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "heic", "heif", "tif", "tiff"]
    ) {
        self.fileManager = fileManager
        self.supportedExtensions = supportedExtensions
    }

    public func imagePaths(in folder: SourceFolder) throws -> [String] {
        let folderURL = URL(fileURLWithPath: folder.path, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw SourceFolderScannerError.folderMissing
        }
        guard fileManager.isReadableFile(atPath: folderURL.path) else {
            throw SourceFolderScannerError.folderUnreadable
        }

        if folder.recursive {
            return try recursiveImagePaths(in: folderURL)
        }

        return try directImagePaths(in: folderURL)
    }

    private func recursiveImagePaths(in folderURL: URL) throws -> [String] {
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw SourceFolderScannerError.folderUnreadable
        }

        var paths: [String] = []
        for case let url as URL in enumerator where isSupportedImageFile(url) {
            paths.append(pathForWorkspace(url, under: folderURL))
        }
        return sortedImagePaths(paths)
    }

    private func directImagePaths(in folderURL: URL) throws -> [String] {
        let urls = try fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter(isSupportedImageFile)
            .map { pathForWorkspace($0, under: folderURL) }
            .sorted(by: imagePathSort)
    }

    private func sortedImagePaths(_ paths: [String]) -> [String] {
        paths.sorted(by: imagePathSort)
    }

    private func imagePathSort(_ lhs: String, _ rhs: String) -> Bool {
        let leftName = URL(fileURLWithPath: lhs).lastPathComponent
        let rightName = URL(fileURLWithPath: rhs).lastPathComponent
        if leftName != rightName {
            return leftName.localizedStandardCompare(rightName) == .orderedAscending
        }
        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    private func pathForWorkspace(_ url: URL, under folderURL: URL) -> String {
        let resolvedFolderPath = folderURL.resolvingSymlinksInPath().path
        let originalFolderPath = folderURL.path
        let resolvedPath = url.resolvingSymlinksInPath().path

        guard resolvedPath.hasPrefix(resolvedFolderPath) else {
            return url.path
        }

        return originalFolderPath + resolvedPath.dropFirst(resolvedFolderPath.count)
    }

    private func isSupportedImageFile(_ url: URL) -> Bool {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            return false
        }

        guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey]) else {
            return false
        }

        return resourceValues.isRegularFile == true
    }
}

public protocol SourceFolderScanning {
    func imagePaths(in folder: SourceFolder) throws -> [String]
}

extension SourceFolderScanner: SourceFolderScanning {}
