// Pure logic of the integrity detectors (maps parsing, diffing, trampoline shapes).
// The syscall-based readers are exercised on-device; here only the parts that need no Android.
#include <gtest/gtest.h>

#include <cstring>
#include <string>
#include <vector>

#include "detectors/IntegrityLogic.h"

#ifdef __linux__
#include <cstdio>
#include <fstream>
#include <sstream>
#endif

using namespace ms::integrity;

namespace {
const char *kLibcLine = "7a1c000000-7a1c0a0000 r-xp 00001000 fd:05 123  /apex/com.android.runtime/lib64/bionic/libc.so";
const char *kApkLine = "7b00000000-7b00020000 r-xp 00123000 fd:06 77   /data/app/~~x/io.example-y/base.apk";
}  // namespace

TEST(MapsParsing, FileBackedExecutableMapping) {
    MapEntry e;
    ASSERT_TRUE(parseMapsLine(kLibcLine, e));
    EXPECT_EQ(0x7a1c000000ULL, e.start);
    EXPECT_EQ(0x7a1c0a0000ULL, e.end);
    EXPECT_EQ(0x1000ULL, e.offset);
    EXPECT_TRUE(e.readable);
    EXPECT_TRUE(e.executable);
    EXPECT_FALSE(e.writable);
    EXPECT_EQ("/apex/com.android.runtime/lib64/bionic/libc.so", e.path);
    EXPECT_TRUE(isFileBacked(e));
}

TEST(MapsParsing, AnonymousMappingHasNoPath) {
    MapEntry e;
    ASSERT_TRUE(parseMapsLine("7ff000000000-7ff000001000 rw-p 00000000 00:00 0 ", e));
    EXPECT_TRUE(e.path.empty());
    EXPECT_TRUE(e.writable);
    EXPECT_FALSE(isFileBacked(e));
}

TEST(MapsParsing, PathsWithSpacesAndDeletedMarkersSurvive) {
    MapEntry e;
    ASSERT_TRUE(parseMapsLine("1000-2000 r-xp 00000000 fd:01 9   /data/app/my app/lib.so (deleted)", e));
    EXPECT_EQ("/data/app/my app/lib.so (deleted)", e.path);
    EXPECT_FALSE(isFileBacked(e)) << "a replaced file cannot be compared";
}

TEST(MapsParsing, SpecialAndDeviceMappingsAreNotFileBacked) {
    MapEntry e;
    ASSERT_TRUE(parseMapsLine("1000-2000 r-xp 00000000 00:01 9   [vdso]", e));
    EXPECT_FALSE(isFileBacked(e));
    ASSERT_TRUE(parseMapsLine("1000-2000 r--s 00000000 00:01 9   /dev/ashmem (deleted)", e));
    EXPECT_FALSE(isFileBacked(e));
    ASSERT_TRUE(parseMapsLine("1000-2000 r-xp 00000000 00:01 9   /memfd:jit-cache (deleted)", e));
    EXPECT_FALSE(isFileBacked(e));
}

TEST(MapsParsing, MalformedLinesAreRejected) {
    MapEntry e;
    EXPECT_FALSE(parseMapsLine("", e));
    EXPECT_FALSE(parseMapsLine("garbage", e));
    EXPECT_FALSE(parseMapsLine("2000-1000 r-xp 00000000 fd:01 9 /x", e)) << "end before start";
    EXPECT_FALSE(parseMapsLine("1000-2000 r-", e));
}

TEST(MapsParsing, WholeFileKeepsOnlyValidLines) {
    const std::string maps = std::string(kLibcLine) + "\nnot a line\n" + kApkLine + "\n";
    EXPECT_EQ(2u, parseMaps(maps).size());
}

TEST(MapsLookup, FindsMappingsWithHalfOpenBounds) {
    std::vector<MapEntry> maps = parseMaps(std::string(kLibcLine) + "\n" + kApkLine + "\n");
    ASSERT_EQ(2u, maps.size());
    EXPECT_EQ(&maps[0], findMapping(maps, 0x7a1c000000ULL));
    EXPECT_EQ(&maps[0], findMapping(maps, 0x7a1c09ffffULL));
    EXPECT_EQ(nullptr, findMapping(maps, 0x7a1c0a0000ULL));
    EXPECT_EQ(&maps[1], findMapping(maps, 0x7b00010000ULL));
    EXPECT_EQ(nullptr, findMapping(maps, 0x1000ULL));
}

TEST(MapsLookup, FileOffsetAccountsForTheMappingOffset) {
    MapEntry libc, apk;
    ASSERT_TRUE(parseMapsLine(kLibcLine, libc));
    ASSERT_TRUE(parseMapsLine(kApkLine, apk));
    EXPECT_EQ(0x1000ULL + 0x234, fileOffsetFor(libc, 0x7a1c000234ULL));
    // A library stored inside an APK: the offset points into the APK file.
    EXPECT_EQ(0x123000ULL + 0x10, fileOffsetFor(apk, 0x7b00000010ULL));
}

TEST(Diff, CountsDifferingBytes) {
    const uint8_t a[] = {1, 2, 3, 4};
    const uint8_t b[] = {1, 9, 3, 8};
    EXPECT_EQ(0u, countDiff(a, a, 4));
    EXPECT_EQ(2u, countDiff(a, b, 4));
    EXPECT_EQ(0u, countDiff(a, b, 1));
    EXPECT_EQ(0u, countDiff(a, b, 0));
}

TEST(Trampolines, Arm64LoadLiteralThenBranch) {
    // ldr x16, #8 ; br x16
    const uint8_t hook[] = {0x50, 0x00, 0x00, 0x58, 0x00, 0x02, 0x1f, 0xd6};
    EXPECT_TRUE(looksLikeTrampoline(Arch::Arm64, hook, sizeof(hook)));
    // stp x29, x30, [sp, #-16]! ; mov x29, sp
    const uint8_t normal[] = {0xfd, 0x7b, 0xbf, 0xa9, 0xfd, 0x03, 0x00, 0x91};
    EXPECT_FALSE(looksLikeTrampoline(Arch::Arm64, normal, sizeof(normal)));
    EXPECT_FALSE(looksLikeTrampoline(Arch::Arm64, hook, 4)) << "needs both instructions";
}

TEST(Trampolines, ArmLdrPcForms) {
    const uint8_t arm[] = {0x04, 0xf0, 0x1f, 0xe5};     // ldr pc, [pc, #-4]
    const uint8_t thumb[] = {0xdf, 0xf8, 0x00, 0xf0};   // ldr.w pc, [pc]
    const uint8_t normal[] = {0x00, 0x48, 0x2d, 0xe9};  // push {fp, lr}
    EXPECT_TRUE(looksLikeTrampoline(Arch::Arm, arm, 4));
    EXPECT_TRUE(looksLikeTrampoline(Arch::Arm, thumb, 4));
    EXPECT_FALSE(looksLikeTrampoline(Arch::Arm, normal, 4));
}

TEST(Trampolines, X86Jumps) {
    const uint8_t jmpRel[] = {0xe9, 0x10, 0x00, 0x00, 0x00};
    const uint8_t jmpMem[] = {0xff, 0x25, 0x00, 0x00, 0x00, 0x00};
    const uint8_t pushRet[] = {0x68, 0x78, 0x56, 0x34, 0x12, 0xc3};
    const uint8_t normal[] = {0x55, 0x48, 0x89, 0xe5};  // push rbp; mov rbp, rsp
    for (Arch arch : {Arch::X86, Arch::X86_64}) {
        EXPECT_TRUE(looksLikeTrampoline(arch, jmpRel, sizeof(jmpRel)));
        EXPECT_TRUE(looksLikeTrampoline(arch, jmpMem, sizeof(jmpMem)));
        EXPECT_TRUE(looksLikeTrampoline(arch, pushRet, sizeof(pushRet)));
        EXPECT_FALSE(looksLikeTrampoline(arch, normal, sizeof(normal)));
    }
    EXPECT_FALSE(looksLikeTrampoline(Arch::X86_64, jmpRel, 1));
}

TEST(PrologueConfidence, IdenticalBytesAreClean) {
    const uint8_t code[16] = {0xfd, 0x7b, 0xbf, 0xa9};
    EXPECT_FLOAT_EQ(0.f, prologueConfidence(Arch::Arm64, code, code, sizeof(code)));
}

TEST(PrologueConfidence, TrampolineIsStrongEvidence) {
    uint8_t disk[16] = {0xfd, 0x7b, 0xbf, 0xa9, 0xfd, 0x03, 0x00, 0x91};
    uint8_t mem[16] = {0x50, 0x00, 0x00, 0x58, 0x00, 0x02, 0x1f, 0xd6};
    EXPECT_FLOAT_EQ(0.9f, prologueConfidence(Arch::Arm64, mem, disk, sizeof(mem)));
}

TEST(PrologueConfidence, OtherDifferencesAreOnlySuspicious) {
    uint8_t disk[16] = {0xfd, 0x7b, 0xbf, 0xa9};
    uint8_t mem[16] = {0xfd, 0x7b, 0xbf, 0xa8};
    const float c = prologueConfidence(Arch::Arm64, mem, disk, sizeof(mem));
    EXPECT_FLOAT_EQ(0.5f, c);
    EXPECT_LT(c, 0.7f);
}

TEST(HostArch, MatchesTheCompilerTarget) {
    const Arch a = hostArch();
    EXPECT_TRUE(a == Arch::Arm64 || a == Arch::X86_64 || a == Arch::Arm || a == Arch::X86);
}

#ifdef __linux__
// Linux only: the logic must agree with the real kernel for this very test binary.
TEST(LinuxSelf, ExecutableCodeMatchesItsBackingFile) {
    std::ifstream maps("/proc/self/maps");
    std::stringstream buffer;
    buffer << maps.rdbuf();
    const std::vector<MapEntry> entries = parseMaps(buffer.str());
    ASSERT_FALSE(entries.empty());

    const uint64_t addr = reinterpret_cast<uintptr_t>(&parseMapsLine);
    const MapEntry *m = findMapping(entries, addr);
    ASSERT_NE(nullptr, m);
    ASSERT_TRUE(m->executable);
    ASSERT_TRUE(isFileBacked(*m));

    uint8_t disk[16] = {0};
    FILE *f = std::fopen(m->path.c_str(), "rb");
    ASSERT_NE(nullptr, f);
    ASSERT_EQ(0, std::fseek(f, static_cast<long>(fileOffsetFor(*m, addr)), SEEK_SET));
    ASSERT_EQ(sizeof(disk), std::fread(disk, 1, sizeof(disk), f));
    std::fclose(f);

    EXPECT_EQ(0u, countDiff(reinterpret_cast<const uint8_t *>(addr), disk, sizeof(disk)));
}
#endif
