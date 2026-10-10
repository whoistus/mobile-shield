import CFNetwork
import Foundation

struct NetworkProxyDetector: Detector {
    let id = "network.proxy"
    let category = ThreatCategory.vpnProxy
    var settings: () -> [String: Any]? = {
        CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]
    }

    static let flags = ["HTTPEnable", "HTTPSEnable", "SOCKSEnable", "ProxyAutoConfigEnable"]

    func run(_ context: DetectorContext) -> DetectionResult {
        guard let settings = settings() else { return .unsupported("no proxy settings") }
        let active = Self.flags.first { (settings[$0] as? NSNumber)?.intValue == 1 }
        return active.map { .hit(0.7, evidence: $0) } ?? .clear
    }
}
