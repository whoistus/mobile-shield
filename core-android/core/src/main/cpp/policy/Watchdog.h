// Opt-in KILL path: terminates the process after a random delay on its own thread.
// Detectors never terminate the process; only the policy engine schedules this.
#pragma once
#include <atomic>
#include <cstdint>

namespace ms {

class Watchdog {
public:
    using Terminator = void (*)();

    static Watchdog &instance();

    // Public so tests can use a fresh instance; production code only uses instance().
    Watchdog() = default;
    Watchdog(const Watchdog &) = delete;
    Watchdog &operator=(const Watchdog &) = delete;

    // Schedules termination once per process; later calls are no-ops. Not cancellable.
    void schedule(int64_t minDelayMs, int64_t maxDelayMs);

    bool isScheduled() const { return scheduled_.load(std::memory_order_acquire); }

    // Test seam: replaces the termination function.
    void setTerminatorForTest(Terminator t) { terminator_ = t; }

private:
    std::atomic<bool> scheduled_{false};
    Terminator terminator_ = nullptr;
};

}  // namespace ms
