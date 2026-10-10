# debugger.ptraced

| Field | Value |
|---|---|
| Id | `debugger.ptraced` |
| Platform | ios |
| Category | DEBUGGER |
| Tier | prod |
| Floor | no |

## Supported range
iOS 13+, device and simulator.

## Evidence used
`sysctl(CTL_KERN, KERN_PROC, KERN_PROC_PID)` and the `P_TRACED` bit of `kp_proc.p_flag`.

## Baseline source
Kernel process table.

## Known benign matches
Running from Xcode or any lldb session sets `P_TRACED`; development builds will report it (default action DEBUGGER=WARN on prod, REPORT on dev).

## Cost
One `sysctl` per cycle.

## Confidence rule
Traced 0.95.

## Unsupported behaviour
`unsupported` if `sysctl` fails.

## Limitations
Debuggers can clear the flag or hook `sysctl`. `PT_DENY_ATTACH` is deliberately not used: it changes host behaviour and breaks development.
