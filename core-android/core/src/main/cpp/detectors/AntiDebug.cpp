// Originally written in-house (author: tuanslg); ported into mobile-shield.
// Changes: unreadable /proc is "unsupported" instead of a hit; no process termination.
#include "AntiDebug.h"

#include <stdlib.h>

#include <cstdio>

#include "../util/Fs.h"
#include "../util/Log.h"
#include "../util/obfuscate.h"

namespace ms {

static int tracerPidOf(const std::string &status) {
    const char *key = AY_OBFUSCATE("TracerPid:");
    const size_t pos = status.find(key);
    if (pos == std::string::npos) return -1;
    return atoi(status.c_str() + pos + SecureAPI::strlen(key));
}

int DebuggerTracerPid::mainTracerPid() {
    std::string status;
    if (!readFile(AY_OBFUSCATE("/proc/self/status"), status)) return -1;
    return tracerPidOf(status);
}

float DebuggerTracerPid::confidence() {
    const int main = mainTracerPid();
    if (main < 0) return kUnsupported;
    if (main > 0) return 0.95f;

    bool traced = false;
    const bool listed = forEachEntry(AY_OBFUSCATE("/proc/self/task"), [&](const char *tid, unsigned char, int) {
        char path[64];
        snprintf(path, sizeof(path), AY_OBFUSCATE("/proc/self/task/%s/status"), tid);
        std::string status;
        if (readFile(path, status) && tracerPidOf(status) > 0) {
            LOGI("thread %s is traced", tid);
            traced = true;
        }
        return traced;
    });
    if (!listed) return kUnsupported;
    return traced ? 0.95f : 0.f;
}

}  // namespace ms
