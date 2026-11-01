import Foundation
import CoreFoundation

/// Presentation-only metadata; the note's original UTF-8 file stays untouched.
struct WebPreview: Sendable {
    let url: URL
    let title: String
    let summary: String
    let iconData: Data?
}

/// Only a whole HTTP(S) address becomes a link note, never prose containing a URL.
func noteWebURL(_ text: String) -> URL? {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.utf8.count <= 8192,
          value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
          let parts = URLComponents(string: value),
          ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
          let host = parts.host, !host.isEmpty,
          parts.user == nil, parts.password == nil else { return nil }
    return parts.url
}

actor WebPreviewLoader {
    static let shared = WebPreviewLoader()
    private var cache: [URL: WebPreview] = [:]
    private var pending: [URL: Task<WebPreview, Never>] = [:]

    func load(_ url: URL) async -> WebPreview {
        if let result = cache[url] { return result }
        if let task = pending[url] { return await task.value }
        let task = Task { await Self.fetch(url) }
        pending[url] = task
        let result = await task.value
        pending[url] = nil
        if cache.count >= 128 { cache.removeAll() }
        cache[url] = result
        return result
    }

    private static func fetch(_ url: URL) async -> WebPreview {
        let fallback = WebPreview(url: url, title: url.host ?? url.absoluteString,
                                  summary: "", iconData: nil)
        do {
            let (data, response) = try await read(url, limit: 512 * 1024, html: true)
            var encoding = String.Encoding.utf8
            if let name = response.textEncodingName {
                let identifier = CFStringConvertIANACharSetNameToEncoding(name as CFString)
                if identifier != kCFStringEncodingInvalidId {
                    encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(identifier))
                }
            }
            guard let html = String(data: data, encoding: encoding)
                    ?? String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) else { return fallback }
            let base = response.url ?? url
            var metadata: [String: String] = [:]
            for tag in matches(#"<meta\b[^>]*>"#, in: html) {
                let attrs = attributes(tag)
                if let key = attrs["property"] ?? attrs["name"], let content = attrs["content"] {
                    metadata[key.lowercased()] = clean(content)
                }
            }
            let titleTag = matches(#"<title\b[^>]*>(.*?)</title\s*>"#, in: html, group: 1).first
            let title = [metadata["og:title"], metadata["twitter:title"], titleTag.map(clean)]
                .compactMap { $0 }.first { !$0.isEmpty } ?? fallback.title
            let summary = [metadata["og:description"], metadata["description"], metadata["twitter:description"]]
                .compactMap { $0 }.first { !$0.isEmpty } ?? ""
            var iconURL: URL?
            for tag in matches(#"<link\b[^>]*>"#, in: html) {
                let attrs = attributes(tag)
                let rel = (attrs["rel"] ?? "").lowercased().split(whereSeparator: { $0.isWhitespace })
                if rel.contains("icon"), let href = attrs["href"] {
                    iconURL = URL(string: clean(href), relativeTo: base)?.absoluteURL
                    break
                }
            }
            let defaultIcon = URL(string: "/favicon.ico", relativeTo: base)?.absoluteURL
            var icon: Data?
            for candidate in [iconURL, defaultIcon].compactMap({ $0 }) {
                guard noteWebURL(candidate.absoluteString) != nil else { continue }
                if let (bytes, _) = try? await read(candidate, limit: 256 * 1024, html: false) {
                    icon = bytes
                    break
                }
            }
            return WebPreview(url: url, title: String(title.prefix(300)),
                              summary: String(summary.prefix(600)), iconData: icon)
        } catch {
            return fallback
        }
    }

    /// Ephemeral requests carry no browser cookies; stream caps bound downloads.
    private static func read(_ url: URL, limit: Int, html: Bool) async throws -> (Data, URLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue(html ? "text/html,application/xhtml+xml" : "image/*", forHTTPHeaderField: "Accept")
        request.setValue("Lineboard/1.6 (web preview)", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let finalURL = response.url, noteWebURL(finalURL.absoluteString) != nil else {
            throw URLError(.badServerResponse)
        }
        let type = (response.mimeType ?? "").lowercased()
        if html && !type.isEmpty && type != "text/html" && type != "application/xhtml+xml" {
            throw URLError(.cannotDecodeContentData)
        }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            data.append(byte)
            if data.count >= limit { break }
        }
        return (data, response)
    }

    private static func matches(_ pattern: String, in text: String, group: Int = 0) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            guard let range = Range($0.range(at: group), in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func attributes(_ tag: String) -> [String: String] {
        let pattern = #"([a-z_:][-a-z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [:] }
        var result: [String: String] = [:]
        for match in regex.matches(in: tag, range: NSRange(tag.startIndex..., in: tag)) {
            guard let key = Range(match.range(at: 1), in: tag) else { continue }
            for index in 2...4 {
                if let value = Range(match.range(at: index), in: tag) {
                    result[String(tag[key]).lowercased()] = String(tag[value])
                    break
                }
            }
        }
        return result
    }

    private static func clean(_ text: String) -> String {
        var value = text.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
        for (entity, replacement) in [("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
                                      ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")] {
            value = value.replacingOccurrences(of: entity, with: replacement)
        }
        let pattern = #"&#(x[0-9a-f]+|[0-9]+);"#
        for entity in matches(pattern, in: value) {
            let number = String(entity.dropFirst(2).dropLast())
            let hexadecimal = number.lowercased().hasPrefix("x")
            if let code = UInt32(hexadecimal ? String(number.dropFirst()) : number, radix: hexadecimal ? 16 : 10),
               let scalar = UnicodeScalar(code) {
                value = value.replacingOccurrences(of: entity, with: String(scalar))
            }
        }
        return value.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
