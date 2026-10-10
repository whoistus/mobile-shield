# debugger.tracerPid

| Field | Value |
|---|---|
| Id | `debugger.tracerPid` |
| Platform | android |
| Category | DEBUGGER |
| Tier | prod |
| Floor | no |

Implementation: `core-android/core/src/main/cpp/detectors/AntiDebug.cpp` (native, raw syscalls)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
`TracerPid` in `/proc/self/status`, then in every `/proc/self/task/<tid>/status` (a debugger can trace a single thread).

## Baseline source
`TracerPid: 0` on an untraced process.

## Known benign matches
Crash reporters or profilers that ptrace the process, `strace`, and developers running a debugger. In prod the default DEBUGGER action is WARN.

## Cost
One file read, plus one per thread when the main thread is clean: under 1 ms for typical thread counts.

## Confidence rule
Any non-zero TracerPid: 0.95. Otherwise 0.

## Unsupported behaviour
`/proc` unreadable: unsupported, no event. Earlier ports treated this as a hit.

## Limitations
A tracer that hides its pid, or a debugger attached through the VM only (see `debugger.javaDebugger`). Hooking frameworks that do not ptrace leave no TracerPid.
