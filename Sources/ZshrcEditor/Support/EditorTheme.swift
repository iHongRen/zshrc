import AppKit

struct EditorThemePalette {
    let editorBackground: NSColor
    let chromeBackground: NSColor
    let divider: NSColor
    let gutterBackground: NSColor
    let gutterLineNumber: NSColor
    let gutterActiveLineNumber: NSColor
    let textColor: NSColor
    let insertionPointColor: NSColor
    let searchBarBackground: NSColor
    let searchFieldBackground: NSColor
    let searchFieldBorder: NSColor
    let searchMatch: NSColor
    let currentSearchMatch: NSColor
    let syntaxErrorLine: NSColor
    let stringColor: NSColor
    let variableColor: NSColor
    let keywordColor: NSColor
    let builtinColor: NSColor
    let commentColor: NSColor
    let functionColor: NSColor
    let pathColor: NSColor
    let argumentColor: NSColor
    let assignmentColor: NSColor
    let commandColor: NSColor
    let operatorColor: NSColor
}

enum EditorTheme {
    static func palette(isDarkMode: Bool) -> EditorThemePalette {
        if isDarkMode {
            return EditorThemePalette(
                editorBackground: .rgb(0x0D1117),
                chromeBackground: .rgb(0x161B22),
                divider: .rgb(0x30363D),
                gutterBackground: .rgb(0x0D1117),
                gutterLineNumber: .rgb(0x8B949E),
                gutterActiveLineNumber: .rgb(0xE6EDF3),
                textColor: .rgb(0xF0F6FC),
                insertionPointColor: .rgb(0xE6EDF3),
                searchBarBackground: .rgb(0x161B22),
                searchFieldBackground: .rgb(0x0D1117),
                searchFieldBorder: .rgb(0x30363D),
                searchMatch: .rgb(0x9E6A03, alpha: 0.42),
                currentSearchMatch: .rgb(0xD29922, alpha: 0.62),
                syntaxErrorLine: .rgb(0xF85149, alpha: 0.18),
                stringColor: .rgb(0xF2DFA7),
                variableColor: .rgb(0xFFA657),
                keywordColor: .rgb(0xFF7B72),
                builtinColor: .rgb(0x79C0FF),
                commentColor: .rgb(0xA5AFBA),
                functionColor: .rgb(0xD2A8FF),
                pathColor: .rgb(0x7EE787),
                argumentColor: .rgb(0xC9D1D9),
                assignmentColor: .rgb(0xFFA657),
                commandColor: .rgb(0x7EE787),
                operatorColor: .rgb(0xC9D1D9)
            )
        }

        return EditorThemePalette(
            editorBackground: .rgb(0xFFFFFF),
            chromeBackground: .rgb(0xF6F8FA),
            divider: .rgb(0xD0D7DE),
            gutterBackground: .rgb(0xFFFFFF),
            gutterLineNumber: .rgb(0x8C959F),
            gutterActiveLineNumber: .rgb(0x24292F),
            textColor: .rgb(0x24292F),
            insertionPointColor: .rgb(0x24292F),
            searchBarBackground: .rgb(0xF6F8FA),
            searchFieldBackground: .rgb(0xFFFFFF),
            searchFieldBorder: .rgb(0xD0D7DE),
            searchMatch: .rgb(0xFFF8C5),
            currentSearchMatch: .rgb(0xFFDF5D),
            syntaxErrorLine: .rgb(0xFFEBE9),
            stringColor: .rgb(0x0A3069),
            variableColor: .rgb(0x953800),
            keywordColor: .rgb(0xCF222E),
            builtinColor: .rgb(0x0550AE),
            commentColor: .rgb(0x6E7781),
            functionColor: .rgb(0x8250DF),
            pathColor: .rgb(0x116329),
            argumentColor: .rgb(0x57606A),
            assignmentColor: .rgb(0x953800),
            commandColor: .rgb(0x116329),
            operatorColor: .rgb(0x57606A)
        )
    }
}

private extension NSColor {
    static func rgb(_ hex: Int, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
