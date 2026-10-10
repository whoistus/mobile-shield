import XCTest
@testable import MobileShieldCore

final class MonitorTests: XCTestCase {
    func testTicksWhileActiveAndStops() {
        let ticked = expectation(description: "tick")
        ticked.expectedFulfillmentCount = 2
        ticked.assertForOverFulfill = false
        let monitor = Monitor { ticked.fulfill() }
        monitor.start(intervalMs: 20, active: true)
        XCTAssertTrue(monitor.isStarted && monitor.isRunning)
        wait(for: [ticked], timeout: 2)
        monitor.stop()
        XCTAssertFalse(monitor.isStarted)
    }

    func testStartedInactiveDoesNotTickUntilActivated() {
        var ticks = 0
        let lock = NSLock()
        let activated = expectation(description: "tick after activation")
        activated.assertForOverFulfill = false
        let monitor = Monitor { lock.lock(); ticks += 1; lock.unlock(); activated.fulfill() }
        monitor.start(intervalMs: 20, active: false)
        XCTAssertFalse(monitor.isRunning)
        let quiet = expectation(description: "quiet period")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { quiet.fulfill() }
        wait(for: [quiet], timeout: 2)
        lock.lock(); XCTAssertEqual(ticks, 0); lock.unlock()
        monitor.setActive(true)
        wait(for: [activated], timeout: 2)
        monitor.stop()
    }

    func testPauseAndResumeAreBalancedAndStopAfterPauseIsSafe() {
        let monitor = Monitor {}
        monitor.start(intervalMs: 20, active: true)
        monitor.setActive(false)
        XCTAssertFalse(monitor.isRunning)
        monitor.setActive(false)
        monitor.setActive(true)
        XCTAssertTrue(monitor.isRunning)
        monitor.setActive(false)
        monitor.stop()
        XCTAssertFalse(monitor.isStarted)
    }

    func testStartIsIdempotent() {
        let monitor = Monitor {}
        monitor.start(intervalMs: 50, active: true)
        monitor.start(intervalMs: 50, active: true)
        monitor.stop()
        monitor.stop()
    }
}
