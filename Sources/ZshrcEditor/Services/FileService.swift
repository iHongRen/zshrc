import Foundation

protocol FileServiceProtocol: Sendable {
    func createIfNeeded(at url: URL) async throws
    func read(url: URL) async throws -> String
    func write(content: String, to url: URL) async throws
}

struct FileService: FileServiceProtocol, Sendable {
    func createIfNeeded(at url: URL) async throws {
        do {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: url.path) {
                let created = fileManager.createFile(atPath: url.path, contents: Data(), attributes: nil)
                if !created {
                    throw CocoaError(.fileWriteUnknown)
                }
            }
        } catch {
            throw AppError.fileWriteFailed(url, error.localizedDescription)
        }
    }

    func read(url: URL) async throws -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw AppError.fileReadFailed(url, error.localizedDescription)
        }
    }

    func write(content: String, to url: URL) async throws {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw AppError.fileWriteFailed(url, error.localizedDescription)
        }
    }
}
