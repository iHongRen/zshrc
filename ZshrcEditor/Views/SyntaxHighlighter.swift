import AppKit

private struct HighlightRule {
    let pattern: NSRegularExpression
    let color: NSColor
}

private struct LinkRule {
    let pattern: NSRegularExpression
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
    private var linkRules: [LinkRule] = []

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

        for rule in linkRules {
            let matches = rule.pattern.matches(in: text, range: fullRange)
            for match in matches {
                let linkRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
                guard linkRange.location != NSNotFound,
                      NSMaxRange(linkRange) <= attributedString.length else {
                    continue
                }

                let rawLink = (text as NSString).substring(with: linkRange)
                guard let url = URL(string: rawLink) else { continue }
                attributedString.addAttribute(.link, value: url, range: linkRange)
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: linkRange)
            }
        }

        return attributedString
    }

    func applyHighlighting(to textStorage: NSTextStorage) {
        textStorage.setAttributedString(makeAttributedString(for: textStorage.string))
    }

    private func rebuildRules() {
        var newRules: [HighlightRule] = []
        let shellKeywords = [
            "if", "then", "else", "elif", "fi",
            "for", "while", "do", "done",
            "case", "esac", "in",
            "function", "return", "local",
            "break", "continue"
        ]
        let builtinCommands = [
            "source", "export", "alias", "unset",
            "typeset", "declare", "eval",
            "setopt", "unsetopt", "read",
            "echo", "printf", "cd", "pwd",
            "dirs", "pushd", "popd", "test",
            "true", "false"
        ]

        if let pattern = try? NSRegularExpression(
            pattern: #"(?<![$A-Za-z0-9_./~+-])([A-Za-z0-9_][A-Za-z0-9_.+-]*)(?![A-Za-z0-9_./~+-])"#
        ) {
            newRules.append(HighlightRule(pattern: pattern, color: argumentColor))
        }

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

        if let pattern = try? NSRegularExpression(
            pattern: #"^\s*([A-Za-z_][A-Za-z0-9_\-]*)\s*\(\)"#,
            options: [.anchorsMatchLines]
        ) {
            newRules.append(HighlightRule(pattern: pattern, color: functionColor))
        }

        if let pattern = try? NSRegularExpression(
            pattern: #"(?m)(?:^|[;&|()]\s*)(source|export|alias|unset|typeset|declare|eval|setopt|unsetopt|read|echo|printf|cd|pwd|dirs|pushd|popd|test|true|false)\b"#
        ) {
            newRules.append(HighlightRule(pattern: pattern, color: builtinColor))
        }

        if let pattern = try? NSRegularExpression(
            pattern: #"(?m)(?:^|[;&|()]\s*)(if|then|else|elif|fi|for|while|do|done|case|esac|in|function|return|local|break|continue)\b"#
        ) {
            newRules.append(HighlightRule(pattern: pattern, color: keywordColor))
        }

        let excludedInvocations = (shellKeywords + builtinCommands).joined(separator: "|")
        if let pattern = try? NSRegularExpression(
            pattern: #"(?m)(?:^|[;&|()]\s*)(?!(?:\#(excludedInvocations))\b)([A-Za-z_][A-Za-z0-9_\-]*)\b(?!\s*=)(?!\s*\()"#
        ) {
            newRules.append(HighlightRule(pattern: pattern, color: commandColor))
        }

        if let pattern = try? NSRegularExpression(pattern: #"\$\([^\n]*\)"#) {
            newRules.append(HighlightRule(pattern: pattern, color: commandColor))
        }

        if let pattern = try? NSRegularExpression(pattern: #"\$\{?[\w@#\*\?!\-0-9]+\}?"#) {
            newRules.append(HighlightRule(pattern: pattern, color: variableColor))
        }

        if let pattern = try? NSRegularExpression(
            pattern: #"\$\{?[\w@#\*\?!\-0-9]+\}?((?:/[A-Za-z0-9._+\-]+)+)"#
        ) {
            newRules.append(HighlightRule(pattern: pattern, color: pathColor))
        }

        if let pattern = try? NSRegularExpression(
            pattern: #"(?<![\w$])((?:~|/|\./|\.\./)[A-Za-z0-9._+/\-]+)"#
        ) {
            newRules.append(HighlightRule(pattern: pattern, color: pathColor))
        }

        if let pattern = try? NSRegularExpression(
            pattern: #"(?:&&|\|\||;;|[;&|(){}\[\]=<>:]|(?<=\s)\\\.|(?<=\s)-{1,2}[A-Za-z0-9][A-Za-z0-9_-]*(?=\s|$|[:)]))"#
        ) {
            newRules.append(HighlightRule(pattern: pattern, color: operatorColor))
        }

        if let pattern = try? NSRegularExpression(
            pattern: ##"\b(?:https?|socks[45])://[^\s"'`(){}<>]+"##
        ) {
            newRules.append(HighlightRule(pattern: pattern, color: stringColor))
            linkRules = [LinkRule(pattern: pattern)]
        } else {
            linkRules = []
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

        if let pattern = try? NSRegularExpression(pattern: #"#[^\n]*"#) {
            newRules.append(HighlightRule(pattern: pattern, color: commentColor))
        }

        rules = newRules
    }

    private var palette: EditorThemePalette {
        EditorTheme.palette(isDarkMode: isDarkMode)
    }

    private var defaultTextColor: NSColor {
        palette.textColor
    }

    private var stringColor: NSColor {
        palette.stringColor
    }

    private var variableColor: NSColor {
        palette.variableColor
    }

    private var keywordColor: NSColor {
        palette.keywordColor
    }

    private var builtinColor: NSColor {
        palette.builtinColor
    }

    private var commentColor: NSColor {
        palette.commentColor
    }

    private var functionColor: NSColor {
        palette.functionColor
    }

    private var pathColor: NSColor {
        palette.pathColor
    }

    private var argumentColor: NSColor {
        palette.argumentColor
    }

    private var assignmentColor: NSColor {
        palette.assignmentColor
    }

    private var commandColor: NSColor {
        palette.commandColor
    }

    private var operatorColor: NSColor {
        palette.operatorColor
    }
}
