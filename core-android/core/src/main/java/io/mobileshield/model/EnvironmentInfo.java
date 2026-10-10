package io.mobileshield.model;

import java.util.Collections;
import java.util.List;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/** Environment summary returned by init. */
public final class EnvironmentInfo {
    public final String sdkVersion;
    public final String platform = "android";
    public final String osVersion;
    public final String abi;
    public final boolean isDebuggable;
    public final boolean gmsAvailable;
    public final boolean hmsAvailable;
    public final String installer;
    public final List<String> attestationKinds;

    public EnvironmentInfo(String sdkVersion, String osVersion, String abi, boolean isDebuggable,
                           boolean gmsAvailable, boolean hmsAvailable, String installer,
                           List<String> attestationKinds) {
        this.sdkVersion = sdkVersion;
        this.osVersion = osVersion;
        this.abi = abi;
        this.isDebuggable = isDebuggable;
        this.gmsAvailable = gmsAvailable;
        this.hmsAvailable = hmsAvailable;
        this.installer = installer;
        this.attestationKinds = Collections.unmodifiableList(attestationKinds);
    }

    public JSONObject toJson() {
        try {
            JSONObject o = new JSONObject();
            o.put("sdkVersion", sdkVersion);
            o.put("platform", platform);
            o.put("osVersion", osVersion);
            o.put("abi", abi);
            o.put("isDebuggable", isDebuggable);
            o.put("gmsAvailable", gmsAvailable);
            o.put("hmsAvailable", hmsAvailable);
            o.put("installer", installer == null ? JSONObject.NULL : installer);
            o.put("attestationKinds", new JSONArray(attestationKinds));
            return o;
        } catch (JSONException e) {
            throw new IllegalStateException(e);
        }
    }
}
