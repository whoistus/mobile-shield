# emulator.scored

| Field | Value |
|---|---|
| Id | `emulator.scored` |
| Platform | android |
| Category | EMULATOR |
| Tier | prod |
| Floor | no |

Implementation: `core-android/core/src/main/java/io/mobileshield/detectors/EmulatorScorer.java` (Java)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
Strong signals: `ro.kernel.qemu`/`ro.boot.qemu`, emulator device files (qemu pipes, goldfish, Genymotion sockets), emulator `Build.HARDWARE` (goldfish, ranchu, vbox86, nox), and two or more emulator-looking `Build.*` fields (fingerprint, model, manufacturer, brand/device, product). Weak signals: exactly one `Build.*` field, x86 plus ARM ABIs together (translation layer), no sensors, no telephony feature.

## Baseline source
None; signals are compared against known emulator markers.

## Known benign matches
White-label tablets, TV boxes and AOSP ROMs with `generic` build strings, Amazon Fire, ChromeOS ARC, Windows Subsystem for Android and cloned-app spaces. These typically trip at most one strong signal.

## Cost
A few file existence checks, one sensor list query and property reads: about 5 to 20 ms, synchronous.

## Confidence rule
3 or more strong: 0.95. 2 strong: 0.9. 1 strong: 0.4, or 0.6 with at least 2 weak signals. No strong and at least 2 weak: 0.2. A single weak signal alone: no event. Only 2 or more strong signals reach the 0.7 block threshold. `details.strongSignals` carries the count.

## Unsupported behaviour
Exception while collecting signals: unsupported, no event.

## Limitations
Hardened emulators can spoof properties and hide device files. Real devices behind a hypervisor (cloud phones) look like hardware. Pair with server-side checks if emulator access is high risk.
