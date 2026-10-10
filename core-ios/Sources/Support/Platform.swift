import Foundation
import MachO
import UIKit

enum Platform {
    static let isSimulator: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }()

    static let simulatorReason = "simulator shares the host filesystem and signing"

    /// iOS app running on an Apple Silicon Mac ("Designed for iPad") or Mac Catalyst: the macOS
    /// filesystem has /bin/bash, sshd and friends, so jailbreak path probes would always hit.
    static let isAppOnMac: Bool = {
        if #available(iOS 14.0, *) {
            let info = ProcessInfo.processInfo
            return info.isiOSAppOnMac || info.isMacCatalystApp
        }
        return false
    }()

    static let appOnMacReason = "iOS app on Mac shares the macOS filesystem"

    /// nil outside a running app (unit tests, extensions); never touch `UIApplication.shared` directly.
    static var application: UIApplication? {
        UIApplication.value(forKey: "sharedApplication") as? UIApplication
    }

    static func mainSync<T>(_ body: () -> T) -> T {
        Thread.isMainThread ? body() : DispatchQueue.main.sync(execute: body)
    }
}

enum FileProbe {
    /// Two independent primitives so hooking one libc symbol is not enough to hide a path.
    static func exists(_ path: String) -> Bool {
        if access(path, F_OK) == 0 { return true }
        let fd = open(path, O_RDONLY)
        if fd >= 0 { close(fd); return true }
        return false
    }
}

enum DyldImages {
    static func names() -> [String] {
        (0..<_dyld_image_count()).compactMap { index in
            _dyld_get_image_name(index).map { String(cString: $0) }
        }
    }

    static func matches(_ needles: [String], in names: [String]) -> [String] {
        let lowered = needles.map { $0.lowercased() }
        return names.filter { name in
            let lower = name.lowercased()
            return lowered.contains(where: lower.contains)
        }
    }
}
