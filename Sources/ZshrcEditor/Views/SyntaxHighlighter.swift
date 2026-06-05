import AppKit

private struct HighlightRule {
    let pattern: NSRegularExpression
    let color: NSColor
}

final class SyntaxHighlighter {
    var isDarkMode: Bool {
        didSet {
            if oldValue != isDarkMode {
                rebuildRules()
            }
        }
    }

    var fontSize: CGFloat

    private var rules: [HighlightRule] = []

    init(isDarkMode: Bool, fontSize: CGFloat) {
        self.isDarkMode = isDarkMode
        self.fontSize = fontSize
        rebuildRules()
    }

    func makeAttributedString(for text: String) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: attributedString.length)

        guard fullRange.length > 0 else { return attributedString }

        attributedString.addAttribute(.foregroundColor, value: defaultTextColor, range: fullRange)
        attributedString.addAttribute(
            .font,
            value: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            range: fullRange
        )

        for rule in rules {
            let matches = rule.pattern.matches(in: text, range: fullRange)
            for match in matches {
                let highlightRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
                guard highlightRange.location != NSNotFound,
                      NSMaxRange(highlightRange) <= attributedString.length else {
                    continue
                }

                attributedString.addAttribute(.foregroundColor, value: rule.color, range: highlightRange)
            }
        }

        return attributedString
    }

    func applyHighlighting(to textStorage: NSTextStorage) {
        textStorage.setAttributedString(makeAttributedString(for: textStorage.string))
    }

    private func rebuildRules() {
        var newRules: [HighlightRule] = []

        if let pattern = try? NSRegularExpression(
            pattern: #"^\s*(?:export\s+|typeset\s+-x\s+|declare\s+-x\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*="#,
            options: [.anchorsMatchLines]
        ) {
            newRules.append(HighlightRule(pattern: pattern, color: assignmentColor))
        }

        if let pattern = try? NSRegularExpression(
            pattern: #"^\s*alias\s+([A-Za-z0-9_\-]+)\s*="#,
            options: [.anchorsMatchLines]
        ) {
            newRules.append(HighlightRule(pattern: pattern, color: assignmentColor))
        }

        if let pattern = try? NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*""#) {
            newRules.append(HighlightRule(pattern: pattern, color: stringColor))
        }

        if let pattern = try? NSRegularExpression(pattern: #"'[^']*'"#) {
            newRules.append(HighlightRule(pattern: pattern, color: stringColor))
        }

        if let pattern = try? NSRegularExpression(pattern: #"`[^`]*`"#) {
            newRules.append(HighlightRule(pattern: pattern, color: stringColor))
        }

        if let pattern = try? NSRegularExpression(pattern: #"\$\([^\n]*\)"#) {
            newRules.append(HighlightRule(pattern: pattern, color: commandColor))
        }

        if let pattern = try? NSRegularExpression(pattern: #"\$\{?[\w@#\*\?!\-0-9]+\}?"#) {
            newRules.append(HighlightRule(pattern: pattern, color: variableColor))
        }

        let keywords = [
            "if", "then", "else", "elif", "fi",
            "for", "while", "do", "done",
            "case", "esac", "in",
            "function", "return", "local",
            "export", "source", "alias", "unset",
            "typeset", "declare", "eval",
            "setopt", "unsetopt", "read",
            "echo", "printf", "break", "continue",
            "true", "false"
        ]
        let keywordPattern = "\\b(?:" + keywords.joined(separator: "|") + ")\\b"
        if let pattern = try? NSRegularExpression(pattern: keywordPattern) {
            newRules.append(HighlightRule(pattern: pattern, color: keywordColor))
        }

        if let pattern = try? NSRegularExpression(
            pattern: #"^\s*([A-Za-z_][A-Za-z0-9_\-]*)\s*\(\)"#,
            options: [.anchorsMatchLines]
        ) {
            newRules.append(HighlightRule(pattern: pattern, color: functionColor))
        }

        if let pattern = try? NSRegularExpression(pattern: #"#[^\n]*"#) {
            newRules.append(HighlightRule(pattern: pattern, color: commentColor))
        }

        rules = newRules
    }

    private var defaultTextColor: NSColor {
        isDarkMode ? NSColor(white: 0.92, alpha: 1) : NSColor(white: 0.10, alpha: 1)
    }

    private var stringColor: NSColor {
        isDarkMode
            ? NSColor(red: 0.40, green: 0.85, blue: 0.40, alpha: 1)
            : NSColor(red: 0.11, green: 0.54, blue: 0.11, alpha: 1)
    }

    private var variableColor: NSColor {
        isDarkMode
            ? NSColor(red: 0.30, green: 0.80, blue: 1.00, alpha: 1)
            : NSColor(red: 0.00, green: 0.45, blue: 0.75, alpha: 1)
    }

    private var keywordColor: NSColor {
        isDarkMode
            ? NSColor(red: 0.84, green: 0.55, blue: 1.00, alpha: 1)
            : NSColor(red: 0.55, green: 0.10, blue: 0.75, alpha: 1)
    }

    private var commentColor: NSColor {
        isDarkMode ? NSColor(white: 0.55, alpha: 1) : NSColor(white: 0.50, alpha: 1)
    }

    private var functionColor: NSColor {
        isDarkMode
            ? NSColor(red: 1.00, green: 0.75, blue: 0.30, alpha: 1)
            : NSColor(red: 0.75, green: 0.35, blue: 0.00, alpha: 1)
    }

    private var assignmentColor: NSColor {
        isDarkMode
            ? NSColor(red: 0.95, green: 0.78, blue: 0.32, alpha: 1)
            : NSColor(red: 0.78, green: 0.35, blue: 0.02, alpha: 1)
    }

    private var commandColor: NSColor {
        isDarkMode
            ? NSColor(red: 1.00, green: 0.65, blue: 0.45, alpha: 1)
            : NSColor(red: 0.75, green: 0.28, blue: 0.08, alpha: 1)
    }
}
