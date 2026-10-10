# hooking.fridaFd

| Field | Value |
|---|---|
| Id | `hooking.fridaFd` |
| Platform | android |
| Category | HOOKING |
| Tier | exp |
| Floor | no |

Implementation: `core-android/core/src/main/cpp/detectors/FridaDetect.cpp` (native)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
Targets of `/proc/self/fd/*` symlinks that name an injector or agent.

## Baseline source
None.

## Known benign matches
Unlikely; file names containing the substring in an app's own assets would match.

## Cost
One `readlinkat` per open fd, about 1 ms.

## Confidence rule
Match: 0.8. Otherwise 0. Experimental tier: always REPORT.

## Unsupported behaviour
`/proc/self/fd` unreadable: unsupported, no event. Unreadable individual links are skipped (earlier ports reported them as a hit).

## Limitations
Renamed injectors and fd closing. One signal of several.
