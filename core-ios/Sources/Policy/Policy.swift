import Foundation

enum Policy {
    /// Applied action for a hit. Experimental ids are forced to REPORT; BLOCK/KILL below
    /// `blockThreshold` degrades to WARN. Unknown ids are treated as prod tier.
    static func decide(category: ThreatCategory, detectorId: String, confidence: Double, config: SecurityConfig) -> Action {
        if Defaults.experimentalIds.contains(detectorId) { return .report }
        let action = config.policy(for: category)
        if action.isEnforcing && confidence < config.blockThreshold { return .warn }
        // Config-protocol events (policy.floor, policy.badSignature) never block or kill.
        if action.isEnforcing && detectorId.hasPrefix("policy.") { return .warn }
        return action
    }
}
