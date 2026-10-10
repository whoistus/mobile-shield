# jailbreak.dyldImages

| Field | Value |
|---|---|
| Id | `jailbreak.dyldImages` |
| Platform | ios |
| Category | ROOT |
| Tier | exp |
| Floor | no |

## Supported range
iOS 13+, device builds. On the simulator the process sees the host macOS filesystem, so the result is `unsupported`.

## Evidence used
Loaded dyld image names containing `substrate`, `substitute`, `libhooker`, `ellekit`, `tweakinject`, `/var/jb`, `cycript`, `sslkillswitch` (case-insensitive).

## Baseline source
Fixed needle list; stock apps load none of these libraries.

## Known benign matches
Debug tooling that injects libraries, and instrumentation SDKs used in test builds.

## Cost
Enumerates all loaded images (a few hundred) per cycle.

## Confidence rule
One image 0.70, two or more 0.85. Experimental: action is always REPORT.

## Unsupported behaviour
Simulator: `unsupported`.

## Limitations
Tweaks can filter `_dyld_get_image_name`; renamed injected libraries are not matched.
