package io.mobileshield.config;

import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONException;
import org.json.JSONObject;

/** Persists the last-known-good runtime config (raw JSON + seq) in app-private storage. */
public final class ConfigStore {
    private static final String PREFS = "io.mobileshield.config";
    private static final String KEY_JSON = "lkg.json";
    private static final String KEY_SEQ = "lkg.seq";

    private final SharedPreferences prefs;

    public ConfigStore(Context context) {
        this.prefs = context.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    public Long lastKnownSeq() {
        return prefs.contains(KEY_SEQ) ? prefs.getLong(KEY_SEQ, 0) : null;
    }

    public JSONObject lastKnownGood() {
        String s = prefs.getString(KEY_JSON, null);
        if (s == null) return null;
        try {
            return new JSONObject(s);
        } catch (JSONException e) {
            return null;
        }
    }

    public void save(JSONObject rawConfig, long seq) {
        prefs.edit().putString(KEY_JSON, rawConfig.toString()).putLong(KEY_SEQ, seq).apply();
    }
}
