import AppKit

final class EditorTextView: NSTextView {
    var onSaveCommand: (() -> Void)?
    var onFindCommand: (() -> Void)?
    var onIncreaseFontSize: (() -> Void)?
    var onDecreaseFontSize: (() -> Void)?
    var onResetFontSize: (() -> Void)?
    var onCancelSearchCommand: (() -> Bool)?
    private var hasAutoFocused = false
    private var isHoveringLink = false

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

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
           let url = linkURL(at: event.locationInWindow) {
            AppOpenActions.openInBrowser(url)
            return
        }

        super.mouseDown(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(visibleRect, cursor: .iBeam)
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursorForMouseLocation(event.locationInWindow)
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        isHoveringLink = false
        NSCursor.iBeam.set()
        super.mouseExited(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        editingContextMenu()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53,
           !hasMarkedText(),
           onCancelSearchCommand?() == true {
            return
        }

        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        if !hasMarkedText(),
           onCancelSearchCommand?() == true {
            return
        }

        super.cancelOperation(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let characters = event.charactersIgnoringModifiers?.lowercased()

        if flags == [.command], characters == "z" {
            undoManager?.undo()
            return true
        }

        if flags == [.command, .shift], characters == "z" {
            undoManager?.redo()
            return true
        }

        if flags == [.command], characters == "x" {
            return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
        }

        if flags == [.command], characters == "c" {
            return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
        }

        if flags == [.command], characters == "v" {
            return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
        }

        if flags == [.command], characters == "s" {
            onSaveCommand?()
            return true
        }

        if flags == [.command], characters == "f" {
            onFindCommand?()
            return true
        }

        if flags == [.command], event.charactersIgnoringModifiers == "=" || event.characters == "+" {
            onIncreaseFontSize?()
            return true
        }

        if flags == [.command], event.charactersIgnoringModifiers == "-" {
            onDecreaseFontSize?()
            return true
        }

        if flags == [.command], event.charactersIgnoringModifiers == "0" {
            onResetFontSize?()
            return true
        }

        if flags == [.command], event.charactersIgnoringModifiers == "/" {
            toggleLineComments()
            return true
        }

        return super.performKeyEquivalent(with: event)
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

    private func linkURL(at windowPoint: NSPoint) -> URL? {
        guard let textStorage,
              let layoutManager,
              let textContainer else {
            return nil
        }

        let localPoint = convert(windowPoint, from: nil)
        let containerPoint = NSPoint(
            x: localPoint.x - textContainerInset.width,
            y: localPoint.y - textContainerInset.height
        )

        guard bounds.contains(localPoint) else { return nil }

        let glyphIndex = layoutManager.glyphIndex(
            for: containerPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: nil
        )

        guard glyphIndex < layoutManager.numberOfGlyphs else { return nil }

        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard characterIndex < textStorage.length else { return nil }

        var effectiveRange = NSRange(location: 0, length: 0)
        let attributes = textStorage.attributes(at: characterIndex, effectiveRange: &effectiveRange)
        guard let url = attributes[.link] as? URL else { return nil }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: effectiveRange, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        guard boundingRect.contains(containerPoint) else { return nil }
        return url
    }

    private func updateCursorForMouseLocation(_ windowPoint: NSPoint) {
        let hoveringLink = linkURL(at: windowPoint) != nil
        guard hoveringLink != isHoveringLink else { return }

        isHoveringLink = hoveringLink
        if hoveringLink {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.iBeam.set()
        }
    }
}

final class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?
    var highlightedLine: Int = 1
    var isDarkMode = false {
        didSet {
            guard oldValue != isDarkMode else { return }
            needsDisplay = true
        }
    }

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
        EditorTheme.palette(isDarkMode: isDarkMode).gutterBackground
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
                    .foregroundColor: isHighlightedLine ? highlightColor : lineNumberColor
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
        EditorTheme.palette(isDarkMode: isDarkMode).gutterActiveLineNumber
    }

    private var lineNumberColor: NSColor {
        EditorTheme.palette(isDarkMode: isDarkMode).gutterLineNumber
    }
}

@MainActor
final class CodeEditorView: NSView {
    var onTextChange: ((String) -> Void)?
    var onCursorChange: ((Int, Int) -> Void)?
    var onSaveCommand: (() -> Void)? {
        didSet { textView.onSaveCommand = onSaveCommand }
    }
    var onIncreaseFontSize: (() -> Void)? {
        didSet { textView.onIncreaseFontSize = onIncreaseFontSize }
    }
    var onDecreaseFontSize: (() -> Void)? {
        didSet { textView.onDecreaseFontSize = onDecreaseFontSize }
    }
    var onResetFontSize: (() -> Void)? {
        didSet { textView.onResetFontSize = onResetFontSize }
    }
    var onFindCommand: (() -> Void)? {
        didSet { textView.onFindCommand = onFindCommand }
    }
    var onCancelSearchCommand: (() -> Bool)? {
        didSet { textView.onCancelSearchCommand = onCancelSearchCommand }
    }

    var text: String = "" {
        didSet { updateTextIfNeeded() }
    }

    var isDarkMode: Bool = false {
        didSet { applyAppearanceChanges(forceRender: oldValue != isDarkMode) }
    }

    var fontSize: CGFloat = AppEditorSettings.defaultFontSize {
        didSet { applyAppearanceChanges(forceRender: oldValue != fontSize) }
    }

    var syntaxErrorLine: Int? {
        didSet { applyDecorationsIfNeeded() }
    }

    var searchResults: [NSRange] = [] {
        didSet { applyDecorationsIfNeeded() }
    }

    var currentSearchIndex: Int = 0 {
        didSet { applyDecorationsIfNeeded() }
    }

    var focusedRange: NSRange? {
        didSet { applyFocusIfNeeded() }
    }

    var focusRevision: Int = 0 {
        didSet { applyFocusIfNeeded() }
    }

    private let scrollView = NSScrollView()
    private let textView = EditorTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
    private lazy var rulerView = LineNumberRulerView(scrollView: scrollView, textView: textView)
    private var highlighter = SyntaxHighlighter(isDarkMode: false, fontSize: AppEditorSettings.defaultFontSize)
    private var isUpdatingProgrammatically = false
    private var isComposingMarkedText = false
    private var lastDecorationHash: Int?
    private var lastFocusRevision = -1

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        textView.delegate = self
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 16, height: 8)
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
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: textView,
            userInfo: nil
        )
        textView.addTrackingArea(trackingArea)

        scrollView.documentView = textView
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        applyAppearanceChanges(forceRender: true)
        render(text: text)
        refreshLineNumbers()
        updateCursorPosition()
    }

    private func updateTextIfNeeded() {
        guard !isUpdatingProgrammatically, textView.string != text else { return }
        render(text: text)
        refreshLineNumbers()
        updateCursorPosition()
        applyDecorationsIfNeeded(force: true)
    }

    private func applyAppearanceChanges(forceRender: Bool) {
        highlighter.isDarkMode = isDarkMode
        highlighter.fontSize = fontSize

        let palette = EditorTheme.palette(isDarkMode: isDarkMode)
        rulerView.isDarkMode = isDarkMode
        textView.backgroundColor = palette.editorBackground
        textView.drawsBackground = true
        textView.insertionPointColor = palette.textColor
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: palette.textColor
        ]
        scrollView.backgroundColor = palette.editorBackground
        scrollView.contentView.backgroundColor = palette.editorBackground

        if forceRender {
            render(text: textView.string)
        }

        refreshLineNumbers()
        applyDecorationsIfNeeded(force: true)
    }

    private func render(text: String) {
        guard let textStorage = textView.textStorage else { return }

        let selectedRanges = textView.selectedRanges
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

    private func refreshLineNumbers() {
        rulerView.refresh()
    }

    private func updateCursorPosition() {
        let selection = textView.selectedRange()
        let location = min(selection.location, (textView.string as NSString).length)
        let prefix = (textView.string as NSString).substring(to: location)
        let lines = prefix.components(separatedBy: "\n")
        let line = max(lines.count, 1)
        let column = (lines.last?.count ?? 0) + 1

        if rulerView.highlightedLine != line {
            rulerView.highlightedLine = line
            rulerView.refresh()
        }

        onCursorChange?(line, column)
    }

    private func applyFocusIfNeeded() {
        guard lastFocusRevision != focusRevision, let focusedRange else { return }
        lastFocusRevision = focusRevision

        let length = (textView.string as NSString).length
        guard NSMaxRange(focusedRange) <= length else { return }
        textView.scrollRangeToVisible(focusedRange)
        textView.setSelectedRange(focusedRange)
        updateCursorPosition()
    }

    private func applyDecorationsIfNeeded(force: Bool = false) {
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
        let hash = hasher.finalize()

        guard force || lastDecorationHash != hash else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)

        if let syntaxErrorLine,
           let syntaxErrorRange = (textStorage.string as NSString).lineRangeForLineNumber(syntaxErrorLine) {
            textStorage.addAttribute(
                .backgroundColor,
                value: palette.syntaxErrorLine,
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

        lastDecorationHash = hash
    }
}

extension CodeEditorView: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard !isUpdatingProgrammatically,
              let changedTextView = notification.object as? NSTextView else { return }

        if changedTextView.hasMarkedText() || isComposingMarkedText {
            isComposingMarkedText = true
            updateCursorPosition()
            refreshLineNumbers()
            return
        }

        isComposingMarkedText = false
        let latestText = changedTextView.string
        if text != latestText {
            text = latestText
            onTextChange?(latestText)
        }

        let selectedRanges = changedTextView.selectedRanges
        guard let textStorage = changedTextView.textStorage else { return }
        highlighter.isDarkMode = isDarkMode
        highlighter.fontSize = fontSize

        textStorage.beginEditing()
        highlighter.applyHighlighting(to: textStorage)
        textStorage.endEditing()
        changedTextView.selectedRanges = selectedRanges

        refreshLineNumbers()
        updateCursorPosition()
        applyDecorationsIfNeeded(force: true)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateCursorPosition()
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
            return CommentToggleResult(replacement: "", selectedRange: NSRange(location: 0, length: 0))
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
            return ShellCommentInfo(isCommented: true, contentAfterPrefix: String(dropFirst(2)), removedPrefixUTF16Length: 2)
        }

        if hasPrefix("#") {
            return ShellCommentInfo(isCommented: true, contentAfterPrefix: String(dropFirst()), removedPrefixUTF16Length: 1)
        }

        return ShellCommentInfo(isCommented: false, contentAfterPrefix: self, removedPrefixUTF16Length: 0)
    }
}

private extension NSRange {
    func offsettingLocation(by delta: Int) -> NSRange {
        NSRange(location: location + delta, length: length)
    }
}
