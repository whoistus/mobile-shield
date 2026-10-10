import Foundation

struct StoredConfig {
    let seq: Int64
    let config: [String: Any]
}

protocol ConfigStoring {
    func load() -> StoredConfig?
    func save(_ config: [String: Any], seq: Int64)
}

/// Last-known-good config in app-private storage (Application Support, excluded from backup).
final class FileConfigStore: ConfigStoring {
    private let url: URL?

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        url = base?.appendingPathComponent("io.mobileshield", isDirectory: true)
            .appendingPathComponent("last-known-good.json")
    }

    func load() -> StoredConfig? {
        guard let url = url, let data = try? Data(contentsOf: url),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let seq = JSONValue.int64(root["seq"]), let config = root["config"] as? [String: Any] else { return nil }
        return StoredConfig(seq: seq, config: config)
    }

    func save(_ config: [String: Any], seq: Int64) {
        let root: [String: Any] = ["seq": seq, "config": config]
        guard let url = url, JSONSerialization.isValidJSONObject(root),
              let data = try? JSONSerialization.data(withJSONObject: root) else { return }
        var directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        try? directory.setResourceValues(excluded)
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
