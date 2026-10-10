# Device matrix

Status: **not executed.** This is a fill-in template; no result below is real until a person runs it on the device and records it. Unsupported detectors emit nothing, so an empty "Observed" cell means "no event", never "clean device"; record `getConfig().unsupportedDetectors` (iOS) and `disabled` per run.

Source of truth for ids and expected actions: `plans/261008-1659-native-security-sdk/design.md` (detector registry, channel defaults). Run with the RN example (`packages/react-native/example`), channel `prod` unless stated; a signed runtime config is needed on prod (or build the example with a test pubkey).

## 1. Run header (copy per device)

| Field | Value |
|---|---|
| Date / tester | |
| SDK version (`getSdkVersion()`) / build (debug or release) | |
| Device model, OS version, ABI | |
| Page size (4KB / 16KB; `adb shell getconf PAGE_SIZE`) | |
| GMS / HMS (`EnvironmentInfo.gmsAvailable/hmsAvailable`) | |
| Installer (`EnvironmentInfo.installer`) | |
| Compromise state (stock / Magisk / Magisk+hide / jailbreak rootless / emulator / simulator) | |
| Hook tool attached (none / Frida version / other) | |
| Channel and signed config seq | |
| `isBlocked()` at launch / after runChecks / after 60 s monitoring | |
| Process killed by KILL? (must be no unless the host opted in) | |

## 2. Devices (one run header + detector table each)

| # | Device | State | Hook tool | Run done | BLOCK/KILL seen | Pass criteria met |
|---|---|---|---|---|---|---|
| A1 | Android emulator (AOSP image) | emulator | none | | | EMULATOR event, BLOCK on prod |
| A2 | Android emulator (Google Play image) | emulator | none | | | EMULATOR event, BLOCK on prod |
| A3 | Android emulator, 16KB page-size image | emulator | none | | | libs load, `libmobileshield` aligned, checks run |
| A4 | Stock Android with GMS (min 2 OEMs) | stock | none | | | 0 BLOCK/KILL |
| A5 | Stock Android without GMS (any OEM the team owns) | stock | none | | | 0 BLOCK/KILL |
| A6 | Xiaomi CN ROM (if available) | stock | none | | | 0 BLOCK/KILL, installer allowlist behaviour noted |
| A7 | Rooted Android, Magisk (no hide) | rooted | none | | | ROOT event(s), BLOCK on prod |
| A8 | Rooted Android, Magisk with hide/Zygisk denylist | rooted+hide | none | | | record which root ids survive hiding |
| A9 | Rooted Android, Magisk | rooted | Frida 17.x | | | HOOKING events (exp ids stay REPORT) |
| A10 | Stock Android | stock | Frida 17.x | | | HOOKING events, no BLOCK from exp ids |
| I1 | Stock iPhone (App Store / TestFlight build) | stock | none | | | 0 BLOCK/KILL |
| I2 | Rootless-jailbroken iPhone | jailbroken | none | | | jailbreak event(s), BLOCK on prod |
| I3 | Rootless-jailbroken iPhone | jailbroken | Frida 17.x | | | HOOKING events |
| I4 | iOS simulator | simulator | none | | | `simulator` event, BLOCK on prod |
| R1 | RN 0.86 (New Architecture) sample, Android | stock | none | | | module works through interop layer |
| R2 | RN 0.86 (New Architecture) sample, iOS | stock | none | | | module works through interop layer |

Prod-channel defaults must produce 0 BLOCK/KILL on every stock GMS and stock non-GMS device (A4, A5, A6, I1) and 0 BLOCK/KILL from any experimental id anywhere.

## 3. Android detector results (22 ids)

Copy this table once per Android device run.

| Detector id | Tier | Expected action (prod channel) | Observed event (conf) | Observed action | False positive? | Notes |
|---|---|---|---|---|---|---|
| `root.suPaths` | prod | per policy table | | | | |
| `root.magiskMounts` | prod | per policy table | | | | |
| `root.rootbeer` | prod | per policy table | | | | |
| `emulator.scored` | prod | per policy table | | | | |
| `debugger.tracerPid` | prod | per policy table | | | | |
| `debugger.javaDebugger` | prod | per policy table | | | | |
| `tampering.signature` | prod | per policy table | | | | |
| `tampering.debuggable` | prod | per policy table | | | | |
| `tampering.nativeVsJava` | prod | per policy table | | | | |
| `installer.source` | prod | per policy table | | | | |
| `screen.captured` | prod | per policy table | | | | |
| `devoptions.adb` | prod | per policy table | | | | |
| `devicelock.absent` | prod | per policy table | | | | |
| `network.vpn` | prod | per policy table | | | | |
| `root.buildTags` | exp | REPORT (forced) | | | | |
| `hooking.fridaThreads` | exp | REPORT (forced) | | | | |
| `hooking.fridaFd` | exp | REPORT (forced) | | | | |
| `hooking.fridaMaps` | exp | REPORT (forced) | | | | |
| `hooking.dbusProbe` | exp | REPORT (forced) | | | | |
| `hooking.prologue` | exp | REPORT (forced) | | | | |
| `hooking.libIntegrity` | exp | REPORT (forced) | | | | |
| `tampering.memDump` | exp | REPORT (forced) | | | | |

## 4. iOS detector results (17 ids)

Copy this table once per iOS device run.

| Detector id | Tier | Expected action (prod channel) | Observed event (conf) | Observed action | False positive? | Notes |
|---|---|---|---|---|---|---|
| `jailbreak.paths` | prod | per policy table | | | | |
| `jailbreak.rootlessPaths` | prod | per policy table | | | | |
| `jailbreak.urlSchemes` | prod | per policy table | | | | |
| `jailbreak.sandboxWrite` | prod | per policy table | | | | |
| `debugger.ptraced` | prod | per policy table | | | | |
| `tampering.bundleId` | prod | per policy table | | | | |
| `tampering.teamId` | prod | per policy table | | | | |
| `simulator` | prod | per policy table | | | | |
| `devicelock.absent` | prod | per policy table | | | | |
| `network.proxy` | prod | per policy table | | | | |
| `screen.captured` | prod | per policy table | | | | |
| `jailbreak.dyldImages` | exp | REPORT (forced) | | | | |
| `jailbreak.dyldEnv` | exp | REPORT (forced) | | | | |
| `hooking.fridaImages` | exp | REPORT (forced) | | | | |
| `hooking.fridaPort` | exp | REPORT (forced) | | | | |
| `hooking.prologue` | exp | REPORT (forced) | | | | |
| `tampering.provisioning` | exp | REPORT (forced) | | | | |

`devicelock.absent`, `screen.captured` and `hooking.prologue` exist on both platforms (39 entries, 36 distinct ids).

## 5. Cross-cutting checks

| Check | How | Result |
|---|---|---|
| Native floor holds | `updateConfig` disabling `tampering.signature` / `tampering.bundleId` on prod: `getConfig().clamped` lists it, detector still runs, `policy.floor` event conf 0.5 does not block | |
| Bad signature | `updateConfig` with a tampered signature: `ConfigRejected` reason `signature`, previous config stays | |
| Stale seq / expired | older `seq` and past `expiresAt`: `ConfigRejected` | |
| Typed errors in JS | call before `init`: `NotInitialized`; missing bootstrap on prod: `BootstrapMissing` | |
| Gating | with BLOCK active, relaunch via deep link and restored session: blocked screen shown (example `ShieldGate`) | |
| JS hooked | Frida hook JS `isBlocked` to false: native still blocked, protected native flows unaffected | |
| Monitoring lifecycle | background app 30 s, foreground: monitoring resumes, no duplicate events per cycle | |
| 16KB | `scripts/check-16kb.sh --only libmobileshield <release apk>` | |

## 6. Frida 17.x open question

Plan.md open item: do the experimental Frida detectors (`hooking.fridaThreads`, `hooking.fridaFd`, `hooking.fridaMaps`, `hooking.dbusProbe`, `hooking.prologue`, `hooking.libIntegrity`, iOS `hooking.fridaImages`, `hooking.fridaPort`) still fire on Frida 17.x (server, gadget injected, and spawn modes)?

| Frida version / mode | Platform | Ids that fired | Ids that did not | Conclusion |
|---|---|---|---|---|
| 17.x server (frida-server) | Android | | | |
| 17.x gadget | Android | | | |
| 17.x server | iOS (rootless) | | | |
| 17.x gadget | iOS | | | |

## 7. Promotion decision (experimental ids)

An experimental id is promoted only after the matrix shows zero false positives on stock GMS and non-GMS devices and a positive on its target state. Record per id: runs, true positives, false positives, decision (promote / keep exp / drop).

| Id | Runs | True positives | False positives | Decision |
|---|---|---|---|---|
| | | | | |

## 8. False positives log

| Id | Device / OS | Conditions | Event (conf) | Action | Follow-up |
|---|---|---|---|---|---|
| | | | | | |
