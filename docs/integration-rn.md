# React Native integration

Package `@whoistus/react-native-mobile-shield` (replace the scope with the real owner if it changes). Classic NativeModule: RN 0.72 old architecture, RN 0.86 New Architecture through the interop layer. Snippets below are taken from `packages/react-native/example` (RN 0.72) and `consumers/rn-072`. Status of what has been run: [implementation-status.md](implementation-status.md).

## 1. Install

Read-token setup (npm, Gradle) is in [consumer-setup.md](consumer-setup.md). In short:

```
# .npmrc
@whoistus:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${NPM_TOKEN}
```

```bash
npm install --save-exact @whoistus/react-native-mobile-shield@X.Y.Z   # pin the exact released version (GitHub Releases); nothing is published yet
cd ios && pod install                                                  # iOS 13.0+ (RN 0.72 default is 12.4: raise `platform :ios`)
```

Android needs the private Maven repository for `io.mobileshield:core`. RN default templates declare repositories in `android/build.gradle`:

```groovy
allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://maven.pkg.github.com/whoistus/mobile-shield")
            credentials {
                username = findProperty("gpr.user") ?: System.getenv("GITHUB_ACTOR")
                password = findProperty("gpr.token") ?: System.getenv("GITHUB_TOKEN")
            }
            content { includeGroup("io.mobileshield") }
        }
    }
}
```

With Gradle centralized repositories (`FAIL_ON_PROJECT_REPOS`) use the `settings.gradle` block from [consumer-setup.md](consumer-setup.md) instead. The wrapper pins the exact core version, so there is nothing else to declare. Requirements: minSdk 21, compileSdk 35, AGP 8.5.1+; JDK 17 for RN 0.72.

## 2. Bootstrap values (native, immutable)

The channel, config public key and identity pins are read natively from the app's signed bundle and never from JS. Missing channel means `prod`.

Android `AndroidManifest.xml` (inside `<application>`):

```xml
<meta-data android:name="io.mobileshield.CHANNEL" android:value="prod" />
<meta-data android:name="io.mobileshield.CONFIG_PUBKEY" android:value="BASE64_RAW_32_BYTE_ED25519_PUBLIC_KEY" />
<meta-data android:name="io.mobileshield.SIGNING_SHA256" android:value="lowercase-hex-sha256-of-signing-cert[,second-cert-for-rotation]" />
```

`CHANNEL` is `dev`, `test` or `prod`. Without `SIGNING_SHA256`, `tampering.signature` is unsupported (no event). The library manifest merges `ACCESS_NETWORK_STATE`, `DETECT_SCREEN_CAPTURE` and `<queries>` for the GMS/HMS packages.

iOS `Info.plist`:

```xml
<key>MobileShieldChannel</key><string>prod</string>
<key>MobileShieldConfigPubKey</key><string>BASE64_RAW_32_BYTE_ED25519_PUBLIC_KEY</string>
<key>MobileShieldTeamId</key><string>$(DEVELOPMENT_TEAM)</string>
<key>MobileShieldBundleId</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<!-- optional: comma list of allowed distribution modes for tampering.provisioning (prod default: appStore,testFlight) -->
<key>MobileShieldDistribution</key><string>appStore,testFlight</string>
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>cydia</string><string>sileo</string><string>zbra</string><string>filza</string><string>undecimus</string>
</array>
```

- `MobileShieldTeamId` must be 10 uppercase alphanumerics, else `tampering.teamId` is unsupported. `MobileShieldBundleId` and `MobileShieldDistribution` are optional.
- Without at least one of the five schemes in `LSApplicationQueriesSchemes`, `jailbreak.urlSchemes` is unsupported (`canOpenURL` would always answer false). Unsupported detectors emit nothing; on iOS `getConfig().unsupportedDetectors` lists them.
- On the simulator `tampering.teamId` and `jailbreak.urlSchemes` report unsupported.

## 3. Runtime config per channel

The config passed to `init`/`updateConfig` is a full config every time: omitted fields return to the channel defaults. `appId` must equal the Android applicationId / iOS bundle id. `seq` must not go below the persisted last-known-good. Details: [runtime-config.md](runtime-config.md).

| Channel | Bootstrap | Config |
|---|---|---|
| `dev` | no key | `{version: 1, appId, seq}` (unsigned accepted; all categories REPORT) |
| `test` | no key, or a key | same; with a key it must be signed. ROOT/DEBUGGER/HOOKING/TAMPERING WARN |
| `prod` | key required | signed config only. Without a key every config is rejected with `BootstrapMissing` |

```ts
// dev/test, unsigned (from packages/react-native/example/src/shield.ts)
export const baseConfig = (): RuntimeConfig => ({version: 1, appId: APP_ID, seq: Math.floor(Date.now() / 1000)});
```

On prod, ship a signed baseline config in the app (or fetch one) and pass it to `init`; an unsigned object is rejected with `ConfigRejected(signature)` and raises a `policy.badSignature` event on every launch. Signing: [runtime-config.md](runtime-config.md#signing-configs).

## 4. Initialise, listen, gate

Subscribe before `init`: the first check runs synchronously inside `init`. On Android the native listener attaches only while JS has a subscriber, and events raised earlier (at most 64) are replayed to the first one. This is the root gate from `example/src/ShieldGate.tsx`; it renders the app only while native `isBlocked()` is false and re-reads the flag on start, foreground, every deep link and every BLOCK/KILL event.

```tsx
import MobileShield, {MobileShieldError, type ThreatEvent} from '@whoistus/react-native-mobile-shield';

const subscription = MobileShield.onThreat((event: ThreatEvent) => {
  if (event.action === 'BLOCK' || event.action === 'KILL') setState('blocked');   // UI hint only
});

try {
  const env = await MobileShield.init(signedConfig);
} catch (error) {
  // ConfigRejected leaves the SDK initialised on defaults / last-known-good; anything else is fatal.
  const rejected = error instanceof MobileShieldError && error.code === 'ConfigRejected';
  if (!rejected) { /* NativeUnavailable, BootstrapMissing, ...: treat as blocked */ }
}
if (!(await MobileShield.isBlocked())) await MobileShield.startMonitoring();
```

Rules:

- BLOCK is advisory. Native holds the sticky flag; the host must call `isBlocked()` before every protected operation: root navigator, incoming deep links, push-opened routes, restored sessions, biometric quick login. Do not derive enforcement from `event.action` in JS (a hooked JS layer can drop events). The flag stays true until the process restarts.
- Fail closed: if `isBlocked()` throws anything other than `NativeUnavailable`, treat it as blocked. For `NativeUnavailable` the example withholds the protected UI too.
- `onThreat` throws `NativeUnavailable` synchronously when the module is not linked. Call `subscription.remove()` on unmount.
- Monitoring runs in the foreground only. `stopMonitoring()` does not cancel a scheduled KILL.
- Attestation is not implemented: `attestEnrol`/`attestAssert` resolve `{status: 'unsupported', kind}` (see [threat-model.md](threat-model.md)).

API surface (`src/index.ts`): `getSdkVersion`, `init`, `updateConfig`, `getConfig`, `runChecks`, `startMonitoring`, `stopMonitoring`, `isBlocked`, `attestEnrol`, `attestAssert`, `onThreat`. Enums `ThreatCategory`, `Action`, `Severity` and the types `RuntimeConfig`, `AppliedConfig`, `ThreatEvent`, `EnvironmentInfo` are exported.

## 5. Errors

All rejections are `MobileShieldError` with `.code` and, for `ConfigRejected`, `.reason`.

| code | When |
|---|---|
| `NativeUnavailable` | module not linked (JS shipped ahead of the native binary), native library failed to load, or an unexpected native failure |
| `NotInitialized` | `updateConfig` before `init` and `getConfig` / `startMonitoring` before `init` (both platforms) |
| `BootstrapMissing` | prod channel without `CONFIG_PUBKEY` / `MobileShieldConfigPubKey` when a runtime config is passed (this includes `init(config)`) |
| `ConfigRejected` | `.reason` is `signature` (missing/invalid), `schema` (bad field, `appId` mismatch), `expired` (`expiresAt` passed or `seq` below last-known-good) or `floor` |
| `DetectorUnsupported`, `AttestationUnsupported` | reserved codes; the current native layers never throw them |

`init` with a rejected config: the SDK is still initialised and the first check has run. For `signature`, `schema`, `expired` nothing was applied: channel defaults or the persisted last-known-good stay active. For `floor` the clamped config is applied and persisted (`getConfig().clamped` lists what was overridden) and the promise still rejects. Either way `getConfig()` and `isBlocked()` work afterwards; call `getConfig()` to learn what is active.

## 6. CodePush and OTA JS

CodePush ships JS only. A JS bundle that calls this API can reach a binary without the native module or with an older core. `MobileShield.getSdkVersion()` rejects with `NativeUnavailable` when the module is missing; guard on it (and on a minimum version you require) before using newer API, and withhold protected UI if the module is absent. New detectors or native behaviour need a store release.

## 7. Verify an install

Run the app once, then in a debug console: `await MobileShield.getSdkVersion()` equals the pinned version, `(await MobileShield.init(config)).platform` is correct, `await MobileShield.getConfig()` shows the expected `channel`. The example app (`packages/react-native/example`) has Environment, Events and Remote config screens for this.
