# devicelock.absent

| Field | Value |
|---|---|
| Id | `devicelock.absent` |
| Platform | android, ios |
| Category | NO_DEVICE_LOCK |
| Tier | prod |
| Floor | no |

## Android

Implementation: `core-android/core/src/main/java/io/mobileshield/detectors/DeviceLockCheck.java` (Java)

### Supported range
Android 5.0+ (API 21), all four ABIs (arm64-v8a, armeabi-v7a, x86, x86_64). `isDeviceSecure()` on API 23+, `isKeyguardSecure()` below.

### Evidence used
`KeyguardManager` reports whether a PIN, pattern, password or equivalent secure lock is set.

### Baseline source
A secure lock screen is expected for a financial app.

### Known benign matches
Shared or kiosk devices intentionally without a lock; some work-profile setups report per-profile locks.

### Cost
One system service call, negligible.

### Confidence rule
No secure lock: 0.8. Otherwise 0. Default action WARN.

### Unsupported behaviour
No `KeyguardManager`: unsupported, no event.

### Limitations
Reflects the platform's answer only; a hooked service can lie.

## iOS

Implementation: `core-ios/Sources/Detectors/DeviceLockDetector.swift`

### Supported range
iOS 13+.

### Evidence used
`LAContext.canEvaluatePolicy(.deviceOwnerAuthentication)`; failure with `LAError.passcodeNotSet` means no passcode.

### Baseline source
A device passcode is expected for a financial app.

### Known benign matches
Simulators report no passcode, so the detector hits there; supervised or shared devices without a passcode.

### Cost
One LocalAuthentication query, negligible.

### Confidence rule
`passcodeNotSet`: 0.8. Otherwise 0. Default action WARN.

### Unsupported behaviour
Any other `LAError`: unsupported, no event.

### Limitations
Reflects the platform's answer only; a hooked LocalAuthentication can lie.
