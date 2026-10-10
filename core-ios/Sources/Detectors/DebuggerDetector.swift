import Foundation

struct DebuggerDetector: Detector {
    let id = "debugger.ptraced"
    let category = ThreatCategory.debugger

    func run(_ context: DetectorContext) -> DetectionResult {
        switch Self.isTraced() {
        case .some(true): return .hit(0.95, evidence: "P_TRACED")
        case .some(false): return .clear
        case .none: return .unsupported("sysctl failed")
        }
    }

    static func isTraced() -> Bool? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&name, u_int(name.count), &info, &size, nil, 0) == 0 else { return nil }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
