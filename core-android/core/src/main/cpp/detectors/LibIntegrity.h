// Rewrite of the in-house AntiLibPatch on dl_iterate_phdr (the original depended on a copyleft ELF
// helper that mobile-shield does not ship).
#pragma once
#include "IDetector.h"

namespace ms {

// Executable segments of this library and libc in memory vs the file they were mapped from.
class LibIntegrity : public IDetector {
public:
    const char *id() const override { return "hooking.libIntegrity"; }
    int category() const override { return kCatHooking; }
    float confidence() override;
    static void anchor();
};

// First bytes of a few libc entry points in memory vs disk; catches inline hooks by shape,
// independent of the hooking tool's name.
class PrologueIntegrity : public IDetector {
public:
    const char *id() const override { return "hooking.prologue"; }
    int category() const override { return kCatHooking; }
    float confidence() override;
};

}  // namespace ms
