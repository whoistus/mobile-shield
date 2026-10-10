# network.vpn

| Field | Value |
|---|---|
| Id | `network.vpn` |
| Platform | android |
| Category | VPN_PROXY |
| Tier | prod |
| Floor | no |

Implementation: `core-android/core/src/main/java/io/mobileshield/detectors/VpnCheck.java` (Java)

## Supported range
Android 6.0+ (API 23); below that the detector is unsupported. Needs `ACCESS_NETWORK_STATE` (declared by the SDK manifest).

## Evidence used
The active network has `TRANSPORT_VPN`.

## Baseline source
No VPN transport on the active network.

## Known benign matches
Corporate and consumer VPNs, always-on VPN profiles and private-DNS tools. Default action is REPORT.

## Cost
One connectivity query, negligible.

## Confidence rule
VPN transport: 0.8. Otherwise 0.

## Unsupported behaviour
API below 23, no connectivity service or any exception: unsupported, no event.

## Limitations
Proxy settings without a VPN are not covered on Android in this version.
