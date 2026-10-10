// A native detector reports evidence only. It never decides an action and never terminates
// the process: the policy engine (policy/Policy.h) turns confidence into an action and the
// watchdog is the only code path that can end the process.
#pragma once

namespace ms {

// Returned by confidence() when the detector cannot run here; produces no event.
constexpr float kUnsupported = -1.f;

// Ordinals match io.mobileshield.model.ThreatCategory.
enum Category : int {
    kCatRoot = 0,
    kCatEmulator,
    kCatDebugger,
    kCatHooking,
    kCatTampering,
};

class IDetector {
public:
    virtual ~IDetector() = default;
    virtual const char *id() const = 0;
    virtual int category() const = 0;
    // 0 = clean, (0,1] = evidence strength, kUnsupported = could not run.
    virtual float confidence() = 0;
};

}  // namespace ms
