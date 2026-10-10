import Foundation
import LocalAuthentication

struct DeviceLockDetector: Detector {
    let id = "devicelock.absent"
    let category = ThreatCategory.noDeviceLock

    func run(_ context: DetectorContext) -> DetectionResult {
        let laContext = LAContext()
        var error: NSError?
        if laContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) { return .clear }
        guard let code = error?.code else { return .unsupported("no LocalAuthentication verdict") }
        return code == LAError.passcodeNotSet.rawValue ? .hit(0.8, evidence: "passcodeNotSet") : .unsupported("LAError \(code)")
    }
}
