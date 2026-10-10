import CryptoKit
import XCTest
@testable import MobileShieldCore

let testAppId = "io.mobileshield.example"
let testNowMs: Int64 = 1_800_000_000_000

final class MemoryConfigStore: ConfigStoring {
    var stored: StoredConfig?

    init(seq: Int64? = nil, config: [String: Any] = [:]) {
        stored = seq.map { StoredConfig(seq: $0, config: config) }
    }

    func load() -> StoredConfig? { stored }
    func save(_ config: [String: Any], seq: Int64) { stored = StoredConfig(seq: seq, config: config) }
}

enum TestSigner {
    static let key = Curve25519.Signing.PrivateKey()
    static var publicKey: Data { key.publicKey.rawRepresentation }

    static func sign(_ config: [String: Any], with signer: Curve25519.Signing.PrivateKey = key) -> [String: Any] {
        var body = config
        body.removeValue(forKey: "signature")
        let canonical = try! CanonicalJSON.string(from: body)
        body["signature"] = try! signer.signature(for: Data(canonical.utf8)).base64EncodedString()
        return body
    }
}

func runtimeConfig(seq: Int64 = 1, _ extra: [String: Any] = [:]) -> [String: Any] {
    var config: [String: Any] = ["version": 1, "appId": testAppId, "seq": seq]
    for (key, value) in extra { config[key] = value }
    return config
}

func applyConfig(_ config: [String: Any], channel: String? = "dev", publicKey: Data? = nil,
                 lastKnownSeq: Int64? = nil, nowMs: Int64 = testNowMs) -> ConfigEngine.Result {
    ConfigEngine.apply(bootstrap: Bootstrap(appId: testAppId, channel: channel, configPublicKey: publicKey),
                       lastKnownSeq: lastKnownSeq, nowMs: nowMs, config: config)
}

final class RunCounter {
    var count = 0
}

struct StubDetector: Detector {
    let id: String
    let category: ThreatCategory
    var result: DetectionResult
    var counter = RunCounter()

    func run(_ context: DetectorContext) -> DetectionResult {
        counter.count += 1
        return result
    }
}

final class EventRecorder {
    private let lock = NSLock()
    private var items: [ThreatEvent] = []

    var events: [ThreatEvent] { lock.lock(); defer { lock.unlock() }; return items }

    func record(_ event: ThreatEvent) { lock.lock(); items.append(event); lock.unlock() }
}

/// Engine wired with in-memory store, fixed clock, no UIKit observers and a non-exiting watchdog.
final class EngineHarness {
    let engine: ShieldEngine
    let store: MemoryConfigStore
    let watchdog: Watchdog
    let recorder = EventRecorder()
    var terminated: () -> Void = {}

    init(channel: String? = "dev", publicKey: Data? = nil, detectors: [Detector] = [],
         store: MemoryConfigStore = MemoryConfigStore(), killRandom: @escaping (ClosedRange<Int64>) -> Int64 = { $0.lowerBound }) {
        self.store = store
        let relay = TerminationRelay()
        watchdog = Watchdog(random: killRandom, terminate: { relay.fire() })
        var deps = ShieldEngine.Dependencies()
        deps.bootstrap = { Bootstrap(appId: testAppId, channel: channel, configPublicKey: publicKey) }
        deps.store = store
        deps.now = { Date(timeIntervalSince1970: Double(testNowMs) / 1000) }
        deps.watchdog = watchdog
        deps.detectors = { _ in detectors }
        deps.isAppActive = { true }
        deps.observeLifecycle = false
        engine = ShieldEngine(deps)
        relay.target = { [weak self] in self?.terminated() }
    }

    func start(runtime: [String: Any]? = nil) -> (environment: EnvironmentInfo, error: ShieldError?) {
        engine.addListener(recorder.record)
        return engine.initialize(runtime: runtime, sdkVersion: "test")
    }
}

private final class TerminationRelay {
    var target: () -> Void = {}
    func fire() { target() }
}
