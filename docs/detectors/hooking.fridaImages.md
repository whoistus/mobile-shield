# hooking.fridaImages

| Field | Value |
|---|---|
| Id | `hooking.fridaImages` |
| Platform | ios |
| Category | HOOKING |
| Tier | exp |
| Floor | no |

## Supported range
iOS 13+, device and simulator.

## Evidence used
Loaded dyld image names containing `frida`, `gum-js`, `gumjs` (case-insensitive).

## Baseline source
Fixed needle list.

## Known benign matches
Security testing on your own builds.

## Cost
Enumerates loaded images per cycle.

## Confidence rule
Match 0.90. Experimental: always REPORT.

## Unsupported behaviour
Never unsupported.

## Limitations
Renamed gadgets, and Frida 17 builds that are not verified against these names (research B section 3, to re-test in phase 4), are missed.
