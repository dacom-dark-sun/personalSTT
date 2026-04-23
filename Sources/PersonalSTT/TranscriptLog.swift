import Foundation

/// Appends every transcription to a daily markdown file under
/// `~/.config/personal-stt/transcripts/YYYY-MM-DD.md`.
///
/// New entries are prepended (latest-first) so the most recent dictation
/// is always at the top — useful as a safety net when focus is lost and
/// the injected text never reaches any input field.
enum TranscriptLog {
    private static let dir: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".config/personal-stt/transcripts")

    static func record(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true
            )

            let now = Date()
            let fileURL = dir.appendingPathComponent("\(dayString(now)).md")
            let entry = "## \(timeString(now))\n\n\(trimmed)\n\n"

            let existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            try (entry + existing).write(to: fileURL, atomically: true, encoding: .utf8)

            // Match config file permissions — transcripts may contain sensitive speech.
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: fileURL.path
            )

            NSLog("personal-stt: transcript logged → %@", fileURL.path)
        } catch {
            NSLog("personal-stt: transcript log write failed: %@", error.localizedDescription)
        }
    }

    private static func dayString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return fmt.string(from: date)
    }

    private static func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        fmt.timeZone = .current
        return fmt.string(from: date)
    }
}
