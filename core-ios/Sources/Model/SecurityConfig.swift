import Foundation

/// Effective configuration after bootstrap + channel defaults + host config + floor.
struct SecurityConfig: Equatable {
    var channel: String
    var policies: [ThreatCategory: Action]
    var disabled: Set<String>
    var blockThreshold: Double
    var monitoringIntervalMs: Int64
    var killDelayMs: ClosedRange<Int64>
    var installerAllowlist: [String]
    var seq: Int64
    var clamped: [String]

    static func defaults(channel: String) -> SecurityConfig {
        SecurityConfig(
            channel: channel,
            policies: Defaults.policies(channel: channel),
            disabled: [],
            blockThreshold: Defaults.blockThreshold,
            monitoringIntervalMs: Defaults.monitoringIntervalMs,
            killDelayMs: Defaults.killDelayMs,
            installerAllowlist: Defaults.installerAllowlist,
            seq: 0,
            clamped: [])
    }

    func policy(for category: ThreatCategory) -> Action { policies[category] ?? .report }

    func isEnabled(_ detectorId: String) -> Bool { !disabled.contains(detectorId) }

    var dictionary: NSDictionary {
        var policyMap: [String: String] = [:]
        for (category, action) in policies { policyMap[category.rawValue] = action.rawValue }
        return [
            "channel": channel,
            "policies": policyMap,
            "disabled": disabled.sorted(),
            "blockThreshold": blockThreshold,
            "monitoringIntervalMs": monitoringIntervalMs,
            "killDelayMsRange": [killDelayMs.lowerBound, killDelayMs.upperBound],
            "installerAllowlist": installerAllowlist,
            "seq": seq,
            "clamped": clamped,
        ]
    }
}
