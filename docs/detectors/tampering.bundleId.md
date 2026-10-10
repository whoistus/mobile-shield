# tampering.bundleId

| Field | Value |
|---|---|
| Id | `tampering.bundleId` |
| Platform | ios |
| Category | TAMPERING |
| Tier | prod |
| Floor | yes |

## Supported range
iOS 13+, device builds. Simulator: `unsupported` (ad-hoc signing, test runners have a different main bundle).

## Evidence used
`CFBundleIdentifier` of the main bundle compared with every other identifier available: (1) the code-signing identifier read from the main executable's in-memory `LC_CODE_SIGNATURE` CodeDirectory; (2) the bundle part of `application-identifier` in `embedded.mobileprovision` when present and not a wildcard; (3) optional Info.plist pin `MobileShieldBundleId`.

## Baseline source
Code-signing identifier and provisioning entitlement are produced at signing time; a plain Info.plist edit makes them disagree.

## Known benign matches
Builds signed with a custom `codesign -i` identifier that differs from the bundle id; set `MobileShieldBundleId` only when it equals the real bundle id.

## Cost
Executable signature parsed once per process (cached); profile read per cycle.

## Confidence rule
Any disagreement 0.95; evidence lists the sources that disagree.

## Unsupported behaviour
`unsupported` if the bundle has no `CFBundleIdentifier`, and on the simulator.

## Limitations
A repackager who re-signs consistently under a new bundle id and also edits the profile passes every internal comparison; the `MobileShieldBundleId` pin plus the signed runtime-config `appId` check narrow this. Device-side evidence only.
