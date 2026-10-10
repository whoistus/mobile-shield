# Threat model

Status: final for 1.0 scope, reviewed against the code in phases 2-5. Device calibration (see [test-matrix.md](test-matrix.md)) is still pending; tiers below are the launch tiers.

## Goal

Raise the cost of running a protected app on a compromised or instrumented device, and tell the host so it can decide. The SDK reports, applies a configured action and keeps a native flag. It does not prove a device is clean, and it does not enforce anything outside the host's own gating.

## Categories and actions

Categories: `ROOT`, `EMULATOR`, `DEBUGGER`, `HOOKING`, `TAMPERING`, `INSTALLER`, `SCREEN_CAPTURE`, `DEV_OPTIONS_ADB`, `NO_DEVICE_LOCK`, `VPN_PROXY`.

Actions: `REPORT` (event only), `WARN` (event, host shows UI), `BLOCK` (event and sticky `isBlocked()`), `KILL` (opt-in delayed process termination). Severity `LOW`..`CRITICAL`. Every event has a confidence 0..1.

Channel defaults (native, compiled in):

| Category | dev | test | prod |
|---|---|---|---|
| ROOT | REPORT | WARN | BLOCK |
| EMULATOR | REPORT | REPORT | BLOCK |
| DEBUGGER | REPORT | WARN | WARN |
| HOOKING | REPORT | WARN | WARN |
| TAMPERING | REPORT | WARN | BLOCK |
| INSTALLER, SCREEN_CAPTURE, DEV_OPTIONS_ADB, NO_DEVICE_LOCK | REPORT | REPORT | WARN |
| VPN_PROXY | REPORT | REPORT | REPORT |

KILL is never a default. BLOCK/KILL only fires when `confidence >= blockThreshold` (default 0.7); below that the applied action degrades to WARN. No single low-confidence signal reaches BLOCK or KILL.

## Detector tiers

39 ids: Android 22, iOS 17. 25 prod tier, 14 experimental. Each id has a spec in `docs/detectors/<id>.md` (evidence, benign matches, confidence rule, limitations).

| Tier | Meaning | Max action |
|---|---|---|
| prod | evidence is strong and false-positive risk is low | any, per policy |
| exp | no false-positive data yet | forced to REPORT, whatever `policies` says |

- Android exp: `root.buildTags`, `hooking.fridaThreads`, `hooking.fridaFd`, `hooking.fridaMaps`, `hooking.dbusProbe`, `hooking.prologue`, `hooking.libIntegrity`, `tampering.memDump`.
- iOS exp: `jailbreak.dyldImages`, `jailbreak.dyldEnv`, `hooking.fridaImages`, `hooking.fridaPort`, `hooking.prologue`, `tampering.provisioning`.
- Everything else is prod tier. The tier lists are compiled into the binary (`Defaults.EXPERIMENTAL_IDS` / `cpp/policy/Tiers.h` on Android, `Defaults.experimentalIds` on iOS) and are not configurable at runtime.

Promotion criteria (experimental to prod, per id, stated in the release notes of the release that changes the list):

1. Spec file complete, positive and negative unit tests present.
2. Device matrix run covering the relevant states (stock, rooted or jailbroken incl. rootless, non-GMS and OEM fleets, emulator or simulator) with no benign-device hit.
3. Report-only observation on at least one real app (at least one week or 500 sessions) with a per-id false-positive review inside the budget.
4. A prod id that shows benign hits is demoted the same way.

Until the device matrix and observation have been run, every tier assignment is provisional.

## Enforcement contract (BLOCK is advisory)

- The SDK decides; the host enforces. The host must call native `isBlocked()` before every protected operation: root navigator, deep links, push-opened routes, restored sessions, biometric quick login. Not only Login.
- `isBlocked()` is true after the first BLOCK/KILL and stays true for the process lifetime. The host restarts to clear it. Events are not the source of truth; a hooked JS/Dart layer can drop them.
- The SDK never intercepts application flows.
- Device-side only. A fully compromised device can lie to the app. There is no backend leg in this version: the server cannot tell a genuine SDK verdict from a forged one.
- KILL (opt-in) schedules termination after a random delay in `killDelayMsRange` (default 500-3000 ms) on a separate native path; `stopMonitoring()` does not cancel it.

## Native floor (prod channel)

Compiled in. A runtime config can raise protection, but anything below the floor is clamped.

- Cannot be disabled: `tampering.signature`, `tampering.nativeVsJava` (Android); `tampering.bundleId`, `tampering.teamId` (iOS).
- TAMPERING action is at least WARN.
- Clamped config is applied, `updateConfig`/`init` report `ConfigRejected(floor)` and a `policy.floor` event (TAMPERING, confidence 0.5) is emitted.
- Floor ids only work if their pins exist: `tampering.signature` needs `io.mobileshield.SIGNING_SHA256`; `tampering.teamId` needs `MobileShieldTeamId`, a real device, and a readable keychain group or provisioning profile. A missing pin makes the detector unsupported (no event), so configure the pins. The floor does not protect a host that forgot them.
- Other than the floor, the code does not stop a trusted (signed) config from loosening policies on prod. The trust boundary is the config signing key; see below.

## Bootstrap vs runtime config

| | Bootstrap | Runtime |
|---|---|---|
| Source | host's signed bundle (Android manifest meta-data, iOS Info.plist), read natively | host passes to `init` / `updateConfig` |
| Contents | channel, config public key, identity pins (signing cert / team / bundle id) | policies, detector switches, intervals, installer allowlist |
| Reaches JS/Dart | never | yes (host forwards it; the SDK does no networking) |

Channel absent means `prod` (fail closed). A bootstrapped Ed25519 key makes signed config mandatory; on prod, runtime config without a key is refused (`BootstrapMissing`). Signature failure keeps the last-known-good config and emits `policy.badSignature` (TAMPERING, 0.5). `policy.*` events never block or kill: both policy engines hard-cap them at WARN, whatever `blockThreshold` is.

## Attestation (deferred)

Not implemented. `attestEnrol` and `attestAssert` return `{status: "unsupported", kind}` for every kind on every layer, and `EnvironmentInfo.attestationKinds` is always empty. Reason: a device-produced attestation blob is useless without a backend verifier, and none exists. The extension point is kept (`AttestationProvider`, empty registry) and the intended design is in [attestation-protocol.md](attestation-protocol.md). Future work is a minor release; no API break.

## Not covered

- Device attestation (Key Attestation, Play Integrity, App Attest) and any backend verification of SDK verdicts.
- SSL pinning (stays app-side), screen-shielding UI, biometrics, keychain/keystore.
- Malware and overlay detection, UI-automation detection, device fingerprinting.
- Screen recording detection: `screen.captured` on Android is the API 34+ screenshot callback (needs the `DETECT_SCREEN_CAPTURE` permission and Activity registration), not a recording detector.
- A determined attacker with full control of the device and time to reverse the SDK (patching the host's `isBlocked()` call sites, the wrapper, or the native library). Layered detectors and cross-checks raise cost; they do not remove bypass.
- Unsupported detectors emit no event, so event absence is never proof of a clean device. iOS `getConfig().unsupportedDetectors` lists what the current build cannot run; Android has no equivalent list.
- Huawei HMS integrity, Frida detection beyond the experimental heuristics, jailbreak tools that hide from every heuristic here.

## Non-GMS devices

No dependency on Google or Huawei services. GMS/HMS presence is probed by package query and reflection and reported only. Absence is never a threat. See [non-gms-devices.md](non-gms-devices.md).
