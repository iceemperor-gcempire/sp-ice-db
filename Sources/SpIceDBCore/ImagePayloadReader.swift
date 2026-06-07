import Foundation

public enum ImagePayloadReaderError: Error, Equatable {
    case fileMissing
    case fileUnreadable
    case unsupportedMimeType
}

public struct ImagePayload: Equatable, Sendable {
    public var sourcePath: String
    public var mimeType: String
    public var base64: String

    public init(sourcePath: String, mimeType: String, base64: String) {
        self.sourcePath = sourcePath
        self.mimeType = mimeType
        self.base64 = base64
    }
}

public protocol ImageFileReading {
    func readData(atPath path: String) throws -> Data
}

public struct FileManagerImageFileReader: ImageFileReading {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func readData(atPath path: String) throws -> Data {
        guard fileManager.fileExists(atPath: path) else {
            throw ImagePayloadReaderError.fileMissing
        }

        guard fileManager.isReadableFile(atPath: path) else {
            throw ImagePayloadReaderError.fileUnreadable
        }

        do {
            return try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
        } catch {
            throw ImagePayloadReaderError.fileUnreadable
        }
    }
}

public struct ImagePayloadReader {
    private let fileReader: ImageFileReading

    public init(fileReader: ImageFileReading = FileManagerImageFileReader()) {
        self.fileReader = fileReader
    }

    public func payload(for image: ImageEntry) throws -> ImagePayload {
        let mimeType = try mimeType(forPath: image.sourcePath)
        let data = try fileReader.readData(atPath: image.sourcePath)

        return ImagePayload(
            sourcePath: image.sourcePath,
            mimeType: mimeType,
            base64: data.base64EncodedString()
        )
    }

    private func mimeType(forPath path: String) throws -> String {
        switch URL(fileURLWithPath: path).pathExtension.lowercased() {
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "webp":
            return "image/webp"
        default:
            throw ImagePayloadReaderError.unsupportedMimeType
        }
    }
}
