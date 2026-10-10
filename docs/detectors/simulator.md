# simulator

| Field | Value |
|---|---|
| Id | `simulator` |
| Platform | ios |
| Category | EMULATOR |
| Tier | prod |
| Floor | no |

## Supported range
iOS 13+; compile-time slice.

## Evidence used
`#if targetEnvironment(simulator)` for the build slice that is running.

## Baseline source
Build target.

## Known benign matches
Developers and CI on simulators (set channel dev). iOS apps running on Apple Silicon Macs (Designed for iPad) use the device slice and are not reported.

## Cost
Constant.

## Confidence rule
Simulator slice 1.0.

## Unsupported behaviour
Never unsupported.

## Limitations
A device slice cannot detect an emulator that executes it unmodified.
