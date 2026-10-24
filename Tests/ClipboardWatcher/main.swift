import AppKit
import os

// Compile the real watcher against an isolated inbox; never touch user notes.
enum Inbox {
    static let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}
let log = Logger(subsystem: "tendedero.tests", category: "clipboard")

@MainActor
func runTests() throws {
    let pb = NSPasteboard.withUniqueName()
    let oldTextEnabled = ClipboardWatcher.textEnabled
    let oldImagesEnabled = ClipboardWatcher.isEnabled
    ClipboardWatcher.textEnabled = true
    ClipboardWatcher.isEnabled = false
    defer {
        ClipboardWatcher.textEnabled = oldTextEnabled
        ClipboardWatcher.isEnabled = oldImagesEnabled
        pb.releaseGlobally()
        try? FileManager.default.removeItem(at: Inbox.folder)
    }
    var liveNotes: [URL] = []
    var captures = 0
    let watcher = ClipboardWatcher(onImage: { url in
        captures += 1
        liveNotes.append(url)
    }, onFiles: { _ in fatalError("Unexpected file capture") }, containsText: {
        containsTextNote($0, at: liveNotes)
    }, pasteboard: pb)
    func publish(_ text: String, marker: NSPasteboard.PasteboardType? = nil) {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        if let marker { item.setString("1", forType: marker) }
        pb.clearContents()
        assert(pb.writeObjects([item]))
        watcher.check()
    }
    let a = "原来的文字 👋\n第二行  "
    publish(a)
    assert(captures == 1)
    watcher.check() // No clipboard change: selecting alone creates nothing.
    assert(captures == 1)
    // Simulate a selection helper restoring identical clipboard text, with a new count.
    for _ in 0..<5 { publish(a) }
    assert(captures == 1)
    let savedFiles = try FileManager.default.contentsOfDirectory(atPath: Inbox.folder.path)
    assert(savedFiles.count == 1)
    // A temporary private payload followed by an unmarked restore must not duplicate A.
    publish("temporary selection", marker: .init("org.nspasteboard.TransientType"))
    publish(a)
    assert(captures == 1)
    publish("new text")
    assert(captures == 2)
    publish(a) // A is older but still on the line.
    assert(captures == 2)
    publish(a + " ") // Exact whitespace differences count as new text.
    assert(captures == 3)
    publish("own write", marker: ClipboardWatcher.ownCopyType)
    publish("secret", marker: .init("org.nspasteboard.ConcealedType"))
    assert(captures == 3)
    // Removing the card releases its identity even if the backing file remains.
    liveNotes.removeFirst()
    publish(a)
    assert(captures == 4)
    // The lookup reads current file contents, including edits and external deletion.
    let edited = liveNotes.last!
    try "edited content".write(to: edited, atomically: true, encoding: .utf8)
    publish("edited content")
    assert(captures == 4)
    try FileManager.default.removeItem(at: edited)
    publish("edited content")
    assert(captures == 5)
    // A new watcher reusing restored live notes must still deduplicate.
    let restored = ClipboardWatcher(onImage: { _ in fatalError("Duplicate after restore") },
        onFiles: { _ in }, containsText: { containsTextNote($0, at: liveNotes) }, pasteboard: pb)
    pb.clearContents()
    pb.setString("edited content", forType: .string)
    restored.check()
    print("Clipboard watcher regression tests passed")
}

try MainActor.assumeIsolated { try runTests() }
