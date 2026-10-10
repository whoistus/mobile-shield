// Native policy engine: the authoritative place where category + confidence become an action.
#pragma once
#include <atomic>
#include <cstdint>
#include <mutex>

namespace ms {

// Ordinals match io.mobileshield.model.ThreatCategory / Action.
constexpr int kCategoryCount = 10;
constexpr int kCategoryTampering = 4;
// Upper bound for a configured kill delay; larger values would stall the watchdog for minutes.
constexpr int64_t kMaxKillDelayMs = 60000;
enum Action : int { kReport = 0, kWarn = 1, kBlock = 2, kKill = 3 };

struct PolicyConfig {
    int actions[kCategoryCount];
    double blockThreshold;
    int64_t killDelayMinMs;
    int64_t killDelayMaxMs;
    bool prodFloor;  // prod channel: TAMPERING never below WARN
};

class Policy {
public:
    static Policy &instance();

    // Atomically replaces the active config; used from the next decision on.
    void apply(const PolicyConfig &cfg);

    // Decides the action for one detector hit and applies its side effects
    // (sticky blocked flag; KILL hands off to the watchdog).
    int decide(int category, const char *detectorId, double confidence);

    // Pure decision without side effects (tests, previews).
    static int evaluate(const PolicyConfig &cfg, int category, const char *detectorId, double confidence);

    bool isBlocked() const { return blocked_.load(std::memory_order_acquire); }

    // Active config after sanitising; lets tests observe what apply() clamped.
    PolicyConfig snapshot() const;

private:
    Policy();
    mutable std::mutex mu_;
    PolicyConfig cfg_;
    std::atomic<bool> blocked_{false};
};

}  // namespace ms
