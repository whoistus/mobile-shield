// Native policy engine: decision table shared with the Java/iOS vectors plus the stateful paths.
#include <gtest/gtest.h>

#include <atomic>
#include <chrono>
#include <thread>

#include "policy/Policy.h"
#include "policy/Watchdog.h"

namespace {

struct Row {
    const char *name;
    int actions[ms::kCategoryCount];
    double threshold;
    int category;
    const char *detectorId;
    double confidence;
    int expected;
};

const Row kRows[] = {
#include "decision_vectors.inc"
};

ms::PolicyConfig configFrom(const Row &r) {
    ms::PolicyConfig c{};
    for (int i = 0; i < ms::kCategoryCount; i++) c.actions[i] = r.actions[i];
    c.blockThreshold = r.threshold;
    c.killDelayMinMs = 10;
    c.killDelayMaxMs = 20;
    c.prodFloor = true;
    return c;
}

ms::PolicyConfig uniform(int action, double threshold = 0.7) {
    ms::PolicyConfig c{};
    for (int &a : c.actions) a = action;
    c.blockThreshold = threshold;
    c.killDelayMinMs = 10;
    c.killDelayMaxMs = 20;
    return c;
}

std::atomic<int> terminated{0};
void fakeTerminate() { terminated++; }

}  // namespace

TEST(PolicyVectors, EveryGeneratedRowMatches) {
    ASSERT_GT(sizeof(kRows) / sizeof(kRows[0]), 5u);
    for (const Row &r : kRows) {
        SCOPED_TRACE(std::string(r.name) + " " + r.detectorId);
        EXPECT_EQ(r.expected, ms::Policy::evaluate(configFrom(r), r.category, r.detectorId, r.confidence));
    }
}

TEST(PolicyEvaluate, BlockAndKillNeedTheThreshold) {
    EXPECT_EQ(ms::kBlock, ms::Policy::evaluate(uniform(ms::kBlock), 0, "root.suPaths", 0.7));
    EXPECT_EQ(ms::kWarn, ms::Policy::evaluate(uniform(ms::kBlock), 0, "root.suPaths", 0.69));
    EXPECT_EQ(ms::kKill, ms::Policy::evaluate(uniform(ms::kKill), 3, "hooking.custom", 1.0));
    EXPECT_EQ(ms::kWarn, ms::Policy::evaluate(uniform(ms::kKill), 3, "hooking.custom", 0.1));
}

TEST(PolicyEvaluate, ThresholdComparisonKeepsDoublePrecision) {
    EXPECT_EQ(ms::kWarn, ms::Policy::evaluate(uniform(ms::kBlock, 0.80000001), 0, "root.suPaths", 0.8));
    EXPECT_EQ(ms::kBlock, ms::Policy::evaluate(uniform(ms::kBlock, 0.8), 0, "root.suPaths", 0.8));
}

TEST(PolicyEvaluate, ReportAndWarnIgnoreConfidence) {
    EXPECT_EQ(ms::kReport, ms::Policy::evaluate(uniform(ms::kReport), 0, "root.suPaths", 1.0));
    EXPECT_EQ(ms::kWarn, ms::Policy::evaluate(uniform(ms::kWarn), 0, "root.suPaths", 0.01));
}

TEST(PolicyEvaluate, EveryExperimentalIdIsReportOnly) {
    const char *ids[] = {"root.buildTags", "hooking.fridaThreads", "hooking.fridaFd", "hooking.fridaMaps",
                         "hooking.dbusProbe", "hooking.prologue", "hooking.libIntegrity", "tampering.memDump"};
    for (const char *id : ids) {
        SCOPED_TRACE(id);
        EXPECT_EQ(ms::kReport, ms::Policy::evaluate(uniform(ms::kKill), 3, id, 1.0));
    }
}

TEST(PolicyEvaluate, UnknownIdsAreProdTierAndBadCategoriesReport) {
    EXPECT_EQ(ms::kBlock, ms::Policy::evaluate(uniform(ms::kBlock), 0, "host.custom", 0.9));
    EXPECT_EQ(ms::kReport, ms::Policy::evaluate(uniform(ms::kKill), -1, "root.suPaths", 1.0));
    EXPECT_EQ(ms::kReport, ms::Policy::evaluate(uniform(ms::kKill), ms::kCategoryCount, "root.suPaths", 1.0));
    EXPECT_EQ(ms::kBlock, ms::Policy::evaluate(uniform(ms::kBlock), 0, nullptr, 0.9));
}

TEST(PolicyEvaluate, ConfigProtocolEventsNeverBlockEvenWithALowThreshold) {
    ms::PolicyConfig c = uniform(ms::kKill, 0.1);
    EXPECT_EQ(ms::kWarn, ms::Policy::evaluate(c, ms::kCategoryTampering, "policy.floor", 0.5));
    EXPECT_EQ(ms::kWarn, ms::Policy::evaluate(c, ms::kCategoryTampering, "policy.badSignature", 1.0));
    EXPECT_EQ(ms::kKill, ms::Policy::evaluate(c, ms::kCategoryTampering, "tampering.signature", 0.5));
}

TEST(PolicyDecide, StickyBlockAndSingleWatchdogKill) {
    ms::Watchdog::instance().setTerminatorForTest(&fakeTerminate);
    ms::Policy &p = ms::Policy::instance();

    ms::PolicyConfig cfg = uniform(ms::kWarn);
    cfg.actions[3] = ms::kKill;  // HOOKING
    cfg.killDelayMinMs = 50;
    cfg.killDelayMaxMs = 60;
    p.apply(cfg);

    EXPECT_EQ(ms::kWarn, p.decide(3, "hooking.custom", 0.5));
    EXPECT_FALSE(p.isBlocked());
    EXPECT_EQ(ms::kReport, p.decide(3, "hooking.fridaThreads", 1.0));
    EXPECT_FALSE(p.isBlocked());
    EXPECT_FALSE(ms::Watchdog::instance().isScheduled());

    EXPECT_EQ(ms::kKill, p.decide(3, "hooking.custom", 0.9));
    EXPECT_TRUE(p.isBlocked());
    EXPECT_TRUE(ms::Watchdog::instance().isScheduled());
    p.decide(3, "hooking.custom", 0.9);
    EXPECT_EQ(0, terminated.load()) << "termination must be delayed, not inline";

    std::this_thread::sleep_for(std::chrono::milliseconds(300));
    EXPECT_EQ(1, terminated.load());

    p.apply(uniform(ms::kReport));
    EXPECT_TRUE(p.isBlocked()) << "blocked flag survives config changes";
}
