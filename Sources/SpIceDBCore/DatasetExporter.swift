import Foundation

public enum DatasetMetadataSource: Equatable, Hashable {
    case user
    case ai
    case userWithAIFallback
}

public enum DatasetCaptionFormat: Equatable, Hashable {
    case sentence
    case tags
}

public struct DatasetExportOptions: Equatable {
    public var metadataSource: DatasetMetadataSource
    public var captionFormat: DatasetCaptionFormat

    public init(
        metadataSource: DatasetMetadataSource,
        captionFormat: DatasetCaptionFormat
    ) {
        self.metadataSource = metadataSource
        self.captionFormat = captionFormat
    }
}

public enum DatasetExportIssue: Equatable {
    case generatedFileMissing(imageID: UUID, outputID: UUID, path: String)
    case captionMissing(imageID: UUID, outputID: UUID)
}

public struct DatasetExportReport: Equatable {
    public var writtenCaptionPaths: [String]
    public var issues: [DatasetExportIssue]

    public init(writtenCaptionPaths: [String] = [], issues: [DatasetExportIssue] = []) {
        self.writtenCaptionPaths = writtenCaptionPaths
        self.issues = issues
    }
}

public struct DatasetExporter {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @discardableResult
    public func exportCaptions(
        from document: WorkspaceDocument,
        options: DatasetExportOptions
    ) throws -> DatasetExportReport {
        var report = DatasetExportReport()

        for image in document.images {
            for output in image.generatedOutputs where output.status == .generated {
                guard fileManager.fileExists(atPath: output.path) else {
                    report.issues.append(
                        .generatedFileMissing(
                            imageID: image.id,
                            outputID: output.id,
                            path: output.path
                        )
                    )
                    continue
                }

                guard let caption = caption(for: image.classification, options: options) else {
                    report.issues.append(
                        .captionMissing(
                            imageID: image.id,
                            outputID: output.id
                        )
                    )
                    continue
                }

                let captionURL = URL(fileURLWithPath: output.path)
                    .deletingPathExtension()
                    .appendingPathExtension("txt")
                try "\(caption)\n".write(to: captionURL, atomically: true, encoding: .utf8)
                report.writtenCaptionPaths.append(captionURL.path)
            }
        }

        return report
    }

    private func caption(
        for classification: Classification,
        options: DatasetExportOptions
    ) -> String? {
        switch options.metadataSource {
        case .user:
            return caption(from: classification.user, format: options.captionFormat)
        case .ai:
            guard let ai = classification.ai else { return nil }
            return caption(from: ai, format: options.captionFormat)
        case .userWithAIFallback:
            if let userCaption = caption(from: classification.user, format: options.captionFormat) {
                return userCaption
            }
            guard let ai = classification.ai else { return nil }
            return caption(from: ai, format: options.captionFormat)
        }
    }

    private func caption(from content: ClassificationContent, format: DatasetCaptionFormat) -> String? {
        switch format {
        case .sentence:
            return trimmedNonEmpty(content.sentence)
        case .tags:
            return joinedTags(content.tags)
        }
    }

    private func caption(from content: AIClassificationContent, format: DatasetCaptionFormat) -> String? {
        switch format {
        case .sentence:
            return trimmedNonEmpty(content.sentence)
        case .tags:
            return joinedTags(content.tags)
        }
    }

    private func trimmedNonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func joinedTags(_ tags: [String]) -> String? {
        let normalized = tags.compactMap(trimmedNonEmpty)
        guard !normalized.isEmpty else { return nil }
        return normalized.joined(separator: ", ")
    }
}
