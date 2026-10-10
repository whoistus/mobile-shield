import XCTest
@testable import MobileShieldCore

final class DetectorSmokeTests: XCTestCase {
    private let devContext = DetectorContext(bootstrap: Bootstrap(appId: testAppId, channel: "dev"))
    private let iosRegistry: Set<String> = [
        "jailbreak.paths", "jailbreak.rootlessPaths", "jailbreak.urlSchemes", "jailbreak.sandboxWrite",
        "jailbreak.dyldImages", "jailbreak.dyldEnv", "debugger.ptraced", "tampering.bundleId", "tampering.teamId",
        "tampering.provisioning", "simulator", "devicelock.absent", "network.proxy", "screen.captured",
        "hooking.fridaImages", "hooking.fridaPort", "hooking.prologue",
    ]

    func testRegistryHasExactlyTheSeventeenIosIds() {
        let ids = DetectorRegistry.all(devContext.bootstrap).map(\.id)
        XCTAssertEqual(ids.count, 17)
        XCTAssertEqual(Set(ids), iosRegistry)
        XCTAssertTrue(Defaults.experimentalIds.isSubset(of: iosRegistry))
        XCTAssertTrue(Defaults.floorIds.isSubset(of: iosRegistry))
    }

    func testRunningTheWholeRegistryOnSimulatorNeverCrashes() {
        for detector in DetectorRegistry.all(devContext.bootstrap) { _ = detector.run(devContext) }
    }

    #if targetEnvironment(simulator)
    func testSimulatorIsDetectedAndNoJailbreakDetectorHits() {
        var hits: [String: Double] = [:]
        for detector in DetectorRegistry.all(devContext.bootstrap) {
            if case .hit(let confidence, _) = detector.run(devContext) { hits[detector.id] = confidence }
        }
        XCTAssertEqual(hits["simulator"], 1.0)
        XCTAssertTrue(hits.keys.filter { $0.hasPrefix("jailbreak.") }.isEmpty, "\(hits)")
        XCTAssertNil(hits["hooking.fridaImages"])
        XCTAssertNil(hits["hooking.prologue"])
    }

    func testJailbreakDetectorsAreUnsupportedOnSimulatorBecauseHostFilesystemIsVisible() {
        for detector in DetectorRegistry.all(devContext.bootstrap) where detector.id.hasPrefix("jailbreak.") {
            XCTAssertEqual(detector.run(devContext), .unsupported(Platform.simulatorReason), detector.id)
        }
    }

    func testIdentityDetectorsAreUnsupportedOnSimulator() {
        let context = DetectorContext(bootstrap: Bootstrap(appId: testAppId, channel: "prod", teamId: "ABCDE12345"))
        XCTAssertEqual(BundleIdDetector().run(context), .unsupported(Platform.simulatorReason))
        XCTAssertEqual(TeamIdDetector().run(context), .unsupported(Platform.simulatorReason))
        XCTAssertEqual(ProvisioningDetector().run(context), .unsupported(Platform.simulatorReason))
    }
    #endif

    func testSimulatorDetectorBothWays() {
        XCTAssertEqual(SimulatorDetector(isSimulator: true).run(devContext), .hit(1.0, evidence: "targetEnvironment(simulator)"))
        XCTAssertEqual(SimulatorDetector(isSimulator: false).run(devContext), .clear)
    }

    func testDebuggerDetectorReportsAConsistentVerdict() {
        let result = DebuggerDetector().run(devContext)
        switch result {
        case .hit(let confidence, _): XCTAssertEqual(confidence, 0.95); XCTAssertEqual(DebuggerDetector.isTraced(), true)
        case .clear: XCTAssertEqual(DebuggerDetector.isTraced(), false)
        case .unsupported: XCTAssertNil(DebuggerDetector.isTraced())
        }
    }

    func testScreenObserverRunDoesNotCrashWithoutApplication() {
        _ = ScreenCaptureObserver().run(devContext)
    }

    func testScreenObserverStartIsIdempotent() {
        let observer = ScreenCaptureObserver()
        let sink: ThreatSink = { _, _, _, _ in }
        observer.startObserving(sink)
        observer.startObserving(sink)
    }

    func testAttestationFacadeStaysUnsupported() {
        XCTAssertEqual(MobileShield.attestEnrol("x", nonce: "n")["status"] as? String, "unsupported")
    }

    // MARK: pure detector logic

    func testPathDetectorsScoreByNumberOfMatches() {
        var legacy = JailbreakPathsDetector()
        legacy.exists = { $0 == "/Applications/Cydia.app" }
        XCTAssertEqual(legacy.evaluate(), .hit(0.9, evidence: "/Applications/Cydia.app"))
        legacy.exists = { $0 == "/Applications/Cydia.app" || $0 == "/etc/apt" }
        XCTAssertEqual(legacy.evaluate(), .hit(0.97, evidence: "/Applications/Cydia.app"))
        legacy.exists = { _ in false }
        XCTAssertEqual(legacy.evaluate(), .clear)
    }

    func testRootlessLayoutsAreCovered() {
        for layout in ["/var/jb", "/var/jb/.installed_dopamine", "/var/jb/Applications/Sileo.app", "/var/jb/basebin", "/var/binpack"] {
            XCTAssertTrue(JailbreakRootlessDetector.paths.contains(layout), layout)
            var detector = JailbreakRootlessDetector()
            detector.exists = { $0 == layout }
            if case .hit(let confidence, _) = detector.evaluate() { XCTAssertEqual(confidence, 0.85) } else { XCTFail(layout) }
        }
        var clean = JailbreakRootlessDetector()
        clean.exists = { _ in false }
        XCTAssertEqual(clean.evaluate(), .clear)
    }

    func testUrlSchemesNeedDeclarationAndOnlyProbeDeclaredOnes() {
        var detector = JailbreakUrlSchemesDetector()
        detector.declared = { [] }
        detector.canOpen = { _ in XCTFail("must not probe undeclared schemes"); return false }
        if case .unsupported = detector.run(devContext) {} else if !Platform.isSimulator { XCTFail("expected unsupported") }
        #if !targetEnvironment(simulator)
        var seen: [String] = []
        detector.declared = { ["sileo", "itms-apps"] }
        detector.canOpen = { seen.append($0.scheme ?? ""); return true }
        XCTAssertEqual(detector.run(devContext), .hit(0.85, evidence: "sileo://"))
        XCTAssertEqual(seen, ["sileo"])
        detector.canOpen = { _ in false }
        XCTAssertEqual(detector.run(devContext), .clear)
        #endif
    }

    func testDyldEnvIgnoresXcodeInjectedLibraries() {
        XCTAssertEqual(JailbreakDyldEnvDetector.evaluate(nil), .clear)
        XCTAssertEqual(JailbreakDyldEnvDetector.evaluate(""), .clear)
        XCTAssertEqual(JailbreakDyldEnvDetector.evaluate("/usr/lib/libMainThreadChecker.dylib:/Developer/usr/lib/libBacktraceRecording.dylib"), .clear)
        XCTAssertEqual(JailbreakDyldEnvDetector.evaluate("/var/jb/usr/lib/TweakInject.dylib"), .hit(0.7, evidence: "TweakInject.dylib"))
        XCTAssertEqual(JailbreakDyldEnvDetector.evaluate("/usr/lib/libMainThreadChecker.dylib:/tmp/evil.dylib"), .hit(0.7, evidence: "evil.dylib"))
    }

    func testDyldImageMatchingIsCaseInsensitive() {
        let images = ["/usr/lib/libSystem.B.dylib", "/var/jb/usr/lib/libSubstrate.dylib", "/private/var/FridaGadget.dylib"]
        XCTAssertEqual(DyldImages.matches(["substrate"], in: images), ["/var/jb/usr/lib/libSubstrate.dylib"])
        var jailbreak = JailbreakDyldImagesDetector()
        jailbreak.images = { images }
        var frida = FridaImagesDetector()
        frida.images = { images }
        XCTAssertEqual(frida.run(devContext), .hit(0.9, evidence: "FridaGadget.dylib"))
        frida.images = { ["/usr/lib/libSystem.B.dylib"] }
        XCTAssertEqual(frida.run(devContext), .clear)
        _ = jailbreak
    }

    func testProxyDetector() {
        var detector = NetworkProxyDetector()
        detector.settings = { ["HTTPEnable": 1, "HTTPSEnable": 0] }
        XCTAssertEqual(detector.run(devContext), .hit(0.7, evidence: "HTTPEnable"))
        detector.settings = { ["HTTPEnable": 0, "SOCKSEnable": 0] }
        XCTAssertEqual(detector.run(devContext), .clear)
        detector.settings = { ["ProxyAutoConfigEnable": 1] }
        XCTAssertEqual(detector.run(devContext), .hit(0.7, evidence: "ProxyAutoConfigEnable"))
        detector.settings = { nil }
        XCTAssertEqual(detector.run(devContext), .unsupported("no proxy settings"))
    }

    func testTrampolinePatternsAreRecognised() {
        let brX16: UInt32 = 0xD61F_0200
        XCTAssertTrue(PrologueDetector.isTrampoline([0x5800_0050, brX16, 0]))
        XCTAssertTrue(PrologueDetector.isTrampoline([0x9000_0010, 0x9100_0210, brX16]))
        XCTAssertFalse(PrologueDetector.isTrampoline([0xD503_237F, 0xA9BF_7BFD, 0x9100_03FD]))
        XCTAssertFalse(PrologueDetector.isTrampoline([0x5800_0050, 0xD65F_03C0, 0]))
        XCTAssertFalse(PrologueDetector.isTrampoline([0x5800_0050]))
    }

    func testPrologueDetectorUsesInjectedWords() {
        #if arch(arm64) || arch(arm64e)
        var detector = PrologueDetector()
        detector.words = { $0 == "open" ? [0x5800_0050, 0xD61F_0200, 0] : [0xD503_237F, 0, 0] }
        XCTAssertEqual(detector.run(devContext), .hit(0.8, evidence: "open"))
        detector.words = { _ in nil }
        XCTAssertEqual(detector.run(devContext), .clear)
        #endif
    }

    func testPrologueOfRealLibcFunctionsIsClean() {
        #if arch(arm64) || arch(arm64e)
        for symbol in PrologueDetector.symbols {
            if let words = PrologueDetector.readWords(symbol) { XCTAssertFalse(PrologueDetector.isTrampoline(words), symbol) }
        }
        #endif
    }

    func testFridaPortDetectorAgainstLocalSockets() throws {
        let (listener, port) = try makeListener()
        defer { close(listener) }
        let open = FridaPortDetector(port: port, ttl: 0)
        XCTAssertEqual(open.run(devContext), .hit(0.5, evidence: "open:\(port)"))
        let (closed, closedPort) = try makeListener()
        close(closed)
        XCTAssertEqual(FridaPortDetector(port: closedPort, ttl: 0).run(devContext), .clear)
    }

    func testFridaPortResultIsCachedWithinTtl() throws {
        var current = Date(timeIntervalSince1970: 1_000)
        let (listener, port) = try makeListener()
        let detector = FridaPortDetector(port: port, ttl: 60, now: { current })
        XCTAssertEqual(detector.run(devContext), .hit(0.5, evidence: "open:\(port)"))
        close(listener)
        XCTAssertEqual(detector.run(devContext), .hit(0.5, evidence: "open:\(port)"))
        current = current.addingTimeInterval(61)
        XCTAssertEqual(detector.run(devContext), .clear)
    }

    func testBundleIdMismatchSources() {
        XCTAssertEqual(BundleIdDetector.mismatches(bundleId: "a.b", pinned: nil, signature: "a.b", profile: nil), [])
        XCTAssertEqual(BundleIdDetector.mismatches(bundleId: "a.b", pinned: "a.b", signature: "c.d", profile: "a.b"), ["codeSignature"])
        XCTAssertEqual(BundleIdDetector.mismatches(bundleId: "a.b", pinned: "x", signature: "y", profile: "z"), ["pinned", "codeSignature", "provisioningProfile"])
    }

    func testBundleIdDetectorVerdicts() {
        var detector = BundleIdDetector()
        detector.infoBundleId = { "a.b" }
        detector.signatureId = { "a.b" }
        detector.profile = { nil }
        if !Platform.isSimulator {
            XCTAssertEqual(detector.run(devContext), .clear)
            detector.signatureId = { "repackaged.app" }
            XCTAssertEqual(detector.run(devContext), .hit(0.95, evidence: "codeSignature"))
        }
    }

    func testTeamIdDecisionTable() {
        let expected = "ABCDE12345"
        XCTAssertEqual(TeamIdDetector.evaluate(expected: expected, keychain: expected, profileTeams: []), .clear)
        XCTAssertEqual(TeamIdDetector.evaluate(expected: expected, keychain: expected, profileTeams: [expected]), .clear)
        XCTAssertEqual(TeamIdDetector.evaluate(expected: expected, keychain: "ZZZZZ99999", profileTeams: [expected]), .hit(0.95, evidence: "keychainGroup"))
        XCTAssertEqual(TeamIdDetector.evaluate(expected: expected, keychain: expected, profileTeams: ["ZZZZZ99999"]), .hit(0.9, evidence: "profileDisagrees"))
        XCTAssertEqual(TeamIdDetector.evaluate(expected: expected, keychain: nil, profileTeams: [expected]), .clear)
        XCTAssertEqual(TeamIdDetector.evaluate(expected: expected, keychain: nil, profileTeams: ["ZZZZZ99999"]), .hit(0.9, evidence: "provisioningProfile"))
        if case .unsupported = TeamIdDetector.evaluate(expected: expected, keychain: nil, profileTeams: []) {} else { XCTFail("expected unsupported") }
    }

    func testTeamIdWithoutBootstrapPinIsUnsupported() {
        if Platform.isSimulator { return }
        if case .unsupported = TeamIdDetector().run(devContext) {} else { XCTFail("expected unsupported without MobileShieldTeamId") }
    }

    func testKeychainAccessGroupPrefix() {
        XCTAssertEqual(KeychainTeam.prefix(ofAccessGroup: "abcde12345.io.mobileshield.example"), "ABCDE12345")
        XCTAssertNil(KeychainTeam.prefix(ofAccessGroup: "io.mobileshield.example"))
        XCTAssertNil(KeychainTeam.prefix(ofAccessGroup: "short.io.example"))
        XCTAssertNil(KeychainTeam.prefix(ofAccessGroup: "noseparator"))
    }

    func testProvisioningProfileParsingAndClassification() throws {
        let development = try XCTUnwrap(ProvisioningProfile.parse(makeProfile([
            "TeamIdentifier": ["abcde12345"], "ProvisionedDevices": ["udid"],
            "Entitlements": ["application-identifier": "ABCDE12345.io.mobileshield.example", "get-task-allow": true],
        ])))
        XCTAssertEqual(development.teamIds, ["ABCDE12345"])
        XCTAssertEqual(development.profileBundleId, "io.mobileshield.example")
        XCTAssertEqual(ProvisioningProfile.classify(development, receiptName: "sandboxReceipt", simulator: false), .development)

        let adHoc = try XCTUnwrap(ProvisioningProfile.parse(makeProfile([
            "TeamIdentifier": ["ABCDE12345"], "ProvisionedDevices": ["udid"], "Entitlements": ["get-task-allow": false],
        ])))
        XCTAssertEqual(ProvisioningProfile.classify(adHoc, receiptName: nil, simulator: false), .adHoc)

        let enterprise = try XCTUnwrap(ProvisioningProfile.parse(makeProfile([
            "ProvisionsAllDevices": true, "Entitlements": ["com.apple.developer.team-identifier": "abcde12345", "application-identifier": "ABCDE12345.*"],
        ])))
        XCTAssertEqual(enterprise.teamIds, ["ABCDE12345"])
        XCTAssertNil(enterprise.profileBundleId)
        XCTAssertEqual(ProvisioningProfile.classify(enterprise, receiptName: nil, simulator: false), .enterprise)

        XCTAssertEqual(ProvisioningProfile.classify(nil, receiptName: "sandboxReceipt", simulator: false), .testFlight)
        XCTAssertEqual(ProvisioningProfile.classify(nil, receiptName: "receipt", simulator: false), .appStore)
        XCTAssertEqual(ProvisioningProfile.classify(nil, receiptName: nil, simulator: false), .unknown)
        XCTAssertEqual(ProvisioningProfile.classify(development, receiptName: nil, simulator: true), .simulator)
    }

    func testProvisioningProfileRejectsGarbage() {
        XCTAssertNil(ProvisioningProfile.parse(Data()))
        XCTAssertNil(ProvisioningProfile.parse(Data("<?xml not a plist </plist>".utf8)))
        XCTAssertNil(ProvisioningProfile.parse(Data("</plist> before <?xml".utf8)))
    }

    func testProvisioningExpectedResultsPerDistributionAndChannel() {
        let prod = Bootstrap(appId: testAppId, channel: "prod")
        let dev = Bootstrap(appId: testAppId, channel: "dev")
        XCTAssertEqual(ProvisioningDetector.evaluate(mode: .appStore, bootstrap: prod), .clear)
        XCTAssertEqual(ProvisioningDetector.evaluate(mode: .testFlight, bootstrap: prod), .clear)
        XCTAssertEqual(ProvisioningDetector.evaluate(mode: .development, bootstrap: prod), .hit(0.7, evidence: "development"))
        XCTAssertEqual(ProvisioningDetector.evaluate(mode: .enterprise, bootstrap: prod), .hit(0.6, evidence: "enterprise"))
        XCTAssertEqual(ProvisioningDetector.evaluate(mode: .adHoc, bootstrap: prod), .hit(0.6, evidence: "adHoc"))
        XCTAssertEqual(ProvisioningDetector.evaluate(mode: .unknown, bootstrap: prod), .hit(0.5, evidence: "unknown"))
        for mode in [DistributionMode.appStore, .testFlight, .enterprise, .adHoc, .development] {
            XCTAssertEqual(ProvisioningDetector.evaluate(mode: mode, bootstrap: dev), .clear, mode.rawValue)
        }
        XCTAssertEqual(ProvisioningDetector.evaluate(mode: .unknown, bootstrap: dev), .hit(0.5, evidence: "unknown"))
        let enterpriseProd = Bootstrap(appId: testAppId, channel: "prod", allowedDistributions: ["enterprise"])
        XCTAssertEqual(ProvisioningDetector.evaluate(mode: .enterprise, bootstrap: enterpriseProd), .clear)
        XCTAssertEqual(ProvisioningDetector.evaluate(mode: .appStore, bootstrap: enterpriseProd), .hit(0.5, evidence: "appStore"))
        if case .unsupported = ProvisioningDetector.evaluate(mode: .simulator, bootstrap: prod) {} else { XCTFail("simulator is unsupported") }
    }

    func testCodeSignatureIdentifierParsing() throws {
        let identifier = "io.mobileshield.example"
        var blob = Data()
        func be(_ value: UInt32) { blob.append(contentsOf: withUnsafeBytes(of: value.bigEndian) { Array($0) }) }
        be(0xFADE_0CC0); be(0); be(1)
        be(0); be(20)
        be(0xFADE_0C02); be(0); be(0x20400); be(0); be(0); be(52)
        while blob.count < 20 + 52 { be(0) }
        blob.removeSubrange((20 + 52)...)
        blob.append(contentsOf: Array(identifier.utf8) + [0])
        let parsed = blob.withUnsafeBytes { CodeSignature.identifier(in: $0.baseAddress!, length: blob.count) }
        XCTAssertEqual(parsed, identifier)

        let truncated = blob.prefix(30)
        let none = Data(truncated).withUnsafeBytes { CodeSignature.identifier(in: $0.baseAddress!, length: truncated.count) }
        XCTAssertNil(none)

        var wrongMagic = blob
        wrongMagic[0] = 0
        XCTAssertNil(wrongMagic.withUnsafeBytes { CodeSignature.identifier(in: $0.baseAddress!, length: wrongMagic.count) })

        var unterminated = Data(blob.prefix(20 + 52))
        unterminated.append(contentsOf: Array(identifier.utf8))
        XCTAssertNil(unterminated.withUnsafeBytes { CodeSignature.identifier(in: $0.baseAddress!, length: unterminated.count) })
    }

    func testPrivacyManifestParses() throws {
        let manifest = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PrivacyInfo.xcprivacy")
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: manifest), format: nil) as? [String: Any])
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertNotNil(plist["NSPrivacyAccessedAPITypes"] as? [Any])
    }

    // MARK: helpers

    private func makeProfile(_ plist: [String: Any]) -> Data {
        let xml = try! PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        return Data([0x30, 0x82, 0x0A, 0xBC]) + xml + Data([0x00, 0x01, 0x02])
    }

    private func makeListener() throws -> (Int32, UInt16) {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        try XCTSkipIf(fd < 0, "no socket")
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = UInt32(0x7F00_0001).bigEndian
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        XCTAssertEqual(bound, 0)
        XCTAssertEqual(listen(fd, 4), 0)
        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &assigned) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        return (fd, UInt16(bigEndian: assigned.sin_port))
    }
}
