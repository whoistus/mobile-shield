# MobileShield React Native example (RN 0.72, old architecture)

Screens: Environment (sdkVersion + EnvironmentInfo + gating demo), Events (runChecks / start/stop monitoring / live onThreat list), Remote config (toggle detector ids and per-category actions, `updateConfig`, `getConfig` showing what native clamped).

Root gating lives in `src/ShieldGate.tsx`: the whole tree renders only while native `isBlocked()` is false; it is re-read on start, foreground, incoming deep links and BLOCK/KILL events.

```bash
cd packages/react-native/example
npm install --legacy-peer-deps      # links the package via file:..
# Android (JDK 17): core must be in Maven Local (./scripts/build-aar.sh) or a GitHub Packages token set
cd android && ./gradlew assembleDebug && cd ..   # or: npm run android
# iOS
cd ios && pod install && cd .. && npm run ios
```

Bootstrap keys: `android/app/src/main/AndroidManifest.xml` (`io.mobileshield.CHANNEL`, plus `CONFIG_PUBKEY` / `SIGNING_SHA256` for test/prod) and `ios/MobileShieldExample/Info.plist` (`MobileShieldChannel`, `MobileShieldBundleId`, `MobileShieldTeamId`, `LSApplicationQueriesSchemes` for cydia, sileo, zbra, filza, undecimus). Channel is `dev` here, so unsigned runtime config is accepted; the native floor still applies on `prod`.
