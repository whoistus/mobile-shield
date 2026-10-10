package io.mobileshield.detectors;

import android.app.KeyguardManager;
import android.content.Context;
import android.os.Build;
import io.mobileshield.model.ThreatCategory;

/** devicelock.absent: no PIN, pattern, password or biometric-backed lock screen. */
public final class DeviceLockCheck implements Detector {
    @Override public String id() { return "devicelock.absent"; }
    @Override public ThreatCategory category() { return ThreatCategory.NO_DEVICE_LOCK; }

    @Override public Finding run(DetectorEnv env) {
        try {
            KeyguardManager km = (KeyguardManager) env.context.getSystemService(Context.KEYGUARD_SERVICE);
            if (km == null) return Finding.UNSUPPORTED;
            boolean secure = Build.VERSION.SDK_INT >= 23 ? km.isDeviceSecure() : km.isKeyguardSecure();
            return Finding.hit(secure ? 0 : 0.8);
        } catch (Throwable t) {
            return Finding.UNSUPPORTED;
        }
    }
}
