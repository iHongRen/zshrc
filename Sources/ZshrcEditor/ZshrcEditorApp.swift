import Combine
import SwiftUI

@MainActor
final class EditorCommandCoordinator {
    var onSave: @MainActor @Sendable () async -> Void = { }
    var onFind: @MainActor () -> Void = { }
    var onRevealInFinder: @MainActor () -> Void = { }
    var onIncreaseFontSize: @MainActor () -> Void = { }
    var onDecreaseFontSize: @MainActor () -> Void = { }
    var onResetFontSize: @MainActor () -> Void = { }

    func save() {
        let action = onSave
        Task { @MainActor in
            await action()
        }
    }

    func find() {
        onFind()
    }

    func revealInFinder() {
        onRevealInFinder()
    }

    func increaseFontSize() {
        onIncreaseFontSize()
    }

    func decreaseFontSize() {
        onDecreaseFontSize()
    }

    func resetFontSize() {
        onResetFontSize()
    }
}

@main
struct ZshrcEditorApp: App {
    @StateObject private var viewModel = EditorViewModel()
    @StateObject private var editorSettings = AppEditorSettings()
    @State private var commandCoordinator = EditorCommandCoordinator()
    @AppStorage(AppThemeMode.storageKey) private var themeModeRawValue = AppThemeMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: viewModel,
                commandCoordinator: commandCoordinator,
                editorSettings: editorSettings
            )
            .preferredColorScheme(selectedTheme.colorScheme)
            .task {
                await viewModel.load()
            }
        }
        .defaultSize(width: 1280, height: 840)
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button(L10n.save) {
                    commandCoordinator.save()
                }
                .keyboardShortcut("s", modifiers: .command)
            }

            CommandGroup(replacing: .newItem) {
                Button(L10n.revealInFinder) {
                    commandCoordinator.revealInFinder()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandMenu(L10n.editor) {
                Button(L10n.find) {
                    commandCoordinator.find()
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            CommandMenu(L10n.view) {
                Button(L10n.zoomIn) {
                    commandCoordinator.increaseFontSize()
                }
                .keyboardShortcut("=", modifiers: .command)

                Button(L10n.zoomOut) {
                    commandCoordinator.decreaseFontSize()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button(L10n.actualSize) {
                    commandCoordinator.resetFontSize()
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            CommandMenu(L10n.appearance) {
                Picker(L10n.appearance, selection: $themeModeRawValue) {
                    ForEach(AppThemeMode.allCases) { theme in
                        Text(theme.title).tag(theme.rawValue)
                    }
                }
            }
        }
    }

    private var selectedTheme: AppThemeMode {
        AppThemeMode(rawValue: themeModeRawValue) ?? .system
    }
}
