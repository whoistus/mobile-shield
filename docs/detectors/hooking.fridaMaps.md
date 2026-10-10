# hooking.fridaMaps

| Field | Value |
|---|---|
| Id | `hooking.fridaMaps` |
| Platform | android |
| Category | HOOKING |
| Tier | exp |
| Floor | no |

Implementation: `core-android/core/src/main/cpp/detectors/FridaDetect.cpp` (native)

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
Mapped images in `/proc/self/maps` and loaded module names from `dl_iterate_phdr` that match agent/gadget names, and executable `memfd` mappings other than ART's JIT cache.

## Baseline source
Maps of a clean process.

## Known benign matches
Executable memfd mappings exist in some WebView and graphics stacks (weak signal, low confidence).

## Cost
One file read of up to a few hundred KB plus a module walk, about 1 to 5 ms.

## Confidence rule
Agent or gadget name in maps or loaded modules: 0.85. Executable memfd only: 0.4. Experimental tier: always REPORT.

## Unsupported behaviour
`/proc/self/maps` unreadable: unsupported, no event.

## Limitations
Renamed agents and memory-only injection without a named mapping.
