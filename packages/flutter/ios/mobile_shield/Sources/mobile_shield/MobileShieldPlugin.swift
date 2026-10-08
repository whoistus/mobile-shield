import Flutter
import MobileShieldCore

public class MobileShieldPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "mobile_shield", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(MobileShieldPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getSdkVersion":
            result(MobileShield.sdkVersion())
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
