import Foundation

/// Immutable values read from the host's signed bundle (Info.plist), never from JS/Dart.
struct Bootstrap {
    static let channelKey = "MobileShieldChannel"
    static let publicKeyKey = "MobileShieldConfigPubKey"
    static let teamIdKey = "MobileShieldTeamId"
    static let bundleIdKey = "MobileShieldBundleId"
    static let distributionKey = "MobileShieldDistribution"

    let appId: String
    let channel: String
    /// nil = key absent. An empty value means a key was configured but is not a valid 32-byte
    /// Ed25519 key; verification then fails closed instead of silently accepting unsigned configs.
    let configPublicKey: Data?
    let teamId: String?
    let pinnedBundleId: String?
    let allowedDistributions: Set<String>?

    var isProd: Bool { channel == "prod" }

    init(appId: String, channel: String? = nil, configPublicKey: Data? = nil, teamId: String? = nil,
         pinnedBundleId: String? = nil, allowedDistributions: Set<String>? = nil) {
        self.appId = appId
        self.channel = Defaults.channel(channel)
        self.configPublicKey = configPublicKey
        self.teamId = teamId
        self.pinnedBundleId = pinnedBundleId
        self.allowedDistributions = allowedDistributions
    }

    init(info: [String: Any], bundleId: String?) {
        func text(_ key: String) -> String? {
            let value = (info[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return value?.isEmpty == false ? value : nil
        }
        var key: Data?
        if let encoded = text(Bootstrap.publicKeyKey) {
            let decoded = Data(base64Encoded: encoded)
            key = decoded?.count == 32 ? decoded : Data()
        }
        let team = text(Bootstrap.teamIdKey)?.uppercased()
        let distributions = text(Bootstrap.distributionKey).map {
            Set($0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        }
        self.init(appId: bundleId ?? "", channel: text(Bootstrap.channelKey), configPublicKey: key,
                  teamId: team.flatMap { Bootstrap.isValidTeamId($0) ? $0 : nil },
                  pinnedBundleId: text(Bootstrap.bundleIdKey), allowedDistributions: distributions)
    }

    static func current(bundle: Bundle = .main) -> Bootstrap {
        Bootstrap(info: bundle.infoDictionary ?? [:], bundleId: bundle.bundleIdentifier)
    }

    static func isValidTeamId(_ value: String) -> Bool {
        value.count == 10 && value.allSatisfy { $0.isASCII && ($0.isUppercase || $0.isNumber) }
    }
}
