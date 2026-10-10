// Originally written in-house (author: tuanslg); ported into mobile-shield.
// Changes: per-id detectors, whole-file mountinfo scan (no chunk-boundary misses), unreadable
// input is "unsupported" instead of a hit.
#include "RootDetect.h"

#include "../secure/SecureAPI.h"
#include "../util/Fs.h"
#include "../util/Log.h"
#include "../util/obfuscate.h"

namespace ms {

// Keep in sync with io.mobileshield.detectors.NativeVsJavaCrossCheck.SU_PATHS.
static const char *const kSuPaths[] = {
    AY_OBFUSCATE("/data/local/su"),
    AY_OBFUSCATE("/data/local/bin/su"),
    AY_OBFUSCATE("/data/local/xbin/su"),
    AY_OBFUSCATE("/sbin/su"),
    AY_OBFUSCATE("/su/bin/su"),
    AY_OBFUSCATE("/system/bin/su"),
    AY_OBFUSCATE("/system/bin/.ext/su"),
    AY_OBFUSCATE("/system/bin/failsafe/su"),
    AY_OBFUSCATE("/system/sd/xbin/su"),
    AY_OBFUSCATE("/system/usr/we-need-root/su"),
    AY_OBFUSCATE("/system/xbin/su"),
    AY_OBFUSCATE("/cache/su"),
    AY_OBFUSCATE("/data/su"),
    AY_OBFUSCATE("/dev/su"),
};

static const char *const kMagiskNeedles[] = {
    AY_OBFUSCATE("magisk"),
    AY_OBFUSCATE("core/mirror"),
    AY_OBFUSCATE("core/img"),
};

bool RootSuPaths::suPresent() {
    for (const char *path : kSuPaths) {
        if (SecureAPI::access(path, F_OK) == 0) {
            LOGI("su found: %s", path);
            return true;
        }
    }
    return false;
}

float RootSuPaths::confidence() { return suPresent() ? 0.9f : 0.f; }

float RootMagiskMounts::confidence() {
    std::string mounts;
    if (!readFile(AY_OBFUSCATE("/proc/self/mountinfo"), mounts)) return kUnsupported;
    for (const char *needle : kMagiskNeedles) {
        if (contains(mounts, needle)) {
            LOGI("magisk mount marker: %s", needle);
            return 0.9f;
        }
    }
    return 0.f;
}

}  // namespace ms
