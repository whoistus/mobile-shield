# tampering.debuggable

| Field | Value |
|---|---|
| Id | `tampering.debuggable` |
| Platform | android |
| Category | TAMPERING |
| Tier | prod |
| Floor | no |

Implementation: `core-android/core/src/main/java/io/mobileshield/detectors/DebuggableCheck.java` (Java)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
`ApplicationInfo.FLAG_DEBUGGABLE` of the running app.

## Baseline source
Release builds are not debuggable.

## Known benign matches
Debug builds. A debug build on the default (prod) channel is blocked by design; set the `dev` channel for debug flavours.

## Cost
Negligible.

## Confidence rule
Flag set: 0.8. Otherwise 0.

## Unsupported behaviour
Exception: unsupported, no event.

## Limitations
A repackager can set the flag legitimately in the manifest; this detects that case. The flag can also be hidden by hooking `getApplicationInfo`, which `tampering.nativeVsJava` partially covers.
