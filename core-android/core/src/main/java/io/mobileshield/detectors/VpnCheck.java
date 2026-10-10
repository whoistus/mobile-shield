package io.mobileshield.detectors;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import android.os.Build;
import io.mobileshield.model.ThreatCategory;

/** network.vpn: the active network runs over a VPN transport. Needs ACCESS_NETWORK_STATE. */
public final class VpnCheck implements Detector {
    @Override public String id() { return "network.vpn"; }
    @Override public ThreatCategory category() { return ThreatCategory.VPN_PROXY; }

    @Override public Finding run(DetectorEnv env) {
        if (Build.VERSION.SDK_INT < 23) return Finding.UNSUPPORTED;
        try {
            ConnectivityManager cm = (ConnectivityManager) env.context.getSystemService(Context.CONNECTIVITY_SERVICE);
            if (cm == null) return Finding.UNSUPPORTED;
            NetworkCapabilities nc = cm.getNetworkCapabilities(cm.getActiveNetwork());
            return Finding.hit(nc != null && nc.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ? 0.8 : 0);
        } catch (Throwable t) {
            return Finding.UNSUPPORTED;
        }
    }
}
