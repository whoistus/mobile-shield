package io.mobileshield.internal;

import io.mobileshield.model.ThreatCategory;

/** JNI surface of libmobileshield.so. Internal: not part of the public API. */
public final class NativeBridge {
    /** One native detector as registered in cpp/detectors/Registry.cpp. */
    public static final class Entry {
        public final String id;
        public final ThreatCategory category;

        Entry(String id, ThreatCategory category) {
            this.id = id;
            this.category = category;
        }
    }

    private static boolean attempted;
    private static boolean loaded;
    private static Entry[] catalog;

    private NativeBridge() {}

    public static synchronized boolean ensureLoaded() {
        if (!attempted) {
            attempted = true;
            try {
                System.loadLibrary("mobileshield");
                loaded = true;
            } catch (UnsatisfiedLinkError e) {
                loaded = false;
            }
        }
        return loaded;
    }

    /** Native detectors in the order {@link #runChecks} reports them. */
    public static synchronized Entry[] catalog() {
        if (catalog == null) {
            String[] ids = nativeCatalog();
            int[] categories = nativeCatalogCategories();
            if (ids == null || categories == null || ids.length != categories.length) return new Entry[0];
            ThreatCategory[] all = ThreatCategory.values();
            Entry[] entries = new Entry[ids.length];
            for (int i = 0; i < ids.length; i++) entries[i] = new Entry(ids[i], all[categories[i]]);
            catalog = entries;
        }
        return catalog;
    }

    /** Confidence per catalog entry: 0 clean, negative = disabled or unsupported. Null on failure. */
    public static float[] runChecks(String[] disabled) {
        return ensureLoaded() ? nativeRunChecks(disabled) : null;
    }

    /** Native readings for the cross-check: [suPresent "1"/"0", TracerPid, version, mapped APK dir]. */
    public static String[] crossReadings(String packageName) {
        return ensureLoaded() ? nativeCrossReadings(packageName) : null;
    }

    public static String version() {
        return ensureLoaded() ? nativeVersion() : null;
    }

    public static boolean isBlocked() {
        return ensureLoaded() && nativeIsBlocked();
    }

    public static int decide(int category, String detectorId, double confidence) {
        return nativeDecide(category, detectorId, confidence);
    }

    /** Kill delays are clamped natively to [0, 60000] ms; the threshold stays double so Java and native agree. */
    public static void configure(int[] actions, double threshold, long minDelayMs, long maxDelayMs, boolean prod) {
        nativeConfigure(actions, threshold, minDelayMs, maxDelayMs, prod);
    }

    private static native String nativeVersion();
    private static native void nativeConfigure(int[] actions, double threshold, long minDelay, long maxDelay, boolean prod);
    private static native int nativeDecide(int category, String id, double confidence);
    private static native boolean nativeIsBlocked();
    private static native String[] nativeCatalog();
    private static native int[] nativeCatalogCategories();
    private static native float[] nativeRunChecks(String[] disabled);
    private static native String[] nativeCrossReadings(String packageName);
}
