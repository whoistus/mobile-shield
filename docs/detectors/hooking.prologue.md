# hooking.prologue

| Field | Value |
|---|---|
| Id | `hooking.prologue` |
| Platform | android, ios |
| Category | HOOKING |
| Tier | exp |
| Floor | no |

## Android

Implementation: `core-android/core/src/main/cpp/detectors/LibIntegrity.cpp` and pure logic in `IntegrityLogic.h`

### Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64).

### Evidence used
First 16 bytes of a few libc entry points (`open`, `read`, `mmap`, `connect`, `ptrace`, `fopen`) in memory vs the same bytes in the file the mapping came from. A recognised trampoline shape (load-literal plus branch, `ldr pc`, `jmp`) is stronger than an arbitrary difference.

### Baseline source
The on-disk libc image of the same device (read through `/proc/self/maps`), so no per-OEM table is needed.

### Known benign matches
Binary-translation layers (Houdini and similar) on x86 images, and OEM libc builds that patch themselves at runtime.

### Cost
Six symbol lookups, 6 small file reads and 96 bytes copied, under 1 ms.

### Confidence rule
Trampoline shape: 0.9. Any other difference: 0.5. Identical: 0. Experimental tier: always REPORT.

### Unsupported behaviour
Maps unreadable, libc not file-backed, symbol missing or memory unreadable (for example execute-only memory): that function is skipped; if none can be checked the result is unsupported. Memory is copied through a pipe, so an unreadable page fails with an error instead of crashing.

### Limitations
Hooks that patch a different instruction than the first bytes, or hook callers instead of libc. Name independent, so it still covers renamed instrumentation tools.

## iOS

Implementation: `core-ios/Sources/Detectors/HookingDetectors.swift`

### Supported range
iOS 13+, arm64/arm64e devices. Unsupported on x86_64 (Intel simulator).

### Evidence used
`dlsym(RTLD_DEFAULT, sym)` for 12 symbols (`open`, `read`, `stat`, `access`, `fopen`, `dlopen`, `dlsym`, `getenv`, `sysctl`, `ptrace`, `_dyld_image_count`, `_dyld_get_image_name`); PAC bits stripped; first three instruction words checked for the inline-hook trampoline shapes `LDR x16,#imm; BR x16` and `ADRP x16; ADD x16,x16,#imm; BR x16`.

### Baseline source
Unhooked system libraries start with ordinary prologues, not an x16 branch trampoline.

### Known benign matches
dyld shared-cache stubs not yet validated on device; must be checked in the device matrix before promotion.

### Cost
12 symbol lookups and 36 bytes read, well under 1 ms.

### Confidence rule
One patched symbol: 0.8. Several: 0.9. Experimental tier: always REPORT.

### Unsupported behaviour
Non-arm64 architecture or no symbol resolvable: unsupported, no event.

### Limitations
Hooks placed after the first three instructions, or hooks on callers (fishhook-style symbol rebinding) are not seen.
