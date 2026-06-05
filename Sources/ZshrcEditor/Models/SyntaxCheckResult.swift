import Foundation

struct SyntaxCheckResult: Equatable {
    let isValid: Bool
    let message: String
    let line: Int?

    var statusLabel: String {
        guard !isValid else { return L10n.syntaxOk }

        if let line {
            return L10n.syntaxErrorAt(line)
        }

        return L10n.syntaxError
    }

    var reasonLabel: String {
        guard !isValid else { return "" }

        let firstLine = message
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !firstLine.isEmpty else { return L10n.zshReportedSyntaxError }

        for pattern in [#"^[^:]+:\d+:\s*"#, #"^[^:]+line\s+\d+:\s*"#] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(firstLine.startIndex..<firstLine.endIndex, in: firstLine)
            let stripped = regex.stringByReplacingMatches(in: firstLine, range: range, withTemplate: "")
            if stripped != firstLine {
                return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return firstLine
    }

    static let valid = SyntaxCheckResult(
        isValid: true,
        message: "",
        line: nil
    )
}
