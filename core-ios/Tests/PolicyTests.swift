import XCTest
@testable import MobileShieldCore

final class PolicyTests: XCTestCase {
    private func decide(_ category: ThreatCategory, _ id: String, _ confidence: Double, channel: String = "prod",
                        policies: [ThreatCategory: Action] = [:], threshold: Double = 0.7) -> Action {
        var config = SecurityConfig.defaults(channel: channel)
        config.blockThreshold = threshold
        for (key, value) in policies { config.policies[key] = value }
        return Policy.decide(category: category, detectorId: id, confidence: confidence, config: config)
    }

    func testProdDefaultTable() {
        let expected: [ThreatCategory: Action] = [
            .root: .block, .emulator: .block, .debugger: .warn, .hooking: .warn, .tampering: .block,
            .installer: .warn, .screenCapture: .warn, .devOptionsAdb: .warn, .noDeviceLock: .warn, .vpnProxy: .report,
        ]
        XCTAssertEqual(Defaults.policies(channel: "prod"), expected)
    }

    func testDevAndTestDefaults() {
        XCTAssertTrue(Defaults.policies(channel: "dev").values.allSatisfy { $0 == .report })
        let test = Defaults.policies(channel: "test")
        for category in [ThreatCategory.root, .debugger, .hooking, .tampering] { XCTAssertEqual(test[category], .warn) }
        XCTAssertEqual(test[.emulator], .report)
    }

    func testMissingOrUnknownChannelFailsClosedToProd() {
        XCTAssertEqual(Defaults.channel(nil), "prod")
        XCTAssertEqual(Defaults.channel("staging"), "prod")
        XCTAssertEqual(Defaults.channel("dev"), "dev")
        XCTAssertEqual(Defaults.channel("test"), "test")
    }

    func testBlockAtOrAboveThreshold() {
        XCTAssertEqual(decide(.root, "jailbreak.paths", 0.9), .block)
        XCTAssertEqual(decide(.root, "jailbreak.paths", 0.7), .block)
    }

    func testBelowThresholdDegradesToWarn() {
        XCTAssertEqual(decide(.root, "jailbreak.paths", 0.69), .warn)
        XCTAssertEqual(decide(.hooking, "custom", 0.6, policies: [.hooking: .kill]), .warn)
    }

    func testReportAndWarnAreNotAffectedByThreshold() {
        XCTAssertEqual(decide(.vpnProxy, "network.proxy", 0.1), .report)
        XCTAssertEqual(decide(.debugger, "debugger.ptraced", 0.1), .warn)
    }

    func testExperimentalIdsAreForcedToReport() {
        for id in Defaults.experimentalIds {
            XCTAssertEqual(decide(.root, id, 1.0, policies: [.root: .kill]), .report, id)
        }
    }

    func testUnknownIdsAreProdTier() {
        XCTAssertEqual(decide(.hooking, "host.custom", 0.8, policies: [.hooking: .kill]), .kill)
    }

    func testKillIsNeverADefault() {
        for channel in ["dev", "test", "prod"] {
            XCTAssertFalse(Defaults.policies(channel: channel).values.contains(.kill), channel)
        }
    }

    func testCustomThresholdIsHonoured() {
        XCTAssertEqual(decide(.root, "jailbreak.paths", 0.8, threshold: 0.9), .warn)
        XCTAssertEqual(decide(.root, "jailbreak.paths", 0.8, threshold: 0.5), .block)
    }

    func testRegistryTiersMatchDesign() {
        XCTAssertEqual(Defaults.experimentalIds, [
            "jailbreak.dyldImages", "jailbreak.dyldEnv", "hooking.fridaImages", "hooking.fridaPort",
            "hooking.prologue", "tampering.provisioning",
        ])
        XCTAssertEqual(Defaults.floorIds, ["tampering.bundleId", "tampering.teamId"])
        XCTAssertTrue(Defaults.floorIds.isDisjoint(with: Defaults.experimentalIds))
    }

    func testActionOrderingAndEnforcement() {
        XCTAssertTrue(Action.report < .warn && Action.warn < .block && Action.block < .kill)
        XCTAssertFalse(Action.warn.isEnforcing)
        XCTAssertTrue(Action.block.isEnforcing && Action.kill.isEnforcing)
    }
}
