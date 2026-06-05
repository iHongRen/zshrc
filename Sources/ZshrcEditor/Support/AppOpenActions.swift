import AppKit
import Foundation

@MainActor
enum AppOpenActions {
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
