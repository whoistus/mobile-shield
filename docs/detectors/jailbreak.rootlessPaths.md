# jailbreak.rootlessPaths

| Field | Value |
|---|---|
| Id | `jailbreak.rootlessPaths` |
| Platform | ios |
| Category | ROOT |
| Tier | prod |
| Floor | no |

## Supported range
iOS 13+, device builds. Layouts: palera1n rootless, Dopamine, `/var/jb` based jailbreaks, binpack (checkra1n, palera1n rootful). On the simulator the process sees the host macOS filesystem, so the result is `unsupported`.

## Evidence used
Existence of `/var/jb` and well-known files under it (`.installed_dopamine`, `.procursus_strapped`, `basebin`, Sileo/Zebra apps, `sshd`, Substrate/ElleKit libraries), `/var/containers/Bundle/tweaksupport`, `/var/binpack`, `/binpack`.

## Baseline source
Fixed path list. Names come from public jailbreak documentation and are unverified on real rootless devices until the phase 4 matrix (see research B section 2).

## Known benign matches
None known.

## Cost
14 probes per cycle, synchronous.

## Confidence rule
One match 0.85, two or more 0.95.

## Unsupported behaviour
Simulator: `unsupported`.

## Limitations
Rootless jailbreaks bind-mount from `/private/preboot/<hash>`; sandbox profiles may hide `/var/jb` from the app entirely. Only a real rootless device can prove coverage. Hiding tweaks defeat file probes.
