# jailbreak.urlSchemes

| Field | Value |
|---|---|
| Id | `jailbreak.urlSchemes` |
| Platform | ios |
| Category | ROOT |
| Tier | prod |
| Floor | no |

## Supported range
iOS 13+, device builds, main-thread `canOpenURL`. On the simulator the process sees the host macOS filesystem, so the result is `unsupported`.

## Evidence used
`canOpenURL` for `cydia://`, `sileo://`, `zbra://`, `filza://`, `undecimus://`. Only schemes the host lists in `LSApplicationQueriesSchemes` are probed.

## Baseline source
Fixed scheme list. Host Info.plist must declare the schemes: `LSApplicationQueriesSchemes` = `cydia`, `sileo`, `zbra`, `filza`, `undecimus`.

## Known benign matches
None known; these handlers exist only when a jailbreak package manager is installed.

## Cost
One `canOpenURL` per declared scheme, dispatched to the main queue when called from the monitor thread.

## Confidence rule
One scheme 0.85, two or more 0.95.

## Unsupported behaviour
`unsupported` when the host declares none of the schemes (without the declaration `canOpenURL` always answers false, which would look like a clean device), and on the simulator.

## Limitations
URL-scheme handlers can be hidden by tweaks; iOS limits an app to 50 declared query schemes.
