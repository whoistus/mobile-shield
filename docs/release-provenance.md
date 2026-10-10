# Release provenance

Every release can be traced from a commit to the bytes consumers install.

## What is recorded per release

| Item | Where |
|---|---|
| Source commit and exact version | git tag `vX.Y.Z[-rc.N]`; `VERSION`; `release.yml` run for that tag |
| Core AAR (`core-<version>.aar`) | GitHub Packages Maven `io.mobileshield:core:<version>` and the GitHub Release asset |
| `MobileShieldCore.xcframework.zip` | GitHub Release asset; the same XCFramework content is vendored in both wrapper packages (`sync-binaries.sh` verifies identical hashes) |
| npm tarball | GitHub Packages npm `@whoistus/react-native-mobile-shield@<version>` |
| Flutter plugin | the git tag itself (`packages/flutter`) |
| Checksums | `SHA256SUMS` release asset covering the AAR, XCFramework zip and symbols archive |
| Unstripped symbols | `mobileshield-symbols-<version>.tar.gz`: per-ABI unstripped `libmobileshield.so` with build ids, for crash symbolication |
| Dependency inventory | `THIRD_PARTY_NOTICES.md` shipped in every package; declared native dependencies in `core-android/core/build.gradle` (RootBeer, Tink) |

## Workflow

`.github/workflows/release.yml` (tag `v*`, or manual resume): version check, `build-core.yml`, `consumers.yml`, Maven publish, npm publish, GitHub Release. See [release-setup.md](release-setup.md) for the step list and how to resume.

- The version check runs `scripts/check-versions.sh <tag>`: `VERSION` must equal the tag (without `v`), `package.json`, both podspecs, `pubspec.yaml`, both wrapper `build.gradle` files (version and core dependency), `Package.swift` and the iOS project version strings.
- The Maven job builds the AAR once, publishes exactly that file and uploads the same file as the Release asset, together with the unstripped libraries from that build. If the version is already on Maven the published AAR is downloaded instead, and no symbols archive is produced by that run.
- Release assets are write-once: a re-run only adds assets that are missing and never overwrites an attached one. `SHA256SUMS` is generated in the run that creates it. If a failed run left a partial release and the missing assets would not match the attached checksums, delete the GitHub Release (not the tag) and re-run to regenerate everything together.
- Builds are not guaranteed bit-for-bit reproducible. The checksums identify what was shipped; they do not prove a rebuild from source gives identical bytes.

## Verifying an install

```bash
gh release download v1.0.0 -p 'SHA256SUMS' -p 'core-*.aar' -p 'MobileShieldCore.xcframework.zip'
shasum -a 256 -c SHA256SUMS            # sha256sum -c on Linux
```

Clean-install verification of every published version (RN 0.72, RN 0.86, Flutter CocoaPods, Flutter SwiftPM, native Android host) with only a read token configured is a release gate: [consumer-setup.md](consumer-setup.md).

## Release gates not enforced by the workflow

The workflow checks versions and builds. It does not check these; the release owner records them before pushing a final tag:

- Written company ownership confirmation for the in-house native code (see [licensing-decision.md](licensing-decision.md)).
- Real-device calibration ([test-matrix.md](test-matrix.md)).
- A report-only observation period for the `-rc` on at least one real app (at least one week or 500 sessions) with a false-positive review per detector id.
- A `1.0.0` tag only after the rc passes clean-install verification.
