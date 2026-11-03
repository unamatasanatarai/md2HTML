import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// Where a top-level Markdown block starts in the input and where its HTML starts in the output.
/// Both offsets are UTF-16 (NSString) offsets, matching NSTextView.
public struct ConversionAnchor: Equatable {
    public let markdownOffset: Int
    public let htmlOffset: Int
}

public struct Conversion {
    public let html: String
    /// One anchor per top-level block, in document order. Used to synchronize scrolling.
    public let anchors: [ConversionAnchor]
}

/// GitHub-flavored Markdown to an indented HTML fragment, via the vendored cmark-gfm. No AppKit.
public enum MarkdownConverter {
    /// GFM extensions to enable. "tagfilter" is deliberately left out so raw HTML passes through.
    static let extensions = ["table", "strikethrough", "tasklist", "autolink"]

    /// Unsafe mode: raw HTML and all link schemes are copied as-is (no sanitizing).
    static let options: Int32 = CMARK_OPT_UNSAFE

    public static func html(from markdown: String) -> String {
        return convert(markdown).html
    }

    /// Converts the whole document. Pure and stateless; safe to call on every keystroke.
    /// Each top-level block is rendered and indented on its own, so block boundaries become anchors.
    public static func convert(_ markdown: String) -> Conversion {
        cmark_gfm_core_extensions_ensure_registered()

        guard let parser = cmark_parser_new(options) else { return Conversion(html: "", anchors: []) }
        defer { cmark_parser_free(parser) }

        for name in extensions {
            let ext = cmark_find_syntax_extension(name)
            assert(ext != nil, "cmark-gfm extension '\(name)' not found")
            if let ext = ext {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        markdown.withCString { cmark_parser_feed(parser, $0, strlen($0)) }

        guard let document = cmark_parser_finish(parser) else { return Conversion(html: "", anchors: []) }
        defer { cmark_node_free(document) }

        let syntaxExtensions = cmark_parser_get_syntax_extensions(parser)
        let lineStarts = lineStartOffsets(markdown)

        var html = ""
        var htmlLength = 0
        var anchors: [ConversionAnchor] = []
        var node = cmark_node_first_child(document)
        while let block = node {
            if let rendered = cmark_render_html(block, options, syntaxExtensions) {
                let chunk = HTMLIndenter.indent(String(cString: rendered))
                free(rendered)

                let line = Int(cmark_node_get_start_line(block)) // 1-based
                let markdownOffset = lineStarts[min(max(line - 1, 0), lineStarts.count - 1)]
                anchors.append(ConversionAnchor(markdownOffset: markdownOffset, htmlOffset: htmlLength))
                html += chunk
                htmlLength += chunk.utf16.count
            }
            node = cmark_node_next(block)
        }
        return Conversion(html: html, anchors: anchors)
    }

    /// Unindented whole-document render. Tests use it to prove block-wise rendering loses nothing.
    static func renderWholeDocumentForTesting(_ markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()
        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }
        for name in extensions {
            if let ext = cmark_find_syntax_extension(name) { cmark_parser_attach_syntax_extension(parser, ext) }
        }
        markdown.withCString { cmark_parser_feed(parser, $0, strlen($0)) }
        guard let document = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(document) }
        guard let rendered = cmark_render_html(document, options, cmark_parser_get_syntax_extensions(parser)) else { return "" }
        defer { free(rendered) }
        return String(cString: rendered)
    }

    /// UTF-16 offset of the start of each line. Lines end at "\n", "\r\n", or "\r", as in CommonMark.
    static func lineStartOffsets(_ text: String) -> [Int] {
        var starts = [0]
        let units = Array(text.utf16)
        var i = 0
        while i < units.count {
            if units[i] == 0x0D { // \r
                if i + 1 < units.count, units[i + 1] == 0x0A { i += 1 }
                starts.append(i + 1)
            } else if units[i] == 0x0A { // \n
                starts.append(i + 1)
            }
            i += 1
        }
        return starts
    }
}
