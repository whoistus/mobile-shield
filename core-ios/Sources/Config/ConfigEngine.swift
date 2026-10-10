import Foundation

/// Pure config pipeline: signature, schema, freshness, merge, floor. No UIKit or global state,
/// so every shared vector runs without a device.
enum ConfigEngine {
    enum Status: String { case applied, clamped, rejected }

    struct PolicyEvent: Equatable {
        let category: ThreatCategory
        let detectorId: String
        let confidence: Double
    }

    struct Result {
        let status: Status
        let reason: ConfigReason?
        let applied: SecurityConfig?
        let events: [PolicyEvent]
        let message: String
    }

    static let floorEventId = "policy.floor"
    static let badSignatureEventId = "policy.badSignature"
    static let policyEventConfidence = 0.5

    static func apply(bootstrap: Bootstrap, lastKnownSeq: Int64?, nowMs: Int64, config: [String: Any]) -> Result {
        guard JSONSerialization.isValidJSONObject(config) else { return reject(.schema, "config is not a JSON object") }

        if let key = bootstrap.configPublicKey, !ConfigVerifier.verify(config, publicKey: key) {
            let event = PolicyEvent(category: .tampering, detectorId: badSignatureEventId, confidence: policyEventConfidence)
            return reject(.signature, "signature missing or invalid", [event])
        }
        guard JSONValue.int64(config["version"]) == 1 else { return reject(.schema, "version must be 1") }
        guard config["appId"] as? String == bootstrap.appId else { return reject(.schema, "appId does not match the bundle id") }
        guard let seq = JSONValue.int64(config["seq"]) else { return reject(.schema, "seq is required") }

        var next = SecurityConfig.defaults(channel: bootstrap.channel)
        next.seq = seq

        if let raw = config["policies"] {
            guard let policies = raw as? [String: Any] else { return reject(.schema, "policies must be an object") }
            for (name, value) in policies {
                guard let category = ThreatCategory(rawValue: name), let action = (value as? String).flatMap(Action.init(rawValue:)) else {
                    return reject(.schema, "bad policy \(name)")
                }
                next.policies[category] = action
            }
        }
        if let raw = config["detectors"] {
            guard let detectors = raw as? [String: Any] else { return reject(.schema, "detectors must be an object") }
            for (id, value) in detectors {
                guard JSONValue.isBool(value), let enabled = (value as? NSNumber)?.boolValue else {
                    return reject(.schema, "detector flag must be boolean: \(id)")
                }
                if !enabled { next.disabled.insert(id) }
            }
        }
        if let raw = config["blockThreshold"] {
            guard let threshold = JSONValue.double(raw), (0...1).contains(threshold) else {
                return reject(.schema, "blockThreshold must be within 0..1")
            }
            next.blockThreshold = threshold
        }
        if let raw = config["monitoringIntervalMs"] {
            guard let interval = JSONValue.int64(raw), interval >= Defaults.monitoringIntervalMinMs else {
                return reject(.schema, "monitoringIntervalMs below minimum")
            }
            next.monitoringIntervalMs = interval
        }
        if let raw = config["killDelayMsRange"] {
            guard let pair = raw as? [Any], pair.count == 2, let low = JSONValue.int64(pair[0]),
                  let high = JSONValue.int64(pair[1]), low >= 0, high >= low else {
                return reject(.schema, "bad killDelayMsRange")
            }
            next.killDelayMs = low...high
        }
        if let raw = config["installerAllowlist"] {
            guard let list = raw as? [String], !list.contains(where: { $0.isEmpty }) else {
                return reject(.schema, "bad installerAllowlist")
            }
            next.installerAllowlist = list
        }

        if let known = lastKnownSeq, seq < known { return reject(.expired, "seq older than last-known-good") }
        if let raw = config["expiresAt"], !(raw is NSNull) {
            guard let expiry = JSONValue.int64(raw) else { return reject(.schema, "expiresAt must be epoch ms") }
            if expiry <= nowMs { return reject(.expired, "config expired") }
        }

        if bootstrap.isProd {
            for id in Defaults.floorIds.sorted() where next.disabled.remove(id) != nil { next.clamped.append("detectors.\(id)") }
            if next.policy(for: .tampering) < Defaults.minTamperingOnProd {
                next.policies[.tampering] = Defaults.minTamperingOnProd
                next.clamped.append("policies.TAMPERING")
            }
        }
        guard next.clamped.isEmpty else {
            let event = PolicyEvent(category: .tampering, detectorId: floorEventId, confidence: policyEventConfidence)
            return Result(status: .clamped, reason: .floor, applied: next, events: [event], message: "clamped: \(next.clamped)")
        }
        return Result(status: .applied, reason: nil, applied: next, events: [], message: "applied")
    }

    private static func reject(_ reason: ConfigReason, _ message: String, _ events: [PolicyEvent] = []) -> Result {
        Result(status: .rejected, reason: reason, applied: nil, events: events, message: message)
    }
}
