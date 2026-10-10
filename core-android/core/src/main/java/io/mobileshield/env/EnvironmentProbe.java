package io.mobileshield.env;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import io.mobileshield.attest.AttestationRegistry;
import io.mobileshield.detectors.InstallerCheck;
import io.mobileshield.model.EnvironmentInfo;

/**
 * Describes the host environment. GMS and HMS are probed by package query and reflection only:
 * the core has no compile-time dependency on either, and absence is never a threat.
 */
public final class EnvironmentProbe {
    static final String GMS_PACKAGE = "com.google.android.gms";
    static final String HMS_PACKAGE = "com.huawei.hwid";
    private static final String GMS_API_CLASS = "com.google.android.gms.common.GoogleApiAvailability";

    private EnvironmentProbe() {}

    public static EnvironmentInfo probe(Context context, String sdkVersion) {
        boolean debuggable = (context.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        return new EnvironmentInfo(sdkVersion, Build.VERSION.RELEASE, Build.SUPPORTED_ABIS[0], debuggable,
                gmsInstalled(context) && gmsApiOnClasspath(), hmsInstalled(context),
                InstallerCheck.installerOf(context), AttestationRegistry.kinds());
    }

    public static boolean gmsInstalled(Context context) { return installed(context, GMS_PACKAGE); }

    public static boolean hmsInstalled(Context context) { return installed(context, HMS_PACKAGE); }

    /** The host app bundles the Play services API (needed before a GMS-backed provider could work). */
    public static boolean gmsApiOnClasspath() {
        try {
            Class.forName(GMS_API_CLASS);
            return true;
        } catch (ClassNotFoundException | LinkageError e) {
            return false;
        }
    }

    /** Installed and the Play services client reports SUCCESS; reflection keeps the dependency optional. */
    public static boolean gmsProviderUsable(Context context) {
        if (!gmsInstalled(context) || !gmsApiOnClasspath()) return false;
        try {
            Class<?> api = Class.forName(GMS_API_CLASS);
            Object instance = api.getMethod("getInstance").invoke(null);
            Object status = api.getMethod("isGooglePlayServicesAvailable", Context.class).invoke(instance, context);
            return Integer.valueOf(0).equals(status);
        } catch (Throwable t) {
            return false;
        }
    }

    private static boolean installed(Context context, String pkg) {
        try {
            context.getPackageManager().getPackageInfo(pkg, 0);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        } catch (RuntimeException e) {
            return false;
        }
    }
}
