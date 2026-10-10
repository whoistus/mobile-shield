import Foundation

/// The only path that terminates the process. Detectors and the policy never exit directly.
/// A scheduled kill is deliberately not cancellable: stopping monitoring must not defuse it.
final class Watchdog {
    private let queue: DispatchQueue
    private let random: (ClosedRange<Int64>) -> Int64
    private let terminate: () -> Void
    private let lock = NSLock()
    private var scheduled = false
    private var delay: Int64?

    init(queue: DispatchQueue = DispatchQueue(label: "io.mobileshield.watchdog", qos: .utility),
         random: @escaping (ClosedRange<Int64>) -> Int64 = { Int64.random(in: $0) },
         terminate: @escaping () -> Void = { _exit(0) }) {
        self.queue = queue
        self.random = random
        self.terminate = terminate
    }

    var isScheduled: Bool { lock.lock(); defer { lock.unlock() }; return scheduled }
    var scheduledDelayMs: Int64? { lock.lock(); defer { lock.unlock() }; return delay }

    /// Returns false when a kill is already pending; only the first call picks a delay.
    @discardableResult
    func schedule(delayMs range: ClosedRange<Int64>) -> Bool {
        lock.lock()
        if scheduled { lock.unlock(); return false }
        scheduled = true
        let chosen = max(0, random(range))
        delay = chosen
        lock.unlock()
        let terminate = self.terminate
        queue.asyncAfter(deadline: .now() + .milliseconds(Int(chosen))) { terminate() }
        return true
    }
}
