# jailbreak.sandboxWrite

| Field | Value |
|---|---|
| Id | `jailbreak.sandboxWrite` |
| Platform | ios |
| Category | ROOT |
| Tier | prod |
| Floor | no |

## Supported range
iOS 13+, device builds. On the simulator the process sees the host macOS filesystem, so the result is `unsupported`.

## Evidence used
Attempt to create (`O_CREAT|O_EXCL`) and unlink a uniquely named file in `/private`, which a sandboxed process cannot write.

## Baseline source
Sandbox policy: creation must fail with `EPERM`/`EACCES` on a stock device.

## Known benign matches
None known. The probe file is removed immediately.

## Cost
One `open`, `close`, `unlink`.

## Confidence rule
Successful write 0.95.

## Unsupported behaviour
Simulator: `unsupported`.

## Limitations
A jailbreak that keeps the app sandboxed (rootless with sandbox enforcement) will not hit; hooks on `open` can fake failure.
