# hooking.fridaPort

| Field | Value |
|---|---|
| Id | `hooking.fridaPort` |
| Platform | ios |
| Category | HOOKING |
| Tier | exp |
| Floor | no |

## Supported range
iOS 13+, device and simulator; loopback only (no local-network permission prompt).

## Evidence used
Non-blocking TCP connect to `127.0.0.1:27042`, then a D-Bus `AUTH` handshake and a `REJECTED` reply check. Result cached for 60 seconds. No port scan.

## Baseline source
frida-server default port and D-Bus protocol.

## Known benign matches
Any unrelated local service on 27042 (reported at lower confidence).

## Cost
Up to about 300 ms worst case once per minute on the monitor thread; the first run happens inside `init`.

## Confidence rule
D-Bus `REJECTED` reply 0.90; port open without a D-Bus reply 0.50. Experimental: always REPORT.

## Unsupported behaviour
`unsupported` if a socket cannot be created.

## Limitations
A non-default listen port, USB-tunnelled or gadget-only setups are not seen.
