# Threat model

Status: draft for review at the start of phases 2 and 3. Design source: plan design.md (contracts, registry).

## Goal

Raise the cost of running a protected app on a compromised or instrumented device, and tell the host app so it can decide. The SDK reports and applies a configured action. It does not prove a device is clean.

## Categories

`ROOT`, `EMULATOR`, `DEBUGGER`, `HOOKING`, `TAMPERING`, `INSTALLER`, `SCREEN_CAPTURE`, `DEV_OPTIONS_ADB`, `NO_DEVICE_LOCK`, `VPN_PROXY`.

Actions: `REPORT` (event only), `WARN` (event, host shows UI), `BLOCK` (sets `isBlocked()`), `KILL` (opt-in delayed termination). Severity: `LOW` to `CRITICAL`. Every event carries a confidence in 0..1.

## Detector tiers

| Tier | Meaning | Max action |
|---|---|---|
| prod | validated, low false-positive risk | any, per policy |
| exp | no false-positive data yet | forced to REPORT until promoted in a release note |

Launch totals: 39 detector ids (Android 22, iOS 17), 25 prod, 14 exp. Each id has a spec at `docs/detectors/<id>.md` (template: [detectors/_template.md](detectors/_template.md)).

BLOCK or KILL only fires when confidence >= `blockThreshold` (default 0.7). No single low-confidence signal reaches BLOCK or KILL. KILL is never a default.

## Enforcement contract (BLOCK is advisory)

- The SDK decides. The host must call `isBlocked()` before every protected operation (root navigator, deep links, restored sessions; not only login).
- `isBlocked()` turns true on the first BLOCK/KILL and stays true for the process lifetime. The host restarts to clear it.
- The SDK never intercepts application flows.
- Enforcement is device-side only in this version. A fully compromised device can lie to the app; there is no backend leg yet.

## Native floor

Compiled into the binary on the prod channel. Runtime config may tighten but never loosen.

- Cannot be disabled: `tampering.signature`, `tampering.nativeVsJava` (Android); `tampering.bundleId`, `tampering.teamId` (iOS).
- Minimum action: TAMPERING >= WARN.
- A config below the floor is clamped; `updateConfig` returns `ConfigRejected(floor)` and emits a low-confidence event that can never block or kill.

## Bootstrap vs runtime config

| | Bootstrap | Runtime |
|---|---|---|
| Source | host signed bundle (Android manifest meta-data, iOS Info.plist), read natively | host passes to `init` / `updateConfig` |
| Contents | channel, config public key, identity pins | policies, detector switches, intervals, allowlist |
| Mutability | immutable | can only tighten what bootstrap allows |
| Reaches JS/Dart | never | yes |

Channel absent means `prod` (fail closed). Runtime config is Ed25519-signed when a public key is bootstrapped; an invalid signature keeps the last-known-good config and emits a low-confidence event. Config fetching is the host's job; the SDK does no networking.

## Not covered

- Device attestation (Key Attestation, Play Integrity, App Attest) and its backend verifier. Deferred: see [attestation-protocol.md](attestation-protocol.md).
- SSL pinning (stays app-side).
- Malware and overlay detection, UI-automation detection, device fingerprinting.
- Backend enforcement: server-side decisions on top of SDK signals.
- A determined attacker with full control of the device and time to reverse the SDK. Layered checks and cross-checks raise cost; they do not eliminate bypass.

## Non-GMS devices

No dependency on Google or Huawei services. GMS/HMS presence is probed and reported only. Absence of GMS is never hostile. Emulator and installer checks are multi-signal and configurable so OEM, TV-box and white-label devices are not penalised by one weak signal.
