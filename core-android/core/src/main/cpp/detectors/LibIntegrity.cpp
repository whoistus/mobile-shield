#include "LibIntegrity.h"

#include <dlfcn.h>
#include <elf.h>
#include <fcntl.h>
#include <link.h>

#include <algorithm>
#include <string>
#include <utility>
#include <vector>

#include "../secure/SecureAPI.h"
#include "../util/Fs.h"
#include "../util/Log.h"
#include "../util/obfuscate.h"
#include "IntegrityLogic.h"

namespace ms {
namespace {

using integrity::MapEntry;

// Copies process memory through a pipe: an unreadable page (execute-only memory, unmapped)
// fails the write with EFAULT instead of raising SIGSEGV, and /proc/self/mem is never opened.
class SafeReader {
public:
    SafeReader() { ok_ = SecureAPI::pipe2(fds_, O_CLOEXEC) == 0; }
    ~SafeReader() {
        if (ok_) {
            SecureAPI::close(fds_[0]);
            SecureAPI::close(fds_[1]);
        }
    }
    bool read(const void *addr, uint8_t *out, size_t n) {
        if (!ok_) return false;
        const uint8_t *p = static_cast<const uint8_t *>(addr);
        while (n > 0) {
            const size_t chunk = std::min<size_t>(n, 4096);
            const long w = static_cast<long>(SecureAPI::write(fds_[1], p, chunk));
            if (w <= 0) return false;
            size_t got = 0;
            while (got < static_cast<size_t>(w)) {
                const long r = static_cast<long>(SecureAPI::read(fds_[0], out + got, static_cast<size_t>(w) - got));
                if (r <= 0) return false;
                got += static_cast<size_t>(r);
            }
            p += w;
            out += w;
            n -= static_cast<size_t>(w);
        }
        return true;
    }

private:
    int fds_[2] = {-1, -1};
    bool ok_ = false;
};

bool readFileRange(int fd, uint64_t offset, uint8_t *out, size_t n) {
    if (SecureAPI::lseek(fd, static_cast<off_t>(offset), SEEK_SET) < 0) return false;
    size_t got = 0;
    while (got < n) {
        const long r = static_cast<long>(SecureAPI::read(fd, out + got, n - got));
        if (r <= 0) return false;
        got += static_cast<size_t>(r);
    }
    return true;
}

bool loadMaps(std::vector<MapEntry> &out) {
    std::string maps;
    if (!readFile(AY_OBFUSCATE("/proc/self/maps"), maps, 4u << 20)) return false;
    out = integrity::parseMaps(maps);
    return !out.empty();
}

struct Module {
    bool isSelf = false;
    bool textRel = false;
    std::vector<std::pair<uint64_t, uint64_t>> exec;  // memory start, length
};

struct Scan {
    uintptr_t anchor;
    std::vector<Module> modules;
};

bool endsWith(const char *s, const char *suffix) {
    const size_t a = SecureAPI::strlen(s), b = SecureAPI::strlen(suffix);
    return a >= b && SecureAPI::strcmp(s + a - b, suffix) == 0;
}

int collect(struct dl_phdr_info *info, size_t, void *data) {
    Scan *scan = static_cast<Scan *>(data);
    Module m;
    bool containsAnchor = false;
    for (int i = 0; i < info->dlpi_phnum; i++) {
        const ElfW(Phdr) &ph = info->dlpi_phdr[i];
        if (ph.p_type == PT_LOAD) {
            const uintptr_t start = info->dlpi_addr + ph.p_vaddr;
            if (scan->anchor >= start && scan->anchor < start + ph.p_memsz) containsAnchor = true;
            if ((ph.p_flags & PF_X) && !(ph.p_flags & PF_W) && ph.p_filesz > 0) m.exec.emplace_back(start, ph.p_filesz);
        } else if (ph.p_type == PT_DYNAMIC) {
            for (const ElfW(Dyn) *d = reinterpret_cast<const ElfW(Dyn) *>(info->dlpi_addr + ph.p_vaddr); d->d_tag != DT_NULL; d++) {
                if (d->d_tag == DT_TEXTREL || (d->d_tag == DT_FLAGS && (d->d_un.d_val & DF_TEXTREL))) m.textRel = true;
            }
        }
    }
    const char *name = info->dlpi_name ? info->dlpi_name : "";
    m.isSelf = containsAnchor;
    if (containsAnchor || endsWith(name, AY_OBFUSCATE("/libc.so"))) scan->modules.push_back(m);
    return 0;
}

// 1 = identical, 0 = differs, -1 = could not compare.
int compareSegment(const std::vector<MapEntry> &maps, SafeReader &reader, uint64_t start, uint64_t len) {
    const MapEntry *map = integrity::findMapping(maps, start);
    if (map == nullptr || !map->readable || !integrity::isFileBacked(*map) || len > (64u << 20)) return -1;
    const int fd = SecureAPI::openat(AT_FDCWD, map->path.c_str(), O_RDONLY | O_CLOEXEC, 0);
    if (fd < 0) return -1;
    const uint64_t fileOffset = integrity::fileOffsetFor(*map, start);
    std::vector<uint8_t> mem(65536), disk(65536);
    int result = 1;
    for (uint64_t done = 0; done < len && result == 1;) {
        const size_t n = static_cast<size_t>(std::min<uint64_t>(len - done, mem.size()));
        if (!reader.read(reinterpret_cast<const void *>(start + done), mem.data(), n) ||
            !readFileRange(fd, fileOffset + done, disk.data(), n)) {
            result = -1;
        } else if (integrity::countDiff(mem.data(), disk.data(), n) != 0) {
            result = 0;
        }
        done += n;
    }
    SecureAPI::close(fd);
    return result;
}

}  // namespace

void LibIntegrity::anchor() {}

float LibIntegrity::confidence() {
    std::vector<MapEntry> maps;
    if (!loadMaps(maps)) return kUnsupported;
    Scan scan{reinterpret_cast<uintptr_t>(&LibIntegrity::anchor), {}};
    dl_iterate_phdr(collect, &scan);

    SafeReader reader;
    float best = kUnsupported;
    for (const Module &m : scan.modules) {
        if (m.textRel) continue;
        for (const auto &seg : m.exec) {
            const int cmp = compareSegment(maps, reader, seg.first, seg.second);
            if (cmp < 0) continue;
            const float conf = cmp == 0 ? (m.isSelf ? 0.9f : 0.85f) : 0.f;
            if (conf > best) best = conf;
            if (cmp == 0) LOGI("exec segment differs from disk (self=%d)", m.isSelf);
        }
    }
    return best;
}

float PrologueIntegrity::confidence() {
    std::vector<MapEntry> maps;
    if (!loadMaps(maps)) return kUnsupported;
    // Resolve through libc's own handle so an interposing library cannot answer for it.
    void *libc = dlopen(AY_OBFUSCATE("libc.so"), RTLD_NOW);
    if (libc == nullptr) return kUnsupported;

    const char *const names[] = {AY_OBFUSCATE("open"), AY_OBFUSCATE("read"), AY_OBFUSCATE("mmap"),
                                 AY_OBFUSCATE("connect"), AY_OBFUSCATE("ptrace"), AY_OBFUSCATE("fopen")};
    constexpr size_t kLen = 16;
    SafeReader reader;
    float best = kUnsupported;
    for (const char *name : names) {
        void *sym = dlsym(libc, name);
        if (sym == nullptr) continue;
        const uint64_t addr = reinterpret_cast<uintptr_t>(sym) & ~static_cast<uintptr_t>(1);  // clear Thumb bit
        const MapEntry *map = integrity::findMapping(maps, addr);
        if (map == nullptr || !map->executable || !integrity::isFileBacked(*map) || addr + kLen > map->end) continue;

        uint8_t mem[kLen], disk[kLen];
        const int fd = SecureAPI::openat(AT_FDCWD, map->path.c_str(), O_RDONLY | O_CLOEXEC, 0);
        if (fd < 0) continue;
        const bool ok = reader.read(reinterpret_cast<const void *>(addr), mem, kLen) &&
                        readFileRange(fd, integrity::fileOffsetFor(*map, addr), disk, kLen);
        SecureAPI::close(fd);
        if (!ok) continue;
        const float conf = integrity::prologueConfidence(integrity::hostArch(), mem, disk, kLen);
        if (conf > best) best = conf;
        if (conf > 0) LOGI("prologue of %s differs from disk", name);
    }
    dlclose(libc);
    return best;
}

}  // namespace ms
