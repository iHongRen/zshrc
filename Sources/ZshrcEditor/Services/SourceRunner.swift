import Foundation

protocol SourceRunnerProtocol: Sendable {
    func source(file: URL) async -> SourceResult
}

struct SourceRunner: SourceRunnerProtocol, Sendable {
    func source(file: URL) async -> SourceResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [
                "-c",
                "source \(file.path.shellEscaped)"
            ]
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { terminatedProcess in
                let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                continuation.resume(
                    returning: SourceResult(
                        success: terminatedProcess.terminationStatus == 0,
                        output: String(data: stdout, encoding: .utf8) ?? "",
                        errorOutput: String(data: stderr, encoding: .utf8) ?? ""
                    )
                )
            }

            do {
                try process.run()
            } catch {
                continuation.resume(
                    returning: SourceResult(
                        success: false,
                        output: "",
                        errorOutput: error.localizedDescription
                    )
                )
            }
        }
    }
}

private extension String {
    var shellEscaped: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
