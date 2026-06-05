import Foundation

protocol EnvironmentIndexServiceProtocol: Sendable {
    func extractSymbols(from content: String) -> [ShellSymbol]
}

struct EnvironmentIndexService: EnvironmentIndexServiceProtocol, Sendable {
    private let variablePattern = try? NSRegularExpression(
        pattern: #"^\s*(?:(export|typeset\s+-x|declare\s+-x)\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$"#,
        options: [.anchorsMatchLines]
    )

    private let aliasPattern = try? NSRegularExpression(
        pattern: #"^\s*alias\s+([A-Za-z0-9_\-]+)=(.*)$"#,
        options: [.anchorsMatchLines]
    )

    func extractSymbols(from content: String) -> [ShellSymbol] {
        let source = content as NSString
        guard source.length > 0 else { return [] }

        var symbols: [ShellSymbol] = []
        var lineNumber = 1
        var location = 0

        while location < source.length {
            let lineRange = source.lineRange(for: NSRange(location: location, length: 0))
            let rawLine = source.substring(with: lineRange)
            let trimmedLine = rawLine.trimmingCharacters(in: .newlines)

            if let variableMatch = variablePattern?.firstMatch(
                in: trimmedLine,
                range: NSRange(location: 0, length: (trimmedLine as NSString).length)
            ) {
                let nsLine = trimmedLine as NSString
                let isExport = variableMatch.range(at: 1).location != NSNotFound
                let name = nsLine.substring(with: variableMatch.range(at: 2))
                let value = nsLine.substring(with: variableMatch.range(at: 3))
                symbols.append(
                    ShellSymbol(
                        kind: isExport ? .exportVariable : .variable,
                        name: name,
                        detail: previewText(for: value),
                        line: lineNumber,
                        range: lineRange
                    )
                )
            } else if let aliasMatch = aliasPattern?.firstMatch(
                in: trimmedLine,
                range: NSRange(location: 0, length: (trimmedLine as NSString).length)
            ) {
                let nsLine = trimmedLine as NSString
                let name = nsLine.substring(with: aliasMatch.range(at: 1))
                let value = nsLine.substring(with: aliasMatch.range(at: 2))
                symbols.append(
                    ShellSymbol(
                        kind: .alias,
                        name: name,
                        detail: previewText(for: value),
                        line: lineNumber,
                        range: lineRange
                    )
                )
            }

            location = NSMaxRange(lineRange)
            lineNumber += 1
        }

        return symbols
    }

    private func previewText(for value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "empty" }

        if trimmed.count <= 60 {
            return trimmed
        }

        let prefix = trimmed.prefix(57)
        return "\(prefix)..."
    }
}
