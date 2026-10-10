// Small raw-syscall file helpers shared by the native detectors.
#pragma once
#include <fcntl.h>

#include <string>

#include "../secure/SecureAPI.h"

namespace ms {

// Reads a whole (small) file; returns false when it cannot be opened or read.
inline bool readFile(const char *path, std::string &out, size_t maxBytes = 1u << 20) {
    out.clear();
    const int fd = SecureAPI::openat(AT_FDCWD, path, O_RDONLY | O_CLOEXEC, 0);
    if (fd < 0) return false;
    char buf[4096];
    bool ok = true;
    while (out.size() < maxBytes) {
        const long n = static_cast<long>(SecureAPI::read(fd, buf, sizeof(buf)));
        if (n < 0) {
            ok = false;
            break;
        }
        if (n == 0) break;
        out.append(buf, static_cast<size_t>(n));
    }
    SecureAPI::close(fd);
    return ok;
}

// Calls fn(name, d_type, dirFd) for every entry except "." and ".."; fn returns true to stop.
// Returns false when the directory cannot be opened.
template <typename Fn>
inline bool forEachEntry(const char *path, Fn fn) {
    const int fd = SecureAPI::openat(AT_FDCWD, path, O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0);
    if (fd < 0) return false;
    alignas(8) char buf[1024];
    bool stop = false;
    long n;
    while (!stop && (n = SecureAPI::getdents64(fd, reinterpret_cast<linux_dirent64 *>(buf), sizeof(buf))) > 0) {
        for (long pos = 0; pos < n && !stop;) {
            auto *d = reinterpret_cast<linux_dirent64 *>(buf + pos);
            pos += d->d_reclen;
            if (d->d_name[0] == '.' && (d->d_name[1] == '\0' || (d->d_name[1] == '.' && d->d_name[2] == '\0'))) {
                continue;
            }
            stop = fn(static_cast<const char *>(d->d_name), d->d_type, fd);
        }
    }
    SecureAPI::close(fd);
    return true;
}

inline bool contains(const std::string &hay, const char *needle) {
    return hay.find(needle) != std::string::npos;
}

}  // namespace ms
