package io.mobileshield;

public final class MobileShield {
    private static volatile boolean nativeLoaded;
    private static boolean loadAttempted;

    private MobileShield() {}

    /**
     * SDK version. Round-trips through JNI when the native library is loaded;
     * falls back to the Java constant otherwise (e.g. JVM unit tests).
     */
    public static String getSdkVersion() {
        if (ensureNativeLoaded()) {
            String v = nativeVersion();
            if (v != null && !v.isEmpty()) {
                return v;
            }
        }
        return BuildConfig.SDK_VERSION;
    }

    /** True when libmobileshield.so was loaded in this process. */
    public static boolean isNativeAvailable() {
        return ensureNativeLoaded();
    }

    static synchronized boolean ensureNativeLoaded() {
        if (!loadAttempted) {
            loadAttempted = true;
            try {
                System.loadLibrary("mobileshield");
                nativeLoaded = true;
            } catch (UnsatisfiedLinkError e) {
                nativeLoaded = false;
            }
        }
        return nativeLoaded;
    }

    static native String nativeVersion();
}
