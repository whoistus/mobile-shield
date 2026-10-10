# Non-GMS devices

The Android core has no compile-time or runtime dependency on Google or Huawei services. Fleets of Huawei, Xiaomi CN, Amazon Fire and white-label devices are supported; absence of GMS is never a threat. There is no HMS attestation provider in this release.

## Environment probe

`init` returns `EnvironmentInfo`. Relevant fields:

| Field | Semantics |
|---|---|
| `gmsAvailable` | true only when the `com.google.android.gms` package is installed **and** `com.google.android.gms.common.GoogleApiAvailability` is on the app classpath (reflection). An app that does not bundle the Play services API reports `false` on a GMS device. Informational |
| `hmsAvailable` | `com.huawei.hwid` package is installed. Informational |
| `installer` | installing package name (`getInstallSourceInfo` on API 30+, `getInstallerPackageName` below), `null` when unknown. On iOS: the distribution mode (App Store, TestFlight, enterprise, ad hoc, development) or `null` |
| `isDebuggable` | `FLAG_DEBUGGABLE` (Android), `get-task-allow` (iOS) |
| `attestationKinds` | always empty in this version |

The probe uses package queries (declared in the library manifest) and reflection only. Nothing in the policy reads `gmsAvailable`/`hmsAvailable`. Use them for your own telemetry or to decide which push provider to use.

## Installer allowlist

`installer.source` (Android, prod tier, category INSTALLER) compares the installing package with `installerAllowlist`. Default allowlist: `com.android.vending` (Google Play), `com.huawei.appmarket`, `com.xiaomi.market`, `com.xiaomi.mipicks`, `com.sec.android.app.samsungapps`, `com.amazon.venezia`, `com.heytap.market`, `com.oppo.market`, `com.bbk.appstore`, `com.hihonor.appmarket`.

- Listed: no event.
- `null` or `*.packageinstaller`: event with `details.source = sideload`, confidence 0.5.
- Any other package: event with `details.source = unlisted`, confidence 0.5.

Confidence is fixed at 0.5, below the default `blockThreshold` (0.7), so this detector can warn but never blocks or kills. Prod default action is WARN.

Tune per fleet by sending your own list in the runtime config (it replaces the default, so include every store you ship through, plus MDM or enterprise installers and Firebase App Distribution if you use them):

```json
{"version": 1, "appId": "com.example.app", "seq": 1790000000,
 "installerAllowlist": ["com.android.vending", "com.huawei.appmarket", "com.mycompany.mdm"]}
```

## Emulator scoring

`emulator.scored` combines independent signals instead of trusting one `Build.*` string, because white-label tablets, TV boxes, AOSP ROMs, ChromeOS ARC and cloned-app spaces often have `generic` build fields.

- Strong: qemu properties, emulator device files (qemu pipe, goldfish, Genymotion sockets), emulator hardware name (goldfish, ranchu, vbox86, nox), two or more emulator-looking `Build.*` fields.
- Weak: exactly one `Build.*` field, x86 plus ARM ABIs (translation layer), no sensors, no telephony.
- Confidence: 3+ strong 0.95; 2 strong 0.9; 1 strong 0.4 (0.6 with two weak); no strong and two weak 0.2; one weak alone no event.

Only two or more strong signals reach the 0.7 block threshold. One strong signal is a WARN at most even on prod (EMULATOR defaults to BLOCK, degraded to WARN under threshold).

`root.buildTags` (test-keys) is experimental and low weight (0.2), so custom ROMs do not trip root detection by themselves. `root.rootbeer` scores RootBeer's checks individually and ignores its test-keys check, so a test-keys-only ROM produces no `root.rootbeer` event.

## Tuning checklist per fleet

1. Run the app in `dev` or `test` channel (REPORT/WARN) on a sample of the fleet and collect events by `detectorId`.
2. Add the fleet's stores or MDM to `installerAllowlist`.
3. If a category fires on benign devices, lower that category's policy (`policies.EMULATOR: "WARN"`) or disable the specific id (`detectors: {"emulator.scored": false}`) instead of lowering `blockThreshold`, which affects every detector.
4. Keep the floor detectors configured (signing pin on Android, team id on iOS); they are independent of the device vendor.
5. Treat a missing event as "unknown", not "clean": unsupported detectors emit nothing.

Real-device calibration (Huawei, Xiaomi CN, Fire) is still pending: see [test-matrix.md](test-matrix.md).
