# root.magiskMounts

| Field | Value |
|---|---|
| Id | `root.magiskMounts` |
| Platform | android |
| Category | ROOT |
| Tier | prod |
| Floor | no |

Implementation: `core-android/core/src/main/cpp/detectors/RootDetect.cpp` (native)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
Whole-file scan of `/proc/self/mountinfo` for Magisk mount markers (`magisk`, `core/mirror`, `core/img`).

## Baseline source
None: stock mount tables never contain these markers.

## Known benign matches
Only a rooted device mounts these. A path or label that happens to contain the word `magisk` (for example a user folder on external storage) is the only realistic collision.

## Cost
One file read of a few KB, about 0.1 ms, synchronous.

## Confidence rule
Marker found: 0.9. Otherwise 0.

## Unsupported behaviour
`/proc/self/mountinfo` unreadable (hidepid, sandbox): returns unsupported and emits no event. Earlier ports treated this as a hit; it is not evidence.

## Limitations
Zygisk modules and Shamiko unmount the traces for apps on the DenyList. KernelSU and APatch leave little in the mount table. Treated as one signal among several, never as proof of a clean device.
