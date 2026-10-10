# installer.source

| Field | Value |
|---|---|
| Id | `installer.source` |
| Platform | android |
| Category | INSTALLER |
| Tier | prod |
| Floor | no |

Implementation: `core-android/core/src/main/java/io/mobileshield/detectors/InstallerCheck.java` (Java)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64). `getInstallSourceInfo()` on API 30+, `getInstallerPackageName()` below.

## Evidence used
Installing package name compared with `installerAllowlist` (default: Play, Huawei AppGallery, Xiaomi, Samsung, Amazon, Oppo/Heytap, Vivo, Honor stores).

## Baseline source
Allowlist from design.md, replaceable per fleet through runtime config.

## Known benign matches
Firebase App Distribution, MDM or enterprise stores, internal testing tracks and `adb install` during development. Add those installers to the allowlist.

## Cost
One package-manager query, negligible.

## Confidence rule
Not in the allowlist: 0.5 (`details.source` is `sideload` for null or `*.packageinstaller`, `unlisted` otherwise). Fixed at 0.5, below the block threshold, so it never blocks or kills.

## Unsupported behaviour
Never unsupported; an unreadable installer counts as null (sideload).

## Limitations
The installer name is reported by the platform and can be spoofed on rooted devices. Not a tamper control on its own.
