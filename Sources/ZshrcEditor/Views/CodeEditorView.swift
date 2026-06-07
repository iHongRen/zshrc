import AppKit
import SwiftUI

final class EditorTextView: NSTextView {
    var onSaveCommand: (() -> Void)?
    var onFindCommand: (() -> Void)?
    var onIncreaseFontSize: (() -> Void)?
    var onDecreaseFontSize: (() -> Void)?
    var onResetFontSize: (() -> Void)?
    private var hasAutoFocused = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard !hasAutoFocused else { return }
        hasAutoFocused = true

        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        editingContextMenu()
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags == [.command], event.charactersIgnoringModifiers?.lowercased() == "s" {
            onSaveCommand?()
            return
        }

        if flags == [.command], event.charactersIgnoringModifiers?.lowercased() == "f" {
            onFindCommand?()
            return
        }

        if flags == [.command], event.charactersIgnoringModifiers == "=" {
            onIncreaseFontSize?()
            return
        }

        if flags == [.command], event.characters == "+" {
            onIncreaseFontSize?()
            return
        }

        if flags == [.command], event.charactersIgnoringModifiers == "-" {
            onDecreaseFontSize?()
            return
        }

        if flags == [.command], event.charactersIgnoringModifiers == "0" {
            onResetFontSize?()
            return
        }

        if flags == [.command], event.charactersIgnoringModifiers == "/" {
            toggleLineComments()
            return
        }

        super.keyDown(with: event)
    }

    private func editingContextMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(contextMenuItem(L10n.undo, action: Selector(("undo:"))))
        menu.addItem(contextMenuItem(L10n.redo, action: Selector(("redo:"))))
        menu.addItem(.separator())

        menu.addItem(contextMenuItem(L10n.cut, action: #selector(NSText.cut(_:))))
        menu.addItem(contextMenuItem(L10n.copy, action: #selector(NSText.copy(_:))))
        menu.addItem(contextMenuItem(L10n.paste, action: #selector(NSText.paste(_:))))
        menu.addItem(contextMenuItem(L10n.delete, action: #selector(NSText.delete(_:))))
        menu.addItem(.separator())

        menu.addItem(contextMenuItem(L10n.selectAll, action: #selector(NSText.selectAll(_:))))

        return menu
    }

    private func contextMenuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = nil
        return item
    }

    private func toggleLineComments() {
        let source = string as NSString
        let selection = selectedRange()
        let lineRange = source.commentableLineRange(for: selection)
        let transformed = source.toggledShellLineComments(
            in: lineRange,
            relativeCaretOffset: max(0, selection.location - lineRange.location),
            keepsSelection: selection.length > 0
        )

        guard transformed.replacement != source.substring(with: lineRange) else { return }
        guard shouldChangeText(in: lineRange, replacementString: transformed.replacement) else { return }

        textStorage?.beginEditing()
        textStorage?.replaceCharacters(in: lineRange, with: transformed.replacement)
        textStorage?.endEditing()
        didChangeText()

        setSelectedRange(transformed.selectedRange.offsettingLocation(by: lineRange.location))
    }
}

private extension NSString {
    struct CommentToggleResult {
        let replacement: String
        let selectedRange: NSRange
    }

    func commentableLineRange(for selection: NSRange) -> NSRange {
        let safeLocation = min(max(selection.location, 0), length)
        let safeEnd = min(max(NSMaxRange(selection), safeLocation), length)

        guard length > 0 else {
            return NSRange(location: safeLocation, length: 0)
        }

        if selection.length == 0 {
            return lineRange(for: NSRange(location: safeLocation, length: 0))
        }

        let adjustedEnd = safeEnd > safeLocation && character(at: safeEnd - 1) == 10
            ? safeEnd - 1
            : safeEnd

        return lineRange(for: NSRange(location: safeLocation, length: adjustedEnd - safeLocation))
    }

    func toggledShellLineComments(
        in targetRange: NSRange,
        relativeCaretOffset: Int,
        keepsSelection: Bool
    ) -> CommentToggleResult {
        guard targetRange.location <= length,
              NSMaxRange(targetRange) <= length else {
            return CommentToggleResult(
                replacement: "",
                selectedRange: NSRange(location: 0, length: 0)
            )
        }

        let lines = shellLineInfos(in: targetRange)
        let nonBlankLines = lines.filter { !$0.isBlank }
        let shouldUncomment = !nonBlankLines.isEmpty && nonBlankLines.allSatisfy(\.isCommented)
        let insertion = "# "

        var replacement = ""
        replacement.reserveCapacity(targetRange.length + lines.count * insertion.utf16.count)

        var updatedCaretOffset = min(relativeCaretOffset, targetRange.length)
        var didMapCaret = false

        for line in lines {
            if shouldUncomment {
                replacement += line.rebuiltLineByUncommenting()

                if !didMapCaret,
                   relativeCaretOffset >= line.relativeLocation,
                   relativeCaretOffset <= line.relativeEnd {
                    updatedCaretOffset = line.relativeLocation + mappedOffsetWhenUncommenting(
                        originalOffset: relativeCaretOffset - line.relativeLocation,
                        indentLength: line.indentUTF16Length,
                        removedLength: line.removedPrefixUTF16Length
                    )
                    didMapCaret = true
                }
            } else {
                replacement += line.rebuiltLineByCommenting(with: insertion)

                if !didMapCaret,
                   relativeCaretOffset >= line.relativeLocation,
                   relativeCaretOffset <= line.relativeEnd {
                    updatedCaretOffset = line.relativeLocation + mappedOffsetWhenCommenting(
                        originalOffset: relativeCaretOffset - line.relativeLocation,
                        indentLength: line.indentUTF16Length,
                        insertedLength: insertion.utf16.count
                    )
                    didMapCaret = true
                }
            }
        }

        let replacementLength = replacement.utf16.count
        return CommentToggleResult(
            replacement: replacement,
            selectedRange: keepsSelection
                ? NSRange(location: 0, length: replacementLength)
                : NSRange(location: min(updatedCaretOffset, replacementLength), length: 0)
        )
    }

    private func mappedOffsetWhenCommenting(
        originalOffset: Int,
        indentLength: Int,
        insertedLength: Int
    ) -> Int {
        if originalOffset < indentLength {
            return originalOffset
        }
        return originalOffset + insertedLength
    }

    private func mappedOffsetWhenUncommenting(
        originalOffset: Int,
        indentLength: Int,
        removedLength: Int
    ) -> Int {
        let removalStart = indentLength
        let removalEnd = indentLength + removedLength

        if originalOffset < removalStart {
            return originalOffset
        }
        if originalOffset <= removalEnd {
            return removalStart
        }
        return originalOffset - removedLength
    }

    private func shellLineInfos(in targetRange: NSRange) -> [ShellLineInfo] {
        guard targetRange.length > 0 || length == 0 else { return [] }

        var lines: [ShellLineInfo] = []
        let segment = substring(with: targetRange) as NSString
        var lineLocation = 0

        while lineLocation < segment.length {
            let fullLineRange = segment.lineRange(for: NSRange(location: lineLocation, length: 0))
            let clampedEnd = min(NSMaxRange(fullLineRange), segment.length)
            let effectiveLineRange = NSRange(location: lineLocation, length: clampedEnd - lineLocation)
            let lineString = segment.substring(with: effectiveLineRange)
            lines.append(ShellLineInfo(line: lineString, relativeLocation: lineLocation))
            lineLocation = clampedEnd
        }

        if lines.isEmpty {
            lines.append(ShellLineInfo(line: "", relativeLocation: 0))
        }

        return lines
    }

    struct ShellLineInfo {
        let rawLine: String
        let indent: String
        let contentAfterIndent: String
        let contentAfterPrefix: String
        let lineEnding: String
        let isCommented: Bool
        let isBlank: Bool
        let indentUTF16Length: Int
        let removedPrefixUTF16Length: Int
        let relativeLocation: Int
        let relativeEnd: Int

        init(line: String, relativeLocation: Int) {
            rawLine = line
            let components = line.decomposedShellLine()

            indent = components.indent
            contentAfterIndent = components.contentAfterIndent
            lineEnding = components.lineEnding
            self.relativeLocation = relativeLocation
            relativeEnd = relativeLocation + line.utf16.count

            let commentInfo = components.contentAfterIndent.shellCommentInfo()
            isCommented = commentInfo.isCommented
            contentAfterPrefix = commentInfo.contentAfterPrefix
            removedPrefixUTF16Length = commentInfo.removedPrefixUTF16Length
            indentUTF16Length = indent.utf16.count
            isBlank = contentAfterIndent.isEmpty
        }

        func rebuiltLineByCommenting(with insertion: String) -> String {
            indent + insertion + contentAfterIndent + lineEnding
        }

        func rebuiltLineByUncommenting() -> String {
            guard isCommented else { return rawLine }
            return indent + contentAfterPrefix + lineEnding
        }
    }
}

private extension String {
    struct DecomposedShellLine {
        let indent: String
        let contentAfterIndent: String
        let lineEnding: String
    }

    struct ShellCommentInfo {
        let isCommented: Bool
        let contentAfterPrefix: String
        let removedPrefixUTF16Length: Int
    }

    func decomposedShellLine() -> DecomposedShellLine {
        let lineEnding: String
        let body: String

        if hasSuffix("\r\n") {
            lineEnding = "\r\n"
            body = String(dropLast(2))
        } else if hasSuffix("\n") {
            lineEnding = "\n"
            body = String(dropLast())
        } else {
            lineEnding = ""
            body = self
        }

        let indentEnd = body.firstIndex { !$0.isWhitespace || $0.isNewline } ?? body.endIndex
        return DecomposedShellLine(
            indent: String(body[..<indentEnd]),
            contentAfterIndent: String(body[indentEnd...]),
            lineEnding: lineEnding
        )
    }

    func shellCommentInfo() -> ShellCommentInfo {
        if hasPrefix("# ") {
            let dropped = String(dropFirst(2))
            return ShellCommentInfo(
                isCommented: true,
                contentAfterPrefix: dropped,
                removedPrefixUTF16Length: 2
            )
        }

        if hasPrefix("#") {
            let dropped = String(dropFirst())
            return ShellCommentInfo(
                isCommented: true,
                contentAfterPrefix: dropped,
                removedPrefixUTF16Length: 1
            )
        }

        return ShellCommentInfo(
            isCommented: false,
            contentAfterPrefix: self,
            removedPrefixUTF16Length: 0
        )
    }
}

private extension NSRange {
    func offsettingLocation(by delta: Int) -> NSRange {
        NSRange(location: location + delta, length: length)
    }
}

final class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?
    var highlightedLine: Int = 1

    private let lineNumberFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 42
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var requiredThickness: CGFloat {
        guard let text = textView?.string else { return 42 }
        let lineCount = max(1, text.components(separatedBy: "\n").count)
        let digits = max(2, String(lineCount).count)
        let sample = String(repeating: "9", count: digits) as NSString
        let width = sample.size(withAttributes: [.font: lineNumberFont]).width
        return width + 18
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        NSBezierPath(rect: bounds).setClip()
        backgroundColor.setFill()
        bounds.fill()
        drawLineNumbers()
    }

    func refresh() {
        ruleThickness = requiredThickness
        needsDisplay = true
    }

    private var backgroundColor: NSColor {
        let appearance = textView?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return EditorTheme.palette(isDarkMode: appearance == .darkAqua).gutterBackground
    }

    private func drawLineNumbers() {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        guard layoutManager.numberOfGlyphs > 0 else { return }

        let visibleRect = scrollView?.contentView.bounds ?? bounds
        let containerOrigin = textView.textContainerOrigin
        let fullText = textView.string as NSString
        let textLength = fullText.length

        layoutManager.ensureLayout(for: textContainer)

        var lineNumber = 1
        var characterIndex = 0
        var drewHighlightedLine = false

        while characterIndex <= textLength {
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: NSRange(location: characterIndex, length: 0),
                actualCharacterRange: nil
            )

            guard glyphRange.location < layoutManager.numberOfGlyphs || characterIndex == 0 else {
                break
            }

            let glyphIndex = min(glyphRange.location, max(layoutManager.numberOfGlyphs - 1, 0))
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            lineRect.origin.y += containerOrigin.y

            if lineRect.minY > visibleRect.maxY {
                break
            }

            if lineRect.maxY >= visibleRect.minY {
                let label = "\(lineNumber)" as NSString
                let isHighlightedLine = lineNumber == highlightedLine
                if isHighlightedLine {
                    drewHighlightedLine = true
                }
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: isHighlightedLine
                        ? NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
                        : lineNumberFont,
                    .foregroundColor: isHighlightedLine
                        ? highlightColor
                        : lineNumberColor
                ]
                let labelSize = label.size(withAttributes: attributes)
                let drawRect = NSRect(
                    x: bounds.width - labelSize.width - 8,
                    y: lineRect.minY - visibleRect.minY + (lineRect.height - labelSize.height) / 2,
                    width: labelSize.width,
                    height: labelSize.height
                )
                label.draw(in: drawRect, withAttributes: attributes)
            }

            if characterIndex >= textLength {
                break
            }

            let remainingRange = NSRange(location: characterIndex, length: textLength - characterIndex)
            let newLineRange = fullText.range(of: "\n", range: remainingRange)
            if newLineRange.location == NSNotFound {
                break
            }

            characterIndex = newLineRange.location + 1
            lineNumber += 1
        }

        // AppKit keeps a separate "extra line fragment" for the trailing empty line.
        // Without drawing it explicitly, the caret can sit on a line that appears to
        // have no line number.
        if !drewHighlightedLine,
           highlightedLine == lineNumber,
           layoutManager.extraLineFragmentTextContainer != nil {
            var extraRect = layoutManager.extraLineFragmentRect
            if extraRect != .zero {
                extraRect.origin.y += containerOrigin.y
                let label = "\(highlightedLine)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: highlightColor
                ]
                let labelSize = label.size(withAttributes: attributes)
                let drawRect = NSRect(
                    x: bounds.width - labelSize.width - 8,
                    y: extraRect.minY - visibleRect.minY + (extraRect.height - labelSize.height) / 2,
                    width: labelSize.width,
                    height: labelSize.height
                )
                label.draw(in: drawRect, withAttributes: attributes)
            }
        }
    }

    private var highlightColor: NSColor {
        let appearance = textView?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return EditorTheme.palette(isDarkMode: appearance == .darkAqua).gutterActiveLineNumber
    }

    private var lineNumberColor: NSColor {
        let appearance = textView?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return EditorTheme.palette(isDarkMode: appearance == .darkAqua).gutterLineNumber
    }
}

struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int

    let isDarkMode: Bool
    let fontSize: CGFloat
    let syntaxErrorLine: Int?
    let searchResults: [NSRange]
    let currentSearchIndex: Int
    let focusedRange: NSRange?
    let focusRevision: Int
    let onSaveCommand: () -> Void
    let onIncreaseFontSize: () -> Void
    let onDecreaseFontSize: () -> Void
    let onResetFontSize: () -> Void
    let onFindCommand: () -> Void

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        var highlighter: SyntaxHighlighter
        var isUpdatingFromSwiftUI = false
        var isComposingMarkedText = false
        var lastDecorationHash: Int?
        var lastFocusRevision = -1
        var lastDarkMode: Bool
        var lastFontSize: CGFloat

        init(parent: CodeEditorView) {
            self.parent = parent
            self.highlighter = SyntaxHighlighter(
                isDarkMode: parent.isDarkMode,
                fontSize: parent.fontSize
            )
            self.lastDarkMode = parent.isDarkMode
            self.lastFontSize = parent.fontSize
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingFromSwiftUI,
                  let textView = notification.object as? NSTextView else {
                return
            }

            if isComposing(in: textView) {
                isComposingMarkedText = true
                updateCursorPosition(for: textView)
                refreshLineNumbers(for: textView)
                return
            }

            isComposingMarkedText = false

            if parent.text != textView.string {
                parent.text = textView.string
            }

            applyHighlightingPreservingSelection(in: textView)
            refreshLineNumbers(for: textView)
            updateCursorPosition(for: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updateCursorPosition(for: textView)
        }

        func updateCursorPosition(for textView: NSTextView) {
            let selection = textView.selectedRange()
            let location = min(selection.location, (textView.string as NSString).length)
            let prefix = (textView.string as NSString).substring(to: location)
            let lines = prefix.components(separatedBy: "\n")
            let line = max(lines.count, 1)
            let column = (lines.last?.count ?? 0) + 1

            if let scrollView = textView.enclosingScrollView,
               let ruler = scrollView.verticalRulerView as? LineNumberRulerView,
               ruler.highlightedLine != line {
                ruler.highlightedLine = line
                ruler.refresh()
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.parent.cursorLine = line
                self.parent.cursorColumn = column
            }
        }

        func refreshLineNumbers(for textView: NSTextView) {
            if let scrollView = textView.enclosingScrollView,
               let ruler = scrollView.verticalRulerView as? LineNumberRulerView {
                ruler.refresh()
            }
        }

        func isComposing(in textView: NSTextView) -> Bool {
            textView.hasMarkedText() || isComposingMarkedText
        }

        func applyHighlightingPreservingSelection(in textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            let selectedRanges = textView.selectedRanges
            highlighter.isDarkMode = parent.isDarkMode
            highlighter.fontSize = parent.fontSize

            textStorage.beginEditing()
            highlighter.applyHighlighting(to: textStorage)
            textStorage.endEditing()

            textView.selectedRanges = selectedRanges
        }

        func render(text: String, into textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            let selectedRanges = textView.selectedRanges
            highlighter.isDarkMode = parent.isDarkMode
            highlighter.fontSize = parent.fontSize

            textStorage.beginEditing()
            textStorage.setAttributedString(highlighter.makeAttributedString(for: text))
            textStorage.endEditing()

            let length = textStorage.length
            textView.selectedRanges = selectedRanges.map { value in
                let range = value.rangeValue
                let location = min(range.location, length)
                let end = min(range.location + range.length, length)
                return NSValue(range: NSRange(location: location, length: end - location))
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = backgroundColor

        let textView = EditorTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        textView.delegate = context.coordinator
        textView.onSaveCommand = onSaveCommand
        textView.onFindCommand = onFindCommand
        textView.onIncreaseFontSize = onIncreaseFontSize
        textView.onDecreaseFontSize = onDecreaseFontSize
        textView.onResetFontSize = onResetFontSize
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.backgroundColor = backgroundColor
        textView.drawsBackground = true
        textView.insertionPointColor = foregroundColor
        textView.textContainerInset = NSSize(width: 16, height: 14)
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.importsGraphics = false

        scrollView.documentView = textView

        let ruler = LineNumberRulerView(scrollView: scrollView, textView: textView)
        ruler.highlightedLine = cursorLine
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        context.coordinator.render(text: text, into: textView)
        textView.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: foregroundColor
        ]

        context.coordinator.refreshLineNumbers(for: textView)
        context.coordinator.updateCursorPosition(for: textView)
        applyDecorations(to: textView, context: context)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorTextView else { return }
        context.coordinator.parent = self
        let isComposingMarkedText = context.coordinator.isComposing(in: textView)

        textView.onSaveCommand = onSaveCommand
        textView.onFindCommand = onFindCommand
        textView.onIncreaseFontSize = onIncreaseFontSize
        textView.onDecreaseFontSize = onDecreaseFontSize
        textView.onResetFontSize = onResetFontSize

        textView.backgroundColor = backgroundColor
        textView.insertionPointColor = foregroundColor
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: foregroundColor
        ]
        scrollView.backgroundColor = backgroundColor

        if isComposingMarkedText {
            context.coordinator.refreshLineNumbers(for: textView)
            context.coordinator.updateCursorPosition(for: textView)
            return
        }

        let contentChanged = !context.coordinator.isUpdatingFromSwiftUI && textView.string != text
        if contentChanged {
            context.coordinator.isUpdatingFromSwiftUI = true
            context.coordinator.render(text: text, into: textView)
            context.coordinator.isUpdatingFromSwiftUI = false
        }

        if context.coordinator.lastDarkMode != isDarkMode {
            context.coordinator.lastDarkMode = isDarkMode
            context.coordinator.render(text: textView.string, into: textView)
        }

        if context.coordinator.lastFontSize != fontSize {
            context.coordinator.lastFontSize = fontSize
            context.coordinator.render(text: textView.string, into: textView)
        }

        context.coordinator.refreshLineNumbers(for: textView)
        context.coordinator.updateCursorPosition(for: textView)
        applyDecorations(to: textView, context: context)

        if context.coordinator.lastFocusRevision != focusRevision, let focusedRange {
            context.coordinator.lastFocusRevision = focusRevision
            let length = (textView.string as NSString).length
            if NSMaxRange(focusedRange) <= length {
                textView.scrollRangeToVisible(focusedRange)
                textView.setSelectedRange(focusedRange)
            }
        }
    }

    private func applyDecorations(to textView: NSTextView, context: Context) {
        guard let textStorage = textView.textStorage else { return }
        let palette = EditorTheme.palette(isDarkMode: isDarkMode)

        var hasher = Hasher()
        hasher.combine(syntaxErrorLine)
        hasher.combine(currentSearchIndex)
        hasher.combine(searchResults.count)
        for range in searchResults {
            hasher.combine(range.location)
            hasher.combine(range.length)
        }
        let resultsHash = hasher.finalize()

        let needsRefresh = context.coordinator.lastDecorationHash != resultsHash

        guard needsRefresh else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)

        if let syntaxErrorLine,
           let syntaxErrorRange = (textStorage.string as NSString).lineRangeForLineNumber(syntaxErrorLine) {
            textStorage.addAttribute(
                .backgroundColor,
                value: syntaxErrorColor,
                range: syntaxErrorRange
            )
        }

        if !searchResults.isEmpty {
            textStorage.beginEditing()
            for (index, range) in searchResults.enumerated() where NSMaxRange(range) <= textStorage.length {
                let color = index == currentSearchIndex ? palette.currentSearchMatch : palette.searchMatch
                textStorage.addAttribute(.backgroundColor, value: color, range: range)
            }
            textStorage.endEditing()
        }

        context.coordinator.lastDecorationHash = resultsHash
    }

    private var backgroundColor: NSColor {
        EditorTheme.palette(isDarkMode: isDarkMode).editorBackground
    }

    private var foregroundColor: NSColor {
        EditorTheme.palette(isDarkMode: isDarkMode).textColor
    }

    private var syntaxErrorColor: NSColor {
        EditorTheme.palette(isDarkMode: isDarkMode).syntaxErrorLine
    }
}

private extension NSString {
    func lineRangeForLineNumber(_ lineNumber: Int) -> NSRange? {
        guard lineNumber > 0 else { return nil }

        if length == 0 {
            return lineNumber == 1 ? NSRange(location: 0, length: 0) : nil
        }

        var currentLine = 1
        var currentLocation = 0

        while currentLine < lineNumber {
            let searchRange = NSRange(location: currentLocation, length: length - currentLocation)
            let newlineRange = range(of: "\n", options: [], range: searchRange)

            guard newlineRange.location != NSNotFound else { return nil }

            currentLocation = newlineRange.location + 1
            currentLine += 1
        }

        return lineRange(for: NSRange(location: min(currentLocation, length), length: 0))
    }
}
