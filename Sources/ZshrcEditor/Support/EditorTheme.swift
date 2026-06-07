import AppKit

struct EditorThemePalette {
    let editorBackground: NSColor
    let chromeBackground: NSColor
    let secondaryChromeBackground: NSColor
    let divider: NSColor
    let gutterBackground: NSColor
    let gutterLineNumber: NSColor
    let gutterActiveLineNumber: NSColor
    let textColor: NSColor
    let insertionPointColor: NSColor
    let secondaryTextColor: NSColor
    let mutedTextColor: NSColor
    let searchBarBackground: NSColor
    let searchFieldBackground: NSColor
    let searchFieldBorder: NSColor
    let searchMatch: NSColor
    let currentSearchMatch: NSColor
    let syntaxErrorLine: NSColor
    let accentColor: NSColor
    let accentMutedBackground: NSColor
    let successColor: NSColor
    let successMutedBackground: NSColor
    let warningColor: NSColor
    let warningMutedBackground: NSColor
    let dangerColor: NSColor
    let dangerMutedBackground: NSColor
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
                secondaryChromeBackground: .rgb(0x0F141B),
                divider: .rgb(0x30363D),
                gutterBackground: .rgb(0x0D1117),
                gutterLineNumber: .rgb(0x8B949E),
                gutterActiveLineNumber: .rgb(0xE6EDF3),
                textColor: .rgb(0xF0F6FC),
                insertionPointColor: .rgb(0xE6EDF3),
                secondaryTextColor: .rgb(0x8B949E),
                mutedTextColor: .rgb(0x6E7681),
                searchBarBackground: .rgb(0x161B22),
                searchFieldBackground: .rgb(0x0D1117),
                searchFieldBorder: .rgb(0x30363D),
                searchMatch: .rgb(0xBB8009, alpha: 0.30),
                currentSearchMatch: .rgb(0xD29922, alpha: 0.52),
                syntaxErrorLine: .rgb(0xF85149, alpha: 0.14),
                accentColor: .rgb(0x2F81F7),
                accentMutedBackground: .rgb(0x1F6FEB, alpha: 0.18),
                successColor: .rgb(0x3FB950),
                successMutedBackground: .rgb(0x238636, alpha: 0.18),
                warningColor: .rgb(0xD29922),
                warningMutedBackground: .rgb(0x9E6A03, alpha: 0.20),
                dangerColor: .rgb(0xF85149),
                dangerMutedBackground: .rgb(0xDA3633, alpha: 0.18),
                stringColor: .rgb(0xA5D6FF),
                variableColor: .rgb(0xFFA657),
                keywordColor: .rgb(0xFF7B72),
                builtinColor: .rgb(0x79C0FF),
                commentColor: .rgb(0x8B949E),
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
            secondaryChromeBackground: .rgb(0xF3F4F6),
            divider: .rgb(0xD0D7DE),
            gutterBackground: .rgb(0xFFFFFF),
            gutterLineNumber: .rgb(0x8C959F),
            gutterActiveLineNumber: .rgb(0x24292F),
            textColor: .rgb(0x24292F),
            insertionPointColor: .rgb(0x24292F),
            secondaryTextColor: .rgb(0x57606A),
            mutedTextColor: .rgb(0x6E7781),
            searchBarBackground: .rgb(0xF6F8FA),
            searchFieldBackground: .rgb(0xFFFFFF),
            searchFieldBorder: .rgb(0xD0D7DE),
            searchMatch: .rgb(0xFFF8C5),
            currentSearchMatch: .rgb(0xF2CC60, alpha: 0.70),
            syntaxErrorLine: .rgb(0xFFEBE9, alpha: 0.90),
            accentColor: .rgb(0x0969DA),
            accentMutedBackground: .rgb(0xDDF4FF),
            successColor: .rgb(0x1A7F37),
            successMutedBackground: .rgb(0xDAFBE1),
            warningColor: .rgb(0x9A6700),
            warningMutedBackground: .rgb(0xFFF8C5),
            dangerColor: .rgb(0xCF222E),
            dangerMutedBackground: .rgb(0xFFEBE9),
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
