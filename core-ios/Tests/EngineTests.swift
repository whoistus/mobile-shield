import XCTest
@testable import MobileShieldCore

final class EngineTests: XCTestCase {
    func testUpdateBeforeInitIsNotInitialized() {
        let harness = EngineHarness()
        let update = harness.engine.updateConfig(runtimeConfig())
        XCTAssertEqual(update.error, .notInitialized)
        XCTAssertNil(update.config)
        XCTAssertTrue(harness.engine.runChecks().isEmpty)
        XCTAssertEqual(harness.engine.configDictionary().count, 0)
    }

    func testInitRunsFirstCheckSynchronouslyAndIsIdempotent() {
        let counter = RunCounter()
        let harness = EngineHarness(detectors: [StubDetector(id: "x.y", category: .root, result: .clear, counter: counter)])
        _ = harness.start()
        XCTAssertEqual(counter.count, 1)
        _ = harness.engine.initialize(runtime: nil, sdkVersion: "test")
        XCTAssertEqual(counter.count, 2)
        XCTAssertTrue(harness.engine.isInitialized)
    }

    func testInitWithRejectedConfigStillInitialises() {
        let harness = EngineHarness()
        let outcome = harness.start(runtime: runtimeConfig(["version": 9]))
        XCTAssertEqual(outcome.error?.reason, "ConfigRejected.schema")
        XCTAssertTrue(harness.engine.isInitialized)
        XCTAssertEqual(outcome.environment.sdkVersion, "test")
    }

    func testEventsBeforeAnyListenerAreBufferedForTheFirstListener() {
        let harness = EngineHarness(detectors: [StubDetector(id: "x.y", category: .root, result: .hit(0.9))])
        _ = harness.engine.initialize(runtime: nil, sdkVersion: "test")
        let late = EventRecorder()
        harness.engine.addListener(late.record)
        XCTAssertEqual(late.events.map(\.detectorId), ["x.y"])
        let second = EventRecorder()
        harness.engine.addListener(second.record)
        XCTAssertTrue(second.events.isEmpty)
    }

    func testListenersCanBeRemoved() {
        let harness = EngineHarness(detectors: [StubDetector(id: "x.y", category: .root, result: .hit(0.9))])
        _ = harness.engine.initialize(runtime: nil, sdkVersion: "test")
        let recorder = EventRecorder()
        let token = harness.engine.addListener(recorder.record)
        // The first listener receives the event buffered during init; removal stops later delivery.
        XCTAssertEqual(recorder.events.count, 1)
        harness.engine.removeListener(token)
        _ = harness.engine.runChecks()
        XCTAssertEqual(recorder.events.count, 1)
    }

    func testBlockIsStickyAcrossConfigChanges() {
        let harness = EngineHarness(detectors: [StubDetector(id: "x.y", category: .root, result: .hit(0.9))])
        _ = harness.start(runtime: runtimeConfig(["policies": ["ROOT": "BLOCK"]]))
        XCTAssertTrue(harness.engine.isBlocked)
        _ = harness.engine.updateConfig(runtimeConfig(seq: 2, ["policies": ["ROOT": "REPORT"]]))
        _ = harness.engine.runChecks()
        XCTAssertTrue(harness.engine.isBlocked)
    }

    func testExperimentalDetectorNeverBlocks() {
        let harness = EngineHarness(detectors: [StubDetector(id: "jailbreak.dyldImages", category: .root, result: .hit(1.0))])
        _ = harness.start(runtime: runtimeConfig(["policies": ["ROOT": "KILL"]]))
        XCTAssertFalse(harness.engine.isBlocked)
        XCTAssertFalse(harness.watchdog.isScheduled)
        XCTAssertEqual(harness.recorder.events.first?.action, .report)
    }

    func testLowConfidenceDegradesBlockToWarn() {
        let harness = EngineHarness(detectors: [StubDetector(id: "x.y", category: .root, result: .hit(0.5))])
        _ = harness.start(runtime: runtimeConfig(["policies": ["ROOT": "BLOCK"]]))
        XCTAssertFalse(harness.engine.isBlocked)
        XCTAssertEqual(harness.recorder.events.first?.action, .warn)
    }

    func testUnsupportedDetectorRaisesNoEventAndIsListed() {
        let harness = EngineHarness(detectors: [StubDetector(id: "x.y", category: .root, result: .unsupported("n/a"))])
        _ = harness.start()
        XCTAssertTrue(harness.recorder.events.isEmpty)
        XCTAssertEqual(harness.engine.configDictionary()["unsupportedDetectors"] as? [String], ["x.y"])
    }

    func testAppliedConfigIsPersistedAndReplayedOnNextLaunch() {
        let first = EngineHarness()
        _ = first.start(runtime: runtimeConfig(seq: 8, ["policies": ["VPN_PROXY": "WARN"]]))
        XCTAssertEqual(first.store.stored?.seq, 8)

        let second = EngineHarness(store: first.store)
        _ = second.start()
        XCTAssertEqual(second.engine.currentConfig()?.policy(for: .vpnProxy), .warn)
        XCTAssertEqual(second.engine.currentConfig()?.seq, 8)
        XCTAssertTrue(second.engine.updateConfig(runtimeConfig(seq: 7)).error != nil)
    }

    func testProdDoesNotReplaySavedConfigWithoutBootstrapKey() {
        let store = MemoryConfigStore(seq: 3, config: runtimeConfig(seq: 3, ["policies": ["ROOT": "REPORT"]]))
        let harness = EngineHarness(channel: "prod", publicKey: nil, store: store)
        _ = harness.start()
        XCTAssertEqual(harness.engine.currentConfig()?.policy(for: .root), .block)
    }

    func testEventDictionaryCarriesContractFields() throws {
        let harness = EngineHarness(detectors: [StubDetector(id: "x.y", category: .tampering, result: .hit(confidence: 0.9, details: ["evidence": "e"]))])
        _ = harness.start()
        let dictionary = try XCTUnwrap(harness.recorder.events.first).dictionary
        XCTAssertEqual(dictionary["category"] as? String, "TAMPERING")
        XCTAssertEqual(dictionary["severity"] as? String, "CRITICAL")
        XCTAssertEqual(dictionary["detectorId"] as? String, "x.y")
        XCTAssertEqual(dictionary["platform"] as? String, "ios")
        XCTAssertEqual(dictionary["timestamp"] as? Int64, testNowMs)
        XCTAssertEqual((dictionary["details"] as? [String: String])?["evidence"], "e")
    }

    func testMonitoringStartStopIsIdempotent() {
        let harness = EngineHarness()
        harness.engine.startMonitoring()
        XCTAssertFalse(harness.engine.isMonitoring)
        _ = harness.start()
        harness.engine.startMonitoring()
        harness.engine.startMonitoring()
        XCTAssertTrue(harness.engine.isMonitoring)
        harness.engine.stopMonitoring()
        XCTAssertFalse(harness.engine.isMonitoring)
    }
}
