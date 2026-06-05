import Foundation

enum AppError: LocalizedError, Equatable {
    case fileReadFailed(URL, String)
    case fileWriteFailed(URL, String)
    case syntaxInvalid(String)
    case sourceFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileReadFailed(let url, let message):
            L10n.unableToRead(url.lastPathComponent, message)
        case .fileWriteFailed(let url, let message):
            L10n.unableToSave(url.lastPathComponent, message)
        case .syntaxInvalid(let message):
            L10n.fixSyntaxErrorsBeforeSaving(message)
        case .sourceFailed(let message):
            L10n.savedButSourceFailed(message)
        }
    }
}
