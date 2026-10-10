import Foundation

/// Foreground-only timer on a background queue. Suspends while the app is inactive and fires one
/// cycle on resume.
final class Monitor {
    private let queue = DispatchQueue(label: "io.mobileshield.monitor", qos: .utility)
    private let lock = NSLock()
    /// Set once before `start`; never mutated while a timer exists.
    var tick: () -> Void
    private var timer: DispatchSourceTimer?
    private var running = false

    init(tick: @escaping () -> Void = {}) { self.tick = tick }

    var isStarted: Bool { lock.lock(); defer { lock.unlock() }; return timer != nil }
    var isRunning: Bool { lock.lock(); defer { lock.unlock() }; return running }

    func start(intervalMs: Int64, active: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard timer == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.setEventHandler { [weak self] in self?.tick() }
        schedule(source, intervalMs)
        timer = source
        if active { source.resume(); running = true }
    }

    func setActive(_ active: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard let source = timer else { return }
        if active && !running {
            source.resume()
            running = true
            queue.async { [weak self] in self?.tick() }
        } else if !active && running {
            source.suspend()
            running = false
        }
    }

    func reschedule(intervalMs: Int64) {
        lock.lock(); defer { lock.unlock() }
        if let source = timer { schedule(source, intervalMs) }
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        guard let source = timer else { return }
        timer = nil
        // A never-resumed or suspended source must be resumed before release.
        if !running { source.resume() }
        source.cancel()
        running = false
    }

    private func schedule(_ source: DispatchSourceTimer, _ intervalMs: Int64) {
        let interval = DispatchTimeInterval.milliseconds(Int(intervalMs))
        source.schedule(deadline: .now() + interval, repeating: interval)
    }
}
