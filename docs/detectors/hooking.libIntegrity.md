# hooking.libIntegrity

| Field | Value |
|---|---|
| Id | `hooking.libIntegrity` |
| Platform | android |
| Category | HOOKING |
| Tier | exp |
| Floor | no |

Implementation: `core-android/core/src/main/cpp/detectors/LibIntegrity.cpp` and `IntegrityLogic.h`

## Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

## Evidence used
Executable `PT_LOAD` segments of this SDK's library and of libc, found with `dl_iterate_phdr`, compared byte for byte with the file each is mapped from (also correct for libraries stored inside the APK). Libraries with text relocations are skipped.

## Baseline source
The file backing the mapping, taken from `/proc/self/maps`; nothing is pinned at build time.

## Known benign matches
Binary-translation layers and OEM runtimes that patch libc in place; devices that load libraries from a replaced file.

## Cost
About 1 MB of memory read and file read per pass, roughly 1 to 3 ms; synchronous.

## Confidence rule
Own library differs: 0.9. libc differs: 0.85. Identical: 0. Experimental tier: always REPORT.

## Unsupported behaviour
Mapping not file-backed or deleted, file unreadable, execute-only memory or text relocations: that segment is skipped; if nothing could be compared the result is unsupported.

## Limitations
Hooks installed in data (GOT/PLT) rather than code are not seen; a tool that also redirects the file reads. Rewrite of the earlier loaded-library patch check on `dl_iterate_phdr`.
