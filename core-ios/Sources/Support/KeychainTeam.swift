import Foundation
import Security

/// Team ID from the default keychain access group (`TEAMID.bundle.id`). The group comes from the
/// signed application-identifier entitlement, so it reflects the real signing identity even when
/// embedded.mobileprovision is absent (App Store / TestFlight). Uses public SecItem API only.
enum KeychainTeam {
    private static let lock = NSLock()
    private static var cached: String?

    static func teamId() -> String? {
        lock.lock(); defer { lock.unlock() }
        if let cached = cached { return cached }
        guard let group = probeAccessGroup(), let team = prefix(ofAccessGroup: group) else { return nil }
        cached = team
        return team
    }

    static func prefix(ofAccessGroup group: String) -> String? {
        guard let dot = group.firstIndex(of: ".") else { return nil }
        let team = String(group[..<dot]).uppercased()
        return Bootstrap.isValidTeamId(team) ? team : nil
    }

    private static func probeAccessGroup() -> String? {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "io.mobileshield.teamprobe",
            kSecAttrAccount as String: "probe",
        ]
        var query = base
        query[kSecReturnAttributes as String] = true
        var result: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = Data([0])
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(query as CFDictionary, &result)
        }
        defer { SecItemDelete(base as CFDictionary) }
        guard status == errSecSuccess, let attributes = result as? [String: Any] else { return nil }
        return attributes[kSecAttrAccessGroup as String] as? String
    }
}
