# root.buildTags

| Field | Value |
|---|---|
| Id | `root.buildTags` |
| Platform | android |
| Category | ROOT |
| Tier | exp |
| Floor | no |

Implementation: `core-android/core/src/main/java/io/mobileshield/detectors/BuildTagsCheck.java` (Java)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
`Build.TAGS` contains `test-keys`.

## Baseline source
Release builds are signed with `release-keys`.

## Known benign matches
Many community ROMs, some OEM engineering builds and AOSP builds use `test-keys`. Hence weight 0.2 and experimental tier.

## Cost
Field read, negligible.

## Confidence rule
Fixed 0.2. Far below the block threshold; experimental ids are forced to REPORT regardless.

## Unsupported behaviour
Never unsupported.

## Limitations
Trivially spoofed. Useful only as a low-weight corroborating signal.
