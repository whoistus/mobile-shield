import XCTest
@testable import MobileShieldCore

final class ConfigFloorTests: XCTestCase {
    func testProdCannotDisableFloorDetectors() throws {
        for id in ["tampering.bundleId", "tampering.teamId"] {
            let result = applyConfig(runtimeConfig(["detectors": [id: false]]), channel: "prod")
            XCTAssertEqual(result.status, .clamped, id)
            XCTAssertEqual(result.reason, .floor, id)
            let applied = try XCTUnwrap(result.applied)
            XCTAssertTrue(applied.isEnabled(id), id)
            XCTAssertEqual(applied.clamped, ["detectors.\(id)"])
        }
    }

    func testProdClampsTamperingToWarn() throws {
        let result = applyConfig(runtimeConfig(["policies": ["TAMPERING": "REPORT"]]), channel: "prod")
        XCTAssertEqual(result.status, .clamped)
        XCTAssertEqual(result.applied?.policy(for: .tampering), .warn)
        XCTAssertEqual(result.applied?.clamped, ["policies.TAMPERING"])
    }

    func testStrongerTamperingPoliciesAreNotClamped() {
        for action in ["WARN", "BLOCK", "KILL"] {
            XCTAssertEqual(applyConfig(runtimeConfig(["policies": ["TAMPERING": action]]), channel: "prod").status, .applied, action)
        }
    }

    func testFloorEventIsLowConfidencePolicyEvent() {
        let result = applyConfig(runtimeConfig(["detectors": ["tampering.teamId": false]]), channel: "prod")
        XCTAssertEqual(result.events, [ConfigEngine.PolicyEvent(category: .tampering, detectorId: "policy.floor", confidence: 0.5)])
    }

    func testNoFloorOutsideProd() {
        for channel in ["dev", "test"] {
            let result = applyConfig(runtimeConfig(["policies": ["TAMPERING": "REPORT"], "detectors": ["tampering.bundleId": false]]), channel: channel)
            XCTAssertEqual(result.status, .applied, channel)
            XCTAssertEqual(result.applied?.policy(for: .tampering), .report)
            XCTAssertEqual(result.applied?.disabled, ["tampering.bundleId"])
        }
    }

    func testEngineAppliesClampedConfigReportsFloorAndNeverBlocks() {
        let harness = EngineHarness(channel: "prod", publicKey: TestSigner.publicKey)
        _ = harness.start()
        let update = harness.engine.updateConfig(TestSigner.sign(runtimeConfig(["detectors": ["tampering.bundleId": false]])))
        XCTAssertEqual(update.error?.reason, "ConfigRejected.floor")
        XCTAssertEqual(update.error?.nsError.userInfo["configReason"] as? String, "floor")
        XCTAssertEqual(update.config?.isEnabled("tampering.bundleId"), true)
        let floorEvents = harness.recorder.events.filter { $0.detectorId == "policy.floor" }
        XCTAssertEqual(floorEvents.count, 1)
        XCTAssertEqual(floorEvents.first?.category, .tampering)
        XCTAssertEqual(floorEvents.first?.confidence, 0.5)
        XCTAssertEqual(floorEvents.first?.action, .warn)
        XCTAssertFalse(harness.engine.isBlocked)
        XCTAssertFalse(harness.watchdog.isScheduled)
    }

    func testEngineRunsFloorDetectorsEvenWhenHostDisablesThem() {
        let counter = RunCounter()
        let detector = StubDetector(id: "tampering.bundleId", category: .tampering, result: .clear, counter: counter)
        let harness = EngineHarness(channel: "prod", publicKey: TestSigner.publicKey, detectors: [detector])
        _ = harness.start()
        counter.count = 0
        _ = harness.engine.updateConfig(TestSigner.sign(runtimeConfig(["detectors": ["tampering.bundleId": false]])))
        _ = harness.engine.runChecks()
        XCTAssertEqual(counter.count, 1)
    }

    func testDisabledNonFloorDetectorIsNotRun() {
        let counter = RunCounter()
        let detector = StubDetector(id: "network.proxy", category: .vpnProxy, result: .hit(0.7), counter: counter)
        let harness = EngineHarness(detectors: [detector])
        _ = harness.start(runtime: runtimeConfig(["detectors": ["network.proxy": false]]))
        counter.count = 0
        XCTAssertTrue(harness.engine.runChecks().isEmpty)
        XCTAssertEqual(counter.count, 0)
    }
}
