import Darwin
import Foundation

struct FridaImagesDetector: Detector {
    let id = "hooking.fridaImages"
    let category = ThreatCategory.hooking
    var images: () -> [String] = DyldImages.names

    static let needles = ["frida", "gum-js", "gumjs"]

    func run(_ context: DetectorContext) -> DetectionResult {
        let found = DyldImages.matches(Self.needles, in: images())
        guard let first = found.first else { return .clear }
        return .hit(0.9, evidence: (first as NSString).lastPathComponent)
    }
}

/// Loopback-only D-Bus handshake on frida-server's default port. Throttled because it opens a socket.
final class FridaPortDetector: Detector {
    let id = "hooking.fridaPort"
    let category = ThreatCategory.hooking

    private let port: UInt16
    private let ttl: TimeInterval
    private let now: () -> Date
    private let lock = NSLock()
    private var cached: (at: Date, result: DetectionResult)?

    init(port: UInt16 = 27042, ttl: TimeInterval = 60, now: @escaping () -> Date = Date.init) {
        self.port = port
        self.ttl = ttl
        self.now = now
    }

    func run(_ context: DetectorContext) -> DetectionResult {
        lock.lock()
        if let cached = cached, now().timeIntervalSince(cached.at) < ttl { lock.unlock(); return cached.result }
        lock.unlock()
        let result = probe()
        lock.lock(); cached = (now(), result); lock.unlock()
        return result
    }

    private func probe() -> DetectionResult {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return .unsupported("socket failed") }
        defer { close(fd) }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = UInt32(0x7F00_0001).bigEndian
        let started = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        if started != 0 {
            guard errno == EINPROGRESS, wait(fd, events: Int16(POLLOUT), timeoutMs: 150) else { return .clear }
            var failure: Int32 = 0
            var length = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &failure, &length)
            guard failure == 0 else { return .clear }
        }
        let hello = Array("\0AUTH\r\n".utf8)
        _ = send(fd, hello, hello.count, 0)
        var buffer = [UInt8](repeating: 0, count: 128)
        if wait(fd, events: Int16(POLLIN), timeoutMs: 150) {
            let count = recv(fd, &buffer, buffer.count, 0)
            if count > 0, String(decoding: buffer.prefix(count), as: UTF8.self).contains("REJECTED") {
                return .hit(0.9, evidence: "dbus-auth:\(port)")
            }
        }
        return .hit(0.5, evidence: "open:\(port)")
    }

    private func wait(_ fd: Int32, events: Int16, timeoutMs: Int32) -> Bool {
        var descriptor = pollfd(fd: fd, events: events, revents: 0)
        return poll(&descriptor, 1, timeoutMs) > 0 && (descriptor.revents & events) != 0
    }
}

/// Name-independent: flags inline-hook trampolines (LDR/ADRP x16; BR x16) at the entry of common
/// libc/libdyld functions. System functions never start with such a stub.
struct PrologueDetector: Detector {
    let id = "hooking.prologue"
    let category = ThreatCategory.hooking
    var words: (String) -> [UInt32]? = PrologueDetector.readWords

    static let symbols = ["open", "read", "stat", "access", "fopen", "dlopen", "dlsym", "getenv", "sysctl", "ptrace", "_dyld_image_count", "_dyld_get_image_name"]

    func run(_ context: DetectorContext) -> DetectionResult {
        #if arch(arm64) || arch(arm64e)
        let patched = Self.symbols.filter { name in words(name).map(Self.isTrampoline) ?? false }
        guard let first = patched.first else { return .clear }
        return .hit(patched.count > 1 ? 0.9 : 0.8, evidence: first)
        #else
        return .unsupported("arm64 only")
        #endif
    }

    static func isTrampoline(_ w: [UInt32]) -> Bool {
        guard w.count >= 3 else { return false }
        let brX16: UInt32 = 0xD61F_0200
        if (w[0] & 0xFF00_001F) == 0x5800_0010 && w[1] == brX16 { return true }
        return (w[0] & 0x9F00_001F) == 0x9000_0010 && (w[1] & 0xFFC0_03FF) == 0x9100_0210 && w[2] == brX16
    }

    static func readWords(_ symbol: String) -> [UInt32]? {
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        guard let raw = dlsym(rtldDefault, symbol) else { return nil }
        // arm64e returns PAC-signed code pointers; the signature bits sit above the 47-bit address.
        let address = UInt(bitPattern: raw) & 0x0000_7FFF_FFFF_FFFF
        guard let code = UnsafePointer<UInt32>(bitPattern: address) else { return nil }
        return [code[0], code[1], code[2]]
    }
}
