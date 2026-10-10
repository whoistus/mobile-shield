import XCTest
@testable import MobileShieldCore

final class AttestationTests: XCTestCase {
    func testEnrolIsUnsupportedForEveryKind() {
        for kind in ["appAttest", "deviceCheck", "hms", ""] {
            let result = MobileShield.attestEnrol(kind, nonce: "nonce")
            XCTAssertEqual(result["status"] as? String, "unsupported", kind)
            XCTAssertEqual(result["kind"] as? String, kind)
        }
    }

    func testAssertIsUnsupported() {
        let result = MobileShield.attestAssert("appAttest", nonce: "nonce", requestHash: "hash")
        XCTAssertEqual(result["status"] as? String, "unsupported")
        XCTAssertEqual(result["kind"] as? String, "appAttest")
    }

    func testEnvironmentAdvertisesNoAttestationKinds() {
        let harness = EngineHarness()
        let info = harness.start().environment.dictionary
        XCTAssertEqual(info["attestationKinds"] as? [String], [])
        XCTAssertEqual(info["platform"] as? String, "ios")
        XCTAssertEqual(info["gmsAvailable"] as? Bool, false)
    }

    func testTypedErrorCodesMatchPublicEnum() {
        XCTAssertEqual(ShieldError.nativeUnavailable("x").nsError.code, MSError.Code.nativeUnavailable.rawValue)
        XCTAssertEqual(ShieldError.notInitialized.nsError.code, MSError.Code.notInitialized.rawValue)
        XCTAssertEqual(ShieldError.bootstrapMissing("x").nsError.code, MSError.Code.bootstrapMissing.rawValue)
        XCTAssertEqual(ShieldError.configRejected(.schema, "x").nsError.code, MSError.Code.configRejected.rawValue)
        XCTAssertEqual(ShieldError.detectorUnsupported("x").nsError.code, MSError.Code.detectorUnsupported.rawValue)
        XCTAssertEqual(ShieldError.attestationUnsupported("x").nsError.code, MSError.Code.attestationUnsupported.rawValue)
        XCTAssertEqual(ShieldError.notInitialized.nsError.domain, MSErrorDomain)
    }
}
