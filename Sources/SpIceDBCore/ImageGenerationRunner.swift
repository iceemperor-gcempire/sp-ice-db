import Foundation

public enum ImageGenerationRunnerError: Error, Equatable {
    case workingDirectoryMissing
    case imageNotFound
    case sourceFileMissing
    case sourceFileUnreadable
    case settingsNotFound
    case generatedDataEmpty
}

public struct ImageGenerationRequest: Equatable {
    public var imageID: UUID
    public var sourcePath: String
    public var displayName: String?
    public var notes: String
    public var classification: Classification
    public var settings: GenerationSettings?

    public init(
        imageID: UUID,
        sourcePath: String,
        displayName: String?,
        notes: String,
        classification: Classification,
        settings: GenerationSettings?
    ) {
        self.imageID = imageID
        self.sourcePath = sourcePath
        self.displayName = displayName
        self.notes = notes
        self.classification = classification
        self.settings = settings
    }
}

public struct GeneratedImageAsset: Equatable {
    public var data: Data
    public var suggestedFilename: String?

    public init(data: Data, suggestedFilename: String? = nil) {
        self.data = data
        self.suggestedFilename = suggestedFilename
    }
}

public protocol ImageGenerationProviding {
    func generateImage(request: ImageGenerationRequest) async throws -> GeneratedImageAsset
}

public struct ImageGenerationRunner {
    private let provider: any ImageGenerationProviding
    private let fileManager: FileManager
    private let idGenerator: () -> UUID
    private let now: () -> Date

    public init(
        provider: any ImageGenerationProviding,
        fileManager: FileManager = .default,
        idGenerator: @escaping () -> UUID = UUID.init,
        now: @escaping () -> Date = Date.init
    ) {
        self.provider = provider
        self.fileManager = fileManager
        self.idGenerator = idGenerator
        self.now = now
    }

    @discardableResult
    public func generateImage(
        imageID: UUID,
        settingsID: UUID? = nil,
        in document: inout WorkspaceDocument
    ) async throws -> GeneratedOutput {
        guard let workingDirectory = document.workspace.workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines),
              !workingDirectory.isEmpty else {
            throw ImageGenerationRunnerError.workingDirectoryMissing
        }

        guard let imageIndex = document.images.firstIndex(where: { $0.id == imageID }) else {
            throw ImageGenerationRunnerError.imageNotFound
        }

        let image = document.images[imageIndex]
        guard fileManager.fileExists(atPath: image.sourcePath) else {
            throw ImageGenerationRunnerError.sourceFileMissing
        }
        guard fileManager.isReadableFile(atPath: image.sourcePath) else {
            throw ImageGenerationRunnerError.sourceFileUnreadable
        }

        let settings: GenerationSettings?
        if let settingsID {
            guard let matchingSettings = document.generationSettings.first(where: { $0.id == settingsID }) else {
                throw ImageGenerationRunnerError.settingsNotFound
            }
            settings = matchingSettings
        } else {
            settings = nil
        }

        let request = ImageGenerationRequest(
            imageID: image.id,
            sourcePath: image.sourcePath,
            displayName: image.displayName,
            notes: image.notes,
            classification: image.classification,
            settings: settings
        )
        let asset = try await provider.generateImage(request: request)
        guard !asset.data.isEmpty else {
            throw ImageGenerationRunnerError.generatedDataEmpty
        }

        let workingURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        try fileManager.createDirectory(at: workingURL, withIntermediateDirectories: true)
        let targetURL = uniqueTargetURL(
            suggestedFilename: asset.suggestedFilename,
            sourcePath: image.sourcePath,
            in: workingURL
        )
        try asset.data.write(to: targetURL, options: .atomic)

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

    private func uniqueTargetURL(
        suggestedFilename: String?,
        sourcePath: String,
        in workingURL: URL
    ) -> URL {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let fallbackName = "\(sourceURL.deletingPathExtension().lastPathComponent)_generated.png"
        let filename = normalizedFilename(suggestedFilename) ?? fallbackName
        let target = workingURL.appendingPathComponent(filename)
        let baseName = target.deletingPathExtension().lastPathComponent
        let fileExtension = target.pathExtension
        var candidate = target
        var counter = 1

        while fileManager.fileExists(atPath: candidate.path) {
            let suffix = String(format: "_%03d", counter)
            let uniqueFilename = fileExtension.isEmpty
                ? "\(baseName)\(suffix)"
                : "\(baseName)\(suffix).\(fileExtension)"
            candidate = workingURL.appendingPathComponent(uniqueFilename)
            counter += 1
        }

        return candidate
    }

    private func normalizedFilename(_ suggestedFilename: String?) -> String? {
        guard let suggestedFilename else { return nil }
        let filename = URL(fileURLWithPath: suggestedFilename).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return filename.isEmpty ? nil : filename
    }
}
