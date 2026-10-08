# Consumer setup

The Android core (`io.mobileshield:core`) is on GitHub Packages Maven and the React Native wrapper on GitHub Packages npm. GitHub Packages requires a token even for reads. Replace `whoistus` with the real owner if it changes.

## Token

Create a personal access token (classic) with scope `read:packages`, or use an org/CI token with the same scope. Store it outside the repo.

Gradle: `~/.gradle/gradle.properties`

```
gpr.user=<github-username>
gpr.token=<token>
```

Or environment variables `GITHUB_ACTOR` and `GITHUB_TOKEN` (CI).

## Android (settings.gradle)

Works with `FAIL_ON_PROJECT_REPOS` / centralized repositories.

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
        }
    }
}
```

## React Native (.npmrc)

Project or user `.npmrc`:

```
@whoistus:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=<token>
```

Then `npm install @whoistus/react-native-mobile-shield` (or yarn equivalent). Pin the exact version.

## Flutter (git dependency)

```yaml
dependencies:
  mobile_shield:
    git:
      url: https://github.com/whoistus/mobile-shield.git
      path: packages/flutter
      ref: v0.1.0
```

Git access uses your normal GitHub credentials. The plugin's Android side still resolves `io.mobileshield:core` from GitHub Packages, so the `settings.gradle` snippet above is also required in the host app.

## Symptom: 401 Unauthorized

Gradle fails with `Could not GET 'https://maven.pkg.github.com/...'. Received status code 401 from server: Unauthorized` (npm: `E401`). Meaning: no token, wrong token, expired token, or missing `read:packages` scope. It is not a missing artifact. Check the properties/env names above and that the token owner can see the repository.

## Local development

Publish the core to the local Maven cache and add `mavenLocal()` to the repositories block (first entry):

```bash
./scripts/build-aar.sh
```

then in `settings.gradle`:

```groovy
repositories { mavenLocal(); google(); mavenCentral() }
```

`mavenLocal()` needs no token. Remove it before release builds so you test the real registry path.
