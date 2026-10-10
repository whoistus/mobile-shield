# Consumer setup

The Android core (`io.mobileshield:core`) is on GitHub Packages Maven, the React Native wrapper on GitHub Packages npm, and the Flutter plugin is a git dependency on this private repository. GitHub Packages requires a token even for reads. The examples use the owner `whoistus`; replace it if the repository moves (npm scope and Maven URL both follow the owner).

## One read token

Create a classic personal access token with scope `read:packages` (the documented path for GitHub Packages; check current GitHub docs before relying on a fine-grained token), owned by a user, or a bot account, who has read access to the `mobile-shield` repository. Packages inherit repository access, so the token owner must be able to see the repo. Store it outside the repo. For Flutter the git fetch needs `repo` read as well (or use SSH, below).

| Where | How |
|---|---|
| Developer machine, Gradle | `~/.gradle/gradle.properties`: `gpr.user=<github-username>` and `gpr.token=<token>` |
| Developer machine, npm | `~/.npmrc`: `//npm.pkg.github.com/:_authToken=<token>` |
| Developer machine, git | normal GitHub credentials (credential manager or SSH key) |
| CI | secret `MOBILE_SHIELD_READ_TOKEN` (name is up to you) in the consumer's repository or org; never commit it |

Do not use the consumer repo's own `GITHUB_TOKEN` to read this package unless an admin has granted that repository access in the package settings; a dedicated read-only token avoids surprises.

## Android (settings.gradle or android/build.gradle)

Centralized repositories (`FAIL_ON_PROJECT_REPOS`) in `settings.gradle`:

```groovy
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://maven.pkg.github.com/whoistus/mobile-shield")
            credentials {
                username = settings.providers.gradleProperty("gpr.user").orNull ?: System.getenv("GITHUB_ACTOR")
                password = settings.providers.gradleProperty("gpr.token").orNull ?: System.getenv("GITHUB_TOKEN")
            }
            content { includeGroup("io.mobileshield") }
        }
    }
}
```

RN and Flutter app templates declare repositories in `android/build.gradle` `allprojects { repositories { ... } }`; put the same `maven { ... }` block there with `findProperty("gpr.user")` (see [integration-rn.md](integration-rn.md)). Native add-to-app hosts: [integration-flutter.md](integration-flutter.md#6-add-to-app-flutter-module-in-a-native-host).

## React Native (.npmrc)

Project `.npmrc` (committed, no secret) plus the token from the user `.npmrc` or CI environment:

```
@whoistus:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${NPM_TOKEN}
```

`npm install --save-exact @whoistus/react-native-mobile-shield@<version>`. Pre-releases live on the `next` dist-tag; always pin the exact version.

## Flutter (git dependency)

```yaml
dependencies:
  mobile_shield:
    git:
      url: https://github.com/whoistus/mobile-shield.git
      path: packages/flutter
      ref: vX.Y.Z   # exact release tag; no tag is published yet
```

The plugin's Android side still resolves `io.mobileshield:core` from GitHub Packages, so the Gradle block above is also required in the app.

## CI

GitHub Actions example (Android, RN and Flutter consumers):

```yaml
env:
  READ_TOKEN: ${{ secrets.MOBILE_SHIELD_READ_TOKEN }}
  NPM_TOKEN: ${{ secrets.MOBILE_SHIELD_READ_TOKEN }}
steps:
  - name: Registry and git credentials
    run: |
      mkdir -p ~/.gradle
      printf 'gpr.user=%s\ngpr.token=%s\n' "ci-bot" "$READ_TOKEN" >> ~/.gradle/gradle.properties
      git config --global url."https://x-access-token:${READ_TOKEN}@github.com/".insteadOf "https://github.com/"
```

Other CI systems: expose the token as a masked variable and write the same Gradle properties, `.npmrc` entry and git rewrite. Alternatively give the runner an SSH deploy key and use `git@github.com:whoistus/mobile-shield.git` as the Flutter URL. Never print the token; use masked variables and avoid `--info` Gradle logs that echo credentials.

## Symptom: 401 Unauthorized

Gradle: `Could not GET 'https://maven.pkg.github.com/...'. Received status code 401 from server: Unauthorized` (npm: `E401`). It means no token, a wrong or expired token, or a token without `read:packages`. A `403`/`404` on a version you know exists means the token owner cannot see the repository.

## Local development without a token

`./scripts/build-aar.sh` publishes the core to Maven Local. Add `mavenLocal()` as the first repository in the consumer build (the example hosts do) and no token is needed. Remove it before release builds so you test the real registry path.

## Clean-install verification (release gate)

On a machine or CI job with only the read token configured and no `mavenLocal()`:

1. RN 0.72 and RN 0.86: new app, `npm install --save-exact` the wrapper, add the repository block, build Android and iOS, print `getSdkVersion()`.
2. Flutter 3.27: `flutter pub add mobile_shield --git-url https://github.com/whoistus/mobile-shield.git --git-ref <tag> --git-path packages/flutter`, build CocoaPods and SwiftPM iOS and Android.
3. Native Android host with centralized repositories (add-to-app).

Record the result for each published version. Not run yet: no version is published ([implementation-status.md](implementation-status.md)).
