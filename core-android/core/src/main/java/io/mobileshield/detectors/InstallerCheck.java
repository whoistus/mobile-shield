package io.mobileshield.detectors;

import android.content.Context;
import android.os.Build;
import io.mobileshield.model.ThreatCategory;
import java.util.List;

/** installer.source: the app was not installed by an allowlisted store. Never reaches KILL. */
public final class InstallerCheck implements Detector {
    public enum Source { STORE, SIDELOAD, UNLISTED }

    static final double CONFIDENCE = 0.5;

    @Override public String id() { return "installer.source"; }
    @Override public ThreatCategory category() { return ThreatCategory.INSTALLER; }

    /** Allowlist wins; then null (adb, MDM, unknown) and any "*.packageinstaller" count as sideload. */
    public static Source classify(String installer, List<String> allowlist) {
        if (installer != null && allowlist.contains(installer)) return Source.STORE;
        if (installer == null || installer.endsWith(".packageinstaller")) return Source.SIDELOAD;
        return Source.UNLISTED;
    }

    public static double confidence(Source source) {
        return source == Source.STORE ? 0 : CONFIDENCE;
    }

    /** Installing package name, or null when unknown. */
    public static String installerOf(Context context) {
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                return context.getPackageManager().getInstallSourceInfo(context.getPackageName()).getInstallingPackageName();
            }
            return context.getPackageManager().getInstallerPackageName(context.getPackageName());
        } catch (Exception e) {
            return null;
        }
    }

    @Override public Finding run(DetectorEnv env) {
        Source source = classify(installerOf(env.context), env.config.installerAllowlist);
        return source == Source.STORE
                ? Finding.NONE
                : Finding.hit(CONFIDENCE, "source", source == Source.SIDELOAD ? "sideload" : "unlisted");
    }
}
