# tampering.teamId

| Field | Value |
|---|---|
| Id | `tampering.teamId` |
| Platform | ios |
| Category | TAMPERING |
| Tier | prod |
| Floor | yes |

## Supported range
iOS 13+, device builds. Simulator: `unsupported`.

## Evidence used
Observed signing team versus the pinned Info.plist value `MobileShieldTeamId` (10 character Apple team id, case-insensitive). Observed team, in order: (1) keychain probe: a generic-password item is added with `SecItemAdd` (`kSecReturnAttributes`), its `kSecAttrAccessGroup` (`TEAMID.bundle.id`, derived from the signed `application-identifier` entitlement) is read, the prefix is the team, then the item is deleted. Public API only; the first successful result is cached for the process. (2) `embedded.mobileprovision` payload: `TeamIdentifier`, else `com.apple.developer.team-identifier`.

## Baseline source
`MobileShieldTeamId` in the host Info.plist (bootstrap, protected by the app signature).

## Known benign matches
Apps whose keychain-access-groups entitlement lists a non-team group first return no team from the probe and fall back to the profile. Locked device before first unlock: the keychain call fails and the profile (if any) is used.

## Cost
Keychain probe once per process after success (an add, a read and a delete); profile read per cycle. No network.

## Confidence rule
Keychain team differs from pin 0.95; keychain agrees but profile names another team 0.90; keychain unavailable and profile team differs 0.90.

## Unsupported behaviour
Method matrix: Development, Ad Hoc, Enterprise: keychain and profile both usable. App Store and TestFlight: no `embedded.mobileprovision`, so the keychain probe is the only source. `unsupported` (no event) when `MobileShieldTeamId` is missing or not 10 uppercase alphanumerics, when neither source yields a team, and on the simulator. Because this is a floor id, an integrator who omits the pin runs without team-id verification; `getConfig().unsupportedDetectors` lists it.

## Limitations
SecTask entitlement APIs are not public on iOS and are not used. A re-signer who also changes the pin must edit Info.plist, which invalidates the original signature, so the pin only helps when combined with an out-of-band check of the signed config `appId`.
