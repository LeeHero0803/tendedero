import Foundation

/// Compare full UTF-8 bytes, not the truncated preview or normalized whitespace.
/// Missing files do not suppress a future capture; callers pass only live notes,
/// never file-reference cards (even when a reference points to a .txt file).
func containsTextNote(_ text: String, at urls: [URL]) -> Bool {
    let bytes = Data(text.utf8)
    return urls.contains { url in
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size == bytes.count,
              let existing = try? Data(contentsOf: url, options: .mappedIfSafe) else { return false }
        return existing == bytes
    }
}
