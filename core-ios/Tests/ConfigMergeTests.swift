import XCTest
@testable import MobileShieldCore

final class ConfigMergeTests: XCTestCase {
    func testEmptyConfigAppliesChannelDefaults() {
        for channel in ["dev", "test", "prod"] {
            let result = applyConfig(runtimeConfig(), channel: channel)
            XCTAssertEqual(result.status, .applied, channel)
            XCTAssertEqual(result.applied?.policies, Defaults.policies(channel: channel), channel)
            XCTAssertEqual(result.applied?.blockThreshold, 0.7)
            XCTAssertEqual(result.applied?.monitoringIntervalMs, 5000)
            XCTAssertEqual(result.applied?.killDelayMs, 500...3000)
        }
    }

    func testHostPolicyOverridesMergeOverDefaults() throws {
        let result = applyConfig(runtimeConfig(["policies": ["VPN_PROXY": "WARN", "DEBUGGER": "BLOCK"]]), channel: "prod")
        let applied = try XCTUnwrap(result.applied)
        XCTAssertEqual(applied.policy(for: .vpnProxy), .warn)
        XCTAssertEqual(applied.policy(for: .debugger), .block)
        XCTAssertEqual(applied.policy(for: .root), .block)
        XCTAssertEqual(applied.policy(for: .hooking), .warn)
    }

    func testDisabledDetectorsAreCollected() throws {
        let result = applyConfig(runtimeConfig(["detectors": ["network.proxy": false, "simulator": true]]))
        let applied = try XCTUnwrap(result.applied)
        XCTAssertEqual(applied.disabled, ["network.proxy"])
        XCTAssertFalse(applied.isEnabled("network.proxy"))
        XCTAssertTrue(applied.isEnabled("simulator"))
    }

    func testOptionalFieldsAreApplied() throws {
        let result = applyConfig(runtimeConfig(["blockThreshold": 0.9, "monitoringIntervalMs": 2500,
                                                "killDelayMsRange": [100, 200], "installerAllowlist": ["com.example.store"]]))
        let applied = try XCTUnwrap(result.applied)
        XCTAssertEqual(applied.blockThreshold, 0.9)
        XCTAssertEqual(applied.monitoringIntervalMs, 2500)
        XCTAssertEqual(applied.killDelayMs, 100...200)
        XCTAssertEqual(applied.installerAllowlist, ["com.example.store"])
        XCTAssertEqual(applied.seq, 1)
    }

    func testSchemaRejections() {
        let bad: [(String, [String: Any])] = [
            ("version", runtimeConfig(["version": 2])),
            ("version type", runtimeConfig(["version": "1"])),
            ("appId", runtimeConfig(["appId": "com.other.app"])),
            ("seq missing", ["version": 1, "appId": testAppId]),
            ("seq fractional", runtimeConfig(["seq": 1.5])),
            ("unknown category", runtimeConfig(["policies": ["NOPE": "BLOCK"]])),
            ("unknown action", runtimeConfig(["policies": ["ROOT": "EXPLODE"]])),
            ("policies type", runtimeConfig(["policies": ["ROOT"]])),
            ("detector flag type", runtimeConfig(["detectors": ["simulator": "no"]])),
            ("detector flag number", runtimeConfig(["detectors": ["simulator": 0]])),
            ("threshold high", runtimeConfig(["blockThreshold": 1.5])),
            ("threshold negative", runtimeConfig(["blockThreshold": -0.1])),
            ("interval low", runtimeConfig(["monitoringIntervalMs": 999])),
            ("interval fractional", runtimeConfig(["monitoringIntervalMs": 1500.5])),
            ("kill range size", runtimeConfig(["killDelayMsRange": [100]])),
            ("kill range order", runtimeConfig(["killDelayMsRange": [300, 100]])),
            ("allowlist empty entry", runtimeConfig(["installerAllowlist": [""]])),
            ("expiresAt type", runtimeConfig(["expiresAt": "soon"])),
        ]
        for (name, config) in bad {
            let result = applyConfig(config)
            XCTAssertEqual(result.status, .rejected, name)
            XCTAssertEqual(result.reason, .schema, name)
            XCTAssertNil(result.applied, name)
        }
    }

    func testNonJsonObjectIsRejectedWithoutCrashing() {
        let result = applyConfig(runtimeConfig(["policies": ["ROOT": Date()]]))
        XCTAssertEqual(result.reason, .schema)
    }

    func testStaleSeqIsRejectedAsExpired() {
        let result = applyConfig(runtimeConfig(seq: 4), lastKnownSeq: 5)
        XCTAssertEqual(result.status, .rejected)
        XCTAssertEqual(result.reason, .expired)
    }

    func testEqualSeqIsAccepted() {
        XCTAssertEqual(applyConfig(runtimeConfig(seq: 5), lastKnownSeq: 5).status, .applied)
    }

    func testExpiryBoundary() {
        XCTAssertEqual(applyConfig(runtimeConfig(["expiresAt": testNowMs - 1])).reason, .expired)
        XCTAssertEqual(applyConfig(runtimeConfig(["expiresAt": testNowMs])).reason, .expired)
        XCTAssertEqual(applyConfig(runtimeConfig(["expiresAt": testNowMs + 60_000])).status, .applied)
        XCTAssertEqual(applyConfig(runtimeConfig(["expiresAt": NSNull()])).status, .applied)
    }

    func testRejectedConfigNeverProducesPolicyEvents() {
        XCTAssertTrue(applyConfig(runtimeConfig(["version": 2])).events.isEmpty)
    }

    func testConfigDictionaryExposesEffectiveValues() throws {
        let harness = EngineHarness(detectors: [StubDetector(id: "x.y", category: .root, result: .unsupported("n/a"))])
        _ = harness.start(runtime: runtimeConfig(["detectors": ["simulator": false]]))
        let config = harness.engine.configDictionary()
        XCTAssertEqual(config["channel"] as? String, "dev")
        XCTAssertEqual(config["disabled"] as? [String], ["simulator"])
        XCTAssertEqual((config["policies"] as? [String: String])?["ROOT"], "REPORT")
        XCTAssertEqual(config["unsupportedDetectors"] as? [String], ["x.y"])
        XCTAssertEqual(config["seq"] as? Int64, 1)
    }
}
