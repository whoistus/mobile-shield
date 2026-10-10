// Originally written in-house (author: tuanslg); ported into mobile-shield.
#pragma once
#include "IDetector.h"

namespace ms {

// inotify watch on /proc/self/mem and /proc/self/pagemap; a hit means something opened or read
// them since the previous run. /proc/self/maps is not watched: the other detectors read it.
class MemDump : public IDetector {
public:
    const char *id() const override { return "tampering.memDump"; }
    int category() const override { return kCatTampering; }
    float confidence() override;

private:
    bool initialised_ = false;
    int fd_ = -1;
};

}  // namespace ms
