import XCTest
@testable import SpIceDBCore

final class ImagePayloadReaderTests: XCTestCase {
    func testReadsPNGImagePayloadAsBase64WithoutChangingSourceFile() throws {
        let directory = try ImagePayloadTemporaryDirectory()
        let imageURL = directory.url.appendingPathComponent("source.png")
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        try imageData.write(to: imageURL)
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: imageURL.path)
        let reader = ImagePayloadReader()

        let payload = try reader.payload(for: imageEntry(path: imageURL.path))

        XCTAssertEqual(payload.sourcePath, imageURL.path)
        XCTAssertEqual(payload.mimeType, "image/png")
        XCTAssertEqual(payload.base64, imageData.base64EncodedString())
        XCTAssertEqual(try Data(contentsOf: imageURL), imageData)
        let updatedAttributes = try FileManager.default.attributesOfItem(atPath: imageURL.path)
        XCTAssertEqual(
            originalAttributes[FileAttributeKey.modificationDate] as? Date,
            updatedAttributes[FileAttributeKey.modificationDate] as? Date
        )
    }

    func testInfersSupportedMimeTypesFromExtensionCaseInsensitively() throws {
        let reader = ImagePayloadReader(fileReader: StubImageFileReader(files: [
            "/tmp/source.JPG": Data([1]),
            "/tmp/source.jpeg": Data([2]),
            "/tmp/source.webp": Data([3])
        ]))

        XCTAssertEqual(try reader.payload(for: imageEntry(path: "/tmp/source.JPG")).mimeType, "image/jpeg")
        XCTAssertEqual(try reader.payload(for: imageEntry(path: "/tmp/source.jpeg")).mimeType, "image/jpeg")
        XCTAssertEqual(try reader.payload(for: imageEntry(path: "/tmp/source.webp")).mimeType, "image/webp")
    }

    func testRejectsMissingUnreadableAndUnsupportedFiles() {
        XCTAssertThrowsError(
            try ImagePayloadReader(fileReader: StubImageFileReader(files: [:]))
                .payload(for: imageEntry(path: "/tmp/missing.png"))
        ) { error in
            XCTAssertEqual(error as? ImagePayloadReaderError, .fileMissing)
        }

        XCTAssertThrowsError(
            try ImagePayloadReader(fileReader: StubImageFileReader(files: [
                "/tmp/source.png": nil
            ])).payload(for: imageEntry(path: "/tmp/source.png"))
        ) { error in
            XCTAssertEqual(error as? ImagePayloadReaderError, .fileUnreadable)
        }

        XCTAssertThrowsError(
            try ImagePayloadReader(fileReader: StubImageFileReader(files: [
                "/tmp/source.tiff": Data([1])
            ])).payload(for: imageEntry(path: "/tmp/source.tiff"))
        ) { error in
            XCTAssertEqual(error as? ImagePayloadReaderError, .unsupportedMimeType)
        }
    }
}

private func imageEntry(path: String) -> ImageEntry {
    ImageEntry(
        id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        sourcePath: path,
        displayName: URL(fileURLWithPath: path).lastPathComponent
    )
}

private struct StubImageFileReader: ImageFileReading {
    var files: [String: Data?]

    func readData(atPath path: String) throws -> Data {
        guard let value = files[path] else {
            throw ImagePayloadReaderError.fileMissing
        }
        guard let data = value else {
            throw ImagePayloadReaderError.fileUnreadable
        }
        return data
    }
}

private final class ImagePayloadTemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sp-ice-db-image-payload-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
