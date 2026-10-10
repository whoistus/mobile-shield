package io.mobileshield.model;

/** Threat categories; string values are identical on every platform and wrapper. */
public enum ThreatCategory {
    ROOT(Severity.HIGH),
    EMULATOR(Severity.MEDIUM),
    DEBUGGER(Severity.HIGH),
    HOOKING(Severity.CRITICAL),
    TAMPERING(Severity.CRITICAL),
    INSTALLER(Severity.MEDIUM),
    SCREEN_CAPTURE(Severity.LOW),
    DEV_OPTIONS_ADB(Severity.LOW),
    NO_DEVICE_LOCK(Severity.MEDIUM),
    VPN_PROXY(Severity.LOW);

    public final Severity severity;

    ThreatCategory(Severity severity) {
        this.severity = severity;
    }

    /** Returns the category for {@code name}, or null when unknown. */
    public static ThreatCategory parse(String name) {
        for (ThreatCategory c : values()) {
            if (c.name().equals(name)) return c;
        }
        return null;
    }
}
