import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "app_theme_mode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return L10n.matchSystem
        case .light:
            return L10n.light
        case .dark:
            return L10n.dark
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
