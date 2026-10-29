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
let advance = ("a" as NSString).size(withAttributes: [.font: font]).width
let container = NSTextContainer(size: NSSize(width: advance * 8.5, height: 1000))
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
print("Card typography regression tests passed")
