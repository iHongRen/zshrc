import Foundation

private final class WeakWatcherBox: @unchecked Sendable {
    weak var watcher: FileWatcher?

    init(_ watcher: FileWatcher) {
        self.watcher = watcher
    }
}

protocol FileWatcherProtocol: AnyObject {
    func watch(urls: [URL], onChange: @escaping @Sendable (URL) -> Void)
    func stopWatching()
}

final class FileWatcher: FileWatcherProtocol {
    private struct WatchEntry {
        let url: URL
        let source: DispatchSourceFileSystemObject
    }

    private var entries: [URL: WatchEntry] = [:]
    private var debounceTimers: [URL: DispatchWorkItem] = [:]
    private let watchQueue = DispatchQueue(label: "com.zshrceditor.filewatcher", qos: .utility)
    private let debounceDelay: TimeInterval = 0.35
    private var onChangeHandler: (@Sendable (URL) -> Void)?

    func watch(urls: [URL], onChange: @escaping @Sendable (URL) -> Void) {
        stopWatching()
        onChangeHandler = onChange

        for url in urls {
            startWatching(url: url, onChange: onChange)
        }
    }

    func stopWatching() {
        for (_, timer) in debounceTimers {
            timer.cancel()
        }
        debounceTimers.removeAll()

        for (_, entry) in entries {
            entry.source.cancel()
        }
        entries.removeAll()
        onChangeHandler = nil
    }

    deinit {
        stopWatching()
    }

    private func startWatching(url: URL, onChange: @escaping @Sendable (URL) -> Void) {
        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: watchQueue
        )

        source.setEventHandler { [weak self] in
            self?.handleEvent(for: url, onChange: onChange)
        }

        source.setCancelHandler {
            close(fileDescriptor)
        }

        source.resume()
        entries[url] = WatchEntry(url: url, source: source)
    }

    private func handleEvent(for url: URL, onChange: @escaping @Sendable (URL) -> Void) {
        let eventData = entries[url]?.source.data ?? []
        if eventData.contains(.rename) || eventData.contains(.delete) {
            rearmWatch(for: url, onChange: onChange)
        }
        scheduleDebounce(for: url, onChange: onChange)
    }

    private func scheduleDebounce(for url: URL, onChange: @escaping @Sendable (URL) -> Void) {
        debounceTimers[url]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.debounceTimers.removeValue(forKey: url)
            onChange(url)
        }

        debounceTimers[url] = workItem
        watchQueue.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
    }

    private func rearmWatch(for url: URL, onChange: @escaping @Sendable (URL) -> Void) {
        debounceTimers[url]?.cancel()
        debounceTimers.removeValue(forKey: url)

        if let entry = entries.removeValue(forKey: url) {
            entry.source.cancel()
        }

        let watcherBox = WeakWatcherBox(self)
        watchQueue.asyncAfter(deadline: .now() + debounceDelay) {
            guard let watcher = watcherBox.watcher else { return }
            watcher.startWatching(url: url, onChange: watcher.onChangeHandler ?? onChange)
        }
    }
}
