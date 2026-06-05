import Foundation

protocol SyntaxCheckerProtocol: Sendable {
    func check(content: String, displayPath: String) async -> SyntaxCheckResult
}

struct SyntaxChecker: SyntaxCheckerProtocol, Sendable {
    func check(content: String, displayPath: String) async -> SyntaxCheckResult {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zshrceditor-syntax-\(UUID().uuidString)")
            .appendingPathExtension("zsh")

        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            return SyntaxCheckResult(
                isValid: false,
                message: error.localizedDescription,
                line: nil
            )
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-n", tempURL.path]
            process.standardOutput = Pipe()
            process.standardError = stderrPipe

            process.terminationHandler = { terminatedProcess in
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                let result: SyntaxCheckResult
                if terminatedProcess.terminationStatus == 0 {
                    result = .valid
                } else {
                    let message = Self.sanitizedMessage(
                        from: stderr,
                        tempURL: tempURL,
                        displayPath: displayPath
                    )

                    result = SyntaxCheckResult(
                        isValid: false,
                        message: message,
                        line: Self.extractedLine(from: message)
                    )
                }

                try? FileManager.default.removeItem(at: tempURL)
                continuation.resume(returning: result)
            }

            do {
                try process.run()
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                continuation.resume(
                    returning: SyntaxCheckResult(
                        isValid: false,
                        message: error.localizedDescription,
                        line: nil
                    )
                )
            }
        }
    }

    private static func sanitizedMessage(from rawMessage: String, tempURL: URL, displayPath: String) -> String {
        let trimmed = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return L10n.zshReportedSyntaxError }

        return trimmed.replacingOccurrences(of: tempURL.path, with: displayPath)
    }

    private static func extractedLine(from message: String) -> Int? {
        for pattern in [#":(\d+):"#, #"line\s+(\d+)"#] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(message.startIndex..<message.endIndex, in: message)

            guard let match = regex.firstMatch(in: message, range: range),
                  match.numberOfRanges > 1,
                  let lineRange = Range(match.range(at: 1), in: message) else {
                continue
            }

            return Int(message[lineRange])
        }

        return nil
    }
}
