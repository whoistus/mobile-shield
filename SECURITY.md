# Security

Internal SDK. This file says where to send findings; it is not a public disclosure policy.

## Reporting a bypass or vulnerability

Contact: **security contact owner TBD** (to be named by the SDK owner before the first release; do not report through public issues, pull requests or chat channels that include people outside the owning team).

Include:

- SDK version (`getSdkVersion()`), platform and OS version, device model, ABI.
- Detector id and category involved, the action you expected and the action observed (`isBlocked()`, event `action`).
- Channel (`dev`/`test`/`prod`) and whether runtime config was signed.
- A minimal reproduction: tool and version (for example Magisk, a jailbreak, Frida), and steps.

Do not include user data, production config signing keys or bootstrap secrets. The config public key and signing-certificate pins are not secret; the config private key is.

## Scope

- In scope: detection bypasses, ways to clear or avoid `isBlocked()` natively, config-signature or floor bypasses, crashes caused by the SDK, false positives on a supported device class.
- Known out of scope (see [docs/threat-model.md](docs/threat-model.md)): a fully compromised device patching the host app's own gating, missing attestation, backend enforcement, malware and overlay detection.

## Handling

Findings are triaged by the SDK owner, fixed on a release branch and shipped as a new version (an rc first, then final). Detectors are retuned or demoted to experimental through the release notes. If the config signing key is suspected leaked, ship an app release with a new public key and stop signing with the old one; there is no remote revocation.
