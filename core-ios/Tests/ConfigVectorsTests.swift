import XCTest
@testable import MobileShieldCore

/// Runs every case in scripts/fixtures/config-vectors.json that targets iOS ("any" or "ios").
/// Read at test time so vectors added by the Android side are picked up without code changes.
final class ConfigVectorsTests: XCTestCase {
    private func loadFixture() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scripts/fixtures/config-vectors.json")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testSchemaVersionAndIosRegistryMatchCode() throws {
        let fixture = try loadFixture()
        XCTAssertEqual(fixture["schemaVersion"] as? Int, 1)
        let experimental = try XCTUnwrap((fixture["experimental"] as? [String: [String]])?["ios"])
        XCTAssertEqual(Set(experimental), Defaults.experimentalIds)
        let floor = try XCTUnwrap((fixture["floor"] as? [String: Any])?["ios"] as? [String])
        XCTAssertEqual(Set(floor), Defaults.floorIds)
        XCTAssertEqual((fixture["floor"] as? [String: Any])?["minTampering"] as? String, Defaults.minTamperingOnProd.rawValue)
        XCTAssertEqual((fixture["rules"] as? [String: Any])?["blockThresholdDefault"] as? Double, Defaults.blockThreshold)
    }

    func testEveryIosVector() throws {
        let fixture = try loadFixture()
        let appId = try XCTUnwrap(fixture["appId"] as? String)
        let publicKey = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(fixture["testPublicKeyEd25519"] as? String)))
        let vectors = try XCTUnwrap(fixture["vectors"] as? [[String: Any]])
        var executed = 0
        for vector in vectors {
            let platform = vector["platform"] as? String ?? "any"
            guard platform == "any" || platform == "ios" else { continue }
            executed += 1
            try run(vector, appId: appId, publicKey: publicKey)
        }
        XCTAssertGreaterThan(executed, 0)
        XCTAssertLessThanOrEqual(executed, vectors.count)
    }

    private func run(_ vector: [String: Any], appId: String, publicKey: Data) throws {
        let name = vector["name"] as? String ?? "?"
        let bootstrap = Bootstrap(
            appId: appId, channel: vector["channel"] as? String,
            configPublicKey: (vector["bootstrap"] as? [String: Any])?["pubkey"] as? Bool == true ? publicKey : nil)
        let lastKnown = (vector["lastKnownGoodSeq"] as? NSNumber)?.int64Value
        let nowMs = try XCTUnwrap((vector["now"] as? NSNumber)?.int64Value, name)
        let config = try XCTUnwrap(vector["config"] as? [String: Any], name)
        let expect = try XCTUnwrap(vector["expect"] as? [String: Any], name)

        let result = ConfigEngine.apply(bootstrap: bootstrap, lastKnownSeq: lastKnown, nowMs: nowMs, config: config)
        XCTAssertEqual(result.status.rawValue, expect["result"] as? String, "\(name): result")
        XCTAssertEqual(result.reason?.rawValue, expect["reason"] as? String, "\(name): reason")

        let effective = result.applied ?? SecurityConfig.defaults(channel: bootstrap.channel)
        if let policies = expect["policies"] as? [String: String] {
            let actual = Dictionary(uniqueKeysWithValues: effective.policies.map { ($0.key.rawValue, $0.value.rawValue) })
            XCTAssertEqual(actual, policies, "\(name): policies")
        }
        if let disabled = expect["disabled"] as? [String] {
            XCTAssertEqual(effective.disabled.sorted(), disabled.sorted(), "\(name): disabled")
        }

        let expectedEvents = expect["events"] as? [[String: Any]] ?? []
        XCTAssertEqual(result.events.count, expectedEvents.count, "\(name): event count")
        for (event, expected) in zip(result.events, expectedEvents) {
            XCTAssertEqual(event.category.rawValue, expected["category"] as? String, "\(name): event category")
            XCTAssertEqual(event.detectorId, expected["detectorId"] as? String, "\(name): event id")
            XCTAssertEqual(event.confidence, (expected["confidence"] as? NSNumber)?.doubleValue, "\(name): event confidence")
            let action = Policy.decide(category: event.category, detectorId: event.detectorId, confidence: event.confidence, config: effective)
            XCTAssertEqual(action.rawValue, expected["action"] as? String, "\(name): event action")
        }

        for decision in vector["decisions"] as? [[String: Any]] ?? [] {
            let target = decision["platform"] as? String ?? "any"
            guard target == "any" || target == "ios" else { continue }
            let category = try XCTUnwrap((decision["category"] as? String).flatMap(ThreatCategory.init(rawValue:)), name)
            let id = try XCTUnwrap(decision["detectorId"] as? String, name)
            let confidence = try XCTUnwrap((decision["confidence"] as? NSNumber)?.doubleValue, name)
            let action = Policy.decide(category: category, detectorId: id, confidence: confidence, config: effective)
            XCTAssertEqual(action.rawValue, decision["action"] as? String, "\(name): decision \(id)@\(confidence)")
        }
    }
}
