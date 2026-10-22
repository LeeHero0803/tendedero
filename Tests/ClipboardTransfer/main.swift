import AppKit

let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: folder) }
let url = folder.appendingPathComponent("中文 note.txt")
let original = "  中文 👋\nsecond line\t  "
try original.write(to: url, atomically: true, encoding: .utf8)
let note = try clipboardTransferItem(url: url, textNote: true)
assert(note.string(forType: .string) == original)
assert(!note.types.contains(.fileURL), "Text drag must not advertise a file")
let file = try clipboardTransferItem(url: url, textNote: false)
assert(file.string(forType: .fileURL) == url.absoluteString)
assert(!file.types.contains(.string), "A copied .txt file must remain a file")
let directory = try clipboardTransferItem(url: folder, textNote: false)
assert(directory.string(forType: .fileURL) == folder.absoluteString)
let missing = folder.appendingPathComponent("missing.txt")
do {
    _ = try clipboardTransferItem(url: missing, textNote: true)
    fatalError("Missing note must fail, never fall back to file transfer")
} catch {}
// Use a private pasteboard; the user's clipboard is untouched.
let pasteboard = NSPasteboard.withUniqueName()
defer { pasteboard.releaseGlobally() }
assert(pasteboard.writeObjects([file]))
let restored = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
assert(restored == [url])
print("Clipboard transfer regression tests passed")
