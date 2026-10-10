import XCTest
@testable import MobileShieldCore

final class WatchdogTests: XCTestCase {
    func testTerminatesAfterChosenDelay() {
        let fired = expectation(description: "terminate")
        let watchdog = Watchdog(random: { _ in 20 }, terminate: { fired.fulfill() })
        XCTAssertTrue(watchdog.schedule(delayMs: 10...50))
        XCTAssertTrue(watchdog.isScheduled)
        XCTAssertEqual(watchdog.scheduledDelayMs, 20)
        wait(for: [fired], timeout: 2)
    }

    func testDelayIsDrawnFromTheConfiguredRange() {
        var seen: ClosedRange<Int64>?
        let watchdog = Watchdog(random: { seen = $0; return $0.upperBound }, terminate: {})
        watchdog.schedule(delayMs: 500...3000)
        XCTAssertEqual(seen, 500...3000)
        XCTAssertEqual(watchdog.scheduledDelayMs, 3000)
    }

    func testSecondScheduleIsIgnoredAndTerminatesOnce() {
        let fired = expectation(description: "terminate once")
        fired.assertForOverFulfill = true
        let watchdog = Watchdog(random: { _ in 10 }, terminate: { fired.fulfill() })
        XCTAssertTrue(watchdog.schedule(delayMs: 0...10))
        XCTAssertFalse(watchdog.schedule(delayMs: 0...10))
        wait(for: [fired], timeout: 2)
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settle.fulfill() }
        wait(for: [settle], timeout: 2)
    }

    func testNegativeRandomIsClampedToZero() {
        let watchdog = Watchdog(random: { _ in -5 }, terminate: {})
        watchdog.schedule(delayMs: 0...1)
        XCTAssertEqual(watchdog.scheduledDelayMs, 0)
    }

    func testNotScheduledByDefault() {
        let watchdog = Watchdog(terminate: {})
        XCTAssertFalse(watchdog.isScheduled)
        XCTAssertNil(watchdog.scheduledDelayMs)
    }

    func testKillActionSchedulesWatchdogAndStopMonitoringDoesNotCancelIt() {
        let harness = EngineHarness(detectors: [
            StubDetector(id: "host.custom", category: .hooking, result: .hit(0.9)),
        ])
        let fired = expectation(description: "kill fires after stopMonitoring")
        harness.terminated = { fired.fulfill() }
        _ = harness.start(runtime: runtimeConfig(["policies": ["HOOKING": "KILL"], "killDelayMsRange": [30, 30]]))
        XCTAssertTrue(harness.watchdog.isScheduled)
        XCTAssertTrue(harness.engine.isBlocked)
        harness.engine.startMonitoring()
        harness.engine.stopMonitoring()
        XCTAssertTrue(harness.watchdog.isScheduled)
        wait(for: [fired], timeout: 2)
    }

    func testBlockNeverSchedulesWatchdog() {
        let harness = EngineHarness(detectors: [StubDetector(id: "host.custom", category: .root, result: .hit(0.9))])
        _ = harness.start(runtime: runtimeConfig(["policies": ["ROOT": "BLOCK"]]))
        XCTAssertTrue(harness.engine.isBlocked)
        XCTAssertFalse(harness.watchdog.isScheduled)
    }
}
