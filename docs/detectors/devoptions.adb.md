# devoptions.adb

| Field | Value |
|---|---|
| Id | `devoptions.adb` |
| Platform | android |
| Category | DEV_OPTIONS_ADB |
| Tier | prod |
| Floor | no |

Implementation: `core-android/core/src/main/java/io/mobileshield/detectors/AdbDevOptionsCheck.java` (Java)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
`Settings.Global.ADB_ENABLED` and `DEVELOPMENT_SETTINGS_ENABLED`.

## Baseline source
Both off on consumer devices.

## Known benign matches
Developers, QA fleets and kiosk devices managed over ADB.

## Cost
Two settings reads, negligible.

## Confidence rule
USB debugging on: 0.6. Developer options on without ADB: 0.4. Otherwise 0. Never reaches the block threshold.

## Unsupported behaviour
Settings unreadable: unsupported, no event.

## Limitations
Settings can be spoofed on rooted devices. Informational posture signal.
