# tampering.nativeVsJava

| Field | Value |
|---|---|
| Id | `tampering.nativeVsJava` |
| Platform | android |
| Category | TAMPERING |
| Tier | prod |
| Floor | yes |

Implementation: `core-android/core/src/main/java/io/mobileshield/detectors/NativeVsJavaCrossCheck.java` plus native `nativeCrossReadings` in `core-android/core/src/main/cpp/mobileshield.cpp`

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
Four signals read once natively (raw syscalls) and once through independent Java APIs: presence of `su` at the shared path list, main-thread `TracerPid`, SDK version string compiled into the native library vs the Java constant, and the directory of the APK mapped for this package vs `ApplicationInfo.sourceDir`.

## Baseline source
Both sides read the same state at the same moment; any disagreement is the evidence. Hiding tools usually patch one side only.

## Known benign matches
A debugger attaching between the two reads (the TracerPid case is re-read once before reporting). Mixed versions of the Java and native parts of the SDK (a packaging error worth flagging).

## Cost
About 20 path checks and two small file reads, under 2 ms.

## Confidence rule
At least one disagreement: 0.95, with `details.mismatch` listing the signal names (`su`, `tracerPid`, `version`, `apkDir`). Unknown values (unreadable proc file, no APK mapping found) never count as disagreement.

## Unsupported behaviour
Native readings unavailable or any exception: unsupported, no event. On prod this id cannot be disabled (floor).

## Limitations
An adversary patching both sides consistently defeats it. It is designed to catch the common one-sided hiding module.
