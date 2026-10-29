import AppKit

/// Shared type scale in a 320-point-wide thumbnail; both card renderers use it.
enum CardTypography {
    enum Size: String, CaseIterable {
        case small, medium, large, extraLarge
        var points: CGFloat {
            switch self {
            case .small: 22
            case .medium: 24
            case .large: 28
            case .extraLarge: 32
            }
        }
    }

    static var size: Size {
        get { Size(rawValue: UserDefaults.standard.string(forKey: "cardTextSize") ?? "") ?? .medium }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "cardTextSize") }
    }

    /// Match Pages' 宋体-简 / Songti SC Regular for both Chinese and Latin text.
    static func font(canvasWidth: CGFloat = 320) -> NSFont {
        let points = size.points * canvasWidth / 320
        if let songti = NSFont(name: "SongtiSC-Regular", size: points) { return songti }
        if let song = NSFont(name: "STSong", size: points) { return song }
        let system = NSFont.systemFont(ofSize: points)
        return NSFont(descriptor: system.fontDescriptor.withDesign(.serif) ?? system.fontDescriptor,
                      size: points) ?? system
    }

    /// Non-note UI uses the regular system face, sharing only the size preference.
    static func fileFont(scale: CGFloat = 1) -> NSFont {
        NSFont.systemFont(ofSize: size.points * scale, weight: .regular)
    }

    static func paragraph(centered: Bool = false, scale: CGFloat = 1) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = centered ? .center : .left
        style.lineBreakMode = .byCharWrapping
        style.lineBreakStrategy = []
        style.hyphenationFactor = 0
        style.lineSpacing = 2 * scale
        return style
    }

    static func fileLabel(_ url: URL) -> (name: String, tag: String?) {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        if values?.isDirectory == true && values?.isPackage != true {
            return (url.lastPathComponent, nil)
        }
        let ext = url.pathExtension
        guard !ext.isEmpty else { return (url.lastPathComponent, nil) }
        return (url.deletingPathExtension().lastPathComponent, ext.uppercased())
    }
}
