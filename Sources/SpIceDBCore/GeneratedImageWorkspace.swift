import Foundation

public enum GeneratedImageWorkspaceError: Error, Equatable {
    case workingDirectoryMissing
    case imageNotFound
    case sourceFileMissing
    case sourceFileUnreadable
}

public struct GeneratedImageWorkspace {
    private let fileManager: FileManager
    private let idGenerator: () -> UUID
    private let now: () -> Date

    public init(
        fileManager: FileManager = .default,
        idGenerator: @escaping () -> UUID = UUID.init,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.idGenerator = idGenerator
        self.now = now
    }

    @discardableResult
    public func collectSourceImage(
        imageID: UUID,
        settingsID: UUID? = nil,
        in document: inout WorkspaceDocument
    ) throws -> GeneratedOutput {
        guard let workingDirectory = document.workspace.workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines),
              !workingDirectory.isEmpty else {
            throw GeneratedImageWorkspaceError.workingDirectoryMissing
        }

        guard let imageIndex = document.images.firstIndex(where: { $0.id == imageID }) else {
            throw GeneratedImageWorkspaceError.imageNotFound
        }

        let sourcePath = document.images[imageIndex].sourcePath
        guard fileManager.fileExists(atPath: sourcePath) else {
            throw GeneratedImageWorkspaceError.sourceFileMissing
        }
        guard fileManager.isReadableFile(atPath: sourcePath) else {
            throw GeneratedImageWorkspaceError.sourceFileUnreadable
        }

        let workingURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        try fileManager.createDirectory(at: workingURL, withIntermediateDirectories: true)

        let sourceURL = URL(fileURLWithPath: sourcePath)
        let targetURL = uniqueTargetURL(
            forSourceURL: sourceURL,
            in: workingURL
        )
        try fileManager.copyItem(at: sourceURL, to: targetURL)

        let output = GeneratedOutput(
            id: idGenerator(),
            path: targetURL.path,
            status: .generated,
            createdAt: now(),
            settingsId: settingsID
        )
        document.images[imageIndex].generatedOutputs.append(output)
        return output
    }

    private func uniqueTargetURL(forSourceURL sourceURL: URL, in workingURL: URL) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        var candidate = workingURL.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 1

        while fileManager.fileExists(atPath: candidate.path) {
            let suffix = String(format: "_%03d", counter)
            let filename = fileExtension.isEmpty
                ? "\(baseName)\(suffix)"
                : "\(baseName)\(suffix).\(fileExtension)"
            candidate = workingURL.appendingPathComponent(filename)
            counter += 1
        }

        return candidate
    }
}
