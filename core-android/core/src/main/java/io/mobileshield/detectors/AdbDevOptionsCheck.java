package io.mobileshield.detectors;

import android.provider.Settings;
import io.mobileshield.model.ThreatCategory;

/** devoptions.adb: USB debugging enabled (0.6) or developer options merely switched on (0.4). */
public final class AdbDevOptionsCheck implements Detector {
    @Override public String id() { return "devoptions.adb"; }
    @Override public ThreatCategory category() { return ThreatCategory.DEV_OPTIONS_ADB; }

    @Override public Finding run(DetectorEnv env) {
        try {
            android.content.ContentResolver cr = env.context.getContentResolver();
            if (Settings.Global.getInt(cr, Settings.Global.ADB_ENABLED, 0) != 0) return Finding.hit(0.6, "setting", "adb");
            if (Settings.Global.getInt(cr, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) != 0) {
                return Finding.hit(0.4, "setting", "developerOptions");
            }
            return Finding.NONE;
        } catch (Throwable t) {
            return Finding.UNSUPPORTED;
        }
    }
}
