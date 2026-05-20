import UIKit

@MainActor
final class HapticFeedback {
    static let shared = HapticFeedback()

    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private init() {}

    func prepare() {
        guard isEnabled else { return }
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        selection.prepare()
        notification.prepare()
    }

    func selectionChanged() {
        guard isEnabled else { return }
        lightImpactGenerator.impactOccurred(intensity: 0.86)
        lightImpactGenerator.prepare()
    }

    func lightImpact() {
        guard isEnabled else { return }
        lightImpactGenerator.impactOccurred(intensity: 0.95)
        lightImpactGenerator.prepare()
    }

    func mediumImpact() {
        guard isEnabled else { return }
        mediumImpactGenerator.impactOccurred(intensity: 1.0)
        mediumImpactGenerator.prepare()
    }

    func strongImpact() {
        guard isEnabled else { return }
        heavyImpactGenerator.impactOccurred(intensity: 1.0)
        heavyImpactGenerator.prepare()
    }

    func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    func warning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    private var isEnabled: Bool {
        guard UserDefaults.standard.object(forKey: StoreKeys.hapticsEnabled) != nil else {
            return true
        }
        return UserDefaults.standard.bool(forKey: StoreKeys.hapticsEnabled)
    }
}
