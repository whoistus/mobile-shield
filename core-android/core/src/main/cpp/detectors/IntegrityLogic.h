// Pure logic behind the library-integrity and prologue detectors. No syscalls, no Android
// headers, so it is unit-tested on the host (src/test/cpp/libintegrity_test.cpp).
#pragma once
#include <stdint.h>

#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace ms {
namespace integrity {

struct MapEntry {
    uint64_t start = 0;
    uint64_t end = 0;
    uint64_t offset = 0;
    bool readable = false;
    bool executable = false;
    bool writable = false;
    std::string path;
};

// "start-end perms offset dev inode   path"; anonymous mappings keep an empty path.
inline bool parseMapsLine(const std::string &line, MapEntry &out) {
    char perms[8] = {0};
    unsigned long long start = 0, end = 0, offset = 0;
    int consumed = 0;
    if (sscanf(line.c_str(), "%llx-%llx %7s %llx %*s %*s %n", &start, &end, perms, &offset, &consumed) < 4) {
        return false;
    }
    if (end <= start || std::strlen(perms) < 4) return false;
    out.start = start;
    out.end = end;
    out.offset = offset;
    out.readable = perms[0] == 'r';
    out.writable = perms[1] == 'w';
    out.executable = perms[2] == 'x';
    out.path.clear();
    if (consumed > 0 && static_cast<size_t>(consumed) < line.size()) out.path = line.substr(consumed);
    while (!out.path.empty() && (out.path.back() == '\n' || out.path.back() == ' ')) out.path.pop_back();
    return true;
}

inline std::vector<MapEntry> parseMaps(const std::string &maps) {
    std::vector<MapEntry> entries;
    size_t pos = 0;
    while (pos < maps.size()) {
        size_t end = maps.find('\n', pos);
        if (end == std::string::npos) end = maps.size();
        MapEntry e;
        if (parseMapsLine(maps.substr(pos, end - pos), e)) entries.push_back(e);
        pos = end + 1;
    }
    return entries;
}

inline const MapEntry *findMapping(const std::vector<MapEntry> &entries, uint64_t addr) {
    for (const MapEntry &e : entries) {
        if (addr >= e.start && addr < e.end) return &e;
    }
    return nullptr;
}

// A mapping can be compared against disk only when it is backed by a real, intact file.
inline bool isFileBacked(const MapEntry &e) {
    return !e.path.empty() && e.path[0] == '/' && e.path.find("(deleted)") == std::string::npos &&
           e.path.compare(0, 5, "/dev/") != 0;
}

// File offset that backs `addr` inside mapping `e` (also correct for libs mapped out of an APK,
// where the mapping path is the APK and e.offset points into it).
inline uint64_t fileOffsetFor(const MapEntry &e, uint64_t addr) { return e.offset + (addr - e.start); }

inline size_t countDiff(const uint8_t *a, const uint8_t *b, size_t n) {
    size_t diff = 0;
    for (size_t i = 0; i < n; i++) diff += a[i] != b[i];
    return diff;
}

enum class Arch { Arm64, Arm, X86, X86_64 };

inline Arch hostArch() {
#if defined(__aarch64__)
    return Arch::Arm64;
#elif defined(__arm__)
    return Arch::Arm;
#elif defined(__x86_64__)
    return Arch::X86_64;
#else
    return Arch::X86;
#endif
}

// Recognises the usual inline-hook trampolines at the start of a function.
inline bool looksLikeTrampoline(Arch arch, const uint8_t *b, size_t n) {
    switch (arch) {
        case Arch::Arm64: {
            if (n < 8) return false;
            uint32_t w0, w1;
            std::memcpy(&w0, b, 4);
            std::memcpy(&w1, b + 4, 4);
            const bool ldrLiteral = (w0 & 0xFF000000u) == 0x58000000u;  // ldr xN, #imm
            const bool br = (w1 & 0xFFFFFC1Fu) == 0xD61F0000u;          // br xN
            return ldrLiteral && br;
        }
        case Arch::Arm: {
            if (n < 4) return false;
            uint32_t w0;
            std::memcpy(&w0, b, 4);
            const bool armLdrPc = w0 == 0xE51FF004u;  // ldr pc, [pc, #-4]
            const bool thumbLdrPc = b[0] == 0xDF && b[1] == 0xF8 && b[2] == 0x00 && b[3] == 0xF0;  // ldr.w pc, [pc]
            return armLdrPc || thumbLdrPc;
        }
        case Arch::X86_64:
        case Arch::X86:
            if (n < 2) return false;
            if (b[0] == 0xE9) return true;                              // jmp rel32
            if (b[0] == 0xFF && b[1] == 0x25) return true;              // jmp [rip+x] / jmp [abs]
            if (b[0] == 0x68 && n >= 6 && b[5] == 0xC3) return true;    // push imm32; ret
            return false;
    }
    return false;
}

// Confidence for a changed function prologue: a recognised trampoline is strong evidence,
// any other difference is only suspicious (e.g. OEM-patched libc).
inline float prologueConfidence(Arch arch, const uint8_t *mem, const uint8_t *disk, size_t n) {
    if (countDiff(mem, disk, n) == 0) return 0.f;
    return looksLikeTrampoline(arch, mem, n) ? 0.9f : 0.5f;
}

}  // namespace integrity
}  // namespace ms
