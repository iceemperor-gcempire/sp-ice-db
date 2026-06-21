import XCTest

final class AppBundlePackagingTests: XCTestCase {
    func testInfoPlistDeclaresLaunchServicesAppBundle() throws {
        let plist = try appBundleInfoPlist()

        XCTAssertEqual(plist["CFBundlePackageType"] as? String, "APPL")
        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "sp-ice-db")
        XCTAssertEqual(plist["CFBundleDisplayName"] as? String, "sp-ice-db")
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "com.gcempire.sp-ice-db")
        XCTAssertEqual(plist["NSPrincipalClass"] as? String, "NSApplication")
    }

    func testBuildScriptCreatesExpectedBundleShape() throws {
        let scriptURL = packageRoot()
            .appendingPathComponent("scripts")
            .appendingPathComponent("build-app-bundle.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(script.contains("swift build"))
        XCTAssertTrue(script.contains("sp-ice-db.app"))
        XCTAssertTrue(script.contains("Contents/MacOS"))
        XCTAssertTrue(script.contains("Contents/Resources"))
        XCTAssertTrue(script.contains("Info.plist"))
    }

    private func appBundleInfoPlist() throws -> [String: Any] {
        let plistURL = packageRoot()
            .appendingPathComponent("Resources")
            .appendingPathComponent("macOS")
            .appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: plistURL)
        let value = try PropertyListSerialization.propertyList(from: data, format: nil)

        guard let plist = value as? [String: Any] else {
            XCTFail("Info.plist should decode to a dictionary.")
            return [:]
        }

        return plist
    }

    private func packageRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)

        while url.path != "/" {
            url.deleteLastPathComponent()

            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url
            }
        }

        XCTFail("Could not locate package root from test file path.")
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}
