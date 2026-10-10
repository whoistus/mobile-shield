# hooking.fridaThreads

| Field | Value |
|---|---|
| Id | `hooking.fridaThreads` |
| Platform | android |
| Category | HOOKING |
| Tier | exp |
| Floor | no |

Implementation: `core-android/core/src/main/cpp/detectors/FridaDetect.cpp` (native)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
Thread names in `/proc/self/task/<tid>/comm` that match common instrumentation runtime names. GLib-style names collide with benign software and only count in pairs.

## Baseline source
None; thread names of a clean app.

## Known benign matches
Apps that bundle GLib or GStreamer can show one of the shared names; hence the two-name rule.

## Cost
One small file read per thread, about 1 to 3 ms for 50 threads.

## Confidence rule
Two distinct names: 0.8. One instrumentation-specific name: 0.5. A single shared name: 0. Experimental tier: always REPORT.

## Unsupported behaviour
`/proc/self/task` unreadable: unsupported, no event.

## Limitations
Renamed builds and custom gadgets change thread names. Tested against Frida 16.x; re-verify on the 17.x line in the device matrix (research B lists this as open).
