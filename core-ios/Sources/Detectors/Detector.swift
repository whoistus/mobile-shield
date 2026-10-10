import Foundation

enum DetectionResult: Equatable {
    case clear
    case hit(confidence: Double, details: [String: String])
    /// The detector cannot judge on this device/build. No event is raised, and absence of an
    /// event is never proof of a clean device.
    case unsupported(String)

    static func hit(_ confidence: Double, evidence: String? = nil) -> DetectionResult {
        .hit(confidence: confidence, details: evidence.map { ["evidence": $0] } ?? [:])
    }
}

struct DetectorContext {
    let bootstrap: Bootstrap
}

protocol Detector {
    var id: String { get }
    var category: ThreatCategory { get }
    func run(_ context: DetectorContext) -> DetectionResult
}

typealias ThreatSink = (ThreatCategory, String, Double, [String: String]) -> Void

/// Detectors that also push events between monitoring cycles (notifications).
protocol ObservingDetector: Detector {
    func startObserving(_ sink: @escaping ThreatSink)
}
