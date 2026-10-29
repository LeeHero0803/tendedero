import AppKit

/// An opaque paper card. Only overflowing text fades; the paper stays legible.
func makeNoteCard(_ url: URL, scale: CGFloat = 1, dark: Bool = false) -> NSImage? {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
    let previewLimit = 4000
    let text = String(decoding: data.prefix(previewLimit), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let width = Int(1040 * scale), height = Int(800 * scale), pad: CGFloat = 60 * scale
    guard width > 0, height > 0,
          let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    (dark ? NSColor(srgbRed: 0.16, green: 0.17, blue: 0.19, alpha: 1)
          : NSColor(srgbRed: 0.995, green: 0.985, blue: 0.95, alpha: 1)).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    let canvasScale = CGFloat(width) / 320
    let style = CardTypography.paragraph(scale: canvasScale)
    let font = CardTypography.font(canvasWidth: CGFloat(width))
    let content = NSAttributedString(string: text, attributes: [
        .font: font,
        .foregroundColor: NSColor(white: dark ? 0.92 : 0.13, alpha: 1),
        .paragraphStyle: style,
    ])
    let availableHeight = CGFloat(height) - pad * 2
    let textWidth = CGFloat(width) - pad * 2
    let measured = content.boundingRect(with: NSSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                                        options: [.usesLineFragmentOrigin, .usesFontLeading]).height
    let overflows = data.count > previewLimit || ceil(measured) > availableHeight
    let textHeight = min(availableHeight, ceil(measured))
    let box = NSRect(x: pad, y: (CGFloat(height) - textHeight) / 2, width: textWidth, height: textHeight)

    let lineHeight = font.ascender - font.descender + font.leading + style.lineSpacing
    let ink = NSColor(white: dark ? 0.85 : 0.25, alpha: dark ? 0.18 : 0.16)
    let leftFade = NSGradient(starting: ink.withAlphaComponent(0), ending: ink)
    let rightFade = NSGradient(starting: ink, ending: ink.withAlphaComponent(0))
    let ruleWidth = max(1, 2 * scale)
    let fadeWidth = textWidth * 0.22
    var y = box.maxY - (font.ascender - font.descender) - 2 * scale
    while y < CGFloat(height) - pad { y += lineHeight }
    while y > pad {
        if y < CGFloat(height) - pad {
            // The middle stays solid; only the ends fade into the paper.
            leftFade?.draw(in: NSRect(x: pad, y: y, width: fadeWidth, height: ruleWidth), angle: 0)
            ink.setFill()
            NSRect(x: pad + fadeWidth, y: y, width: textWidth - 2 * fadeWidth, height: ruleWidth).fill()
            rightFade?.draw(in: NSRect(x: pad + textWidth - fadeWidth, y: y, width: fadeWidth, height: ruleWidth), angle: 0)
        }
        y -= lineHeight
    }

    let cg = context.cgContext
    cg.saveGState()
    cg.clip(to: box)
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    // No ellipsis on notes: the bottom fade communicates continuation instead.
    content.draw(with: box, options: [.usesLineFragmentOrigin, .usesFontLeading])
    if overflows {
        let fadeHeight = min(box.height, lineHeight * 1.4)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: [NSColor.white.withAlphaComponent(0).cgColor,
                                              NSColor.white.cgColor] as CFArray,
                                     locations: [0, 1]) {
            cg.setBlendMode(.destinationIn)
            cg.drawLinearGradient(gradient,
                start: CGPoint(x: box.midX, y: box.minY),
                end: CGPoint(x: box.midX, y: box.minY + fadeHeight),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }
    cg.endTransparencyLayer()
    cg.restoreGState()

    let image = NSImage(size: NSSize(width: width, height: height))
    image.addRepresentation(rep)
    return image
}

/// A fixed preview window and a single inline [extension] filename row.
func makeFileCard(_ url: URL, dark: Bool, preview: NSImage? = nil) -> NSImage {
    let size = NSSize(width: 320, height: 246)
    let artwork = preview ?? NSWorkspace.shared.icon(forFile: url.path)
    let font = CardTypography.font()
    let label = CardTypography.fileLabel(url)
    return NSImage(size: size, flipped: false) { rect in
        (dark ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.96, alpha: 1)).setFill()
        rect.fill()
        let foreground = NSColor(white: dark ? 0.92 : 0.13, alpha: 1)
        // These bounds never depend on filename length, font size, or file type.
        let slot = NSRect(x: 20, y: 86, width: 280, height: 140)
        let fitSlot = preview == nil ? slot.insetBy(dx: 0, dy: 26) : slot
        let ratio = min(fitSlot.width / max(1, artwork.size.width), fitSlot.height / max(1, artwork.size.height))
        let drawingSize = NSSize(width: artwork.size.width * ratio, height: artwork.size.height * ratio)
        let drawingRect = NSRect(x: fitSlot.midX - drawingSize.width / 2, y: fitSlot.midY - drawingSize.height / 2,
                                 width: drawingSize.width, height: drawingSize.height)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: slot, xRadius: 6, yRadius: 6).addClip()
        artwork.draw(in: drawingRect)
        NSGraphicsContext.restoreGraphicsState()

        let row = NSRect(x: 16, y: 20, width: 288, height: 50)
        let style = CardTypography.paragraph()
        style.lineBreakMode = .byTruncatingTail
        style.lineSpacing = 0
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: foreground, .paragraphStyle: style,
        ]
        let title = label.name.components(separatedBy: .newlines).joined(separator: " ")
            .replacingOccurrences(of: "\t", with: " ")
        let titleHeight = ceil(font.ascender - font.descender + font.leading)
        let titleWidth = ceil((title as NSString).size(withAttributes: titleAttributes).width)
        let tagFont = CardTypography.font(canvasWidth: 320 * 0.65)
        let tagStyle = CardTypography.paragraph(centered: true)
        tagStyle.lineBreakMode = .byTruncatingTail
        tagStyle.lineSpacing = 0
        let tagAttributes: [NSAttributedString.Key: Any] = [
            .font: tagFont, .foregroundColor: foreground.withAlphaComponent(0.85), .paragraphStyle: tagStyle,
        ]
        let tagWidth: CGFloat = label.tag.map { min(82, ceil(($0 as NSString).size(withAttributes: tagAttributes).width) + 18) } ?? 0
        let gap: CGFloat = label.tag == nil ? 0 : 8
        let groupWidth = min(row.width, tagWidth + gap + titleWidth)
        let left = row.midX - groupWidth / 2
        if let tag = label.tag {
            let tagHeight = ceil(tagFont.ascender - tagFont.descender + tagFont.leading) + 8
            let tagRect = NSRect(x: left, y: row.midY - tagHeight / 2, width: tagWidth, height: tagHeight)
            (dark ? NSColor(white: 1, alpha: 0.09) : NSColor(white: 0, alpha: 0.06)).setFill()
            NSBezierPath(roundedRect: tagRect, xRadius: tagHeight / 2, yRadius: tagHeight / 2).fill()
            (tag as NSString).draw(in: tagRect.insetBy(dx: 9, dy: 4), withAttributes: tagAttributes)
        }
        let titleRect = NSRect(x: left + tagWidth + gap, y: row.midY - titleHeight / 2,
                               width: groupWidth - tagWidth - gap, height: titleHeight)
        (title as NSString).draw(in: titleRect, withAttributes: titleAttributes)
        return true
    }
}
