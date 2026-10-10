import Foundation

/// Compares every available identifier for the main bundle; they agree on an untouched build.
struct BundleIdDetector: Detector {
    let id = "tampering.bundleId"
    let category = ThreatCategory.tampering
    var infoBundleId: () -> String? = { Bundle.main.bundleIdentifier }
    var signatureId: () -> String? = { CodeSignature.mainExecutableIdentifier }
    var profile: () -> ProvisioningProfile? = { ProvisioningProfile.load() }

    func run(_ context: DetectorContext) -> DetectionResult {
        if Platform.isSimulator { return .unsupported(Platform.simulatorReason) }
        guard let bundleId = infoBundleId() else { return .unsupported("no CFBundleIdentifier") }
        let mismatches = Self.mismatches(bundleId: bundleId, pinned: context.bootstrap.pinnedBundleId,
                                         signature: signatureId(), profile: profile()?.profileBundleId)
        return mismatches.isEmpty ? .clear : .hit(0.95, evidence: mismatches.joined(separator: ","))
    }

    static func mismatches(bundleId: String, pinned: String?, signature: String?, profile: String?) -> [String] {
        [("pinned", pinned), ("codeSignature", signature), ("provisioningProfile", profile)]
            .compactMap { source, value in value.flatMap { $0 == bundleId ? nil : source } }
    }
}

/// Observed team (keychain access group, else provisioning profile) vs the pinned bootstrap team.
struct TeamIdDetector: Detector {
    let id = "tampering.teamId"
    let category = ThreatCategory.tampering
    var keychainTeam: () -> String? = KeychainTeam.teamId
    var profile: () -> ProvisioningProfile? = { ProvisioningProfile.load() }

    func run(_ context: DetectorContext) -> DetectionResult {
        if Platform.isSimulator { return .unsupported(Platform.simulatorReason) }
        guard let expected = context.bootstrap.teamId else { return .unsupported("MobileShieldTeamId not set in Info.plist") }
        return Self.evaluate(expected: expected, keychain: keychainTeam(), profileTeams: profile()?.teamIds ?? [])
    }

    static func evaluate(expected: String, keychain: String?, profileTeams: [String]) -> DetectionResult {
        if let keychain = keychain {
            if keychain != expected { return .hit(0.95, evidence: "keychainGroup") }
            if !profileTeams.isEmpty && !profileTeams.contains(expected) { return .hit(0.9, evidence: "profileDisagrees") }
            return .clear
        }
        guard !profileTeams.isEmpty else { return .unsupported("neither keychain group nor provisioning profile available") }
        return profileTeams.contains(expected) ? .clear : .hit(0.9, evidence: "provisioningProfile")
    }
}

/// Experimental: flags distribution modes the channel does not expect (see docs/detectors).
struct ProvisioningDetector: Detector {
    let id = "tampering.provisioning"
    let category = ThreatCategory.tampering
    var profile: () -> ProvisioningProfile? = { ProvisioningProfile.load() }
    var receiptName: () -> String? = { Bundle.main.appStoreReceiptURL?.lastPathComponent }

    func run(_ context: DetectorContext) -> DetectionResult {
        let mode = ProvisioningProfile.classify(profile(), receiptName: receiptName(), simulator: Platform.isSimulator)
        return Self.evaluate(mode: mode, bootstrap: context.bootstrap)
    }

    static func allowed(for bootstrap: Bootstrap) -> Set<String> {
        if let configured = bootstrap.allowedDistributions { return configured }
        if bootstrap.isProd { return [DistributionMode.appStore.rawValue, DistributionMode.testFlight.rawValue] }
        return Set([DistributionMode.appStore, .testFlight, .enterprise, .adHoc, .development].map { $0.rawValue })
    }

    static func evaluate(mode: DistributionMode, bootstrap: Bootstrap) -> DetectionResult {
        if mode == .simulator { return .unsupported(Platform.simulatorReason) }
        if allowed(for: bootstrap).contains(mode.rawValue) { return .clear }
        switch mode {
        case .development: return .hit(0.7, evidence: mode.rawValue)
        case .enterprise, .adHoc: return .hit(0.6, evidence: mode.rawValue)
        default: return .hit(0.5, evidence: mode.rawValue)
        }
    }
}
