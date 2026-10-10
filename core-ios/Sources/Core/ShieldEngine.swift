import Foundation
import UIKit

struct ConfigUpdate {
    let config: SecurityConfig?
    let error: ShieldError?
}

/// Runtime state and orchestration. One shared instance backs the ObjC facade; tests build their
/// own with injected store, clock, detectors and watchdog.
final class ShieldEngine {
    static let shared = ShieldEngine()

    struct Dependencies {
        var bootstrap: () -> Bootstrap = { Bootstrap.current() }
        var store: ConfigStoring = FileConfigStore()
        var now: () -> Date = Date.init
        var watchdog = Watchdog()
        var detectors: (Bootstrap) -> [Detector] = DetectorRegistry.all
        var isAppActive: () -> Bool = { Platform.mainSync { Platform.application?.applicationState == .active } }
        var observeLifecycle = true
    }

    private struct State {
        let bootstrap: Bootstrap
        var config: SecurityConfig
        let detectors: [Detector]
        var unsupported: [String: String] = [:]
        var appliedSeq: Int64?
    }

    private let deps: Dependencies
    private let bus = EventBus()
    private let lock = NSLock()
    /// Serialises init and config apply so the seq check-and-set is atomic and a second `init`
    /// cannot return before last-known-good is restored. Recursive: listeners may call back in.
    private let configLock = NSRecursiveLock()
    private var state: State?
    private var blocked = false
    private let monitor = Monitor()
    private var lifecycleTokens: [NSObjectProtocol] = []

    init(_ dependencies: Dependencies = Dependencies()) {
        deps = dependencies
        monitor.tick = { [weak self] in _ = self?.runChecks() }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    var isBlocked: Bool { locked { blocked } }
    var isInitialized: Bool { locked { state != nil } }
    var isMonitoring: Bool { monitor.isStarted }

    @discardableResult
    func addListener(_ listener: @escaping (ThreatEvent) -> Void) -> UUID { bus.add(listener) }
    func removeListener(_ token: UUID) { bus.remove(token) }

    func initialize(runtime: [String: Any]?, sdkVersion: String) -> (environment: EnvironmentInfo, error: ShieldError?) {
        configLock.lock()
        let isFirst = locked { () -> Bool in
            guard state == nil else { return false }
            let bootstrap = deps.bootstrap()
            state = State(bootstrap: bootstrap, config: .defaults(channel: bootstrap.channel), detectors: deps.detectors(bootstrap))
            return true
        }
        if isFirst { setUp() }
        configLock.unlock()
        let failure = runtime.flatMap { updateConfig($0).error }
        _ = runChecks()
        return (environment(sdkVersion: sdkVersion), failure)
    }

    private func setUp() {
        let detectors = locked { state?.detectors ?? [] }
        let sink: ThreatSink = { [weak self] category, id, confidence, details in
            _ = self?.emit(category, id, confidence, details)
        }
        for detector in detectors { (detector as? ObservingDetector)?.startObserving(sink) }
        if deps.observeLifecycle { observeLifecycle() }
        let bootstrap = locked { state?.bootstrap }
        if let saved = deps.store.load(), let bootstrap = bootstrap, !bootstrap.isProd || bootstrap.configPublicKey != nil {
            _ = apply(saved.config, persist: false)
        }
    }

    private func observeLifecycle() {
        let center = NotificationCenter.default
        lifecycleTokens.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.monitor.setActive(false)
        })
        lifecycleTokens.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.monitor.setActive(true)
        })
    }

    func updateConfig(_ runtime: [String: Any]) -> ConfigUpdate {
        guard let bootstrap = locked({ state?.bootstrap }) else { return ConfigUpdate(config: nil, error: .notInitialized) }
        if bootstrap.isProd && bootstrap.configPublicKey == nil {
            return ConfigUpdate(config: currentConfig(), error: .bootstrapMissing("production runtime config requires a public key"))
        }
        return apply(runtime, persist: true)
    }

    private func apply(_ runtime: [String: Any], persist: Bool) -> ConfigUpdate {
        configLock.lock(); defer { configLock.unlock() }
        guard let (bootstrap, known) = locked({ state.map { ($0.bootstrap, $0.appliedSeq) } }) else {
            return ConfigUpdate(config: nil, error: .notInitialized)
        }
        let stored = deps.store.load()?.seq
        let lastKnown = [stored, known].compactMap { $0 }.max()
        let result = ConfigEngine.apply(bootstrap: bootstrap, lastKnownSeq: lastKnown,
                                        nowMs: Self.millis(deps.now()), config: runtime)
        if let applied = result.applied {
            locked { state?.config = applied; state?.appliedSeq = applied.seq }
            if persist { deps.store.save(runtime, seq: applied.seq) }
            monitor.reschedule(intervalMs: applied.monitoringIntervalMs)
        }
        for event in result.events { _ = emit(event.category, event.detectorId, event.confidence, [:]) }
        let error = result.reason.map { ShieldError.configRejected($0, result.message) }
        return ConfigUpdate(config: currentConfig(), error: error)
    }

    func currentConfig() -> SecurityConfig? { locked { state?.config } }

    func configDictionary() -> NSDictionary {
        guard let (config, unsupported) = locked({ state.map { ($0.config, $0.unsupported) } }) else { return [:] }
        let merged = NSMutableDictionary(dictionary: config.dictionary)
        merged["unsupportedDetectors"] = unsupported.keys.sorted()
        return merged
    }

    @discardableResult
    func runChecks() -> [ThreatEvent] {
        guard let snapshot = locked({ state.map { ($0.bootstrap, $0.detectors) } }) else { return [] }
        let context = DetectorContext(bootstrap: snapshot.0)
        var events: [ThreatEvent] = []
        for detector in snapshot.1 {
            guard locked({ state?.config.isEnabled(detector.id) ?? false }) else { continue }
            let result = autoreleasepool { detector.run(context) }
            switch result {
            case .clear:
                locked { _ = state?.unsupported.removeValue(forKey: detector.id) }
            case .unsupported(let reason):
                locked { state?.unsupported[detector.id] = reason }
            case .hit(let confidence, let details):
                locked { _ = state?.unsupported.removeValue(forKey: detector.id) }
                if let event = emit(detector.category, detector.id, confidence, details) { events.append(event) }
            }
        }
        return events
    }

    /// The single decision point: policy, sticky block flag, watchdog, then delivery. Listeners
    /// run outside the lock.
    func emit(_ category: ThreatCategory, _ id: String, _ confidence: Double, _ details: [String: String]) -> ThreatEvent? {
        guard confidence > 0 else { return nil }
        var killRange: ClosedRange<Int64>?
        let event: ThreatEvent? = locked {
            guard let current = state else { return nil }
            if !id.hasPrefix("policy.") && !current.config.isEnabled(id) { return nil }
            let score = min(confidence, 1)
            let action = Policy.decide(category: category, detectorId: id, confidence: score, config: current.config)
            if action.isEnforcing { blocked = true }
            if action == .kill { killRange = current.config.killDelayMs }
            return ThreatEvent(category: category, detectorId: id, confidence: score, action: action,
                               timestampMs: Self.millis(deps.now()), details: details)
        }
        guard let event = event else { return nil }
        if let range = killRange { deps.watchdog.schedule(delayMs: range) }
        bus.publish(event)
        return event
    }

    func startMonitoring() {
        guard let interval = locked({ state?.config.monitoringIntervalMs }) else { return }
        monitor.start(intervalMs: interval, active: deps.isAppActive())
    }

    /// Does not touch the watchdog: a scheduled kill stays scheduled.
    func stopMonitoring() { monitor.stop() }

    private func environment(sdkVersion: String) -> EnvironmentInfo {
        let profile = ProvisioningProfile.load()
        let mode = ProvisioningProfile.classify(profile, receiptName: Bundle.main.appStoreReceiptURL?.lastPathComponent,
                                                simulator: Platform.isSimulator)
        return EnvironmentInfo(sdkVersion: sdkVersion, osVersion: UIDevice.current.systemVersion, abi: EnvironmentInfo.currentAbi,
                               isDebuggable: profile?.getTaskAllow ?? false,
                               installer: mode == .unknown ? nil : mode.rawValue)
    }

    private static func millis(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }
}
