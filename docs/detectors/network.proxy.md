# network.proxy

| Field | Value |
|---|---|
| Id | `network.proxy` |
| Platform | ios |
| Category | VPN_PROXY |
| Tier | prod |
| Floor | no |

## Supported range
iOS 13+, device and simulator.

## Evidence used
`CFNetworkCopySystemProxySettings`: `HTTPEnable`, `HTTPSEnable`, `SOCKSEnable`, `ProxyAutoConfigEnable`.

## Baseline source
System network configuration.

## Known benign matches
Corporate proxies and PAC files; developer tools such as Charles.

## Cost
One CFNetwork call per cycle.

## Confidence rule
Any enabled proxy 0.70. Default action for VPN_PROXY is REPORT.

## Unsupported behaviour
`unsupported` if settings cannot be read.

## Limitations
Per-app VPN and on-device VPN tunnels without proxy settings are not reported (VPN detection is out of scope for this id).
