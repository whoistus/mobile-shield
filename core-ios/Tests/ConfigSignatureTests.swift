import CryptoKit
import XCTest
@testable import MobileShieldCore

final class ConfigSignatureTests: XCTestCase {
    private func apply(_ config: [String: Any], key: Data? = TestSigner.publicKey) -> ConfigEngine.Result {
        applyConfig(config, channel: "prod", publicKey: key)
    }

    func testValidSignatureIsAccepted() {
        XCTAssertEqual(apply(TestSigner.sign(runtimeConfig(["policies": ["VPN_PROXY": "WARN"]]))).status, .applied)
    }

    func testTamperedBodyIsRejected() {
        var signed = TestSigner.sign(runtimeConfig(["policies": ["VPN_PROXY": "WARN"]]))
        signed["policies"] = ["VPN_PROXY": "BLOCK"]
        assertBadSignature(apply(signed))
    }

    func testMissingSignatureIsRejectedWhenBootstrapHasKey() {
        assertBadSignature(apply(runtimeConfig()))
    }

    func testSignatureFromAnotherKeyIsRejected() {
        let other = Curve25519.Signing.PrivateKey()
        assertBadSignature(apply(TestSigner.sign(runtimeConfig(), with: other)))
    }

    func testMalformedSignatureEncodingIsRejected() {
        var signed = TestSigner.sign(runtimeConfig())
        signed["signature"] = "not base64 !!"
        assertBadSignature(apply(signed))
        signed["signature"] = ""
        assertBadSignature(apply(signed))
        signed["signature"] = 7
        assertBadSignature(apply(signed))
    }

    func testMalformedBootstrapKeyFailsClosed() {
        let signed = TestSigner.sign(runtimeConfig())
        assertBadSignature(apply(signed, key: Data()))
        assertBadSignature(apply(signed, key: Data(repeating: 1, count: 31)))
    }

    func testUnsignedConfigIsAcceptedWhenBootstrapHasNoKey() {
        XCTAssertEqual(apply(runtimeConfig(), key: nil).status, .applied)
    }

    func testSignatureIsCheckedBeforeSchema() {
        var config = TestSigner.sign(runtimeConfig(["version": 2]))
        config["signature"] = "AAAA"
        XCTAssertEqual(apply(config).reason, .signature)
    }

    func testBootstrapParsesInfoPlistKeys() {
        let key = TestSigner.publicKey.base64EncodedString()
        let boot = Bootstrap(info: ["MobileShieldChannel": "test", "MobileShieldConfigPubKey": key, "MobileShieldTeamId": "abcde12345"], bundleId: testAppId)
        XCTAssertEqual(boot.channel, "test")
        XCTAssertEqual(boot.configPublicKey, TestSigner.publicKey)
        XCTAssertEqual(boot.teamId, "ABCDE12345")
        XCTAssertEqual(boot.appId, testAppId)
        let malformed = Bootstrap(info: ["MobileShieldConfigPubKey": "###", "MobileShieldTeamId": "short"], bundleId: testAppId)
        XCTAssertEqual(malformed.channel, "prod")
        XCTAssertEqual(malformed.configPublicKey, Data())
        XCTAssertNil(malformed.teamId)
        XCTAssertNil(Bootstrap(info: [:], bundleId: testAppId).configPublicKey)
    }

    func testEngineRejectsBadSignatureKeepsLastKnownGoodAndEmitsWarnEvent() throws {
        let harness = EngineHarness(channel: "prod", publicKey: TestSigner.publicKey)
        _ = harness.start()
        let good = harness.engine.updateConfig(TestSigner.sign(runtimeConfig(seq: 3, ["policies": ["VPN_PROXY": "WARN"]])))
        XCTAssertNil(good.error)
        var forged = TestSigner.sign(runtimeConfig(seq: 4, ["policies": ["ROOT": "REPORT"]]))
        forged["policies"] = ["ROOT": "REPORT", "VPN_PROXY": "REPORT"]
        let bad = harness.engine.updateConfig(forged)
        XCTAssertEqual(bad.error?.reason, "ConfigRejected.signature")
        XCTAssertEqual(bad.config?.policy(for: .vpnProxy), .warn)
        XCTAssertEqual(bad.config?.policy(for: .root), .block)
        XCTAssertEqual(harness.store.stored?.seq, 3)
        let events = harness.recorder.events.filter { $0.detectorId == "policy.badSignature" }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.confidence, 0.5)
        XCTAssertEqual(events.first?.action, .warn)
        XCTAssertFalse(harness.engine.isBlocked)
    }

    func testProdWithoutBootstrapKeyRefusesRuntimeConfig() {
        let harness = EngineHarness(channel: "prod", publicKey: nil)
        _ = harness.start()
        let update = harness.engine.updateConfig(runtimeConfig())
        XCTAssertEqual(update.error?.reason, "BootstrapMissing")
        XCTAssertEqual(update.error?.nsError.code, 3)
    }

    func testCanonicalObjectKeysSortByUtf16CodeUnits() throws {
        let object: [String: Any] = ["\u{20AC}": 1, "\r": 2, "\u{FB33}": 3, "1": 4, "\u{1F600}": 5, "\u{0080}": 6, "\u{00F6}": 7]
        let text = try CanonicalJSON.string(from: object)
        XCTAssertEqual(text, "{\"\\r\":2,\"1\":4,\"\u{0080}\":6,\"\u{00F6}\":7,\"\u{20AC}\":1,\"\u{1F600}\":5,\"\u{FB33}\":3}")
    }

    func testCanonicalScalarsAndEscapes() throws {
        XCTAssertEqual(try CanonicalJSON.string(from: ["b": [true, false, NSNull()], "a": "x\"\\\n\u{01}/"] as [String: Any]),
                       "{\"a\":\"x\\\"\\\\\\n\\u0001/\",\"b\":[true,false,null]}")
        XCTAssertThrowsError(try CanonicalJSON.string(from: Date()))
        XCTAssertThrowsError(try CanonicalJSON.string(from: Double.nan))
    }

    func testCanonicalNumbersMatchRfc8785() {
        let cases: [(Double, String)] = [
            (0, "0"), (-0.0, "0"), (1, "1"), (-1, "-1"), (4.5, "4.5"), (0.002, "0.002"), (0.7, "0.7"),
            (0.000001, "0.000001"), (1e-7, "1e-7"), (1.5e-7, "1.5e-7"), (1e21, "1e+21"), (1e23, "1e+23"),
            (9007199254740992, "9007199254740992"), (2.9514790517935283e20, "295147905179352830000"),
            (333333333.33333329, "333333333.3333333"), (1.7976931348623157e308, "1.7976931348623157e+308"),
            (1800000000000, "1800000000000"), (1.2345678901234568e20, "123456789012345680000"),
        ]
        for (value, expected) in cases {
            XCTAssertEqual(CanonicalJSON.numberString(value), expected, "\(value)")
        }
    }

    private func assertBadSignature(_ result: ConfigEngine.Result, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(result.status, .rejected, file: file, line: line)
        XCTAssertEqual(result.reason, .signature, file: file, line: line)
        XCTAssertEqual(result.events, [ConfigEngine.PolicyEvent(category: .tampering, detectorId: "policy.badSignature", confidence: 0.5)],
                       file: file, line: line)
    }
}
