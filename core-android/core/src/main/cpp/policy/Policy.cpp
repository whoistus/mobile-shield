#include "Policy.h"

#include <algorithm>
#include <cstring>

#include "Tiers.h"
#include "Watchdog.h"

namespace ms {

Policy &Policy::instance() {
    static Policy p;
    return p;
}

Policy::Policy() {
    // Before any config arrives: prod defaults (fail closed), threshold 0.7.
    static const int kProd[kCategoryCount] = {kBlock, kBlock, kWarn, kWarn, kBlock,
                                              kWarn,  kWarn,  kWarn, kWarn, kReport};
    for (int i = 0; i < kCategoryCount; i++) cfg_.actions[i] = kProd[i];
    cfg_.blockThreshold = 0.7;
    cfg_.killDelayMinMs = 500;
    cfg_.killDelayMaxMs = 3000;
    cfg_.prodFloor = true;
}

void Policy::apply(const PolicyConfig &cfg) {
    std::lock_guard<std::mutex> lock(mu_);
    cfg_ = cfg;
    for (int &a : cfg_.actions) {
        if (a < kReport || a > kKill) a = kReport;
    }
    if (!(cfg_.blockThreshold >= 0.0 && cfg_.blockThreshold <= 1.0)) cfg_.blockThreshold = 0.7;  // also rejects NaN
    cfg_.killDelayMinMs = std::min<int64_t>(std::max<int64_t>(cfg_.killDelayMinMs, 0), kMaxKillDelayMs);
    cfg_.killDelayMaxMs = std::min<int64_t>(std::max<int64_t>(cfg_.killDelayMaxMs, cfg_.killDelayMinMs), kMaxKillDelayMs);
    // Defence in depth: the Java config engine already clamps, native re-applies the floor.
    if (cfg_.prodFloor && cfg_.actions[kCategoryTampering] < kWarn) cfg_.actions[kCategoryTampering] = kWarn;
}

PolicyConfig Policy::snapshot() const {
    std::lock_guard<std::mutex> lock(mu_);
    return cfg_;
}

int Policy::evaluate(const PolicyConfig &cfg, int category, const char *detectorId, double confidence) {
    if (category < 0 || category >= kCategoryCount) return kReport;
    if (isExperimental(detectorId)) return kReport;
    int action = cfg.actions[category];
    if (action >= kBlock && confidence < cfg.blockThreshold) action = kWarn;
    // Config-protocol events (policy.floor, policy.badSignature) must never block or kill, whatever the host threshold.
    if (action > kWarn && detectorId != nullptr && std::strncmp(detectorId, "policy.", 7) == 0) action = kWarn;
    return action;
}

int Policy::decide(int category, const char *detectorId, double confidence) {
    PolicyConfig snapshot;
    {
        std::lock_guard<std::mutex> lock(mu_);
        snapshot = cfg_;
    }
    int action = evaluate(snapshot, category, detectorId, confidence);
    if (action >= kBlock) blocked_.store(true, std::memory_order_release);
    if (action == kKill) {
        try {
            Watchdog::instance().schedule(snapshot.killDelayMinMs, snapshot.killDelayMaxMs);
        } catch (...) {
            // Thread creation failed (std::system_error); the sticky block flag above still holds.
        }
    }
    return action;
}

}  // namespace ms
