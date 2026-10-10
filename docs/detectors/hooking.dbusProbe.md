# hooking.dbusProbe

| Field | Value |
|---|---|
| Id | `hooking.dbusProbe` |
| Platform | android |
| Category | HOOKING |
| Tier | exp |
| Floor | no |

Implementation: `core-android/core/src/main/cpp/detectors/FridaDetect.cpp` (native)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64). Needs loopback socket permission; apps without the INTERNET permission get an unsupported result.

## Evidence used
A single non-blocking connect to `127.0.0.1:27042` (the default instrumentation server port) and one protocol line. There is no port scan.

## Baseline source
Nothing listens on that port on a clean device.

## Known benign matches
Another local service using the same port.

## Cost
Loopback connect and up to 150 ms of poll in the worst case; the result is cached for 10 minutes so the probe is rare.

## Confidence rule
Server answers the protocol probe: 0.8. Something accepts the connection but does not answer: 0.3. Otherwise 0. Experimental tier: always REPORT.

## Unsupported behaviour
Socket creation denied: unsupported, no event.

## Limitations
Servers on non-default ports are not found by design (cost and bypassability of scanning all ports).
