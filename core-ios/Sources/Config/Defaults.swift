import Foundation

/// Compiled-in defaults from design.md: channel table, prod floor, launch tiers.
enum Defaults {
    static let blockThreshold = 0.7
    static let monitoringIntervalMs: Int64 = 5000
    static let monitoringIntervalMinMs: Int64 = 1000
    static let killDelayMs: ClosedRange<Int64> = 500...3000

    static let installerAllowlist = [
        "com.android.vending", "com.huawei.appmarket", "com.xiaomi.market", "com.xiaomi.mipicks",
        "com.sec.android.app.samsungapps", "com.amazon.venezia", "com.heytap.market",
        "com.oppo.market", "com.bbk.appstore", "com.hihonor.appmarket",
    ]

    /// Detector ids that a prod-channel config can never disable.
    static let floorIds: Set<String> = ["tampering.bundleId", "tampering.teamId"]
    static let minTamperingOnProd: Action = .warn

    /// Experimental-tier ids: always REPORT until promoted in a release.
    static let experimentalIds: Set<String> = [
        "jailbreak.dyldImages", "jailbreak.dyldEnv", "hooking.fridaImages", "hooking.fridaPort",
        "hooking.prologue", "tampering.provisioning",
    ]

    /// Anything missing or unknown fails closed to prod.
    static func channel(_ raw: String?) -> String {
        guard let raw = raw, raw == "dev" || raw == "test" else { return "prod" }
        return raw
    }

    static func policies(channel: String) -> [ThreatCategory: Action] {
        var map = Dictionary(uniqueKeysWithValues: ThreatCategory.allCases.map { ($0, Action.report) })
        switch channel {
        case "dev":
            break
        case "test":
            for category in [ThreatCategory.root, .debugger, .hooking, .tampering] { map[category] = .warn }
        default:
            map[.root] = .block
            map[.emulator] = .block
            map[.tampering] = .block
            for category in [ThreatCategory.debugger, .hooking, .installer, .screenCapture, .devOptionsAdb, .noDeviceLock] {
                map[category] = .warn
            }
        }
        return map
    }
}
