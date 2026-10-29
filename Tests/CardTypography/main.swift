import AppKit

let original = UserDefaults.standard.object(forKey: "cardTextSize")
defer {
    if let original { UserDefaults.standard.set(original, forKey: "cardTextSize") }
    else { UserDefaults.standard.removeObject(forKey: "cardTextSize") }
}
for size in CardTypography.Size.allCases {
    CardTypography.size = size
    assert(CardTypography.size == size)
    let fileFont = CardTypography.font()
    let noteFont = CardTypography.font(canvasWidth: 1040)
    assert(fileFont.fontName == noteFont.fontName)
    assert(abs(noteFont.pointSize / 3.25 - fileFont.pointSize) < 0.001)
}
CardTypography.size = .medium
let font = CardTypography.font()
let text = "alpha beta gamma"
let storage = NSTextStorage(string: text, attributes: [.font: font, .paragraphStyle: CardTypography.paragraph()])
let layout = NSLayoutManager()
let prefixWidth = ("alpha be" as NSString).size(withAttributes: [.font: font]).width
let nextWidth = ("t" as NSString).size(withAttributes: [.font: font]).width
let container = NSTextContainer(size: NSSize(width: prefixWidth + nextWidth * 0.2, height: 1000))
container.lineFragmentPadding = 0
container.lineBreakMode = .byCharWrapping
layout.addTextContainer(container)
storage.addLayoutManager(layout)
layout.ensureLayout(for: container)
var firstLine = NSRange()
_ = layout.lineFragmentRect(forGlyphAt: 0, effectiveRange: &firstLine)
// Word wrapping would stop at "alpha "; character wrapping must fill into "beta".
assert(firstLine.length > 6 && firstLine.length < 10)

let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: folder) }
let file = folder.appendingPathComponent("中文 report.final.pdf")
try Data().write(to: file)
let label = CardTypography.fileLabel(file)
assert(label.name == "中文 report.final" && label.tag == "PDF")
let plain = CardTypography.fileLabel(folder.appendingPathComponent("README"))
assert(plain.name == "README" && plain.tag == nil)
let dottedFolder = folder.appendingPathComponent("folder.v2")
try FileManager.default.createDirectory(at: dottedFolder, withIntermediateDirectories: true)
let directory = CardTypography.fileLabel(dottedFolder)
assert(directory.name == "folder.v2" && directory.tag == nil)
// Compile and exercise the actual card renderers, not just their font helper.
let preview = NSImage(size: NSSize(width: 280, height: 140), flipped: false) { rect in
    NSColor.red.setFill()
    rect.fill()
    return true
}
let longFile = folder.appendingPathComponent(String(repeating: "长文件名英文name", count: 12) + ".pdf")
let note = folder.appendingPathComponent("note.txt")
for size in CardTypography.Size.allCases {
    CardTypography.size = size
    if let songti = NSFont(name: "SongtiSC-Regular", size: size.points) {
        assert(CardTypography.font().fontName == songti.fontName)
    }
    for dark in [false, true] {
        for text in ["短便签 / Short note", String(repeating: "中文English 内容 alpha beta gamma\n", count: 50)] {
            try text.write(to: note, atomically: true, encoding: .utf8)
            guard let image = makeNoteCard(note, scale: 0.5, dark: dark),
                  let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                fatalError("Note rendering failed")
            }
            assert(cg.width == 520 && cg.height == 400)
            let rep = NSBitmapImageRep(cgImage: cg)
            assert((rep.colorAt(x: 0, y: 0)?.alphaComponent ?? 0) > 0.99,
                   "Paper background must stay opaque")
        }
        for url in [file, longFile, dottedFolder] {
            let card = makeFileCard(url, dark: dark, preview: preview)
            guard let cg = card.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                fatalError("File card rendering failed")
            }
            assert(cg.width == 320 && cg.height == 246)
            let rep = NSBitmapImageRep(cgImage: cg)
            let color = rep.colorAt(x: 160, y: 123)?.usingColorSpace(.deviceRGB)
            assert((color?.redComponent ?? 0) > 0.95 && (color?.greenComponent ?? 1) < 0.05,
                   "Fixed preview area must not move with font size or filename length")
        }
    }
}
print("Card typography and rendering regression tests passed")
