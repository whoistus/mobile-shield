# tampering.signature

| Field | Value |
|---|---|
| Id | `tampering.signature` |
| Platform | android |
| Category | TAMPERING |
| Tier | prod |
| Floor | yes |

Implementation: `core-android/core/src/main/java/io/mobileshield/detectors/SignatureCheck.java` (Java)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64). Uses `GET_SIGNING_CERTIFICATES` on API 28+, `GET_SIGNATURES` below.

## Evidence used
SHA-256 of every APK signing certificate, compared with the pin(s) in the manifest meta-data `io.mobileshield.SIGNING_SHA256` (lowercase hex; several pins separated by commas for key rotation).

## Baseline source
Build-time pin supplied by the host in its manifest (bootstrap). The pin is protected by the APK signature, not secret.

## Known benign matches
Debug builds signed with the debug key when the pin is the release key; Play App Signing re-signs uploads, so pin the app-signing key, not the upload key.

## Cost
One package-manager query and a hash, about 1 to 3 ms.

## Confidence rule
Any signer not in the pin set: 0.95. Package-manager failure: 0.6 (below the block threshold, so it cannot block alone). Match: 0.

## Unsupported behaviour
No pin configured: unsupported, no event (the host has not enabled the check). On prod this id cannot be disabled (floor).

## Limitations
A repackager can patch both the pin in the manifest and this code. The check raises the bar and is cross-checked natively by `tampering.nativeVsJava`; a server-side certificate digest is the authoritative control.
