#include "CrossReadings.h"

#include "../util/Fs.h"
#include "../util/obfuscate.h"
#include "IntegrityLogic.h"

namespace ms {

std::string mappedApkDir(const std::string &packageName) {
    if (packageName.empty()) return std::string();
    std::string maps;
    if (!readFile(AY_OBFUSCATE("/proc/self/maps"), maps, 4u << 20)) return std::string();
    const std::string marker = "/" + packageName + "-";
    for (const integrity::MapEntry &e : integrity::parseMaps(maps)) {
        const size_t at = e.path.find(marker);
        if (at == std::string::npos || e.path.size() < 4 || e.path.compare(e.path.size() - 4, 4, ".apk") != 0) continue;
        const size_t slash = e.path.rfind('/');
        return e.path.substr(0, slash);
    }
    return std::string();
}

}  // namespace ms
