package io.mobileshield.detectors;

import android.content.Context;
import io.mobileshield.config.AppliedConfig;
import io.mobileshield.config.Bootstrap;

/** Everything a Java detector may read. */
public final class DetectorEnv {
    public final Context context;
    public final Bootstrap bootstrap;
    public final AppliedConfig config;

    public DetectorEnv(Context context, Bootstrap bootstrap, AppliedConfig config) {
        this.context = context;
        this.bootstrap = bootstrap;
        this.config = config;
    }
}
