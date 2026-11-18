import Foundation

/// 地址发布页解析：HTML → script src → publish.js → var urls × var subdomains。
enum PublishParser {
    static func scriptSource(in html: String) -> String? {
        let pattern = #"src\s*=\s*["']([^"']+\.js[^"']*)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[valueRange])
    }

    static func absolute(base: String, relative: String) -> String {
        if relative.hasPrefix("http://") || relative.hasPrefix("https://") {
            return relative
        }
        guard let baseURL = URL(string: base),
              let scheme = baseURL.scheme,
              let host = baseURL.host else {
            return relative
        }
        if relative.hasPrefix("/") {
            return "\(scheme)://\(host)\(relative)"
        }
        return "\(scheme)://\(host)/\(relative)"
    }

    /// 取 `var <decl> = [ ... ]` 里的字符串数组；去掉引号外的行尾 `//` 注释。
    static func jsArray(_ source: String, declaration: String) -> [String] {
        guard let declRange = source.range(of: declaration) else { return [] }
        let rest = source[declRange.lowerBound...]
        guard let open = rest.firstIndex(of: "["),
              let close = rest[open...].firstIndex(of: "]") else { return [] }

        let body = rest[rest.index(after: open)..<close]
        return stripLineComments(String(body))
            .split(separator: ",")
            .map { raw in
                raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    /// 子域 × 域名；没有 subdomains 时把域名本身作为 host。
    static func mirrorURLs(js: String, limit: Int = 60) -> [String]? {
        let domains = jsArray(js, declaration: "var urls")
        guard !domains.isEmpty else { return nil }
        let subdomains = jsArray(js, declaration: "var subdomains")

        var seen = Set<String>()
        var result: [String] = []
        outer: for domain in domains {
            let cleanDomain = domain.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !cleanDomain.isEmpty else { continue }
            let hosts = subdomains.isEmpty
                ? [cleanDomain]
                : subdomains.map { "\($0).\(cleanDomain)" }

            for host in hosts where seen.insert(host).inserted {
                let url = "https://\(host)"
                guard let parsed = URL(string: url), parsed.host != nil else { continue }
                result.append(url)
                if result.count >= limit { break outer }
            }
        }
        return result.isEmpty ? nil : result
    }

    private static func stripLineComments(_ body: String) -> String {
        var out = ""
        var quote: Character?
        var iterator = body.makeIterator()

        while let character = iterator.next() {
            if let current = quote {
                out.append(character)
                if character == current { quote = nil }
            } else if character == "'" || character == "\"" {
                quote = character
                out.append(character)
            } else if character == "/", let next = iterator.next() {
                if next == "/" {
                    // 吃掉到行尾
                    while let next = iterator.next(), next != "\n" {}
                    out.append("\n")
                } else {
                    out.append(character)
                    out.append(next)
                }
            } else {
                out.append(character)
            }
        }
        return out
    }
}
