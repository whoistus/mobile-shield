// Originally written in-house (author: tuanslg); ported into mobile-shield.
#pragma once
#include "IDetector.h"

namespace ms {

class DebuggerTracerPid : public IDetector {
public:
    const char *id() const override { return "debugger.tracerPid"; }
    int category() const override { return kCatDebugger; }
    float confidence() override;
    // TracerPid of the main thread (/proc/self/status), -1 when unreadable. Cross-check input.
    static int mainTracerPid();
};

}  // namespace ms
