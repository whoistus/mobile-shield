# root.rootbeer

| Field | Value |
|---|---|
| Id | `root.rootbeer` |
| Platform | android |
| Category | ROOT |
| Tier | prod |
| Floor | no |

Implementation: `core-android/core/src/main/java/io/mobileshield/detectors/RootBeerCheck.java` (Java, RootBeer 0.1.1, Apache-2.0)

## Supported range
Android 5.0+ (API 21). RootBeer ships its own native helper in the consumer APK.

## Evidence used
RootBeer 0.1.1's individual public checks, never the aggregate `isRooted*()` (which includes `detectTestKeys()` and the busybox check).

- Strong: `checkForSuBinary`, `checkForMagiskBinary`, `checkForRootNative`, `checkSuExists`, `detectRootManagementApps`.
- Weak: `checkForDangerousProps`, `checkForRWPaths`, `detectPotentiallyDangerousApps`, `detectRootCloakingApps`.
- Never used: `detectTestKeys` (custom ROMs; owned by experimental `root.buildTags`) and the busybox checks (busybox alone is not root).

## Baseline source
Library defaults (RootBeer 0.1.1).

## Known benign matches
Debug/userdebug images, some OEM diagnostic apps and enterprise-managed rooted fleets.

## Cost
Tens of milliseconds, synchronous; part of the 300 ms `runChecks` budget.

## Confidence rule
Any strong check: 0.85 (reaches the default block threshold). No strong check: two or more weak checks 0.6, one weak check 0.4 (both below the default 0.7, so WARN at most). Otherwise 0. Test keys never contribute.

## Unsupported behaviour
Constructing RootBeer failing: unsupported, no event. A single check throwing (e.g. its native helper is missing) is skipped; the others still count.

## Limitations
Name-based package checks are trivially randomised. Kept for breadth; the native detectors and the cross-check carry the stronger signals.
