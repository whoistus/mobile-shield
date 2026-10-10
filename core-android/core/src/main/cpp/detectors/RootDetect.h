// Originally written in-house (author: tuanslg); ported into mobile-shield.
#pragma once
#include "IDetector.h"

namespace ms {

class RootSuPaths : public IDetector {
public:
    const char *id() const override { return "root.suPaths"; }
    int category() const override { return kCatRoot; }
    float confidence() override;
    // Shared with the native-vs-Java cross-check.
    static bool suPresent();
};

class RootMagiskMounts : public IDetector {
public:
    const char *id() const override { return "root.magiskMounts"; }
    int category() const override { return kCatRoot; }
    float confidence() override;
};

}  // namespace ms
