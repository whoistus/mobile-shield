// Originally written in-house (author: tuanslg); ported into mobile-shield.
// Changes: non-blocking inotify (the original read() could block the caller), bounded watch
// list, maps no longer watched, fd closed only if init fails; no process termination.
#include "AntiDump.h"

#include <sys/inotify.h>

#include "../secure/SecureAPI.h"
#include "../util/Log.h"
#include "../util/obfuscate.h"

namespace ms {

float MemDump::confidence() {
    if (!initialised_) {
        initialised_ = true;
        fd_ = SecureAPI::inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
        if (fd_ >= 0) {
            const int a = SecureAPI::inotify_add_watch(fd_, AY_OBFUSCATE("/proc/self/mem"), IN_ACCESS | IN_OPEN);
            const int b = SecureAPI::inotify_add_watch(fd_, AY_OBFUSCATE("/proc/self/pagemap"), IN_ACCESS | IN_OPEN);
            if (a < 0 && b < 0) {
                SecureAPI::close(fd_);
                fd_ = -1;
            }
        }
        return fd_ >= 0 ? 0.f : kUnsupported;
    }
    if (fd_ < 0) return kUnsupported;

    bool hit = false;
    alignas(inotify_event) char buf[1024];
    long n;
    while ((n = static_cast<long>(SecureAPI::read(fd_, buf, sizeof(buf)))) > 0) {
        for (long pos = 0; pos < n;) {
            const auto *ev = reinterpret_cast<const inotify_event *>(buf + pos);
            if (ev->mask & (IN_ACCESS | IN_OPEN)) hit = true;
            pos += static_cast<long>(sizeof(inotify_event) + ev->len);
        }
    }
    if (hit) LOGI("process memory opened or read");
    return hit ? 0.8f : 0.f;
}

}  // namespace ms
