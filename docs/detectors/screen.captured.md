# screen.captured

| Field | Value |
|---|---|
| Id | `screen.captured` |
| Platform | android, ios |
| Category | SCREEN_CAPTURE |
| Tier | prod |
| Floor | no |

## Android

Implementation: `core-android/core/src/main/java/io/mobileshield/AppLifecycle.java` (event driven, not part of `runChecks`)

### Supported range
Android 14+ (API 34). Needs the `DETECT_SCREEN_CAPTURE` permission, declared by the SDK manifest, and a started Activity.

### Evidence used
`Activity.ScreenCaptureCallback`: the platform reports that a screenshot of the app window was taken. This is not a screen-recording detector.

### Baseline source
No screenshot callback fired.

### Known benign matches
Users taking ordinary screenshots; accessibility tools. Default action WARN.

### Cost
No polling: the callback is registered when an activity starts and removed when it stops.

### Confidence rule
Callback fired: 0.9 (one event per screenshot). Never reaches BLOCK by default because SCREEN_CAPTURE defaults to WARN.

### Unsupported behaviour
Below API 34, permission missing or registration failure: nothing is registered and no event is raised.

### Limitations
Only screenshots on API 34+; screen recording, mirroring and capture by privileged software are not detected.

## iOS

Implementation: `core-ios/Sources/Detectors/ScreenCaptureObserver.swift` (observers registered at `init`)

### Supported range
iOS 13+.

### Evidence used
`UIScreen.capturedDidChangeNotification` (recording, mirroring, AirPlay), `UIApplication.userDidTakeScreenshotNotification`, plus an `isCaptured` poll of the connected scenes' screens each cycle. Unlike Android, screenshots and recordings are both reported (parity with the wallet's previous AppDelegate observers).

### Baseline source
Screen not captured, no screenshot notification.

### Known benign matches
Ordinary user screenshots, AirPlay mirroring to a TV, QuickTime capture during development. Default action WARN.

### Cost
Notification observers plus one property read per cycle.

### Confidence rule
Capture or screenshot observed: 0.9.

### Unsupported behaviour
None on supported iOS versions.

### Limitations
No shielding UI (ScreenGuard stays app-side); capture by a jailbroken device's privileged tooling may not raise notifications.
