package io.mobileshield;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import io.mobileshield.attest.AttestationRegistry;
import io.mobileshield.config.AppliedConfig;
import io.mobileshield.config.Bootstrap;
import io.mobileshield.config.ConfigStore;
import io.mobileshield.config.Defaults;
import io.mobileshield.env.EnvironmentProbe;
import io.mobileshield.internal.NativeBridge;
import io.mobileshield.model.Action;
import io.mobileshield.model.EnvironmentInfo;
import io.mobileshield.model.ThreatCategory;
import io.mobileshield.model.ThreatEvent;
import java.lang.ref.WeakReference;
import java.util.Collections;
import java.util.List;
import org.json.JSONObject;

/**
 * Public facade. Bootstrap values are read from the signed application manifest, detectors report
 * evidence, and the native policy engine decides the action for every event.
 */
public final class MobileShield {
    public interface Listener { void onThreat(ThreatEvent event); }

    private static final CheckRunner runner = new CheckRunner();
    private static final Monitor monitor = new Monitor(new Monitor.Cycle() {
        @Override public void run() { runChecks(); }
        @Override public long intervalMs() { return core == null ? 5000 : core.config().monitoringIntervalMs; }
        @Override public boolean inForeground() { return lifecycle == null || lifecycle.inForeground(); }
    });
    // Static so wrappers can subscribe before init and still receive the first pass.
    private static final EventHub earlyHub = new EventHub();
    private static volatile Context context;
    private static volatile Bootstrap bootstrap;
    private static volatile ShieldCore core;
    private static volatile AppLifecycle lifecycle;
    private static WeakReference<Activity> pendingActivity;

    private MobileShield() {}

    public static String getSdkVersion() {
        String value = NativeBridge.version();
        return value != null && !value.isEmpty() ? value : BuildConfig.SDK_VERSION;
    }

    public static boolean isNativeAvailable() { return NativeBridge.ensureLoaded(); }

    public static synchronized EnvironmentInfo init(Context host, JSONObject runtime) throws MobileShieldException {
        if (!NativeBridge.ensureLoaded()) {
            throw new MobileShieldException(MobileShieldException.Reason.NativeUnavailable, "native library is unavailable");
        }
        Context app = host.getApplicationContext();
        if (context == null) {
            bootstrap = Bootstrap.fromManifest(app);
            core = new ShieldCore(bootstrap, new NativePlatform(app), earlyHub);
            context = app;
            restoreLastKnownGood(app);
            lifecycle = new AppLifecycle(new AppLifecycle.Listener() {
                @Override public void onForeground() { monitor.wake(); }
                @Override public void onScreenCaptured() { core.emitOne(ThreatCategory.SCREEN_CAPTURE, "screen.captured", 0.9); }
            });
            if (app instanceof Application) ((Application) app).registerActivityLifecycleCallbacks(lifecycle);
            Activity waiting = pendingActivity == null ? null : pendingActivity.get();
            pendingActivity = null;
            if (waiting != null) attachActivity(waiting);
        }
        MobileShieldException rejected = null;
        if (runtime != null) {
            try {
                updateConfig(runtime);
            } catch (MobileShieldException e) {
                rejected = e;
            }
        }
        // The SDK stays initialised on a rejected config (defaults or last-known-good apply); the host still sees why.
        runChecks();
        if (rejected != null) throw rejected;
        return EnvironmentProbe.probe(app, getSdkVersion());
    }

    public static AppliedConfig updateConfig(JSONObject runtime) throws MobileShieldException {
        requireInit();
        if (bootstrap.isProd() && bootstrap.configPublicKey == null) {
            throw new MobileShieldException(MobileShieldException.Reason.BootstrapMissing,
                    "production runtime config requires a public key");
        }
        return core.update(runtime, true);
    }

    public static AppliedConfig getConfig() throws MobileShieldException { requireInit(); return core.config(); }
    public static boolean isBlocked() { return NativeBridge.isBlocked(); }

    /**
     * Events raised while no listener is registered (the first check pass at init) are buffered, at
     * most 64, and replayed to the first listener that registers.
     */
    public static void addListener(Listener listener) { earlyHub.add(listener); }
    public static void removeListener(Listener listener) { earlyHub.remove(listener); }

    /**
     * Tells the SDK which activity is already started when {@link #init} runs mid-session (React
     * Native, Flutter): counts it as foreground and registers the API 34 screenshot callback.
     * Safe to call from any thread, repeatedly, and before init (applied once init completes).
     */
    public static void attachActivity(final Activity activity) {
        if (activity == null) return;
        synchronized (MobileShield.class) {
            if (lifecycle == null) {
                pendingActivity = new WeakReference<>(activity);
                return;
            }
        }
        final AppLifecycle target = lifecycle;
        if (Looper.myLooper() == Looper.getMainLooper()) {
            target.seed(activity);
        } else {
            new Handler(Looper.getMainLooper()).post(new Runnable() { @Override public void run() { target.seed(activity); } });
        }
    }

    public static void startMonitoring() throws MobileShieldException { requireInit(); monitor.start(); }
    public static void stopMonitoring() { monitor.stop(); }

    public static List<ThreatEvent> runChecks() {
        ShieldCore current = core;
        return current == null ? Collections.<ThreatEvent>emptyList() : current.runChecks();
    }

    public static JSONObject attestEnrol(String kind, String nonce) { return AttestationRegistry.unsupported(kind); }
    public static JSONObject attestAssert(String kind, String nonce, String requestHash) { return AttestationRegistry.unsupported(kind); }

    private static void restoreLastKnownGood(Context app) {
        JSONObject saved = new ConfigStore(app).lastKnownGood();
        if (saved == null || (bootstrap.isProd() && bootstrap.configPublicKey == null)) return;
        try {
            core.update(saved, false);
        } catch (MobileShieldException ignored) {
            // Expired, re-keyed or corrupt: channel defaults stay active.
        }
    }

    private static void requireInit() throws MobileShieldException {
        if (context == null) throw new MobileShieldException(MobileShieldException.Reason.NotInitialized, "call init first");
    }

    private static final class NativePlatform implements ShieldCore.Platform {
        private final Context app;
        private final ConfigStore store;

        NativePlatform(Context app) {
            this.app = app;
            this.store = new ConfigStore(app);
        }

        @Override public void push(AppliedConfig value) {
            int[] actions = new int[ThreatCategory.values().length];
            for (ThreatCategory category : ThreatCategory.values()) actions[category.ordinal()] = value.policy(category).ordinal();
            NativeBridge.configure(actions, value.blockThreshold, value.killDelayMinMs, value.killDelayMaxMs,
                    Defaults.CHANNEL_PROD.equals(value.channel));
        }

        @Override public Long lastKnownSeq() { return store.lastKnownSeq(); }
        @Override public void save(JSONObject raw, long seq) { store.save(raw, seq); }

        @Override public Action decide(ThreatCategory category, String detectorId, double confidence) {
            return Action.fromOrdinal(NativeBridge.decide(category.ordinal(), detectorId, confidence));
        }

        @Override public List<CheckRunner.Hit> collect(AppliedConfig value) {
            return runner.run(app, bootstrap, value);
        }
    }
}
