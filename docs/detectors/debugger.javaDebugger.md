# debugger.javaDebugger

| Field | Value |
|---|---|
| Id | `debugger.javaDebugger` |
| Platform | android |
| Category | DEBUGGER |
| Tier | prod |
| Floor | no |

Implementation: `core-android/core/src/main/java/io/mobileshield/detectors/JavaDebuggerCheck.java` (Java)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
`Debug.isDebuggerConnected()` or `Debug.waitingForDebugger()`.

## Baseline source
No debugger attached.

## Known benign matches
Developers on debug builds with JDWP attached.

## Cost
Negligible.

## Confidence rule
Connected or waiting: 0.95. Otherwise 0.

## Unsupported behaviour
Exception: unsupported, no event.

## Limitations
Easily patched in a repackaged app; `debugger.tracerPid` covers native debuggers and `tampering.debuggable` covers a flipped manifest flag.
