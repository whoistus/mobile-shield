package io.mobileshield.detectors;

import android.content.Context;
import android.content.pm.PackageManager;
import android.hardware.Sensor;
import android.hardware.SensorManager;
import android.os.Build;
import io.mobileshield.model.ThreatCategory;
import java.io.File;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

/**
 * emulator.scored: multi-signal score. Single Build.* strings match white-label tablets, TV boxes and
 * AOSP ROMs, so only independent strong signals (two or more) reach the block threshold.
 */
public final class EmulatorScorer implements Detector {
    /** Raw observations; scoring is pure so it is unit-tested without a device. */
    public static final class Signals {
        public boolean qemuProps;
        public boolean qemuFiles;
        public boolean emulatorHardware;
        public int buildFieldHits;
        public boolean abiMismatch;
        public boolean noSensors;
        public boolean noTelephony;
    }

    private static final List<String> QEMU_FILES = Arrays.asList(
            "/dev/qemu_pipe", "/dev/goldfish_pipe", "/dev/socket/qemud", "/sys/qemu_trace",
            "/system/bin/qemu-props", "/system/lib/libc_malloc_debug_qemu.so",
            "/dev/socket/genyd", "/dev/socket/baseband_genyd");
    private static final List<String> EMULATOR_HARDWARE = Arrays.asList("goldfish", "ranchu", "vbox86", "nox", "ttvm_x86");

    @Override public String id() { return "emulator.scored"; }
    @Override public ThreatCategory category() { return ThreatCategory.EMULATOR; }

    public static int strongCount(Signals s) {
        return (s.qemuProps ? 1 : 0) + (s.qemuFiles ? 1 : 0) + (s.emulatorHardware ? 1 : 0) + (s.buildFieldHits >= 2 ? 1 : 0);
    }

    public static int weakCount(Signals s) {
        return (s.buildFieldHits == 1 ? 1 : 0) + (s.abiMismatch ? 1 : 0) + (s.noSensors ? 1 : 0) + (s.noTelephony ? 1 : 0);
    }

    /** 0 = clean. Two strong signals reach 0.9; one strong stays below the 0.7 block threshold. */
    public static double confidence(Signals s) {
        int strong = strongCount(s);
        int weak = weakCount(s);
        if (strong >= 3) return 0.95;
        if (strong == 2) return 0.9;
        if (strong == 1) return weak >= 2 ? 0.6 : 0.4;
        return weak >= 2 ? 0.2 : 0;
    }

    /** Number of Build fields that look like an emulator image. */
    public static int buildFieldHits(String fingerprint, String model, String manufacturer, String brand,
                                     String device, String product) {
        int hits = 0;
        String fp = lower(fingerprint);
        if (fp.startsWith("generic") || fp.startsWith("unknown") || fp.contains("emulator") || fp.contains("sdk_gphone")) hits++;
        String m = lower(model);
        if (m.contains("emulator") || m.contains("android sdk built for") || m.contains("google_sdk") || m.contains("sdk_gphone")) hits++;
        if (lower(manufacturer).contains("genymotion")) hits++;
        if (lower(brand).startsWith("generic") || lower(device).startsWith("generic")) hits++;
        String p = lower(product);
        if (p.contains("sdk") || p.contains("emulator") || p.contains("simulator") || p.contains("vbox")) hits++;
        return hits;
    }

    private static String lower(String s) {
        return s == null ? "" : s.toLowerCase(Locale.ROOT);
    }

    @Override public Finding run(DetectorEnv env) {
        try {
            Signals s = collect(env.context);
            double c = confidence(s);
            return c > 0 ? Finding.hit(c, "strongSignals", String.valueOf(strongCount(s))) : Finding.NONE;
        } catch (Throwable t) {
            return Finding.UNSUPPORTED;
        }
    }

    static Signals collect(Context context) {
        Signals s = new Signals();
        s.qemuProps = "1".equals(systemProperty("ro.kernel.qemu")) || "1".equals(systemProperty("ro.boot.qemu"));
        for (String f : QEMU_FILES) {
            if (new File(f).exists()) { s.qemuFiles = true; break; }
        }
        s.emulatorHardware = EMULATOR_HARDWARE.contains(lower(Build.HARDWARE));
        s.buildFieldHits = buildFieldHits(Build.FINGERPRINT, Build.MODEL, Build.MANUFACTURER, Build.BRAND, Build.DEVICE, Build.PRODUCT);
        boolean x86 = false;
        boolean arm = false;
        for (String abi : Build.SUPPORTED_ABIS) {
            x86 |= abi.startsWith("x86");
            arm |= abi.startsWith("arm");
        }
        s.abiMismatch = x86 && arm;
        SensorManager sm = (SensorManager) context.getSystemService(Context.SENSOR_SERVICE);
        s.noSensors = sm != null && sm.getSensorList(Sensor.TYPE_ALL).isEmpty();
        s.noTelephony = !context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_TELEPHONY);
        return s;
    }

    private static String systemProperty(String key) {
        try {
            Class<?> c = Class.forName("android.os.SystemProperties");
            return (String) c.getMethod("get", String.class).invoke(null, key);
        } catch (Throwable t) {
            return "";
        }
    }
}
