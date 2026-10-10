// The watchdog is the only code path allowed to end the process; its terminator is faked here.
#include <gtest/gtest.h>

#include <atomic>
#include <chrono>
#include <thread>

#include "policy/Watchdog.h"

namespace {
std::atomic<int> fired{0};
std::atomic<long long> firedAtMs{0};

long long nowMs() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::steady_clock::now().time_since_epoch()).count();
}

void terminator() {
    firedAtMs = nowMs();
    fired++;
}

void resetFakes() {
    fired = 0;
    firedAtMs = 0;
}
}  // namespace

TEST(Watchdog, FiresOnceAfterTheDelayAndNotInline) {
    resetFakes();
    ms::Watchdog w;
    w.setTerminatorForTest(&terminator);
    EXPECT_FALSE(w.isScheduled());

    const long long start = nowMs();
    w.schedule(80, 80);
    EXPECT_TRUE(w.isScheduled());
    EXPECT_EQ(0, fired.load());

    std::this_thread::sleep_for(std::chrono::milliseconds(400));
    ASSERT_EQ(1, fired.load());
    EXPECT_GE(firedAtMs.load() - start, 70);
}

TEST(Watchdog, LaterSchedulesAreNoOps) {
    resetFakes();
    ms::Watchdog w;
    w.setTerminatorForTest(&terminator);
    w.schedule(20, 30);
    w.schedule(0, 0);
    w.schedule(0, 0);
    std::this_thread::sleep_for(std::chrono::milliseconds(300));
    EXPECT_EQ(1, fired.load());
}

TEST(Watchdog, DelayStaysInsideTheConfiguredRange) {
    for (int i = 0; i < 5; i++) {
        resetFakes();
        ms::Watchdog w;
        w.setTerminatorForTest(&terminator);
        const long long start = nowMs();
        w.schedule(60, 120);
        std::this_thread::sleep_for(std::chrono::milliseconds(400));
        ASSERT_EQ(1, fired.load());
        const long long delay = firedAtMs.load() - start;
        EXPECT_GE(delay, 50);
        EXPECT_LE(delay, 300);
    }
}

TEST(Watchdog, NegativeAndInvertedRangesAreNormalised) {
    resetFakes();
    ms::Watchdog w;
    w.setTerminatorForTest(&terminator);
    w.schedule(-100, -200);
    std::this_thread::sleep_for(std::chrono::milliseconds(200));
    EXPECT_EQ(1, fired.load());

    resetFakes();
    ms::Watchdog inverted;
    inverted.setTerminatorForTest(&terminator);
    inverted.schedule(50, 10);
    std::this_thread::sleep_for(std::chrono::milliseconds(300));
    EXPECT_EQ(1, fired.load());
}

TEST(Watchdog, SeparateInstancesAreIndependentButTheSingletonIsShared) {
    ms::Watchdog a, b;
    EXPECT_FALSE(a.isScheduled());
    EXPECT_FALSE(b.isScheduled());
    EXPECT_EQ(&ms::Watchdog::instance(), &ms::Watchdog::instance());
}
