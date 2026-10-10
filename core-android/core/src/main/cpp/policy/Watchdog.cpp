#include "Watchdog.h"

#include <unistd.h>

#include <chrono>
#include <random>
#include <thread>

namespace ms {

Watchdog &Watchdog::instance() {
    static Watchdog w;
    return w;
}

void Watchdog::schedule(int64_t minDelayMs, int64_t maxDelayMs) {
    bool expected = false;
    if (!scheduled_.compare_exchange_strong(expected, true)) return;
    if (minDelayMs < 0) minDelayMs = 0;
    if (maxDelayMs < minDelayMs) maxDelayMs = minDelayMs;
    std::random_device rd;
    std::uniform_int_distribution<int64_t> dist(minDelayMs, maxDelayMs);
    const int64_t delay = dist(rd);
    Terminator t = terminator_;
    std::thread([delay, t]() {
        std::this_thread::sleep_for(std::chrono::milliseconds(delay));
        if (t != nullptr) {
            t();
        } else {
            _exit(0);
        }
    }).detach();
}

}  // namespace ms
