import XCTest
import MobileShieldCore

final class MobileShieldCoreTests: XCTestCase {
    func testSdkVersionMatchesVersionFile() throws {
        let versionURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("VERSION")
        let expected = try String(contentsOf: versionURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let actual = MobileShield.sdkVersion()
        XCTAssertFalse(actual.isEmpty)
        XCTAssertEqual(actual, expected)
    }
}
