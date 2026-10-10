import Foundation

/// ObjC-visible bridge for the facade in MobileShield.m. Internal to the framework: MobileShield.h
/// is the only public header.
@objc(MSInternal)
final class MSInternal: NSObject {
    private static var engine: ShieldEngine { ShieldEngine.shared }

    @objc(setupWithConfig:sdkVersion:error:)
    static func setup(_ config: NSDictionary?, sdkVersion: String, error: NSErrorPointer) -> NSDictionary {
        let outcome = engine.initialize(runtime: config as? [String: Any], sdkVersion: sdkVersion)
        error?.pointee = outcome.error?.nsError
        return outcome.environment.dictionary
    }

    @objc(updateWithConfig:error:)
    static func update(_ config: NSDictionary, error: NSErrorPointer) -> NSDictionary {
        guard let runtime = config as? [String: Any] else {
            error?.pointee = ShieldError.configRejected(.schema, "config must be a string-keyed object").nsError
            return engine.configDictionary()
        }
        let outcome = engine.updateConfig(runtime)
        error?.pointee = outcome.error?.nsError
        return engine.configDictionary()
    }

    @objc static func config() -> NSDictionary { engine.configDictionary() }
    @objc static func checks() -> [NSDictionary] { engine.runChecks().map { $0.dictionary } }
    @objc static func start() { engine.startMonitoring() }
    @objc static func stop() { engine.stopMonitoring() }
    @objc static func blocked() -> Bool { engine.isBlocked }

    @objc static func listen(_ listener: @escaping (NSDictionary) -> Void) -> NSUUID {
        engine.addListener { listener($0.dictionary) } as NSUUID
    }

    @objc static func unlisten(_ token: NSUUID) { engine.removeListener(token as UUID) }
}
