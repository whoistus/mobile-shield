#include "Registry.h"

#include <algorithm>
#include <mutex>

#include "AntiDebug.h"
#include "AntiDump.h"
#include "FridaDetect.h"
#include "LibIntegrity.h"
#include "RootDetect.h"

namespace ms {

const std::vector<IDetector *> &detectors() {
    static RootSuPaths suPaths;
    static RootMagiskMounts magiskMounts;
    static DebuggerTracerPid tracerPid;
    static FridaThreads fridaThreads;
    static FridaFd fridaFd;
    static FridaMaps fridaMaps;
    static DbusProbe dbusProbe;
    static PrologueIntegrity prologue;
    static LibIntegrity libIntegrity;
    static MemDump memDump;
    static const std::vector<IDetector *> all = {
        &suPaths,   &magiskMounts, &tracerPid, &fridaThreads, &fridaFd,
        &fridaMaps, &dbusProbe,    &prologue,  &libIntegrity, &memDump,
    };
    return all;
}

std::vector<float> runAll(const std::vector<std::string> &disabled) {
    static std::mutex mu;
    std::lock_guard<std::mutex> lock(mu);
    const auto &all = detectors();
    std::vector<float> out(all.size(), kUnsupported);
    for (size_t i = 0; i < all.size(); i++) {
        if (std::find(disabled.begin(), disabled.end(), all[i]->id()) != disabled.end()) continue;
        try {
            out[i] = all[i]->confidence();
        } catch (...) {
            out[i] = kUnsupported;
        }
    }
    return out;
}

}  // namespace ms
