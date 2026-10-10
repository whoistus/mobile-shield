import Foundation

struct SimulatorDetector: Detector {
    let id = "simulator"
    let category = ThreatCategory.emulator
    var isSimulator = Platform.isSimulator

    func run(_ context: DetectorContext) -> DetectionResult {
        isSimulator ? .hit(1.0, evidence: "targetEnvironment(simulator)") : .clear
    }
}
