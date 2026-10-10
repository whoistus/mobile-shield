package io.mobileshield.attest;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import org.json.JSONException;
import org.json.JSONObject;

/** Registry of attestation providers. Empty in this version; the facade reports "unsupported". */
public final class AttestationRegistry {
    // Add-on provider classes the core may load reflectively; none ship today.
    private static final String[] KNOWN_PROVIDER_CLASSES = {};
    private static final CopyOnWriteArrayList<AttestationProvider> providers = new CopyOnWriteArrayList<>();

    static {
        for (String name : KNOWN_PROVIDER_CLASSES) {
            try {
                register((AttestationProvider) Class.forName(name).getDeclaredConstructor().newInstance());
            } catch (ReflectiveOperationException | ClassCastException | LinkageError ignored) {
                // Optional add-on not on the classpath.
            }
        }
    }

    private AttestationRegistry() {}

    public static void register(AttestationProvider provider) {
        for (AttestationProvider p : providers) {
            if (p.kind().equals(provider.kind())) return;
        }
        providers.add(provider);
    }

    public static List<String> kinds() {
        List<String> kinds = new ArrayList<>();
        for (AttestationProvider p : providers) kinds.add(p.kind());
        return Collections.unmodifiableList(kinds);
    }

    public static AttestationProvider find(String kind) {
        for (AttestationProvider p : providers) {
            if (p.kind().equals(kind)) return p;
        }
        return null;
    }

    /** The only result this version returns for any kind. */
    public static JSONObject unsupported(String kind) {
        JSONObject result = new JSONObject();
        try {
            result.put("status", "unsupported");
            result.put("kind", kind);
        } catch (JSONException e) {
            throw new IllegalStateException(e);
        }
        return result;
    }
}
