# Release setup (publishers)

## Registries

| Artifact | Registry |
|---|---|
| `io.mobileshield:core` AAR + POM | GitHub Packages Maven, `https://maven.pkg.github.com/whoistus/mobile-shield` |
| `@whoistus/react-native-mobile-shield` | GitHub Packages npm, `https://npm.pkg.github.com` |
| `mobile_shield` | git tag on this repository (Flutter git dependency) |

## CI secrets and permissions

- Workflows publish with the built-in `GITHUB_TOKEN`; the job needs `permissions: packages: write, contents: write`. No PAT is stored for publishing.
- If publishing from a machine instead: PAT (classic) with `write:packages` and `read:packages`, in `~/.gradle/gradle.properties` as `gpr.user` / `gpr.token` and in `~/.npmrc` for `npm.pkg.github.com`.
- Consumer CI needs a separate read-only token (`read:packages`) stored as a secret in the consumer repository.

## Versioning

`VERSION` is the single source of truth; core, RN and Flutter move in lockstep. `scripts/sync-binaries.sh` stamps it into the wrappers. Release candidates use `X.Y.Z-rc.N` (npm dist-tag `next`). Consumers pin exact versions.

## Publish order (idempotent, resumable)

1. Core AAR to Maven.
2. XCFramework synced into both wrappers (`sync-binaries.sh`), hash verified.
3. npm publish of the RN wrapper.
4. Git tag for Flutter.

Re-running a step that already succeeded must be a no-op or a skipped duplicate, not a failure.
