# tampering.memDump

| Field | Value |
|---|---|
| Id | `tampering.memDump` |
| Platform | android |
| Category | TAMPERING |
| Tier | exp |
| Floor | no |

Implementation: `core-android/core/src/main/cpp/detectors/AntiDump.cpp` (native)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
An inotify watch on `/proc/self/mem` and `/proc/self/pagemap`; any open or read since the previous run is reported. `/proc/self/maps` is deliberately not watched because the other detectors read it.

## Baseline source
Nothing normally opens those files in the app's own process.

## Known benign matches
In-process native crash handlers and unwinders that read `/proc/self/mem`, and system crash dumping.

## Cost
One non-blocking inotify read per run; the first run only sets up the watch.

## Confidence rule
Access observed: 0.8. Otherwise 0. Experimental tier: always REPORT.

## Unsupported behaviour
inotify unavailable or the proc files cannot be watched: unsupported, no event.

## Limitations
Dumpers that use `process_vm_readv` or ptrace and never open the files; events before the first run are not seen.
