# Runtime configuration

Two layers. Bootstrap (channel, config public key, identity pins) is read natively from the app's signed bundle and never reaches JS/Dart: see [integration-rn.md](integration-rn.md#2-bootstrap-values-native-immutable). Runtime config is a JSON object the host passes to `init` and `updateConfig`. The SDK never fetches config; the host gets it from its own remote-config service and forwards it.

## Shape

Every config is complete and replaces the previous one. Omitted optional fields revert to the channel defaults; they do not inherit from the last config.

| Field | Required | Meaning |
|---|---|---|
| `version` | yes | must be `1` |
| `appId` | yes | must equal the Android applicationId / iOS bundle id, else `ConfigRejected(schema)` |
| `seq` | yes | integer, see below |
| `signature` | when bootstrap has a public key | base64 Ed25519, see [Signing configs](#signing-configs) |
| `expiresAt` | no | epoch ms; at or past it the config is rejected as `expired` |
| `policies` | no | `{ROOT: "BLOCK", ...}` merged over the channel defaults (`REPORT`, `WARN`, `BLOCK`, `KILL`) |
| `detectors` | no | `{"detector.id": false}`; boolean values only |
| `installerAllowlist` | no | installer package names (default list: see [non-gms-devices.md](non-gms-devices.md)) |
| `monitoringIntervalMs` | no | default 5000, minimum 1000 |
| `killDelayMsRange` | no | `[min, max]` ms, default `[500, 3000]` |
| `blockThreshold` | no | 0..1, default 0.7: confidence needed for BLOCK/KILL; below it the action degrades to WARN |

```json
{
  "version": 1,
  "appId": "com.example.app",
  "seq": 1790000000,
  "expiresAt": 1798000000000,
  "policies": {"ROOT": "BLOCK", "EMULATOR": "WARN", "VPN_PROXY": "REPORT"},
  "detectors": {"network.vpn": false, "installer.source": false},
  "blockThreshold": 0.7,
  "signature": "BASE64"
}
```

## Detectors

All 39 detector ids are on by default. A detector set to `false` is not run and raises no events. Ids are listed in [threat-model.md](threat-model.md) and `docs/detectors/`. Experimental ids stay REPORT whatever `policies` says. `getConfig()` returns what is effective: `channel`, `policies`, `disabled`, `clamped`, `blockThreshold`, `monitoringIntervalMs`, `killDelayMsRange`, `installerAllowlist`, `seq`, and on iOS `unsupportedDetectors`.

## Remote config flow

```ts
// host code; fetchSignedConfig() is your service call, it returns the signed object
const config = await fetchSignedConfig();
try {
  await MobileShield.updateConfig(config);
} catch (e) {
  if (e instanceof MobileShieldError && e.code === 'ConfigRejected') {
    // nothing (signature/schema/expired) or the clamped config (floor) is active; log e.reason
  }
}
```

Dart: `await MobileShield.updateConfig(config)` with `on ConfigRejectedException`. The new config takes effect at the next monitoring cycle.

## Production floor and clamping

On the `prod` channel the compiled-in floor is applied after the merge:

| Platform | Detectors that cannot be disabled | Action floor |
|---|---|---|
| Android | `tampering.signature`, `tampering.nativeVsJava` | TAMPERING >= WARN |
| iOS | `tampering.bundleId`, `tampering.teamId` | TAMPERING >= WARN |

A config below the floor is clamped, not discarded: the floor detectors are re-enabled, TAMPERING is raised, the result is applied and persisted, `updateConfig`/`init` reject with `ConfigRejected(floor)`, `getConfig().clamped` lists entries like `detectors.tampering.signature` or `policies.TAMPERING`, and a `policy.floor` event (TAMPERING, confidence 0.5) is emitted. The floor does not apply on `dev` and `test`. Anything else in a signed config is honoured, so protect the signing key.

Floor detectors need their pins: Android `io.mobileshield.SIGNING_SHA256`, iOS `MobileShieldTeamId` (and a device). Without a pin the detector is unsupported and emits nothing.

## Outcomes

| Result | Applied? | Promise | Event |
|---|---|---|---|
| ok | yes, persisted | resolves `AppliedConfig` | none |
| `floor` | clamped config, persisted | rejects `ConfigRejected(floor)` | `policy.floor` 0.5 |
| `signature` | no | rejects | `policy.badSignature` 0.5 |
| `schema` | no | rejects | none |
| `expired` | no | rejects | none |
| prod, no public key | no | rejects `BootstrapMissing` | none |

Checks run in this order: signature, schema, `seq`/expiry, merge, floor. "No" means the previous effective config (defaults or last-known-good) stays. `policy.*` events are low confidence by construction and must not block (see [threat-model.md](threat-model.md)).

## seq, expiry, last-known-good

- `seq` is a monotonic integer. A config with `seq` lower than the persisted last-known-good is rejected as `expired`; equal is accepted. The examples use epoch seconds, which is monotonic across launches. Do not reuse small constants after a higher value has been persisted on a device.
- The last applied config (with its `seq`) is persisted natively in app-private storage. At the first `init` it is restored before the host config is processed, unless the channel is prod without a public key. A stored config that has since expired or no longer verifies is ignored and channel defaults apply.
- On a rejected config the SDK keeps running on what was effective before. A bad remote config therefore cannot brick monitoring.
- Rolling back means publishing a config with a higher `seq`.

## Signing configs

When bootstrap contains `io.mobileshield.CONFIG_PUBKEY` / `MobileShieldConfigPubKey`, every config must carry a valid signature. On prod this is mandatory. The key is base64 of the raw 32-byte Ed25519 public key; any other length is treated as an invalid key and all signed configs fail closed.

Signature: Ed25519 over the UTF-8 bytes of the RFC 8785 canonical JSON of the config without the `signature` member (keys sorted by UTF-16 code units, no whitespace, ES number formatting). The private key lives only on the config service.

Generate a key pair (OpenSSL 3; the macOS system LibreSSL lacks Ed25519 raw signing):

```bash
openssl genpkey -algorithm ed25519 -out config-signing.pem          # keep secret, never commit
openssl pkey -in config-signing.pem -pubout -outform DER | tail -c 32 | base64   # value for CONFIG_PUBKEY
```

Sign on the server (Node 18+, no dependencies; this produces the same signatures as `scripts/fixtures/gen-config-vectors.py` for every signed vector in `scripts/fixtures/config-vectors.json`):

```js
import {createPrivateKey, sign} from 'node:crypto';

const canonical = v =>
  Array.isArray(v) ? `[${v.map(canonical).join(',')}]`
  : v && typeof v === 'object' ? `{${Object.keys(v).sort().map(k => `${JSON.stringify(k)}:${canonical(v[k])}`).join(',')}}`
  : JSON.stringify(v);

export function signConfig(config, privateKeyPem) {
  const {signature, ...body} = config;
  const sig = sign(null, Buffer.from(canonical(body), 'utf8'), createPrivateKey(privateKeyPem));
  return {...body, signature: sig.toString('base64')};
}
```

Ship the public key in the app (manifest / Info.plist), then `signConfig({version: 1, appId, seq, ...}, pem)` per release or per fleet change. Changing `seq`, `expiresAt` or any field means signing again. Rotating the signing key needs an app release (one key per build). The repo test key `scripts/fixtures/test-ed25519.pem` is for tests only; never ship its public key.

Caveat: the Android and iOS canonicalizers follow RFC 8785 for the value types configs use (objects, arrays, strings, booleans, null, finite numbers), but they have not had an independent conformance review and the shared vector suites are written, not yet run on both platforms. Verify a signed production config against a real build of each platform before depending on it. Use ASCII keys and integer or simple decimal numbers.

## Versions and the `next` dist-tag

Lockstep versions: one `VERSION` for core, RN and Flutter. Pre-releases are `X.Y.Z-rc.N`; the npm package publishes them under the `next` dist-tag only, `latest` moves on stable releases. Consumers pin exact versions:

```bash
npm install --save-exact @whoistus/react-native-mobile-shield@next          # latest rc
npm install --save-exact @whoistus/react-native-mobile-shield@1.0.0-rc.1    # pinned rc
```

Flutter consumers pin the git tag (`ref: v1.0.0-rc.1`). See [release-provenance.md](release-provenance.md).
