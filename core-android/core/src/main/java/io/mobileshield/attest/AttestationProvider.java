package io.mobileshield.attest;

import org.json.JSONObject;

/**
 * Extension point for device attestation (Key Attestation, Play Integrity, HMS SysIntegrity).
 * No provider ships in this version: attestation needs a backend verifier. Add-ons register
 * through {@link AttestationRegistry} without any change to the public facade.
 */
public interface AttestationProvider {
    String kind();

    boolean isAvailable();

    /** Returns an opaque enrolment payload for the verifier. */
    JSONObject enrol(String nonce) throws Exception;

    /** Java has no method named assert; this is the design's {@code assert(nonce, requestHash)}. */
    JSONObject assertion(String nonce, String requestHash) throws Exception;
}
