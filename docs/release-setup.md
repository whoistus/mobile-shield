# Release setup (publishers)

Status: `.github/workflows/release.yml` is written but has never run. Nothing is published. Do not tag until the gates in [implementation-status.md](implementation-status.md) and [release-provenance.md](release-provenance.md#release-gates-not-enforced-by-the-workflow) are met.

## Registries

| Artifact | Registry |
|---|---|
| `io.mobileshield:core` AAR + POM | GitHub Packages Maven, `https://maven.pkg.github.com/whoistus/mobile-shield` |
| `@whoistus/react-native-mobile-shield` | GitHub Packages npm, `https://npm.pkg.github.com` |
| `mobile_shield` | git tag on this repository (Flutter git dependency) |
| AAR, `MobileShieldCore.xcframework.zip`, `SHA256SUMS`, symbols | GitHub Release for the tag |

GitHub Packages npm requires the package scope to equal the repository owner (`@whoistus`). Moving the repository to an organisation means renaming the npm scope (a new package name) and updating the Maven URL in every consumer; it is not a transparent move. `release.yml` fails early if scope and owner differ.

## CI permissions

- The workflow uses the built-in `GITHUB_TOKEN`. Top-level permission is `contents: read`; jobs elevate: `packages: write` for the Maven and npm jobs, `contents: write` for the release job. No PAT is stored.
- Publishing from a machine instead: classic PAT with `write:packages` and `read:packages` in `~/.gradle/gradle.properties` (`gpr.user`, `gpr.token`) and `~/.npmrc`.
- Consumer CI uses a separate read-only token: [consumer-setup.md](consumer-setup.md).

## Versioning

`VERSION` is the single source of truth; core, RN and Flutter move in lockstep. `scripts/sync-binaries.sh` stamps it into the wrappers and then runs `scripts/check-versions.sh`. Release candidates are `X.Y.Z-rc.N` (npm dist-tag `next`). Commit the stamped files before tagging: the release refuses to run if any stamped file differs from `VERSION` or from the tag.

```bash
echo 1.0.0-rc.1 > VERSION
# build-xcframework.sh first, then:
./scripts/sync-binaries.sh         # stamps wrappers, copies XCFramework, checks versions
./scripts/check-versions.sh v1.0.0-rc.1
git add VERSION core-ios packages && git commit -m "chore: release 1.0.0-rc.1"
git tag v1.0.0-rc.1 && git push origin v1.0.0-rc.1
```

## What release.yml does (tag `v*`)

1. `version`: the ref must be a tag; `scripts/check-versions.sh <tag>` (VERSION, tag, `package.json`, both podspecs, `pubspec.yaml`, both wrapper `build.gradle`, `Package.swift`, iOS project strings); npm scope equals repository owner. Output: version and whether it is a prerelease (contains `-`).
2. `core`: calls `build-core.yml` (forbidden strings, AAR, 16KB gate, iOS tests, XCFramework, sync, 16KB emulator smoke).
3. `consumers`: calls `consumers.yml` (host matrix). Both gate publishing.
4. `maven`: HTTP status of `.../io/mobileshield/core/<version>/core-<version>.pom` on GitHub Packages. 404: build the AAR, 16KB check, `publishReleasePublicationToGitHubPackagesRepository`, keep the AAR and unstripped libraries. 200: skip and download the published AAR. Any other status fails.
5. `npm`: `npm view <name>@<version>`. Absent: download the XCFramework, run `sync-binaries.sh`, `npm publish` (`--tag next` for prereleases). Present: skip.
6. `release`: creates the GitHub Release if missing (`--prerelease` for rc, generated notes) and uploads each asset that is not already attached. Existing assets are never overwritten.

Flutter has no publish step: consumers use the git tag.

## Resuming after a partial failure

Every publish step checks "already published at this version" and skips, so re-running is safe. Re-run failed jobs from the Actions run, or start the workflow again from the Actions tab: choose the **tag** as "Use workflow from" (not a branch) and enter the same tag in the `tag` input. The workflow fails fast if the ref is a branch or the input differs from the ref. If a run failed after a partial release upload, read the checksum note in [release-provenance.md](release-provenance.md).

`npm unpublish`/Maven deletion is outside this workflow; a bad version is fixed by publishing the next rc, not by overwriting.
