import Foundation
import UIKit

/// Reports screen recording/mirroring and screenshots as screen.captured. No shielding UI.
final class ScreenCaptureObserver: ObservingDetector {
    let id = "screen.captured"
    let category = ThreatCategory.screenCapture

    private let lock = NSLock()
    private var tokens: [NSObjectProtocol] = []

    func run(_ context: DetectorContext) -> DetectionResult {
        Platform.mainSync { Self.isCaptured() } ? .hit(0.9, evidence: "recording") : .clear
    }

    func startObserving(_ sink: @escaping ThreatSink) {
        lock.lock(); defer { lock.unlock() }
        guard tokens.isEmpty else { return }
        let center = NotificationCenter.default
        tokens.append(center.addObserver(forName: UIScreen.capturedDidChangeNotification, object: nil, queue: nil) { _ in
            if Self.isCaptured() { sink(.screenCapture, "screen.captured", 0.9, ["evidence": "recording"]) }
        })
        tokens.append(center.addObserver(forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: nil) { _ in
            sink(.screenCapture, "screen.captured", 0.9, ["evidence": "screenshot"])
        })
    }

    private static func isCaptured() -> Bool {
        let scenes = Platform.application?.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen } ?? []
        return scenes.isEmpty ? UIScreen.main.isCaptured : scenes.contains { $0.isCaptured }
    }
}
