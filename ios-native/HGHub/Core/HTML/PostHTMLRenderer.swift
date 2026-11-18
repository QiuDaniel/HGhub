import Foundation
import UIKit
import ZMarkupParser
import ZNSTextAttachment

@MainActor
enum PostHTMLRenderer {
    private static let parser: ZHTMLParser = {
        let style = MarkupStyle(
            font: MarkupStyleFont(size: 15),
            paragraphStyle: MarkupStyleParagraphStyle(lineSpacing: 4, paragraphSpacing: 10),
            foregroundColor: MarkupStyleColor(color: .label)
        )
        return ZHTMLParserBuilder.initWithDefault()
            .set(rootStyle: style)
            .build()
    }()

    static func render(_ content: String, baseURL: URL) -> NSAttributedString {
        guard HTMLSanitizer.isHTML(content) else {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 4
            style.paragraphSpacing = 10
            return NSAttributedString(
                string: content,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 15),
                    .foregroundColor: UIColor.label,
                    .paragraphStyle: style,
                ]
            )
        }

        let clean = (try? HTMLSanitizer.sanitize(content, baseURL: baseURL)) ?? content
        return parser.render(clean)
    }
}
