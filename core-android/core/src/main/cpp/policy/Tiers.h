// Launch tiers from design.md. Experimental ids are always REPORT until promoted in a release.
// Mirrors io.mobileshield.config.Defaults.EXPERIMENTAL_IDS.
#pragma once
#include <cstring>

namespace ms {

inline bool isExperimental(const char *id) {
    static const char *const kExperimental[] = {
        "root.buildTags",     "hooking.fridaThreads", "hooking.fridaFd",      "hooking.fridaMaps",
        "hooking.dbusProbe",  "hooking.prologue",     "hooking.libIntegrity", "tampering.memDump",
    };
    if (id == nullptr) return false;
    for (const char *e : kExperimental) {
        if (std::strcmp(e, id) == 0) return true;
    }
    return false;
}

}  // namespace ms
