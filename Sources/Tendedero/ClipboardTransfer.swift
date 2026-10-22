import AppKit

/// Internal storage never determines the representation sent to another app.
func clipboardTransferItem(url: URL, textNote: Bool) throws -> NSPasteboardItem {
    let item = NSPasteboardItem()
    if textNote {
        item.setString(try String(contentsOf: url, encoding: .utf8), forType: .string)
    } else {
        item.setString(url.absoluteString, forType: .fileURL)
    }
    return item
}
