import AppKit
import Foundation

@MainActor
enum AppOpenActions {
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func openInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
