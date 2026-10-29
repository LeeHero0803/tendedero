import AppKit
import AVFoundation
import Combine
import QuickLookThumbnailing
import os

let log = Logger(subsystem: "app.tendedero.Tendedero", category: "line")

/// One screenshot hanging on the line.
struct Pegged: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var thumb: NSImage
    var isFileReference = false
    var filePreview: NSImage?
    var isTextNote: Bool { !isFileReference && isNote(url) }
    /// Every photo hangs a little crooked, like on a real line.
    let tilt = Double.random(in: -2.5...2.5)
    var falling = false
    /// Still flying in from where it was captured; the card waits hidden.
    var flying = false
    /// A screen recording rather than a screenshot.
    var isRecording: Bool { !isFileReference && Tendedero.isRecording(url) }

    static func == (a: Pegged, b: Pegged) -> Bool {
        a.id == b.id && a.falling == b.falling && a.flying == b.flying && a.thumb === b.thumb
    }
}

/// The line itself: what hangs on it and what you can do with each item.
/// The files never move. The line is only a view onto them.
@MainActor
final class Line: ObservableObject {
    @Published private(set) var items: [Pegged] = []
    @Published private(set) var gust = 0
    @Published var copiedID: UUID?
    @Published var draggingID: UUID?
    @Published var pressedID: UUID?
    /// Whether the line has slid down into view.
    @Published var revealed = false

    /// Card frames in window coordinates, reported by the views. The panel
    /// uses them to only catch clicks over photos and let the rest through.
    var hitRects: [UUID: CGRect] = [:]

    var maxItems = 8
    /// How many photos fit across the screen. With Keep on line set, the
    /// line can hold more, and the rest are reached by scrolling.
    var visibleCount = 8
    /// How far the line is scrolled towards older photos, in points; 0 shows
    /// the newest.
    @Published var scroll: CGFloat = 0

    /// Keep on line, from the menu bar: how many photos the line keeps, or
    /// nil for as many as fit across the screen.
    nonisolated static let keepChoices = [25, 50, 100]
    nonisolated static var keepOnLine: Int? {
        get {
            let n = UserDefaults.standard.integer(forKey: "keepOnLine")
            return keepChoices.contains(n) ? n : nil
        }
        set { UserDefaults.standard.set(newValue ?? 0, forKey: "keepOnLine") }
    }


    var soundOn: Bool {
        get { !UserDefaults.standard.bool(forKey: "soundOff") }
        set { UserDefaults.standard.set(!newValue, forKey: "soundOff") }
    }

    var liveCount: Int { items.filter { !$0.falling }.count }

    private let storeKey = "pegged"
    private var darkCards = false
    private var previewRequests: [UUID: QLThumbnailGenerator.Request] = [:]

    func updateAppearance(dark: Bool) {
        guard darkCards != dark else { return }
        darkCards = dark
        reloadThumbnails()
    }

    private func thumbnail(_ url: URL, reference: Bool, preview: NSImage? = nil) -> NSImage? {
        if reference { return makeFileCard(url, dark: darkCards, preview: preview) }
        if isNote(url) { return makeNoteCard(url, scale: min(1, CGFloat(Int(320 * Layout.size.scale)) / 1040), dark: darkCards) }
        return makeThumbnail(url)
    }

    init() {
        restore()
        for item in items where item.isFileReference { requestPreview(for: item.id) }
        scheduleGust()
    }

    // MARK: Hanging and dropping

    @discardableResult
    func hang(_ url: URL, quietly: Bool = false, flying: Bool = false, fileReference: Bool = false) -> UUID? {
        guard !items.contains(where: { $0.url == url && !$0.falling }),
              let thumb = thumbnail(url, reference: fileReference) else { return nil }
        var item = Pegged(url: url, thumb: thumb, isFileReference: fileReference)
        item.flying = flying
        items.append(item)
        if fileReference { requestPreview(for: item.id) }
        scroll = 0
        // A full line lets the oldest photo fall off the far end. Only one: a
        // line hung on a wider screen keeps its length here instead of losing
        // several photos to a single capture.
        if liveCount > maxItems, let oldest = items.first(where: { !$0.falling }) {
            letGo(oldest.id)
        }
        save()
        if !quietly { play("Tink", volume: 0.35) }
        return item.id
    }

    /// The capture has reached the line: the real card takes over.
    func land(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].flying = false
    }

    /// Called just before a photo starts falling, so the fall can be drawn
    /// over the whole screen.
    var onFall: ((Pegged) -> Void)?

    func drop(_ id: UUID, quietly: Bool = false) {
        guard let i = items.firstIndex(where: { $0.id == id }), !items[i].falling else { return }
        if let request = previewRequests.removeValue(forKey: id) { QLThumbnailGenerator.shared.cancel(request) }
        onFall?(items[i])
        items[i].falling = true
        hitRects[id] = nil
        save()
        if !quietly { play("Pop", volume: 0.25) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.items.removeAll { $0.id == id }
        }
    }

    /// "Take everything down": every photo goes the way of its corner cross.
    func clear() {
        takeDown(items.filter { !$0.falling })
    }

    /// The photos hung before (left) or after (right) this one.
    func neighbours(of id: UUID, toTheLeft: Bool) -> [Pegged] {
        let live = items.filter { !$0.falling }
        guard let i = live.firstIndex(where: { $0.id == id }) else { return [] }
        return toTheLeft ? Array(live[..<i]) : Array(live[(i + 1)...])
    }

    /// Takes down everything on one side of a photo. Each one goes the way
    /// of its own corner button: to the Trash from Tendedero's folder, and
    /// only off the line from anywhere else.
    func takeDown(_ id: UUID, toTheLeft: Bool) {
        takeDown(neighbours(of: id, toTheLeft: toTheLeft))
    }

    /// One after another, and only the first makes a sound.
    private func takeDown(_ live: [Pegged]) {
        for (n, item) in live.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06 * Double(n)) { [weak self] in
                self?.discard(item.id, quietly: n > 0)
            }
        }
    }

    /// Photos whose file was deleted or moved away fall off by themselves.
    func prune() {
        for item in items where !item.falling && !FileManager.default.fileExists(atPath: item.url.path) {
            drop(item.id, quietly: true)
        }
    }

    /// Use live files rather than a permanent history cache: removed notes can
    /// be copied again, restored notes are covered, and edits take effect immediately.
    func containsText(_ text: String) -> Bool {
        containsTextNote(text, at: items.filter { !$0.falling && $0.isTextNote }.map(\.url))
    }

    // MARK: Actions on one photo

    func copy(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        guard let entry = try? clipboardTransferItem(url: item.url, textNote: item.isTextNote) else {
            NSSound.beep()
            return
        }
        if !item.isTextNote, !item.isFileReference, !item.isRecording, let png = pngData(item.url) {
            entry.setData(png, forType: .png)
        }
        entry.setString("1", forType: ClipboardWatcher.ownCopyType)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([entry])

        copiedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.copiedID == id { self?.copiedID = nil }
        }
    }

    func open(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.open(item.url)
    }

    /// Moves the file to the Trash and takes the photo off the line. When a
    /// drag ends on the Dock's Trash, macOS only reports it: deleting the file
    /// is the source app's job, as Finder does.
    @discardableResult
    func trash(_ id: UUID, quietly: Bool = false) -> Bool {
        guard let item = items.first(where: { $0.id == id }) else { return false }
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            log.notice("Trashed \(item.url.lastPathComponent, privacy: .public)")
            if soundOn && !quietly { Line.trashSound?.play() }
            drop(id, quietly: true)
            return true
        } catch {
            log.error("Could not trash \(item.url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            if !quietly { NSSound.beep() }
            return false
        }
    }

    private static let trashSound = NSSound(
        contentsOfFile: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/drag to trash.aif",
        byReference: true)

    /// Whether the file lives in Tendedero's own folder. Those are discarded
    /// to the Trash, or the folder would fill up with forgotten screenshots.
    /// Files anywhere else, like the Desktop, stay where they are.
    func isInInbox(_ id: UUID) -> Bool {
        guard let item = items.first(where: { $0.id == id }) else { return false }
        return !item.isFileReference && item.url.standardizedFileURL.path.hasPrefix(Inbox.folder.standardizedFileURL.path + "/")
    }

    /// The corner cross and "Take down" both end up here.
    func discard(_ id: UUID, quietly: Bool = false) {
        if isInInbox(id) { trash(id, quietly: quietly) } else { drop(id, quietly: quietly) }
    }

    /// The oldest photo falling off a full line. Like the cross, a file from
    /// Tendedero's folder goes to the Trash, or nothing would ever take it out
    /// of that folder. If the Trash refuses it, it still leaves the line.
    /// Moves along a line that holds more than fit, from a scroll gesture.
    func scroll(by delta: CGFloat) {
        let most = CGFloat(max(0, items.count - visibleCount)) * Layout.spacing
        let next = min(most, max(0, scroll + delta))
        if next != scroll { scroll = next }
    }

    /// After Keep on line is lowered, the oldest photos past it go the way
    /// of a full line.
    func trim() {
        while liveCount > maxItems, let oldest = items.first(where: { !$0.falling }) {
            letGo(oldest.id)
        }
        scroll = 0
    }

    private func letGo(_ id: UUID) {
        if isInInbox(id), trash(id, quietly: true) { return }
        drop(id, quietly: true)
    }

    /// Inbox mode: keep a screenshot by moving it to the Desktop.
    func saveToDesktop(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let target = uniqueURL(in: desktop, for: item.url.lastPathComponent)
        do {
            try FileManager.default.moveItem(at: item.url, to: target)
            drop(id, quietly: true)
        } catch {
            log.error("Could not save to Desktop: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
        }
    }

    private func uniqueURL(in folder: URL, for name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return candidate
    }

    /// Long press: open the photo in the system Markup editor. Markup does
    /// not edit video, so a recording opens in the trimming editor instead.
    func markup(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        if item.isTextNote || item.isFileReference {
            // A note has nothing to mark up: it opens in the text editor instead.
            NSWorkspace.shared.open(item.url)
        } else if item.isRecording {
            Trim.shared.edit(item.url, size: item.thumb.size)
        } else {
            Markup.shared.edit(item.url)
        }
    }

    /// After editing, the photo on the line shows the new version.
    func reloadThumbnail(for url: URL) {
        guard let i = items.firstIndex(where: { $0.url == url && !$0.falling }),
              let thumb = thumbnail(url, reference: items[i].isFileReference) else { return }
        items[i].thumb = thumb
        if items[i].isFileReference {
            items[i].filePreview = nil
            requestPreview(for: items[i].id)
        }
    }

    /// Quick Look on this photo, with the rest of the line a key press away.
    func quickLook(_ id: UUID) {
        let live = items.filter { !$0.falling }
        guard let index = live.firstIndex(where: { $0.id == id }) else { return }
        QuickLook.shared.show(live.map(\.url), at: index)
    }

    /// After a change of size, every photo is redrawn sharp at the new one.
    func reloadThumbnails() {
        for i in items.indices where !items[i].falling {
            if let thumb = thumbnail(items[i].url, reference: items[i].isFileReference, preview: items[i].filePreview) { items[i].thumb = thumb }
        }
    }

    /// Quick Look supplies image, movie and document previews without blocking the UI.
    /// Unsupported files and folders keep their system icon.
    private func requestPreview(for id: UUID) {
        guard let item = items.first(where: { $0.id == id && !$0.falling }), item.isFileReference,
              (try? item.url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true else { return }
        if let old = previewRequests.removeValue(forKey: id) { QLThumbnailGenerator.shared.cancel(old) }
        let request = QLThumbnailGenerator.Request(fileAt: item.url,
            size: CGSize(width: 512, height: 320), scale: 1, representationTypes: .thumbnail)
        previewRequests[id] = request
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            Task { @MainActor [weak self] in
                guard let self, self.previewRequests[id] === request else { return }
                self.previewRequests[id] = nil
                guard let representation, let i = self.items.firstIndex(where: { $0.id == id && !$0.falling }) else { return }
                let preview = representation.nsImage
                self.items[i].filePreview = preview
                self.items[i].thumb = makeFileCard(self.items[i].url, dark: self.darkCards, preview: preview)
            }
        }
    }

    func reveal(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    // MARK: Breeze

    /// Every so often a little wind moves the line. It is the detail that
    /// makes it feel like an object and not a widget.
    private func scheduleGust() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 7...16)) { [weak self] in
            guard let self else { return }
            if !self.items.isEmpty && self.draggingID == nil { self.gust += 1 }
            self.scheduleGust()
        }
    }

    // MARK: Persistence

    private func save() {
        let paths = items.filter { !$0.falling }.map(\.url.path)
        UserDefaults.standard.set(paths, forKey: storeKey)
        UserDefaults.standard.set(items.filter { !$0.falling && $0.isFileReference }.map(\.url.path), forKey: "peggedFileReferences")
    }

    /// Everything comes back as it was. This runs before the line knows its
    /// screen, so the capacity is still the default one: hanging through
    /// `hang` would let photos fall off a wide screen's line at every launch.
    private func restore() {
        let paths = UserDefaults.standard.stringArray(forKey: storeKey) ?? []
        let references = Set(UserDefaults.standard.stringArray(forKey: "peggedFileReferences") ?? [])
        for path in paths where FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            guard !items.contains(where: { $0.url == url }), let thumb = thumbnail(url, reference: references.contains(path)) else { continue }
            items.append(Pegged(url: url, thumb: thumb, isFileReference: references.contains(path)))
        }
    }

    // MARK: Helpers

    private func play(_ name: String, volume: Float) {
        guard soundOn, let sound = NSSound(named: name)?.copy() as? NSSound else { return }
        sound.volume = volume
        sound.play()
    }

    private func pngData(_ url: URL) -> Data? {
        if url.pathExtension.lowercased() == "png" { return try? Data(contentsOf: url) }
        guard let tiff = NSImage(contentsOf: url)?.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

/// Screen recordings, as macOS saves them.
func isRecording(_ url: URL) -> Bool {
    ["mov", "mp4"].contains(url.pathExtension.lowercased())
}

/// Copied text is kept as a .txt file and hangs as a note card.
func isNote(_ url: URL) -> Bool { url.pathExtension.lowercased() == "txt" }

/// The default size covers a card at twice its size in points, as on a
/// Retina screen, and no more: every photo on the line keeps one in memory.
func makeThumbnail(_ url: URL, maxPixels: Int = Int(320 * Layout.size.scale)) -> NSImage? {
    if isRecording(url) { return firstFrame(url, maxPixels: maxPixels) }
    if isNote(url) { return makeNoteCard(url, scale: min(1, CGFloat(maxPixels) / 1040)) }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixels,
    ]
    guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
}

/// A recording shows its first frame.
private func firstFrame(_ url: URL, maxPixels: Int) -> NSImage? {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: maxPixels, height: maxPixels)
    guard let cg = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
    return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
}

/// Draws the text on a paper card, wrapped and cut off with an ellipsis
/// when it runs past the bottom.
func makeNoteCard(_ url: URL, scale: CGFloat = 1, dark: Bool = false) -> NSImage? {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
    let text = String(decoding: data.prefix(4000), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let width = Int(1040 * scale), height = Int(800 * scale), pad: CGFloat = 60 * scale
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    (dark ? NSColor(srgbRed: 0.16, green: 0.17, blue: 0.19, alpha: 1)
          : NSColor(srgbRed: 0.995, green: 0.985, blue: 0.95, alpha: 1)).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    style.lineSpacing = 6 * scale
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 72 * scale, weight: .medium),
        .foregroundColor: NSColor(white: dark ? 0.92 : 0.13, alpha: 1),
        .paragraphStyle: style,
    ]
    let content = NSAttributedString(string: text, attributes: attributes)
    let availableHeight = CGFloat(height) - pad * 2
    let textWidth = CGFloat(width) - pad * 2
    let measured = content.boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                                        options: [.usesLineFragmentOrigin, .usesFontLeading]).height
    let textHeight = min(availableHeight, ceil(measured))
    let box = NSRect(x: pad, y: (CGFloat(height) - textHeight) / 2, width: textWidth, height: textHeight)

    // Quiet ruled paper; align the first rule to the centered text block.
    let font = NSFont.systemFont(ofSize: 72 * scale, weight: .medium)
    let lineHeight = font.ascender - font.descender + font.leading + style.lineSpacing
    let rules = NSBezierPath()
    rules.lineWidth = max(1, 2 * scale)
    var y = box.maxY - (font.ascender - font.descender) - 2 * scale
    while y < CGFloat(height) - pad { y += lineHeight }
    while y > pad {
        if y < CGFloat(height) - pad {
            rules.move(to: NSPoint(x: pad, y: y))
            rules.line(to: NSPoint(x: CGFloat(width) - pad, y: y))
        }
        y -= lineHeight
    }
    NSColor(white: dark ? 0.85 : 0.25, alpha: dark ? 0.18 : 0.16).setStroke()
    rules.stroke()
    content.draw(with: box, options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine])
    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: NSSize(width: width, height: height))
    image.addRepresentation(rep)
    return image
}

/// File references keep their identity, including .txt files and folders.
func makeFileCard(_ url: URL, dark: Bool, preview: NSImage? = nil) -> NSImage {
    let size = NSSize(width: 320, height: 246)
    let artwork = preview ?? NSWorkspace.shared.icon(forFile: url.path)
    return NSImage(size: size, flipped: false) { rect in
        (dark ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.96, alpha: 1)).setFill()
        rect.fill()
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingMiddle
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .medium),
            .foregroundColor: NSColor(white: dark ? 0.92 : 0.13, alpha: 1),
            .paragraphStyle: style,
        ]
        // Center the complete artwork + gap + filename group, not just the icon.
        let titleHeight: CGFloat = 26
        let gap: CGFloat = 14
        let artworkHeight: CGFloat = preview == nil ? 88 : 146
        let groupHeight = artworkHeight + gap + titleHeight
        let bottom = (size.height - groupHeight) / 2
        let slot = NSRect(x: 20, y: bottom + titleHeight + gap, width: 280, height: artworkHeight)
        let ratio = min(slot.width / max(1, artwork.size.width), slot.height / max(1, artwork.size.height))
        let drawingSize = NSSize(width: artwork.size.width * ratio, height: artwork.size.height * ratio)
        let drawingRect = NSRect(x: slot.midX - drawingSize.width / 2, y: slot.midY - drawingSize.height / 2,
                                 width: drawingSize.width, height: drawingSize.height)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: drawingRect, xRadius: preview == nil ? 0 : 6, yRadius: preview == nil ? 0 : 6).addClip()
        artwork.draw(in: drawingRect)
        NSGraphicsContext.restoreGraphicsState()
        (url.lastPathComponent as NSString).draw(in: NSRect(x: 16, y: bottom, width: 288, height: titleHeight), withAttributes: attributes)
        return true
    }
}
