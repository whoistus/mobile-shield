package io.mobileshield.config;

import io.mobileshield.model.Action;
import io.mobileshield.model.ThreatCategory;
import java.util.Arrays;
import java.util.Collections;
import java.util.EnumMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Compiled-in defaults from design.md: channel table, prod floor, launch tiers. */
public final class Defaults {
    private Defaults() {}

    public static final String CHANNEL_DEV = "dev";
    public static final String CHANNEL_TEST = "test";
    public static final String CHANNEL_PROD = "prod";

    public static final double BLOCK_THRESHOLD = 0.7;
    public static final long MONITORING_INTERVAL_MS = 5000;
    public static final long MONITORING_INTERVAL_MIN_MS = 1000;
    public static final long[] KILL_DELAY_MS_RANGE = {500, 3000};

    public static final List<String> INSTALLER_ALLOWLIST = Collections.unmodifiableList(Arrays.asList(
            "com.android.vending", "com.huawei.appmarket", "com.xiaomi.market", "com.xiaomi.mipicks",
            "com.sec.android.app.samsungapps", "com.amazon.venezia", "com.heytap.market",
            "com.oppo.market", "com.bbk.appstore", "com.hihonor.appmarket"));

    /** Detector ids that the prod floor never lets a config disable. */
    public static final Set<String> FLOOR_IDS = Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
            "tampering.signature", "tampering.nativeVsJava")));

    /** Minimum action for TAMPERING on the prod channel. */
    public static final Action FLOOR_MIN_TAMPERING = Action.WARN;

    /** Experimental-tier ids: always REPORT until promoted in a release. Mirrors cpp/policy/Tiers.h. */
    public static final Set<String> EXPERIMENTAL_IDS = Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
            "root.buildTags", "hooking.fridaThreads", "hooking.fridaFd", "hooking.fridaMaps",
            "hooking.dbusProbe", "hooking.prologue", "hooking.libIntegrity", "tampering.memDump")));

    /** Normalises a bootstrap channel; anything missing or unknown fails closed to prod. */
    public static String channel(String raw) {
        if (CHANNEL_DEV.equals(raw) || CHANNEL_TEST.equals(raw)) return raw;
        return CHANNEL_PROD;
    }

    public static Map<ThreatCategory, Action> policies(String channel) {
        Map<ThreatCategory, Action> m = new EnumMap<>(ThreatCategory.class);
        String ch = channel(channel);
        for (ThreatCategory c : ThreatCategory.values()) m.put(c, Action.REPORT);
        if (CHANNEL_TEST.equals(ch)) {
            m.put(ThreatCategory.ROOT, Action.WARN);
            m.put(ThreatCategory.DEBUGGER, Action.WARN);
            m.put(ThreatCategory.HOOKING, Action.WARN);
            m.put(ThreatCategory.TAMPERING, Action.WARN);
        } else if (CHANNEL_PROD.equals(ch)) {
            m.put(ThreatCategory.ROOT, Action.BLOCK);
            m.put(ThreatCategory.EMULATOR, Action.BLOCK);
            m.put(ThreatCategory.DEBUGGER, Action.WARN);
            m.put(ThreatCategory.HOOKING, Action.WARN);
            m.put(ThreatCategory.TAMPERING, Action.BLOCK);
            m.put(ThreatCategory.INSTALLER, Action.WARN);
            m.put(ThreatCategory.SCREEN_CAPTURE, Action.WARN);
            m.put(ThreatCategory.DEV_OPTIONS_ADB, Action.WARN);
            m.put(ThreatCategory.NO_DEVICE_LOCK, Action.WARN);
        }
        return m;
    }
}
