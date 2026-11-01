import AppKit
import CoreText

/// An opaque paper card. Only overflowing text fades; the paper stays legible.
func makeNoteCard(_ url: URL, scale: CGFloat = 1, dark: Bool = false, webPreview: WebPreview? = nil) -> NSImage? {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
    let previewLimit = 4000
    let text = String(decoding: data.prefix(previewLimit), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let completeText = data.count <= 8192 ? String(data: data, encoding: .utf8) : nil
    let webAddress = completeText.flatMap(noteWebURL)
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

    if let webAddress, let completeText {
        drawWebNote(completeText.trimmingCharacters(in: .whitespacesAndNewlines),
                    address: webAddress, preview: webPreview,
                    width: CGFloat(width), height: CGFloat(height), pad: pad, font: font, dark: dark)
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)
        return image
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
    let font = CardTypography.fileFont()
    let label = CardTypography.fileLabel(url)
    return NSImage(size: size, flipped: false) { rect in
        (dark ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.96, alpha: 1)).setFill()
        rect.fill()
        let foreground = NSColor(white: dark ? 0.92 : 0.13, alpha: 1)
        // These bounds never depend on filename length, font size, or file type.
        let slot = NSRect(x: 20, y: 78, width: 280, height: 140)
        let ratio = min(slot.width / max(1, artwork.size.width), slot.height / max(1, artwork.size.height))
        let drawingSize = NSSize(width: artwork.size.width * ratio, height: artwork.size.height * ratio)
        let drawingRect = NSRect(x: slot.midX - drawingSize.width / 2, y: slot.midY - drawingSize.height / 2,
                                 width: drawingSize.width, height: drawingSize.height)
        NSGraphicsContext.saveGraphicsState()
        // Previews get icon-like corner proportions; system icons keep their own silhouette.
        let radius = preview == nil ? 0 : min(drawingRect.width, drawingRect.height) * 0.22
        NSBezierPath(roundedRect: drawingRect, xRadius: radius, yRadius: radius).addClip()
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
        let titleWidth = ceil((title as NSString).size(withAttributes: titleAttributes).width)
        let tagFont = CardTypography.fileFont(scale: 0.65)
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
            drawFileLine(tag, font: tagFont, color: foreground.withAlphaComponent(0.85),
                         in: tagRect.insetBy(dx: 9, dy: 0), centered: true)
        }
        let titleRect = NSRect(x: left + tagWidth + gap, y: row.minY,
                               width: groupWidth - tagWidth - gap, height: row.height)
        drawFileLine(title, font: font, color: foreground, in: titleRect)
        return true
    }
}

/// A small paper attachment, drawn into the note rather than a clickable web view.
private func drawWebNote(_ text: String, address: URL, preview: WebPreview?,
                         width: CGFloat, height: CGFloat, pad: CGFloat, font: NSFont, dark: Bool) {
    let unit = width / 320
    let foreground = NSColor(white: dark ? 0.92 : 0.13, alpha: 1)
    let urlRow = NSRect(x: pad, y: height - pad - 40 * unit,
                        width: width - pad * 2, height: 40 * unit)
    drawFileLine(text, font: font, color: foreground, in: urlRow)

    let slip = NSRect(x: pad, y: 42 * unit, width: width - pad * 2, height: 114 * unit)
    let paper = dark ? NSColor(srgbRed: 0.20, green: 0.21, blue: 0.23, alpha: 1)
                     : NSColor(srgbRed: 0.98, green: 0.96, blue: 0.89, alpha: 1)
    let outline = NSBezierPath(roundedRect: slip, xRadius: 5 * unit, yRadius: 5 * unit)
    paper.setFill()
    outline.fill()
    foreground.withAlphaComponent(dark ? 0.13 : 0.10).setStroke()
    outline.lineWidth = 0.7 * unit
    outline.stroke()

    let iconBox = NSRect(x: slip.minX + 13 * unit, y: slip.midY - 17 * unit,
                         width: 34 * unit, height: 34 * unit)
    if let bytes = preview?.iconData, let icon = NSImage(data: bytes) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: iconBox, xRadius: 6 * unit, yRadius: 6 * unit).addClip()
        let ratio = min(iconBox.width / max(1, icon.size.width), iconBox.height / max(1, icon.size.height))
        let size = NSSize(width: icon.size.width * ratio, height: icon.size.height * ratio)
        icon.draw(in: NSRect(x: iconBox.midX - size.width / 2, y: iconBox.midY - size.height / 2,
                             width: size.width, height: size.height))
        NSGraphicsContext.restoreGraphicsState()
    } else {
        foreground.withAlphaComponent(0.45).setStroke()
        let globe = NSBezierPath(ovalIn: iconBox.insetBy(dx: 3 * unit, dy: 3 * unit))
        globe.appendOval(in: iconBox.insetBy(dx: 10 * unit, dy: 3 * unit))
        globe.move(to: NSPoint(x: iconBox.minX + 3 * unit, y: iconBox.midY))
        globe.line(to: NSPoint(x: iconBox.maxX - 3 * unit, y: iconBox.midY))
        globe.lineWidth = 1.1 * unit
        globe.stroke()
    }

    let textX = iconBox.maxX + 12 * unit
    let textWidth = slip.maxX - textX - 12 * unit
    let titleFont = NSFont(name: font.fontName, size: font.pointSize * 0.75) ?? font
    let summaryFont = NSFont(name: font.fontName, size: font.pointSize * 0.57) ?? font
    let title = preview?.title ?? address.host ?? address.absoluteString
    let summary: String
    if let preview {
        summary = preview.summary.isEmpty ? "暂无网页介绍" : preview.summary
    } else {
        summary = "正在读取网页信息…"
    }
    func block(_ value: String, font: NSFont, opacity: CGFloat, rect: NSRect) {
        let paragraph = CardTypography.paragraph(scale: unit)
        let attributed = NSAttributedString(string: value, attributes: [
            .font: font, .foregroundColor: foreground.withAlphaComponent(opacity), .paragraphStyle: paragraph,
        ])
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine])
        NSGraphicsContext.restoreGraphicsState()
    }
    block(title, font: titleFont, opacity: 1,
          rect: NSRect(x: textX, y: slip.maxY - 52 * unit, width: textWidth, height: 42 * unit))
    block(summary, font: summaryFont, opacity: 0.62,
          rect: NSRect(x: textX, y: slip.minY + 12 * unit, width: textWidth, height: 36 * unit))

    // One quiet silver paperclip crossing the attachment's upper edge.
    let x = slip.minX + 18 * unit, y = slip.maxY + 7 * unit
    let clip = NSBezierPath()
    clip.move(to: NSPoint(x: x + 7 * unit, y: y - 24 * unit))
    clip.line(to: NSPoint(x: x + 7 * unit, y: y))
    clip.curve(to: NSPoint(x: x - 5 * unit, y: y),
               controlPoint1: NSPoint(x: x + 7 * unit, y: y + 8 * unit),
               controlPoint2: NSPoint(x: x - 5 * unit, y: y + 8 * unit))
    clip.line(to: NSPoint(x: x - 5 * unit, y: y - 21 * unit))
    clip.curve(to: NSPoint(x: x + 2 * unit, y: y - 21 * unit),
               controlPoint1: NSPoint(x: x - 5 * unit, y: y - 26 * unit),
               controlPoint2: NSPoint(x: x + 2 * unit, y: y - 26 * unit))
    clip.line(to: NSPoint(x: x + 2 * unit, y: y - 3 * unit))
    clip.lineWidth = 1.5 * unit
    clip.lineCapStyle = .round
    clip.lineJoinStyle = .round
    (dark ? NSColor(white: 0.76, alpha: 1) : NSColor(white: 0.48, alpha: 1)).setStroke()
    clip.stroke()
}

/// Draw one line using actual glyph bounds, rather than clipping to nominal
/// font metrics (which can cut off Chinese fallback glyphs and descenders).
private func drawFileLine(_ text: String, font: NSFont, color: NSColor,
                          in rect: NSRect, centered: Bool = false) {
    guard rect.width > 0, rect.height > 0, let cg = NSGraphicsContext.current?.cgContext else { return }
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
    ]
    let original = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes) as CFAttributedString)
    let token = CTLineCreateWithAttributedString(NSAttributedString(string: "…", attributes: attributes) as CFAttributedString)
    let line: CTLine
    if CTLineGetTypographicBounds(original, nil, nil, nil) > Double(rect.width) {
        guard let truncated = CTLineCreateTruncatedLine(original, Double(rect.width), .end, token) else { return }
        line = truncated
    } else {
        line = original
    }
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    cg.saveGState()
    defer { cg.restoreGState() }
    cg.clip(to: rect)
    cg.textMatrix = .identity
    cg.textPosition = CGPoint(x: centered ? rect.midX - bounds.midX : rect.minX - bounds.minX,
                              y: rect.midY - bounds.midY)
    CTLineDraw(line, cg)
}
