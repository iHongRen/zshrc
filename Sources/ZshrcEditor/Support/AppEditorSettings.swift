import SwiftUI

@MainActor
final class AppEditorSettings: ObservableObject {
    static let minFontSize: CGFloat = 11
    static let maxFontSize: CGFloat = 24
    static let defaultFontSize: CGFloat = 13
    static let step: CGFloat = 1
    private static let defaultsKey = "editor_font_size"

    private let defaults = UserDefaults.standard
    @Published private(set) var fontSize: CGFloat

    init() {
        let storedValue = defaults.object(forKey: Self.defaultsKey) as? Double
        fontSize = Self.clamped(storedValue.map { CGFloat($0) } ?? Self.defaultFontSize)
    }

    func increaseFontSize() {
        updateFontSize(fontSize + Self.step)
    }

    func decreaseFontSize() {
        updateFontSize(fontSize - Self.step)
    }

    func resetFontSize() {
        updateFontSize(Self.defaultFontSize)
    }

    private func updateFontSize(_ newValue: CGFloat) {
        let clampedValue = Self.clamped(newValue)
        guard clampedValue != fontSize else { return }
        fontSize = clampedValue
        defaults.set(Double(clampedValue), forKey: Self.defaultsKey)
    }

    private static func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, minFontSize), maxFontSize)
    }
}
