// Native readings of signals the Java side can also read; tampering.nativeVsJava compares them.
#pragma once
#include <string>

namespace ms {

// Directory of the APK mapped for `packageName` (matches "/<packageName>-" in /proc/self/maps),
// empty when none is mapped.
std::string mappedApkDir(const std::string &packageName);

}  // namespace ms
