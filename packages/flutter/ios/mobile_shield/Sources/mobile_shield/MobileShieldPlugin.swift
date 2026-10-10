import Flutter
import Foundation
import MobileShieldCore

/// One instance per Flutter engine. The native SDK is process-wide, so engines share it;
/// registering an engine never initialises it, only the Dart `init` call does.
public class MobileShieldPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    // Serial: keeps native calls ordered across engines (init before updateConfig).
    private static let worker = DispatchQueue(label: "io.mobileshield.flutter", qos: .userInitiated)

    private var methods: FlutterMethodChannel?
    private var events: FlutterEventChannel?
    private var sink: FlutterEventSink?
    private var token: Any?
    private var attached = true

    public static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = MobileShieldPlugin()
        let methods = FlutterMethodChannel(name: "mobile_shield", binaryMessenger: registrar.messenger())
        let events = FlutterEventChannel(name: "mobile_shield/threats", binaryMessenger: registrar.messenger())
        plugin.methods = methods
        plugin.events = events
        registrar.addMethodCallDelegate(plugin, channel: methods)
        events.setStreamHandler(plugin)
        registrar.publish(plugin)
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        attached = false
        detachListener()
        methods?.setMethodCallHandler(nil)
        events?.setStreamHandler(nil)
        methods = nil
        events = nil
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        detachListener()
        sink = events
        token = MobileShield.addListener { [weak self] event in
            let payload = MobileShieldPlugin.encode(event)
            DispatchQueue.main.async {
                guard let self = self, self.attached else { return }
                self.sink?(payload)
            }
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        detachListener()
        return nil
    }

    private func detachListener() {
        if let token = token { MobileShield.removeListener(token) }
        token = nil
        sink = nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        let arguments = call.arguments
        MobileShieldPlugin.worker.async {
            let outcome = MobileShieldPlugin.dispatch(method, arguments)
            DispatchQueue.main.async {
                if self.attached { result(outcome) }
            }
        }
    }

    // Returns a value, nil (void), FlutterError, or FlutterMethodNotImplemented, as FlutterResult expects.
    private static func dispatch(_ method: String, _ arguments: Any?) -> Any? {
        let args = arguments as? [String: Any]
        switch method {
        case "getSdkVersion":
            return MobileShield.sdkVersion()
        case "init":
            var error: NSError?
            let value = MobileShield.initWithConfig(args, error: &error)
            return error.map(flutterError) ?? encode(value)
        case "updateConfig":
            var error: NSError?
            let value = MobileShield.updateConfig(args ?? [:], error: &error)
            return error.map(flutterError) ?? encode(value)
        case "getConfig":
            return requireInitialized() ?? encode(MobileShield.getConfig())
        case "runChecks":
            return encode(MobileShield.runChecks())
        case "startMonitoring":
            if let failure = requireInitialized() { return failure }
            MobileShield.startMonitoring()
            return nil
        case "stopMonitoring":
            MobileShield.stopMonitoring()
            return nil
        case "isBlocked":
            return MobileShield.isBlocked()
        case "attestEnrol":
            return encode(MobileShield.attestEnrol(text(args, "kind"), nonce: text(args, "nonce")))
        case "attestAssert":
            return encode(MobileShield.attestAssert(
                text(args, "kind"), nonce: text(args, "nonce"), requestHash: text(args, "requestHash")))
        default:
            return FlutterMethodNotImplemented
        }
    }

    // getConfig is empty until init succeeded in this process.
    private static func requireInitialized() -> FlutterError? {
        MobileShield.getConfig().isEmpty
            ? FlutterError(code: "NotInitialized", message: "call init first", details: nil)
            : nil
    }

    private static func flutterError(_ error: NSError) -> FlutterError {
        let reason = error.userInfo["reason"] as? String ?? "NativeError"
        let code = reason.split(separator: ".").first.map(String.init) ?? reason
        var details: [String: String]?
        if code == "ConfigRejected", let why = error.userInfo["configReason"] as? String {
            details = ["reason": why]
        }
        return FlutterError(code: code, message: error.localizedDescription, details: details)
    }

    private static func text(_ args: [String: Any]?, _ key: String) -> String {
        args?[key] as? String ?? ""
    }

    private static func encode(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}
