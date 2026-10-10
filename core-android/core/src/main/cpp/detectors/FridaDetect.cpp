// Originally written in-house (author: tuanslg); ported into mobile-shield.
// Changes: split per detector id; thread/fd/maps signals added; the 1..65535 port scan and the
// websocket fingerprint are replaced by a single D-Bus probe; failures are "unsupported".
#include "FridaDetect.h"

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <link.h>
#include <netinet/in.h>
#include <poll.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#include <cstdio>
#include <cstring>
#include <set>

#include "../secure/SecureAPI.h"
#include "../util/Fs.h"
#include "../util/Log.h"
#include "../util/obfuscate.h"

namespace ms {

float FridaThreads::confidence() {
    std::set<std::string> seen;
    bool fridaSpecific = false;
    const bool listed = forEachEntry(AY_OBFUSCATE("/proc/self/task"), [&](const char *tid, unsigned char, int) {
        char path[64];
        snprintf(path, sizeof(path), AY_OBFUSCATE("/proc/self/task/%s/comm"), tid);
        std::string comm;
        if (!readFile(path, comm, 64)) return false;
        while (!comm.empty() && (comm.back() == '\n' || comm.back() == '\0')) comm.pop_back();
        // gmain/gdbus are GLib names and collide with benign GLib users: counted only in pairs.
        const char *const names[] = {AY_OBFUSCATE("gmain"), AY_OBFUSCATE("gdbus"),
                                     AY_OBFUSCATE("gum-js-loop"), AY_OBFUSCATE("pool-frida")};
        for (size_t i = 0; i < 4; i++) {
            if (comm == names[i]) {
                seen.insert(comm);
                if (i >= 2) fridaSpecific = true;
            }
        }
        return false;
    });
    if (!listed) return kUnsupported;
    if (seen.size() >= 2) return 0.8f;
    return fridaSpecific ? 0.5f : 0.f;
}

float FridaFd::confidence() {
    bool found = false;
    const bool listed = forEachEntry(AY_OBFUSCATE("/proc/self/fd"), [&](const char *name, unsigned char, int dirFd) {
        char target[256];
        const int n = SecureAPI::readlinkat(dirFd, name, target, sizeof(target) - 1);
        if (n <= 0) return false;
        target[n] = '\0';
        if (SecureAPI::strstr(target, AY_OBFUSCATE("linjector")) || SecureAPI::strstr(target, AY_OBFUSCATE("frida")) ||
            SecureAPI::strstr(target, AY_OBFUSCATE("gum-js"))) {
            LOGI("frida fd: %s", target);
            found = true;
        }
        return found;
    });
    if (!listed) return kUnsupported;
    return found ? 0.8f : 0.f;
}

static bool isFridaName(const char *name) {
    return SecureAPI::strstr(name, AY_OBFUSCATE("frida-agent")) || SecureAPI::strstr(name, AY_OBFUSCATE("libfrida")) ||
           SecureAPI::strstr(name, AY_OBFUSCATE("frida-gadget")) || SecureAPI::strstr(name, AY_OBFUSCATE("frida-helper"));
}

float FridaMaps::confidence() {
    std::string maps;
    if (!readFile(AY_OBFUSCATE("/proc/self/maps"), maps, 4u << 20)) return kUnsupported;

    float best = 0.f;
    size_t pos = 0;
    while (pos < maps.size()) {
        size_t end = maps.find('\n', pos);
        if (end == std::string::npos) end = maps.size();
        const std::string line = maps.substr(pos, end - pos);
        pos = end + 1;
        if (isFridaName(line.c_str())) return 0.85f;
        // Executable memfd mappings other than ART's JIT cache are how injected agents often load.
        if (line.find("memfd:") != std::string::npos && line.find(" r-xp ") != std::string::npos &&
            line.find("jit-cache") == std::string::npos && line.find("doublemapper") == std::string::npos) {
            best = 0.4f;
        }
    }

    bool loaded = false;
    dl_iterate_phdr(
        [](struct dl_phdr_info *info, size_t, void *data) -> int {
            if (info->dlpi_name != nullptr && isFridaName(info->dlpi_name)) {
                *static_cast<bool *>(data) = true;
                return 1;
            }
            return 0;
        },
        &loaded);
    return loaded ? 0.85f : best;
}

float DbusProbe::confidence() {
    static const long kMinGapSec = 600;
    static float cached = 0.f;
    static long lastRun = -1;
    timespec now{};
    clock_gettime(CLOCK_MONOTONIC, &now);
    if (lastRun >= 0 && now.tv_sec - lastRun < kMinGapSec) return cached;
    lastRun = now.tv_sec;

    const int fd = SecureAPI::socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) return cached = kUnsupported;

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(27042);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
    int rc = SecureAPI::connect(fd, reinterpret_cast<const sockaddr *>(&addr), sizeof(addr));
    float result = 0.f;
    if (rc == 0 || rc == -EINPROGRESS) {
        pollfd p{fd, POLLOUT, 0};
        if (poll(&p, 1, 50) == 1 && (p.revents & POLLOUT) && !(p.revents & (POLLERR | POLLHUP))) {
            // Frida's server answers a D-Bus auth line with REJECTED; any other listener stays silent.
            const char hello[] = "\0AUTH\r\n";
            SecureAPI::write(fd, hello, sizeof(hello) - 1);
            pollfd r{fd, POLLIN, 0};
            char reply[64] = {0};
            if (poll(&r, 1, 100) == 1 && (r.revents & POLLIN) &&
                static_cast<long>(SecureAPI::read(fd, reply, sizeof(reply) - 1)) > 0 && SecureAPI::strstr(reply, AY_OBFUSCATE("REJECTED"))) {
                result = 0.8f;
            } else {
                result = 0.3f;
            }
        }
    }
    SecureAPI::close(fd);
    return cached = result;
}

}  // namespace ms
