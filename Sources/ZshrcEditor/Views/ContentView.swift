import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: EditorViewModel
    let commandCoordinator: EditorCommandCoordinator
    @ObservedObject var editorSettings: AppEditorSettings

    @Environment(\.colorScheme) private var colorScheme

    @State private var isSearchBarVisible = false
    @State private var cursorLine = 1
    @State private var cursorColumn = 1
    @State private var showReloadConfirmation = false

    private var palette: EditorThemePalette {
        EditorTheme.palette(isDarkMode: colorScheme == .dark)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSearchBarVisible {
                SearchBarView(
                    isVisible: $isSearchBarVisible,
                    viewModel: viewModel
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            editor
            statusBar
        }
        .background(Color(nsColor: palette.editorBackground))
        .navigationTitle(viewModel.targetURL.lastPathComponent)
        .onAppear {
            commandCoordinator.onSave = { [weak viewModel] in
                guard let viewModel else { return }
                await viewModel.save()
            }

            commandCoordinator.onFind = {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSearchBarVisible = true
                }
            }

            commandCoordinator.onRevealInFinder = { [targetURL = viewModel.targetURL] in
                AppOpenActions.revealInFinder(targetURL)
            }
        }
        .alert(L10n.discardEditsTitle, isPresented: $showReloadConfirmation) {
            Button(L10n.reload, role: .destructive) {
                Task { await viewModel.load() }
            }
            Button(L10n.cancel, role: .cancel) { }
        } message: {
            Text(L10n.reloadMessage)
        }
        .alert(
            L10n.somethingWentWrong,
            isPresented: Binding(
                get: { viewModel.lastError != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.lastError = nil
                    }
                }
            )
        ) {
            Button(L10n.ok, role: .cancel) {
                viewModel.lastError = nil
            }
        } message: {
            Text(viewModel.lastError?.errorDescription ?? "")
        }
    }

    private var editor: some View {
        CodeEditorView(
            text: $viewModel.content,
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            isDarkMode: colorScheme == .dark,
            fontSize: editorSettings.fontSize,
            syntaxErrorLine: syntaxErrorLine,
            searchResults: viewModel.searchResults,
            currentSearchIndex: viewModel.currentSearchIndex,
            focusedRange: viewModel.focusedRange,
            focusRevision: viewModel.focusRevision,
            onSaveCommand: {
                Task { await viewModel.save() }
            },
            onIncreaseFontSize: {
                editorSettings.increaseFontSize()
            },
            onDecreaseFontSize: {
                editorSettings.decreaseFontSize()
            },
            onResetFontSize: {
                editorSettings.resetFontSize()
            },
            onFindCommand: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSearchBarVisible = true
                }
            }
        )
    }

    private var statusBar: some View {
        HStack(spacing: 0) {
            statusItem(
                viewModel.isModified ? L10n.unsavedChanges : L10n.saved,
                color: viewModel.isModified ? .red : .secondary
            )

            statusItem(L10n.lineColumn(cursorLine, cursorColumn))
            statusItem(verbatim: "UTF-8")
            statusItem(verbatim: "LF")

            if let syntaxResult = viewModel.syntaxResult, !syntaxResult.isValid {
                statusItem(
                    syntaxResult.statusLabel,
                    help: syntaxResult.message,
                    color: .red
                )

                statusMessageItem(
                    syntaxResult.reasonLabel,
                    help: syntaxResult.message,
                    color: .red
                )
            }

            if let result = viewModel.sourceResult, !result.success {
                statusItem(L10n.sourceFailed, color: .red)
            }

            if !viewModel.searchQuery.isEmpty {
                let label = viewModel.searchResults.isEmpty
                    ? L10n.noMatches
                    : L10n.matchesCount(
                        current: viewModel.currentSearchIndex + 1,
                        total: viewModel.searchResults.count
                    )
                statusItem(label)
            }

            Spacer()

            if let lastSavedAt = viewModel.lastSavedAt {
                Text(lastSavedAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
            }
        }
        .frame(height: 32)
        .background(Color(nsColor: palette.chromeBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(nsColor: palette.divider))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func statusItem(_ text: String, help: String? = nil, color: Color = .secondary) -> some View {
        let item = Text(verbatim: text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 14)

        if let help, !help.isEmpty {
            item.help(help)
        } else {
            item
        }
    }

    @ViewBuilder
    private func statusItem(verbatim text: String, help: String? = nil, color: Color = .secondary) -> some View {
        let item = Text(verbatim: text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 14)

        if let help, !help.isEmpty {
            item.help(help)
        } else {
            item
        }
    }

    @ViewBuilder
    private func statusMessageItem(_ text: String, help: String? = nil, color: Color = .secondary) -> some View {
        let item = Text(verbatim: text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 14)

        if let help, !help.isEmpty {
            item.help(help)
        } else {
            item
        }
    }

    private var syntaxErrorLine: Int? {
        guard let syntaxResult = viewModel.syntaxResult, !syntaxResult.isValid else { return nil }
        return syntaxResult.line
    }
}
