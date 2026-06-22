import Combine
import Foundation

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var content: String = "" {
        didSet {
            guard content != oldValue else { return }
            handleContentChange()
        }
    }

    @Published var isModified = false
    @Published var isCaseSensitive = false
    @Published var searchQuery = ""
    @Published var searchResults: [NSRange] = []
    @Published var currentSearchIndex = 0
    @Published var focusedRange: NSRange?
    @Published var focusRevision = 0
    @Published var sourceResult: SourceResult?
    @Published var syntaxResult: SyntaxCheckResult?
    @Published var isCheckingSyntax = false
    @Published var lastError: AppError?
    @Published var isLoading = false
    @Published var lastSavedAt: Date?

    let targetURL: URL

    private let fileService: any FileServiceProtocol
    private let sourceRunner: any SourceRunnerProtocol
    private let syntaxChecker: any SyntaxCheckerProtocol
    private let fileWatcher: FileWatcherProtocol

    private enum SaveTrigger {
        case manual
    }

    private var lastSavedContent = ""
    private var isApplyingProgrammaticChange = false
    private var isSaving = false

    init(
        targetURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc"),
        fileService: FileServiceProtocol = FileService(),
        sourceRunner: SourceRunnerProtocol = SourceRunner(),
        syntaxChecker: SyntaxCheckerProtocol = SyntaxChecker(),
        fileWatcher: FileWatcherProtocol = FileWatcher()
    ) {
        self.targetURL = targetURL
        self.fileService = fileService
        self.sourceRunner = sourceRunner
        self.syntaxChecker = syntaxChecker
        self.fileWatcher = fileWatcher
    }

    func load() async {
        isCheckingSyntax = false
        isLoading = true
        defer { isLoading = false }

        do {
            try await fileService.createIfNeeded(at: targetURL)
            let loadedContent = try await fileService.read(url: targetURL)
            applyProgrammaticContent(loadedContent)
            lastSavedContent = loadedContent
            isModified = false
            lastSavedAt = Date()
            lastError = nil
            sourceResult = nil
            syntaxResult = nil
            startWatchingFileChanges()
        } catch let error as AppError {
            lastError = error
        } catch {
            lastError = .fileReadFailed(targetURL, error.localizedDescription)
        }
    }

    func save() async {
        await save(trigger: .manual)
    }

    func syncWithDiskIfNeeded() async {
        await reloadFromDiskIfNeeded(force: true)
    }

    func search(query: String, caseSensitive: Bool, shouldFocusFirstResult: Bool = true) {
        guard !query.isEmpty else {
            searchResults = []
            currentSearchIndex = 0
            return
        }

        let source = content as NSString
        var compareOptions: NSString.CompareOptions = [.literal]
        if !caseSensitive {
            compareOptions.insert(.caseInsensitive)
        }

        var results: [NSRange] = []
        var searchRange = NSRange(location: 0, length: source.length)

        while searchRange.location < source.length {
            let foundRange = source.range(of: query, options: compareOptions, range: searchRange)
            guard foundRange.location != NSNotFound else { break }
            results.append(foundRange)
            let nextLocation = foundRange.location + max(foundRange.length, 1)
            searchRange = NSRange(location: nextLocation, length: source.length - nextLocation)
        }

        searchResults = results
        currentSearchIndex = 0

        if shouldFocusFirstResult, let first = results.first {
            focus(on: first)
        }
    }

    func nextMatch() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
        focus(on: searchResults[currentSearchIndex])
    }

    func previousMatch() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
        focus(on: searchResults[currentSearchIndex])
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        currentSearchIndex = 0
    }

    private func handleContentChange() {
        guard !isApplyingProgrammaticChange else { return }

        isModified = content != lastSavedContent
        if isModified {
            sourceResult = nil
            syntaxResult = nil
        }

        if searchQuery.isEmpty {
            searchResults = []
            currentSearchIndex = 0
        } else {
            search(query: searchQuery, caseSensitive: isCaseSensitive, shouldFocusFirstResult: false)
        }
    }

    private func applyProgrammaticContent(_ newContent: String) {
        isApplyingProgrammaticChange = true
        content = newContent
        isApplyingProgrammaticChange = false
    }

    private func focus(on range: NSRange) {
        focusedRange = range
        focusRevision += 1
    }

    private func startWatchingFileChanges() {
        fileWatcher.watch(urls: [targetURL]) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.reloadFromDiskIfNeeded()
            }
        }
    }

    private func reloadFromDiskIfNeeded(force: Bool = false) async {
        guard force || !isModified else { return }

        do {
            let diskContent = try await fileService.read(url: targetURL)
            guard diskContent != content else { return }

            applyProgrammaticContent(diskContent)
            lastSavedContent = diskContent
            isModified = false
            lastSavedAt = Date()
            sourceResult = nil
            syntaxResult = nil
        } catch let error as AppError {
            lastError = error
        } catch {
            lastError = .fileReadFailed(targetURL, error.localizedDescription)
        }
    }

    private func save(
        trigger: SaveTrigger,
        precomputedSyntaxResult: SyntaxCheckResult? = nil,
        contentSnapshot: String? = nil
    ) async {
        guard !isSaving else { return }

        let snapshot = contentSnapshot ?? content
        let latestSyntaxResult: SyntaxCheckResult
        if let precomputedSyntaxResult {
            latestSyntaxResult = precomputedSyntaxResult
        } else {
            latestSyntaxResult = await refreshSyntaxStatus(for: snapshot, showProgress: true)
        }

        applySyntaxResult(latestSyntaxResult, trigger: trigger)

        guard latestSyntaxResult.isValid else {
            sourceResult = nil
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await fileService.write(content: snapshot, to: targetURL)
            lastSavedContent = snapshot
            isModified = content != lastSavedContent
            lastSavedAt = Date()
            lastError = nil

            let result = await sourceRunner.source(file: targetURL)
            sourceResult = result

            if !result.success {
                let message = result.errorOutput.isEmpty ? L10n.unknownZshError : result.errorOutput
                lastError = .sourceFailed(message)
            }
        } catch let error as AppError {
            lastError = error
        } catch {
            lastError = .fileWriteFailed(targetURL, error.localizedDescription)
        }
    }

    private func refreshSyntaxStatus(for content: String, showProgress: Bool) async -> SyntaxCheckResult {
        if showProgress {
            isCheckingSyntax = true
        }

        let result = await syntaxChecker.check(content: content, displayPath: displayPath)

        if showProgress {
            isCheckingSyntax = false
        }

        return result
    }

    private func applySyntaxResult(_ result: SyntaxCheckResult, trigger: SaveTrigger) {
        let previousResult = syntaxResult
        syntaxResult = result

        guard !result.isValid, let line = result.line else { return }

        let shouldFocus = trigger == .manual || previousResult?.line != line

        if shouldFocus {
            focus(onLine: line)
        }
    }

    private func focus(onLine lineNumber: Int) {
        guard let location = lineStartLocation(for: lineNumber, in: content as NSString) else { return }
        focus(on: NSRange(location: location, length: 0))
    }

    private func lineStartLocation(for lineNumber: Int, in text: NSString) -> Int? {
        guard lineNumber > 0 else { return nil }
        guard text.length > 0 else { return lineNumber == 1 ? 0 : nil }

        var currentLine = 1
        var currentLocation = 0

        while currentLine < lineNumber {
            let searchRange = NSRange(location: currentLocation, length: text.length - currentLocation)
            let newlineRange = text.range(of: "\n", options: [], range: searchRange)

            guard newlineRange.location != NSNotFound else { return nil }

            currentLocation = newlineRange.location + 1
            currentLine += 1
        }

        return min(currentLocation, text.length)
    }

    private var displayPath: String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        guard targetURL.path.hasPrefix(homePath) else { return targetURL.path }
        return targetURL.path.replacingOccurrences(of: homePath, with: "~")
    }
}
