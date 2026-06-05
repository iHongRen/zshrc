import SwiftUI

struct SearchBarView: View {
    @Binding var isVisible: Bool
    @ObservedObject var viewModel: EditorViewModel

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isSearchFieldFocused: Bool

    private var hasNoMatch: Bool {
        !viewModel.searchQuery.isEmpty && viewModel.searchResults.isEmpty
    }

    private var matchCountText: String {
        guard !viewModel.searchQuery.isEmpty else { return "" }
        guard !viewModel.searchResults.isEmpty else { return L10n.noResults }
        return "\(viewModel.currentSearchIndex + 1)/\(viewModel.searchResults.count)"
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)

                TextField(L10n.searchPlaceholder, text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        viewModel.nextMatch()
                    }
                    .onChange(of: viewModel.searchQuery) { _, newValue in
                        viewModel.search(
                            query: newValue,
                            caseSensitive: viewModel.isCaseSensitive
                        )
                    }

                if !viewModel.searchQuery.isEmpty {
                    Text(matchCountText)
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(hasNoMatch ? noResultsTint : .secondary)
                        .frame(minWidth: 52, alignment: .trailing)
                        .padding(.trailing, 4)
                }

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                        viewModel.search(query: "", caseSensitive: viewModel.isCaseSensitive)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 26)
                }
            }
            .frame(height: 28)
            .padding(.trailing, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                Color(nsColor: .separatorColor),
                                lineWidth: 1
                            )
                    )
            )
            .frame(width: 320)

            Button {
                viewModel.isCaseSensitive.toggle()
                viewModel.search(
                    query: viewModel.searchQuery,
                    caseSensitive: viewModel.isCaseSensitive
                )
            } label: {
                Text("Aa")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(viewModel.isCaseSensitive ? Color.accentColor : .secondary)
                    .frame(width: 28, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(viewModel.isCaseSensitive ? Color.accentColor.opacity(0.14) : .clear)
                    )
            }
            .buttonStyle(.plain)
            .help(L10n.matchCase)

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                Button {
                    viewModel.previousMatch()
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.searchResults.isEmpty)
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Button {
                    viewModel.nextMatch()
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.searchResults.isEmpty)
                .keyboardShortcut("g", modifiers: .command)
            }

            Button {
                closeSearch()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFieldFocused = true
            }
        }
        .onChange(of: isVisible) { _, visible in
            if visible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isSearchFieldFocused = true
                }
            }
        }
        .onExitCommand {
            closeSearch()
        }
    }

    private func closeSearch() {
        viewModel.clearSearch()
        isVisible = false
    }

    private var noResultsTint: Color {
        if colorScheme == .dark {
            return Color(nsColor: .systemGray)
        }
        return Color(nsColor: .systemGray)
    }
}
