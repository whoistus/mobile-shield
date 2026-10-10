import Foundation

struct EnvironmentInfo {
    let sdkVersion: String
    let osVersion: String
    let abi: String
    let isDebuggable: Bool
    let installer: String?

    var dictionary: NSDictionary {
        [
            "sdkVersion": sdkVersion,
            "platform": "ios",
            "osVersion": osVersion,
            "abi": abi,
            "isDebuggable": isDebuggable,
            "gmsAvailable": false,
            "hmsAvailable": false,
            "installer": installer ?? NSNull(),
            "attestationKinds": [String](),
        ]
    }

    static var currentAbi: String {
        #if arch(arm64e)
        return "arm64e"
        #elseif arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
