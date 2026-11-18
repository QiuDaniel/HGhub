import Foundation
import SwiftSoup

enum HTMLSanitizerError: LocalizedError {
    case parseFailed

    var errorDescription: String? { "正文解析失败" }
}

enum HTMLSanitizer {
    static func isHTML(_ value: String) -> Bool {
        value.range(
            of: #"<(p|div|br|img|h[1-6]|ul|ol|li|blockquote|span|strong|em|a)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    static func sanitize(_ html: String, baseURL: URL) throws -> String {
        let document = try SwiftSoup.parseBodyFragment(html)
        try document.select("script, style, iframe, noscript, object, embed, form, input, button").remove()

        for element in try document.select("*") {
            let attributes = element.getAttributes()?.asList() ?? []
            for attribute in attributes {
                let key = attribute.getKey()
                let lower = key.lowercased()
                let value = attribute.getValue()

                if lower.hasPrefix("on") {
                    try element.removeAttr(key)
                    continue
                }
                if (lower == "href" || lower == "src"),
                   value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("javascript:") {
                    try element.removeAttr(key)
                    continue
                }
                if lower == "src" || lower == "href" {
                    try element.attr(key, resolve(value, base: baseURL))
                }
            }
        }

        for image in try document.select("img") {
            let dataSrc = try image.attr("data-src")
            if !dataSrc.isEmpty {
                try image.attr("src", resolve(dataSrc, base: baseURL))
                try image.removeAttr("data-src")
            }
            try image.removeAttr("srcset")
        }

        return try document.body()?.html() ?? ""
    }

    private static func resolve(_ value: String, base: URL) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("data:") {
            return trimmed
        }
        if trimmed.hasPrefix("//") {
            return "\(base.scheme ?? "https"):\(trimmed)"
        }
        return URL(string: trimmed, relativeTo: base)?.absoluteString ?? trimmed
    }
}
