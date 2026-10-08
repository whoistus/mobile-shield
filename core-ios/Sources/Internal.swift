import Foundation

/// Internal Swift entry point called by the ObjC facade.
/// Keeping a call edge from `+[MobileShield sdkVersion]` forces every host,
/// including ObjC-only ones linking the static framework, to link the Swift objects.
@objc(MSInternal)
final class MSInternal: NSObject {
    @objc static func normalizedVersion(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
