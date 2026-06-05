import Foundation

enum ShellSymbolKind: String, Equatable {
    case exportVariable
    case variable
    case alias

    var badgeText: String {
        switch self {
        case .exportVariable:
            L10n.badgeExport
        case .variable:
            L10n.badgeVariable
        case .alias:
            L10n.badgeAlias
        }
    }
}

struct ShellSymbol: Identifiable, Equatable {
    let kind: ShellSymbolKind
    let name: String
    let detail: String
    let line: Int
    let range: NSRange

    var id: String {
        "\(kind.rawValue)-\(name)-\(line)-\(range.location)"
    }
}
