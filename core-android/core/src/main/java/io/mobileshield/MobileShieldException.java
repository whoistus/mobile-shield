package io.mobileshield;

/** Typed SDK error; reason names match every platform and wrapper. */
public final class MobileShieldException extends Exception {
    public enum Reason {
        NativeUnavailable,
        NotInitialized,
        BootstrapMissing,
        ConfigRejected,
        DetectorUnsupported,
        AttestationUnsupported
    }

    /** Sub-reason for {@link Reason#ConfigRejected}. */
    public enum ConfigReason { signature, floor, schema, expired }

    public final Reason reason;
    public final ConfigReason configReason;

    public MobileShieldException(Reason reason, String message) {
        this(reason, null, message);
    }

    public MobileShieldException(Reason reason, ConfigReason configReason, String message) {
        super(configReason == null ? reason + ": " + message : reason + "(" + configReason + "): " + message);
        this.reason = reason;
        this.configReason = configReason;
    }
}
