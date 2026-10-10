import Foundation

/// Reasons for `ConfigRejected`; raw values are identical on every platform.
enum ConfigReason: String {
    case signature, floor, schema, expired
}

/// Typed SDK errors. Codes match `MSErrorCode` in MobileShield.h.
enum ShieldError: Error, Equatable {
    case nativeUnavailable(String)
    case notInitialized
    case bootstrapMissing(String)
    case configRejected(ConfigReason, String)
    case detectorUnsupported(String)
    case attestationUnsupported(String)

    static let domain = "io.mobileshield"

    private var code: Int {
        switch self {
        case .nativeUnavailable: return 1
        case .notInitialized: return 2
        case .bootstrapMissing: return 3
        case .configRejected: return 4
        case .detectorUnsupported: return 5
        case .attestationUnsupported: return 6
        }
    }

    /// Stable string used by wrappers as the rejection code.
    var reason: String {
        switch self {
        case .nativeUnavailable: return "NativeUnavailable"
        case .notInitialized: return "NotInitialized"
        case .bootstrapMissing: return "BootstrapMissing"
        case .configRejected(let why, _): return "ConfigRejected.\(why.rawValue)"
        case .detectorUnsupported: return "DetectorUnsupported"
        case .attestationUnsupported: return "AttestationUnsupported"
        }
    }

    private var message: String {
        switch self {
        case .notInitialized: return "call init first"
        case .nativeUnavailable(let m), .bootstrapMissing(let m), .detectorUnsupported(let m),
             .attestationUnsupported(let m), .configRejected(_, let m):
            return m
        }
    }

    var nsError: NSError {
        var info: [String: Any] = [NSLocalizedDescriptionKey: message, "reason": reason]
        if case .configRejected(let why, _) = self { info["configReason"] = why.rawValue }
        return NSError(domain: ShieldError.domain, code: code, userInfo: info)
    }
}
