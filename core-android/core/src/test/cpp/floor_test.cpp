// Native floor and config sanitising; observed through Policy::snapshot(), no side effects.
#include <gtest/gtest.h>

#include "policy/Policy.h"

namespace {

ms::PolicyConfig base(bool prod) {
    ms::PolicyConfig c{};
    for (int &a : c.actions) a = ms::kReport;
    c.blockThreshold = 0.7;
    c.killDelayMinMs = 500;
    c.killDelayMaxMs = 3000;
    c.prodFloor = prod;
    return c;
}

ms::PolicyConfig applied(const ms::PolicyConfig &in) {
    ms::Policy::instance().apply(in);
    return ms::Policy::instance().snapshot();
}

// Captured during static initialisation, before any test calls apply().
const ms::PolicyConfig kInitial = ms::Policy::instance().snapshot();

}  // namespace

TEST(NativeFloor, ProdRaisesTamperingToWarn) {
    EXPECT_EQ(ms::kWarn, applied(base(true)).actions[ms::kCategoryTampering]);
}

TEST(NativeFloor, ProdKeepsStricterTamperingActions) {
    for (int action : {ms::kWarn, ms::kBlock, ms::kKill}) {
        ms::PolicyConfig c = base(true);
        c.actions[ms::kCategoryTampering] = action;
        EXPECT_EQ(action, applied(c).actions[ms::kCategoryTampering]);
    }
}

TEST(NativeFloor, NonProdHasNoFloor) {
    EXPECT_EQ(ms::kReport, applied(base(false)).actions[ms::kCategoryTampering]);
}

TEST(NativeFloor, OnlyTamperingIsFloored) {
    ms::PolicyConfig out = applied(base(true));
    for (int i = 0; i < ms::kCategoryCount; i++) {
        if (i != ms::kCategoryTampering) EXPECT_EQ(ms::kReport, out.actions[i]) << "category " << i;
    }
}

TEST(NativeFloor, OutOfRangeActionsBecomeReportBeforeTheFloor) {
    ms::PolicyConfig c = base(true);
    c.actions[0] = 99;
    c.actions[1] = -4;
    c.actions[ms::kCategoryTampering] = 77;
    ms::PolicyConfig out = applied(c);
    EXPECT_EQ(ms::kReport, out.actions[0]);
    EXPECT_EQ(ms::kReport, out.actions[1]);
    EXPECT_EQ(ms::kWarn, out.actions[ms::kCategoryTampering]);
}

TEST(NativeSanitise, ThresholdOutsideZeroToOneResetsToDefault) {
    for (double bad : {-0.1, 1.5}) {
        ms::PolicyConfig c = base(true);
        c.blockThreshold = bad;
        EXPECT_DOUBLE_EQ(0.7, applied(c).blockThreshold);
    }
    ms::PolicyConfig edge = base(true);
    edge.blockThreshold = 1.0;
    EXPECT_DOUBLE_EQ(1.0, applied(edge).blockThreshold);
    edge.blockThreshold = 0.0;
    EXPECT_DOUBLE_EQ(0.0, applied(edge).blockThreshold);
}

TEST(NativeSanitise, KillDelaysAreClampedToAValidRange) {
    ms::PolicyConfig c = base(true);
    c.killDelayMinMs = -5;
    c.killDelayMaxMs = -10;
    ms::PolicyConfig out = applied(c);
    EXPECT_EQ(0, out.killDelayMinMs);
    EXPECT_EQ(0, out.killDelayMaxMs);

    c.killDelayMinMs = 800;
    c.killDelayMaxMs = 100;
    out = applied(c);
    EXPECT_EQ(800, out.killDelayMinMs);
    EXPECT_EQ(800, out.killDelayMaxMs);
}

TEST(NativeSanitise, HugeKillDelaysSaturateInsteadOfWrapping) {
    ms::PolicyConfig c = base(true);
    c.killDelayMinMs = 4294967296LL;
    c.killDelayMaxMs = 4294967296LL;
    ms::PolicyConfig out = applied(c);
    EXPECT_EQ(ms::kMaxKillDelayMs, out.killDelayMinMs);
    EXPECT_EQ(ms::kMaxKillDelayMs, out.killDelayMaxMs);
}

TEST(NativeDefaults, BeforeAnyConfigTheEngineFailsClosedLikeProd) {
    EXPECT_EQ(ms::kBlock, kInitial.actions[0]);                     // ROOT
    EXPECT_EQ(ms::kBlock, kInitial.actions[1]);                     // EMULATOR
    EXPECT_EQ(ms::kBlock, kInitial.actions[ms::kCategoryTampering]);
    EXPECT_EQ(ms::kReport, kInitial.actions[9]);                    // VPN_PROXY
    EXPECT_DOUBLE_EQ(0.7, kInitial.blockThreshold);
    EXPECT_TRUE(kInitial.prodFloor);
}
