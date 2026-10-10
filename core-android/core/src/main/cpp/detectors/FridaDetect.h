// Originally written in-house (author: tuanslg); ported into mobile-shield.
#pragma once
#include "IDetector.h"

namespace ms {

class FridaThreads : public IDetector {
public:
    const char *id() const override { return "hooking.fridaThreads"; }
    int category() const override { return kCatHooking; }
    float confidence() override;
};

class FridaFd : public IDetector {
public:
    const char *id() const override { return "hooking.fridaFd"; }
    int category() const override { return kCatHooking; }
    float confidence() override;
};

class FridaMaps : public IDetector {
public:
    const char *id() const override { return "hooking.fridaMaps"; }
    int category() const override { return kCatHooking; }
    float confidence() override;
};

// One probe of the default Frida listener port (27042), rate limited. No port scan.
class DbusProbe : public IDetector {
public:
    const char *id() const override { return "hooking.dbusProbe"; }
    int category() const override { return kCatHooking; }
    float confidence() override;
};

}  // namespace ms
