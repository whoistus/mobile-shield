import Foundation
import UIKit

private func guardSimulator() -> DetectionResult? {
    if Platform.isSimulator { return .unsupported(Platform.simulatorReason) }
    if Platform.isAppOnMac { return .unsupported(Platform.appOnMacReason) }
    return nil
}

private func score(_ matches: Int, one: Double, many: Double) -> Double { matches > 1 ? many : one }

/// Rootful layouts: Cydia/Substrate-era files and daemons.
struct JailbreakPathsDetector: Detector {
    let id = "jailbreak.paths"
    let category = ThreatCategory.root
    var exists: (String) -> Bool = FileProbe.exists

    static let paths = [
        "/Applications/Cydia.app", "/Applications/Sileo.app", "/Applications/Zebra.app",
        "/Applications/Installer.app", "/Applications/blackra1n.app", "/Applications/FakeCarrier.app",
        "/Applications/Icy.app", "/Applications/IntelliScreen.app", "/Applications/SBSettings.app",
        "/Applications/WinterBoard.app", "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/Library/MobileSubstrate/DynamicLibraries", "/bin/bash", "/usr/sbin/sshd", "/usr/bin/sshd",
        "/usr/libexec/sftp-server", "/etc/apt", "/private/var/lib/apt", "/private/var/lib/cydia",
        "/private/var/stash", "/var/cache/apt", "/var/lib/dpkg", "/usr/libexec/cydia",
    ]

    func run(_ context: DetectorContext) -> DetectionResult {
        if let blocked = guardSimulator() { return blocked }
        return evaluate()
    }

    func evaluate() -> DetectionResult {
        let found = Self.paths.filter(exists)
        guard let first = found.first else { return .clear }
        return .hit(score(found.count, one: 0.9, many: 0.97), evidence: first)
    }
}

/// Rootless layouts (palera1n, Dopamine): everything lives under /var/jb or a preboot bind.
struct JailbreakRootlessDetector: Detector {
    let id = "jailbreak.rootlessPaths"
    let category = ThreatCategory.root
    var exists: (String) -> Bool = FileProbe.exists

    static let paths = [
        "/var/jb", "/var/jb/.installed_dopamine", "/var/jb/.procursus_strapped", "/var/jb/basebin",
        "/var/jb/Applications/Sileo.app", "/var/jb/Applications/Zebra.app", "/var/jb/usr/bin/sshd",
        "/var/jb/usr/lib/libsubstrate.dylib", "/var/jb/usr/lib/libellekit.dylib",
        "/var/jb/Library/MobileSubstrate/DynamicLibraries", "/var/jb/etc/apt",
        "/var/containers/Bundle/tweaksupport", "/var/binpack", "/binpack",
    ]

    func run(_ context: DetectorContext) -> DetectionResult {
        if let blocked = guardSimulator() { return blocked }
        return evaluate()
    }

    func evaluate() -> DetectionResult {
        let found = Self.paths.filter(exists)
        guard let first = found.first else { return .clear }
        return .hit(score(found.count, one: 0.85, many: 0.95), evidence: first)
    }
}

/// Needs the host to list the schemes in LSApplicationQueriesSchemes; otherwise canOpenURL always
/// answers false and the detector would report "clean" for the wrong reason.
struct JailbreakUrlSchemesDetector: Detector {
    let id = "jailbreak.urlSchemes"
    let category = ThreatCategory.root
    var declared: () -> [String] = {
        Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String] ?? []
    }
    var canOpen: (URL) -> Bool = { url in Platform.mainSync { Platform.application?.canOpenURL(url) ?? false } }

    static let schemes = ["cydia", "sileo", "zbra", "filza", "undecimus"]

    func run(_ context: DetectorContext) -> DetectionResult {
        if let blocked = guardSimulator() { return blocked }
        let probe = Self.schemes.filter { declared().map { $0.lowercased() }.contains($0) }
        guard !probe.isEmpty else { return .unsupported("LSApplicationQueriesSchemes lacks jailbreak schemes") }
        let open = probe.filter { URL(string: "\($0)://").map(canOpen) ?? false }
        guard let first = open.first else { return .clear }
        return .hit(score(open.count, one: 0.85, many: 0.95), evidence: "\(first)://")
    }
}

/// A sandboxed app cannot create files outside its container; success means the sandbox is broken.
struct JailbreakSandboxWriteDetector: Detector {
    let id = "jailbreak.sandboxWrite"
    let category = ThreatCategory.root

    func run(_ context: DetectorContext) -> DetectionResult {
        if let blocked = guardSimulator() { return blocked }
        let path = "/private/mobileshield-\(UUID().uuidString)"
        let fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        guard fd >= 0 else { return .clear }
        close(fd)
        unlink(path)
        return .hit(0.95, evidence: "/private")
    }
}

struct JailbreakDyldImagesDetector: Detector {
    let id = "jailbreak.dyldImages"
    let category = ThreatCategory.root
    var images: () -> [String] = DyldImages.names

    static let needles = ["substrate", "substitute", "libhooker", "ellekit", "tweakinject", "/var/jb", "cycript", "sslkillswitch"]

    func run(_ context: DetectorContext) -> DetectionResult {
        if let blocked = guardSimulator() { return blocked }
        let found = DyldImages.matches(Self.needles, in: images())
        guard let first = found.first else { return .clear }
        return .hit(score(found.count, one: 0.7, many: 0.85), evidence: (first as NSString).lastPathComponent)
    }
}

struct JailbreakDyldEnvDetector: Detector {
    let id = "jailbreak.dyldEnv"
    let category = ThreatCategory.root
    var value: () -> String? = { getenv("DYLD_INSERT_LIBRARIES").map { String(cString: $0) } }

    private static let benignMarkers = ["libMainThreadChecker", "libBacktraceRecording", "libViewDebuggerSupport", "libLogRedirect", "/Developer/", "Xcode.app", "CoreSimulator"]

    func run(_ context: DetectorContext) -> DetectionResult {
        if let blocked = guardSimulator() { return blocked }
        return Self.evaluate(value())
    }

    /// Xcode injects its own debugging dylibs when launching from the IDE; those are not hostile.
    static func evaluate(_ raw: String?) -> DetectionResult {
        let entries = (raw ?? "").split(separator: ":").map(String.init)
        let suspicious = entries.filter { entry in !benignMarkers.contains(where: entry.contains) }
        guard let first = suspicious.first else { return .clear }
        return .hit(0.7, evidence: (first as NSString).lastPathComponent)
    }
}
