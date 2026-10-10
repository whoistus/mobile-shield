import Foundation

struct ThreatEvent: Equatable {
    let category: ThreatCategory
    let detectorId: String
    let confidence: Double
    let action: Action
    let timestampMs: Int64
    let details: [String: String]

    var severity: Severity { category.severity }

    var dictionary: NSDictionary {
        var value: [String: Any] = [
            "category": category.rawValue,
            "severity": severity.rawValue,
            "confidence": confidence,
            "detectorId": detectorId,
            "action": action.rawValue,
            "timestamp": timestampMs,
            "platform": "ios",
        ]
        if !details.isEmpty { value["details"] = details }
        return value as NSDictionary
    }
}
