package io.mobileshield;

import android.annotation.TargetApi;
import android.app.Activity;
import android.app.Application;
import android.os.Build;
import android.os.Bundle;
import java.util.IdentityHashMap;
import java.util.Map;

/**
 * Tracks whether any activity is visible (monitoring pauses in the background) and, on API 34+,
 * forwards screenshot callbacks for screen.captured. Plain activity callbacks avoid a lifecycle dependency.
 */
final class AppLifecycle implements Application.ActivityLifecycleCallbacks {
    interface Listener {
        void onForeground();
        void onScreenCaptured();
    }

    private final Listener listener;
    private final Map<Activity, Object> captureCallbacks = new IdentityHashMap<>();
    private final Map<Activity, Boolean> started = new IdentityHashMap<>();
    private volatile boolean foreground = true;

    AppLifecycle(Listener listener) {
        this.listener = listener;
    }

    boolean inForeground() {
        return foreground;
    }

    @Override public void onActivityStarted(Activity activity) {
        markStarted(activity);
    }

    /** Counts an already-started activity (init ran mid-session); idempotent. Main thread only. */
    void seed(Activity activity) {
        markStarted(activity);
    }

    private void markStarted(Activity activity) {
        boolean wasBackground = !foreground;
        synchronized (started) {
            started.put(activity, Boolean.TRUE);
        }
        foreground = true;
        if (Build.VERSION.SDK_INT >= 34) register(activity);
        if (wasBackground) listener.onForeground();
    }

    @Override public void onActivityStopped(Activity activity) {
        synchronized (started) {
            started.remove(activity);
            foreground = !started.isEmpty();
        }
        if (Build.VERSION.SDK_INT >= 34) unregister(activity);
    }

    private void register(Activity activity) {
        try {
            synchronized (captureCallbacks) {
                if (!captureCallbacks.containsKey(activity)) {
                    captureCallbacks.put(activity, Api34.register(activity, listener));
                }
            }
        } catch (RuntimeException ignored) {
            // Missing permission or a finishing activity: screen.captured is simply not delivered.
        }
    }

    private void unregister(Activity activity) {
        Object callback;
        synchronized (captureCallbacks) {
            callback = captureCallbacks.remove(activity);
        }
        if (callback == null) return;
        try {
            Api34.unregister(activity, callback);
        } catch (RuntimeException ignored) {
            // Activity already torn down.
        }
    }

    @Override public void onActivityCreated(Activity a, Bundle b) {}
    @Override public void onActivityResumed(Activity a) {}
    @Override public void onActivityPaused(Activity a) {}
    @Override public void onActivitySaveInstanceState(Activity a, Bundle b) {}
    @Override public void onActivityDestroyed(Activity a) {}

    /** Isolated so older devices never load the API 34 callback type; callers gate on SDK_INT >= 34. */
    @TargetApi(34)
    private static final class Api34 {
        static Object register(Activity activity, Listener listener) {
            Activity.ScreenCaptureCallback callback = listener::onScreenCaptured;
            activity.registerScreenCaptureCallback(activity.getMainExecutor(), callback);
            return callback;
        }

        static void unregister(Activity activity, Object callback) {
            activity.unregisterScreenCaptureCallback((Activity.ScreenCaptureCallback) callback);
        }
    }
}
