import Foundation

/// Fan-out with a small backlog: events raised while nobody listens (init's first synchronous
/// check runs before a wrapper subscribes) go to the first listener that registers.
final class EventBus {
    static let backlogLimit = 64

    private let lock = NSLock()
    private var listeners: [UUID: (ThreatEvent) -> Void] = [:]
    private var backlog: [ThreatEvent] = []

    func add(_ listener: @escaping (ThreatEvent) -> Void) -> UUID {
        let token = UUID()
        lock.lock()
        let pending = listeners.isEmpty ? backlog : []
        backlog.removeAll()
        listeners[token] = listener
        lock.unlock()
        pending.forEach(listener)
        return token
    }

    func remove(_ token: UUID) {
        lock.lock(); listeners.removeValue(forKey: token); lock.unlock()
    }

    func publish(_ event: ThreatEvent) {
        lock.lock()
        let targets = Array(listeners.values)
        if targets.isEmpty {
            backlog.append(event)
            if backlog.count > Self.backlogLimit { backlog.removeFirst() }
        }
        lock.unlock()
        targets.forEach { $0(event) }
    }
}
