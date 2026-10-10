enum DetectorRegistry {
    /// One detector per iOS registry id (17). Tiers are enforced by `Defaults.experimentalIds`.
    static func all(_ bootstrap: Bootstrap) -> [Detector] {
        [
            JailbreakPathsDetector(), JailbreakRootlessDetector(), JailbreakUrlSchemesDetector(),
            JailbreakSandboxWriteDetector(), JailbreakDyldImagesDetector(), JailbreakDyldEnvDetector(),
            DebuggerDetector(), SimulatorDetector(), BundleIdDetector(), TeamIdDetector(),
            ProvisioningDetector(), DeviceLockDetector(), NetworkProxyDetector(),
            FridaImagesDetector(), FridaPortDetector(), PrologueDetector(), ScreenCaptureObserver(),
        ]
    }
}
