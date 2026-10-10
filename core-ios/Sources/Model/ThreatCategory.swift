enum ThreatCategory: String, CaseIterable {
    case root = "ROOT"
    case emulator = "EMULATOR"
    case debugger = "DEBUGGER"
    case hooking = "HOOKING"
    case tampering = "TAMPERING"
    case installer = "INSTALLER"
    case screenCapture = "SCREEN_CAPTURE"
    case devOptionsAdb = "DEV_OPTIONS_ADB"
    case noDeviceLock = "NO_DEVICE_LOCK"
    case vpnProxy = "VPN_PROXY"

    var severity: Severity {
        switch self {
        case .root, .debugger: return .high
        case .hooking, .tampering: return .critical
        case .emulator, .installer, .noDeviceLock: return .medium
        case .screenCapture, .devOptionsAdb, .vpnProxy: return .low
        }
    }
}
