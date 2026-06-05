import SwiftUI

struct EnvironmentSidebarView: View {
    @ObservedObject var viewModel: EditorViewModel

    @State private var filter = ""

    private var filteredSymbols: [ShellSymbol] {
        guard !filter.isEmpty else { return viewModel.shellSymbols }

        return viewModel.shellSymbols.filter { symbol in
            symbol.name.localizedCaseInsensitiveContains(filter)
                || symbol.detail.localizedCaseInsensitiveContains(filter)
        }
    }

    private var variableSymbols: [ShellSymbol] {
        filteredSymbols.filter { $0.kind != .alias }
    }

    private var aliasSymbols: [ShellSymbol] {
        filteredSymbols.filter { $0.kind == .alias }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.quickJump)
                    .font(.system(size: 24, weight: .semibold))

                Text(L10n.quickJumpDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                TextField(L10n.filterSymbols, text: $filter)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    countPill(L10n.variablesCount(variableSymbols.count))
                    countPill(L10n.aliasesCount(aliasSymbols.count))
                }
            }
            .padding(16)

            List {
                if filteredSymbols.isEmpty {
                    ContentUnavailableView(
                        L10n.noShellSymbolsFound,
                        systemImage: "terminal",
                        description: Text(L10n.noShellSymbolsDescription)
                    )
                    .listRowInsets(EdgeInsets())
                    .padding(.top, 32)
                } else {
                    if !variableSymbols.isEmpty {
                        Section(L10n.environment) {
                            ForEach(variableSymbols) { symbol in
                                Button {
                                    viewModel.focus(on: symbol)
                                } label: {
                                    SymbolRow(symbol: symbol)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !aliasSymbols.isEmpty {
                        Section(L10n.aliases) {
                            ForEach(aliasSymbols) { symbol in
                                Button {
                                    viewModel.focus(on: symbol)
                                } label: {
                                    SymbolRow(symbol: symbol)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func countPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.10))
            )
    }
}

private struct SymbolRow: View {
    let symbol: ShellSymbol

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(symbol.name)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)

                    Text(symbol.kind.badgeText)
                        .font(.system(size: 10, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(badgeColor.opacity(0.14))
                        )
                }

                Text(symbol.detail)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(L10n.lineBadge(symbol.line))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var badgeColor: Color {
        switch symbol.kind {
        case .exportVariable:
            return .green
        case .variable:
            return .orange
        case .alias:
            return .blue
        }
    }
}
