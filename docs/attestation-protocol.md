# Attestation protocol (DEFERRED)

Status: design note only. Not implemented in this version: there is no backend verifier, and device-produced attestation blobs without one are dead code.

## What ships now

Core keeps an `AttestationProvider` interface and an empty registry. `attestEnrol` / `attestAssert` return `AttestationUnsupported(kind)` for every kind; `EnvironmentInfo.attestationKinds` is `[]`.

```
interface AttestationProvider {
  kind(): string                              // e.g. "keyAttestation", "appAttest", "hmsSysIntegrity"
  isAvailable(): bool
  enrol(nonce) -> AttestationResult           // create a hardware-backed key, return evidence bound to nonce
  assert(nonce, requestHash) -> AttestationResult   // sign/assert for one request
}
```

Add-ons register providers by reflection; no core API change.

## Intended flow

1. Enrol: backend issues a single-use nonce; device creates a key and returns evidence (Android certificate chain, iOS App Attest object); backend verifies and stores the public key per device.
2. Assert: for a sensitive request, backend issues a nonce; device signs `nonce + requestHash`; backend verifies against the enrolled key and a counter/replay check.

## Verifier requirements

- Chain validation to an allowlist of trusted roots, including OEM roots measured from the real fleet. On devices without Google Play the OEM defines its own root.
- Check the secure-hardware level, the challenge equals the nonce, and boot state / lock state fields.
- Revocation: honour the published revocation status list and its caching headers.
- Nonces single-use and short-lived.
- Result `unsupported` (provider unavailable, no GMS, unknown OEM root) is not hostile. Policy decides the trust tier; absence alone must not block a user.
- Attestation proves hardware and boot state, not app genuineness or post-boot tampering; combine with the in-SDK identity checks.
