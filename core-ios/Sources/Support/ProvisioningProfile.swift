import Foundation

enum DistributionMode: String {
    case appStore, testFlight, enterprise, adHoc, development, simulator, unknown
}

/// Fields of embedded.mobileprovision (a CMS envelope around an XML plist). The envelope's
/// signature was already verified by iOS at install time; only the plist payload is read.
struct ProvisioningProfile: Equatable {
    var teamIds: [String] = []
    var applicationIdentifier: String?
    var getTaskAllow = false
    var provisionsAllDevices = false
    var hasDevices = false

    static func load(bundle: Bundle = .main) -> ProvisioningProfile? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        return parse(data)
    }

    static func parse(_ data: Data) -> ProvisioningProfile? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), options: .backwards),
              start.lowerBound < end.upperBound,
              let plist = (try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil))
                as? [String: Any] else { return nil }
        let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
        var profile = ProvisioningProfile()
        profile.teamIds = (plist["TeamIdentifier"] as? [String] ?? []).map { $0.uppercased() }
        if profile.teamIds.isEmpty, let team = entitlements["com.apple.developer.team-identifier"] as? String {
            profile.teamIds = [team.uppercased()]
        }
        profile.applicationIdentifier = entitlements["application-identifier"] as? String
        profile.getTaskAllow = entitlements["get-task-allow"] as? Bool ?? false
        profile.provisionsAllDevices = plist["ProvisionsAllDevices"] as? Bool ?? false
        profile.hasDevices = !(plist["ProvisionedDevices"] as? [Any] ?? []).isEmpty
        return profile
    }

    /// Bundle id part of `TEAMID.bundle.id`; nil for wildcard profiles (`TEAMID.*`).
    var profileBundleId: String? {
        guard let value = applicationIdentifier, let dot = value.firstIndex(of: ".") else { return nil }
        let id = String(value[value.index(after: dot)...])
        return id.hasSuffix("*") ? nil : id
    }

    /// `receiptName` is `Bundle.main.appStoreReceiptURL?.lastPathComponent`.
    static func classify(_ profile: ProvisioningProfile?, receiptName: String?, simulator: Bool) -> DistributionMode {
        if simulator { return .simulator }
        if let profile = profile {
            if profile.provisionsAllDevices { return .enterprise }
            if profile.getTaskAllow { return .development }
            return profile.hasDevices ? .adHoc : .unknown
        }
        switch receiptName {
        case "sandboxReceipt": return .testFlight
        case "receipt": return .appStore
        default: return .unknown
        }
    }
}
