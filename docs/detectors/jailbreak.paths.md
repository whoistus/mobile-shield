# jailbreak.paths

| Field | Value |
|---|---|
| Id | `jailbreak.paths` |
| Platform | ios |
| Category | ROOT |
| Tier | prod |
| Floor | no |

## Supported range
iOS 13+, device builds. On the simulator the process sees the host macOS filesystem, so the result is `unsupported`.

## Evidence used
Existence of rootful jailbreak artefacts: package managers (Cydia, Sileo, Zebra, Installer), Substrate files, `sshd`/`sftp-server`, `/bin/bash`, apt and dpkg state. Each path is probed with two independent primitives (`access`, `open`).

## Baseline source
Fixed path list compiled into the SDK; a stock iOS sandbox sees none of them.

## Known benign matches
None known on stock devices. Developer tools on an Apple Silicon Mac running the iOS app (Designed for iPad) can expose `/bin/bash`; that case is not covered by the simulator guard and needs the device matrix.

## Cost
About 25 `access`/`open` calls per cycle, synchronous, no allocation beyond the path list.

## Confidence rule
One matching path 0.90, two or more 0.97. Reaches `blockThreshold` (0.7) on any match.

## Unsupported behaviour
Simulator: `unsupported` (no event).

## Limitations
Jailbreak-hiding tweaks (Shadow, Choicy, Liberty) hook `access`/`open`/`stat` and hide these paths; `jailbreak.sandboxWrite`, `jailbreak.dyldImages` and `hooking.prologue` give independent evidence.
