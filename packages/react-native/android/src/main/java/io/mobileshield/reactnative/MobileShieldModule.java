package io.mobileshield.reactnative;

import android.app.Activity;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.UiThreadUtil;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import io.mobileshield.MobileShield;
import io.mobileshield.MobileShieldException;
import io.mobileshield.model.ThreatEvent;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Thin bridge: forwards to the native facade and never decides enforcement.
 * Config crosses as a JSON string so numeric types survive for signature canonicalisation.
 */
public final class MobileShieldModule extends ReactContextBaseJavaModule {
    static final String EVENT = "MobileShield.onThreat";

    private final ExecutorService worker = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "MobileShield-rn");
        t.setDaemon(true);
        return t;
    });
    private final MobileShield.Listener listener;
    private int subscribers;

    public MobileShieldModule(ReactApplicationContext context) {
        super(context);
        listener = event -> {
            if (!context.hasActiveReactInstance()) return;
            context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                    .emit(EVENT, event.toJson().toString());
        };
    }

    @Override public String getName() { return "MobileShield"; }

    @Override public void invalidate() {
        synchronized (this) { subscribers = 0; }
        MobileShield.removeListener(listener);
        worker.shutdown();
        super.invalidate();
    }

    // The native listener is attached only while JS listens, so the core's pre-listener backlog
    // replays to JS when the first subscriber arrives instead of draining into a void.
    @ReactMethod public void addListener(String eventName) {
        boolean first;
        synchronized (this) { first = subscribers++ == 0; }
        if (first) MobileShield.addListener(listener);
    }

    @ReactMethod public void removeListeners(double count) {
        boolean last;
        synchronized (this) {
            subscribers = Math.max(0, subscribers - (int) count);
            last = subscribers == 0;
        }
        if (last) MobileShield.removeListener(listener);
    }

    @ReactMethod public void getSdkVersion(Promise promise) {
        try { promise.resolve(MobileShield.getSdkVersion()); }
        catch (Throwable e) { reject(promise, e); }
    }

    @ReactMethod public void init(String configJson, Promise promise) {
        UiThreadUtil.runOnUiThread(() -> {
            Activity current = getCurrentActivity();
            if (current != null) MobileShield.attachActivity(current);
        });
        run(promise, () -> MobileShield.init(getReactApplicationContext(), parse(configJson)).toJson().toString());
    }

    @ReactMethod public void updateConfig(String configJson, Promise promise) {
        run(promise, () -> MobileShield.updateConfig(parse(configJson)).toJson().toString());
    }

    @ReactMethod public void getConfig(Promise promise) {
        run(promise, () -> MobileShield.getConfig().toJson().toString());
    }

    @ReactMethod public void runChecks(Promise promise) {
        run(promise, () -> {
            JSONArray result = new JSONArray();
            for (ThreatEvent event : MobileShield.runChecks()) result.put(event.toJson());
            return result.toString();
        });
    }

    @ReactMethod public void startMonitoring(Promise promise) {
        run(promise, () -> { MobileShield.startMonitoring(); return null; });
    }

    @ReactMethod public void stopMonitoring(Promise promise) {
        run(promise, () -> { MobileShield.stopMonitoring(); return null; });
    }

    @ReactMethod public void isBlocked(Promise promise) {
        try { promise.resolve(MobileShield.isBlocked()); }
        catch (Throwable e) { reject(promise, e); }
    }

    @ReactMethod public void attestEnrol(String kind, String nonce, Promise promise) {
        run(promise, () -> MobileShield.attestEnrol(kind, nonce).toString());
    }

    @ReactMethod public void attestAssert(String kind, String nonce, String requestHash, Promise promise) {
        run(promise, () -> MobileShield.attestAssert(kind, nonce, requestHash).toString());
    }

    private interface Call { Object call() throws Exception; }

    private void run(Promise promise, Call call) {
        try {
            worker.execute(() -> {
                try { promise.resolve(call.call()); }
                catch (Throwable e) { reject(promise, e); }
            });
        } catch (RuntimeException rejected) {
            reject(promise, rejected);
        }
    }

    private static JSONObject parse(String json) throws MobileShieldException {
        if (json == null) return null;
        try {
            return new JSONObject(json);
        } catch (JSONException e) {
            throw new MobileShieldException(MobileShieldException.Reason.ConfigRejected,
                    MobileShieldException.ConfigReason.schema, "runtime config is not valid JSON");
        }
    }

    // Same shape as iOS: code = typed error name, userInfo.reason = ConfigRejected sub-reason.
    private static void reject(Promise promise, Throwable e) {
        if (e instanceof MobileShieldException) {
            MobileShieldException ms = (MobileShieldException) e;
            WritableMap info = Arguments.createMap();
            if (ms.configReason != null) info.putString("reason", ms.configReason.name());
            promise.reject(ms.reason.name(), ms.getMessage(), info);
        } else {
            promise.reject("NativeUnavailable", String.valueOf(e.getMessage()), Arguments.createMap());
        }
    }
}
