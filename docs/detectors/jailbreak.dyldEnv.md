# jailbreak.dyldEnv

| Field | Value |
|---|---|
| Id | `jailbreak.dyldEnv` |
| Platform | ios |
| Category | ROOT |
| Tier | exp |
| Floor | no |

## Supported range
iOS 13+, device builds. On the simulator the process sees the host macOS filesystem, so the result is `unsupported`.

## Evidence used
`DYLD_INSERT_LIBRARIES` in the process environment, after dropping entries that Xcode injects when launching from the IDE (`libMainThreadChecker`, `libBacktraceRecording`, `libViewDebuggerSupport`, `libLogRedirect`, `/Developer/`, `Xcode.app`, `CoreSimulator`).

## Baseline source
Fixed benign-marker list; an App Store process has no `DYLD_INSERT_LIBRARIES`.

## Known benign matches
Debugger-launched development builds (filtered); custom test harnesses.

## Cost
One `getenv`.

## Confidence rule
Remaining suspicious entry 0.70. Experimental: always REPORT.

## Unsupported behaviour
Simulator: `unsupported` (Xcode sets the variable for every simulator launch).

## Limitations
The variable is stripped by `dyld` for hardened/restricted processes and is trivially unset by an injector after load.
