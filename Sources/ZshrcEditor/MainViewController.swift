import AppKit
import Combine

@MainActor
final class MainViewController: NSViewController {
    static let defaultContentSize = NSSize(width: 1280, height: 840)
    static let minimumContentSize = NSSize(width: 900, height: 560)

    private let viewModel: EditorViewModel
    private let editorSettings: AppEditorSettings
    private let commandCoordinator: EditorCommandCoordinator

    private var cancellables: Set<AnyCancellable> = []
    private var currentThemeMode: AppThemeMode {
        didSet { applyTheme() }
    }
    private var currentLanguageRawValue: String {
        didSet { handleLanguageChange() }
    }
    private var cursorLine = 1
    private var cursorColumn = 1
    private var isSearchBarVisible = false
    private var hasShownInitialWindow = false

    private let containerView = NSView()
    private let searchBarView = SearchBarContainerView()
    private let editorView = CodeEditorView()
    private let statusBarView = StatusBarContainerView()
    private var searchBarHeightConstraint: NSLayoutConstraint?

    init(
        viewModel: EditorViewModel,
        editorSettings: AppEditorSettings,
        commandCoordinator: EditorCommandCoordinator
    ) {
        self.viewModel = viewModel
        self.editorSettings = editorSettings
        self.commandCoordinator = commandCoordinator
        self.currentThemeMode = AppThemeMode(
            rawValue: UserDefaults.standard.string(forKey: AppThemeMode.storageKey) ?? AppThemeMode.system.rawValue
        ) ?? .system
        self.currentLanguageRawValue = UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.system.rawValue
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        containerView.frame = NSRect(origin: .zero, size: Self.defaultContentSize)
        view = containerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        setupActions()
        bindState()
        applyTheme()
        preferredContentSize = Self.defaultContentSize
        refreshAll()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        syncWindowAppearance()
        refreshAll()
    }

    private func setupLayout() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        view.setFrameSize(Self.defaultContentSize)

        searchBarView.translatesAutoresizingMaskIntoConstraints = false
        editorView.translatesAutoresizingMaskIntoConstraints = false
        statusBarView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(searchBarView)
        containerView.addSubview(editorView)
        containerView.addSubview(statusBarView)

        NSLayoutConstraint.activate([
            searchBarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            searchBarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            searchBarView.topAnchor.constraint(equalTo: containerView.topAnchor),

            editorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            editorView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            editorView.topAnchor.constraint(equalTo: searchBarView.bottomAnchor),
            editorView.bottomAnchor.constraint(equalTo: statusBarView.topAnchor),

            statusBarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            statusBarView.heightAnchor.constraint(equalToConstant: 32)
        ])

        let searchBarHeightConstraint = searchBarView.heightAnchor.constraint(equalToConstant: 0)
        searchBarHeightConstraint.isActive = true
        self.searchBarHeightConstraint = searchBarHeightConstraint

        view.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumContentSize.width).isActive = true
        view.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumContentSize.height).isActive = true
    }

    private func setupActions() {
        searchBarView.onQueryChange = { [weak self] query in
            guard let self else { return }
            self.viewModel.searchQuery = query
            self.viewModel.search(query: query, caseSensitive: self.viewModel.isCaseSensitive)
        }
        searchBarView.onNext = { [weak self] in self?.viewModel.nextMatch() }
        searchBarView.onPrevious = { [weak self] in self?.viewModel.previousMatch() }
        searchBarView.onToggleCaseSensitive = { [weak self] in
            guard let self else { return }
            self.viewModel.isCaseSensitive.toggle()
            self.viewModel.search(
                query: self.viewModel.searchQuery,
                caseSensitive: self.viewModel.isCaseSensitive
            )
        }
        searchBarView.onClose = { [weak self] in self?.hideSearchBar() }
        searchBarView.onClear = { [weak self] in
            guard let self else { return }
            self.viewModel.searchQuery = ""
            self.viewModel.search(query: "", caseSensitive: self.viewModel.isCaseSensitive)
        }

        editorView.onTextChange = { [weak self] newText in
            self?.viewModel.content = newText
        }
        editorView.onCursorChange = { [weak self] line, column in
            guard let self else { return }
            self.cursorLine = line
            self.cursorColumn = column
            self.updateStatusBar()
        }
        editorView.onSaveCommand = { [weak self] in
            guard let self else { return }
            Task { await self.viewModel.save() }
        }
        editorView.onFindCommand = { [weak self] in self?.showSearchBar() }
        editorView.onCancelSearchCommand = { [weak self] in
            guard let self, self.isSearchBarVisible else { return false }
            self.hideSearchBar()
            return true
        }
        editorView.onIncreaseFontSize = { [weak self] in self?.editorSettings.increaseFontSize() }
        editorView.onDecreaseFontSize = { [weak self] in self?.editorSettings.decreaseFontSize() }
        editorView.onResetFontSize = { [weak self] in self?.editorSettings.resetFontSize() }

        commandCoordinator.onSave = { [weak self] in
            guard let self else { return }
            await self.viewModel.save()
        }
        commandCoordinator.onFind = { [weak self] in self?.showSearchBar() }
        commandCoordinator.onRevealInFinder = { [targetURL = viewModel.targetURL] in
            AppOpenActions.revealInFinder(targetURL)
        }

        AppMenuActionHandler.shared.onThemeChange = { [weak self] newValue in
            self?.currentThemeMode = AppThemeMode(rawValue: newValue) ?? .system
        }
        AppMenuActionHandler.shared.onLanguageChange = { [weak self] newValue in
            self?.currentLanguageRawValue = newValue
        }
        AppMenuActionHandler.shared.onSave = { [weak self] in
            self?.commandCoordinator.save()
        }
        AppMenuActionHandler.shared.onRevealInFinder = { [weak self] in
            self?.commandCoordinator.revealInFinder()
        }
        AppMenuActionHandler.shared.onFind = { [weak self] in
            self?.commandCoordinator.find()
        }
    }

    private func bindState() {
        viewModel.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async {
                    self?.refreshAll()
                }
            }
            .store(in: &cancellables)

        editorSettings.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async {
                    self?.editorView.fontSize = self?.editorSettings.fontSize ?? AppEditorSettings.defaultFontSize
                }
            }
            .store(in: &cancellables)
    }

    private func refreshAll() {
        if !hasShownInitialWindow {
            hasShownInitialWindow = true
            view.window?.title = viewModel.targetURL.lastPathComponent
        }

        let isDarkMode = resolvedIsDarkMode
        editorView.isDarkMode = isDarkMode
        editorView.fontSize = editorSettings.fontSize
        editorView.text = viewModel.content
        editorView.syntaxErrorLine = syntaxErrorLine
        editorView.searchResults = viewModel.searchResults
        editorView.currentSearchIndex = viewModel.currentSearchIndex
        editorView.focusedRange = viewModel.focusedRange
        editorView.focusRevision = viewModel.focusRevision

        searchBarView.apply(
            query: viewModel.searchQuery,
            isVisible: isSearchBarVisible,
            isDarkMode: isDarkMode,
            isCaseSensitive: viewModel.isCaseSensitive,
            resultsCount: viewModel.searchResults.count,
            currentIndex: viewModel.currentSearchIndex
        )
        updateStatusBar()
        presentAlertsIfNeeded()
    }

    private func updateStatusBar() {
        let palette = EditorTheme.palette(isDarkMode: resolvedIsDarkMode)
        statusBarView.apply(
            isDarkMode: resolvedIsDarkMode,
            lastSavedAt: viewModel.lastSavedAt,
            items: statusItems(palette: palette)
        )
    }

    private func statusItems(palette: EditorThemePalette) -> [StatusBarContainerView.Item] {
        var items: [StatusBarContainerView.Item] = []
        items.append(
            .init(
                text: viewModel.isModified ? L10n.unsavedChanges : L10n.saved,
                color: viewModel.isModified ? palette.dangerColor : palette.secondaryTextColor,
                toolTip: nil
            )
        )
        items.append(.init(text: L10n.lineColumn(cursorLine, cursorColumn), color: palette.secondaryTextColor, toolTip: nil))
        items.append(.init(text: "UTF-8", color: palette.secondaryTextColor, toolTip: nil))
        items.append(.init(text: "LF", color: palette.secondaryTextColor, toolTip: nil))

        if let syntaxResult = viewModel.syntaxResult, !syntaxResult.isValid {
            items.append(.init(text: syntaxResult.statusLabel, color: palette.dangerColor, toolTip: syntaxResult.message))
            items.append(.init(text: syntaxResult.reasonLabel, color: palette.dangerColor, toolTip: syntaxResult.message))
        }

        if let result = viewModel.sourceResult {
            let text = result.success ? L10n.sourceSucceeded : L10n.sourceFailed
            let color = result.success ? palette.successColor : palette.dangerColor
            let toolTip = result.success ? result.output : result.errorOutput
            items.append(.init(text: text, color: color, toolTip: toolTip))
        }

        if !viewModel.searchQuery.isEmpty {
            let label = viewModel.searchResults.isEmpty
                ? L10n.noMatches
                : L10n.matchesCount(current: viewModel.currentSearchIndex + 1, total: viewModel.searchResults.count)
            items.append(.init(text: label, color: palette.secondaryTextColor, toolTip: nil))
        }

        return items
    }

    private func presentAlertsIfNeeded() {
        if let error = viewModel.lastError {
            let alert = NSAlert()
            alert.messageText = L10n.somethingWentWrong
            alert.informativeText = error.errorDescription ?? ""
            alert.addButton(withTitle: L10n.ok)
            alert.beginSheetModal(for: view.window ?? NSWindow()) { [weak self] _ in
                self?.viewModel.lastError = nil
            }
        }
    }

    private func showSearchBar() {
        isSearchBarVisible = true
        searchBarHeightConstraint?.constant = 42
        searchBarView.apply(
            query: viewModel.searchQuery,
            isVisible: true,
            isDarkMode: resolvedIsDarkMode,
            isCaseSensitive: viewModel.isCaseSensitive,
            resultsCount: viewModel.searchResults.count,
            currentIndex: viewModel.currentSearchIndex
        )
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            view.layoutSubtreeIfNeeded()
        }
        searchBarView.focusSearchField()
    }

    private func hideSearchBar() {
        viewModel.clearSearch()
        isSearchBarVisible = false
        searchBarHeightConstraint?.constant = 0
        searchBarView.apply(
            query: viewModel.searchQuery,
            isVisible: false,
            isDarkMode: resolvedIsDarkMode,
            isCaseSensitive: viewModel.isCaseSensitive,
            resultsCount: viewModel.searchResults.count,
            currentIndex: viewModel.currentSearchIndex
        )
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            view.layoutSubtreeIfNeeded()
        }
    }

    private func handleLanguageChange() {
        MenuBarController.installMenu()
        refreshAll()
    }

    private func applyTheme() {
        syncWindowAppearance()
        MenuBarController.installMenu()
        refreshAll()
    }

    private func syncWindowAppearance() {
        view.window?.appearance = currentThemeMode.appearance
    }

    private var resolvedIsDarkMode: Bool {
        switch currentThemeMode {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            let appearance = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            return appearance == .darkAqua
        }
    }

    private var syntaxErrorLine: Int? {
        guard let syntaxResult = viewModel.syntaxResult, !syntaxResult.isValid else { return nil }
        return syntaxResult.line
    }
}

@MainActor
private final class SearchBarContainerView: NSView, NSTextFieldDelegate {
    var onQueryChange: ((String) -> Void)?
    var onToggleCaseSensitive: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onClose: (() -> Void)?
    var onClear: (() -> Void)?

    private let iconView = NSImageView()
    private let searchField = NSTextField()
    private let resultLabel = NSTextField(labelWithString: "")
    private let clearButton = NSButton()
    private let caseButton = NSButton(title: "Aa", target: nil, action: nil)
    private let previousButton = NSButton()
    private let nextButton = NSButton()
    private let closeButton = NSButton()
    private let fieldContainer = NSView()
    private let caseButtonTitle = "Aa"

    private var currentPalette = EditorTheme.palette(isDarkMode: false)
    private var isApplyingState = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(
        query: String,
        isVisible: Bool,
        isDarkMode: Bool,
        isCaseSensitive: Bool,
        resultsCount: Int,
        currentIndex: Int
    ) {
        isHidden = !isVisible
        currentPalette = EditorTheme.palette(isDarkMode: isDarkMode)
        layer?.backgroundColor = currentPalette.searchBarBackground.cgColor
        fieldContainer.layer?.backgroundColor = currentPalette.searchFieldBackground.cgColor
        fieldContainer.layer?.borderColor = currentPalette.searchFieldBorder.cgColor

        isApplyingState = true
        if searchField.stringValue != query {
            searchField.stringValue = query
        }
        isApplyingState = false

        let hasNoMatch = !query.isEmpty && resultsCount == 0
        if query.isEmpty {
            resultLabel.stringValue = ""
        } else if hasNoMatch {
            resultLabel.stringValue = L10n.noResults
        } else {
            resultLabel.stringValue = "\(currentIndex + 1)/\(resultsCount)"
        }

        resultLabel.textColor = hasNoMatch ? currentPalette.dangerColor : currentPalette.secondaryTextColor
        clearButton.isHidden = query.isEmpty
        previousButton.isEnabled = resultsCount > 0
        nextButton.isEnabled = resultsCount > 0
        caseButton.state = isCaseSensitive ? .on : .off
        caseButton.contentTintColor = isCaseSensitive ? currentPalette.accentColor : currentPalette.secondaryTextColor
        caseButton.bezelColor = isCaseSensitive ? currentPalette.accentMutedBackground : .clear
        caseButton.attributedTitle = NSAttributedString(
            string: caseButtonTitle,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: isCaseSensitive ? currentPalette.accentColor : currentPalette.secondaryTextColor
            ]
        )
        iconView.contentTintColor = currentPalette.secondaryTextColor
        searchField.textColor = currentPalette.textColor
        searchField.backgroundColor = currentPalette.searchFieldBackground
    }

    func focusSearchField() {
        window?.makeFirstResponder(searchField)
    }

    private func setupView() {
        fieldContainer.translatesAutoresizingMaskIntoConstraints = false
        fieldContainer.wantsLayer = true
        fieldContainer.layer?.cornerRadius = 6
        fieldContainer.layer?.borderWidth = 1
        addSubview(fieldContainer)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        caseButton.translatesAutoresizingMaskIntoConstraints = false
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        iconView.image = NSImage(
            systemSymbolName: "magnifyingglass",
            accessibilityDescription: L10n.searchPlaceholder
        )
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        resultLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        resultLabel.alignment = .right

        searchField.font = .systemFont(ofSize: 13)
        searchField.placeholderString = L10n.searchPlaceholder
        searchField.isBordered = false
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(submitSearch)

        configureSymbolButton(
            clearButton,
            systemName: "xmark.circle.fill",
            pointSize: 12,
            accessibilityDescription: L10n.delete,
            action: #selector(clearSearch)
        )

        caseButton.setButtonType(.toggle)
        caseButton.bezelStyle = .inline
        caseButton.isBordered = true
        caseButton.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        caseButton.target = self
        caseButton.action = #selector(toggleCaseSensitive)

        configureSymbolButton(
            previousButton,
            systemName: "chevron.up",
            pointSize: 11,
            accessibilityDescription: L10n.find,
            action: #selector(previousMatch)
        )

        configureSymbolButton(
            nextButton,
            systemName: "chevron.down",
            pointSize: 11,
            accessibilityDescription: L10n.find,
            action: #selector(nextMatch)
        )

        configureSymbolButton(
            closeButton,
            systemName: "xmark",
            pointSize: 11,
            accessibilityDescription: L10n.cancel,
            action: #selector(closeSearch)
        )

        fieldContainer.addSubview(iconView)
        fieldContainer.addSubview(searchField)
        fieldContainer.addSubview(resultLabel)
        fieldContainer.addSubview(clearButton)
        addSubview(caseButton)
        addSubview(previousButton)
        addSubview(nextButton)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            fieldContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            fieldContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            fieldContainer.widthAnchor.constraint(equalToConstant: 320),
            fieldContainer.heightAnchor.constraint(equalToConstant: 28),

            iconView.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            searchField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            searchField.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            searchField.trailingAnchor.constraint(equalTo: resultLabel.leadingAnchor, constant: -8),

            resultLabel.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            resultLabel.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -4),
            resultLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 52),

            clearButton.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor, constant: -4),
            clearButton.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 24),
            clearButton.heightAnchor.constraint(equalToConstant: 24),

            caseButton.leadingAnchor.constraint(equalTo: fieldContainer.trailingAnchor, constant: 12),
            caseButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            caseButton.widthAnchor.constraint(equalToConstant: 32),
            caseButton.heightAnchor.constraint(equalToConstant: 24),

            previousButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -4),
            previousButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 28),
            previousButton.heightAnchor.constraint(equalToConstant: 24),

            nextButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 28),
            nextButton.heightAnchor.constraint(equalToConstant: 24),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 28)
            ,
            closeButton.heightAnchor.constraint(equalToConstant: 24)
        ])

        fieldContainer.layer?.backgroundColor = currentPalette.searchFieldBackground.cgColor
        fieldContainer.layer?.borderColor = currentPalette.searchFieldBorder.cgColor
    }

    private func configureSymbolButton(
        _ button: NSButton,
        systemName: String,
        pointSize: CGFloat,
        accessibilityDescription: String,
        action: Selector
    ) {
        button.image = NSImage(
            systemSymbolName: systemName,
            accessibilityDescription: accessibilityDescription
        )
        button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        button.isBordered = false
        button.bezelStyle = .inline
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onClose?()
            return
        }
        super.keyDown(with: event)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard !isApplyingState else { return }
        onQueryChange?(searchField.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onClose?()
            return true
        }
        return false
    }

    @objc private func submitSearch() {
        onNext?()
    }

    @objc private func clearSearch() {
        onClear?()
    }

    @objc private func toggleCaseSensitive() {
        onToggleCaseSensitive?()
    }

    @objc private func previousMatch() {
        onPrevious?()
    }

    @objc private func nextMatch() {
        onNext?()
    }

    @objc private func closeSearch() {
        onClose?()
    }
}

@MainActor
private final class StatusBarContainerView: NSView {
    struct Item {
        let text: String
        let color: NSColor
        let toolTip: String?
    }

    private let stackView = NSStackView()
    private let spacer = NSView()
    private let savedAtLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(isDarkMode: Bool, lastSavedAt: Date?, items: [Item]) {
        let palette = EditorTheme.palette(isDarkMode: isDarkMode)
        layer?.backgroundColor = palette.chromeBackground.cgColor
        layer?.borderColor = palette.divider.cgColor
        layer?.borderWidth = 1

        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for item in items {
            let label = NSTextField(labelWithString: item.text)
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = item.color
            label.toolTip = item.toolTip
            stackView.addArrangedSubview(label)
        }

        stackView.addArrangedSubview(spacer)

        if let lastSavedAt {
            savedAtLabel.stringValue = lastSavedAt.formatted(date: .omitted, time: .shortened)
            savedAtLabel.isHidden = false
            savedAtLabel.textColor = palette.secondaryTextColor
        } else {
            savedAtLabel.isHidden = true
        }
    }

    private func setupView() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 14

        spacer.translatesAutoresizingMaskIntoConstraints = false
        savedAtLabel.translatesAutoresizingMaskIntoConstraints = false
        savedAtLabel.font = .systemFont(ofSize: 12, weight: .medium)

        addSubview(stackView)
        addSubview(savedAtLabel)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: savedAtLabel.leadingAnchor, constant: -14),

            savedAtLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            savedAtLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
