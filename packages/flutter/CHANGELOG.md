# Changelog

## 0.1.0

- Initial internal release: `init`, `updateConfig`, `getConfig`, `runChecks`, `startMonitoring`, `stopMonitoring`, `isBlocked`, `attestEnrol`, `attestAssert`, `sdkVersion`, `threats` stream.
- Typed exceptions mirroring the native error names.
- Attestation is reserved and always reports `unsupported`.
- Android core via GitHub Packages Maven; iOS XCFramework vendored (CocoaPods and SwiftPM).
