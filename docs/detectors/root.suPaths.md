# root.suPaths

| Field | Value |
|---|---|
| Id | `root.suPaths` |
| Platform | android |
| Category | ROOT |
| Tier | prod |
| Floor | no |

Implementation: `core-android/core/src/main/cpp/detectors/RootDetect.cpp` (native, raw syscalls)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
Existence of `su` at 14 well-known locations, checked with raw `openat` and `faccessat` syscalls so libc hooks do not see them. Path strings are obfuscated in the binary.

## Baseline source
None needed: a stock device has no `su` at those locations.

## Known benign matches
`userdebug`/`eng` builds, some kiosk, POS and rugged-device images and community ROMs ship `su` by design. Enterprise fleets that run such images must lower ROOT to WARN or REPORT in config.

## Cost
14 syscalls, well under 1 ms, synchronous. No network.

## Confidence rule
Any path present: 0.9. No partial scores. Reaches the 0.7 block threshold on its own, so ROOT=BLOCK (prod default) applies.

## Unsupported behaviour
Never unsupported: a missing file is a normal negative result.

## Limitations
Magisk with Zygisk DenyList, Shamiko and KernelSU hide or avoid these paths. Covered by `root.magiskMounts`, `root.rootbeer` and the Java-vs-native cross-check (`tampering.nativeVsJava`), not by this detector alone.
