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

    /// SF Mono for Latin text, with system fallback for Chinese and other scripts.
    static func font(canvasWidth: CGFloat = 320) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size.points * canvasWidth / 320, weight: .medium)
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
