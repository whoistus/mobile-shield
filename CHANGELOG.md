# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/). Versions are lockstep for core, React Native and Flutter.

## Unreleased

Development snapshot 0.1.0. Compile-verified only; not released.

### Added

- Android core (phase 2): manifest bootstrap, runtime config pipeline (Ed25519 signature, schema, seq/expiry, merge, prod floor), last-known-good persistence, native policy engine and sticky `isBlocked()`, watchdog, foreground monitoring, environment probe, 22 detector ids (14 prod, 8 experimental), four ABIs with 16KB alignment.
- iOS core (phase 3): Info.plist bootstrap, same config pipeline with CryptoKit, policy, watchdog, monitoring, 17 detector ids (11 prod, 6 experimental) including `tampering.teamId`, static XCFramework (device and simulator).
- React Native wrapper (phase 4): typed JS API (`init`, `updateConfig`, `getConfig`, `runChecks`, `startMonitoring`, `stopMonitoring`, `isBlocked`, `onThreat`, attestation stubs), `MobileShieldError`, example app with a root `ShieldGate`.
- Flutter plugin (phase 5): Dart API with typed exceptions and `threats` stream, CocoaPods and SwiftPM support, example app, add-to-app module and Android host.
- Docs (phase 7): RN and Flutter integration guides, final threat model, runtime config and signing guide, non-GMS notes, consumer setup, support matrix, release provenance and release setup, third-party notices, SECURITY.md.
- `scripts/check-versions.sh` (lockstep version gate, also run by `sync-binaries.sh`) and `.github/workflows/release.yml` (tag-driven, resumable publish to GitHub Packages Maven and npm plus GitHub Release). `build-core.yml` and `consumers.yml` are now reusable (`workflow_call`).

### Not yet

- Device matrix, rooted/jailbroken/non-GMS calibration, report-only observation of an rc.
- Attestation (`attestEnrol`/`attestAssert` return `unsupported`), backend enforcement.
- Wallet app migration (phase 6), first publish, clean registry installs.

See [docs/implementation-status.md](docs/implementation-status.md).
