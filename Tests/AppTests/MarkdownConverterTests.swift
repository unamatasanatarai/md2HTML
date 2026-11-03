import Foundation

/// Fixture Markdown -> expected cmark-gfm HTML, one case per PRD success item.
public enum MarkdownConverterTests {
    public static func run(testRunner: (String, () throws -> Void) -> Void) {
        func html(_ markdown: String) -> String {
            return MarkdownConverter.html(from: markdown)
        }

        testRunner("Converter: heading") {
            let out = html("# Hi")
            assert(out == "<h1>Hi</h1>\n", "got \(out.debugDescription)")
        }

        testRunner("Converter: emphasis and strong") {
            let out = html("*a* and **b**")
            assert(out == "<p><em>a</em> and <strong>b</strong></p>\n", "got \(out.debugDescription)")
        }

        testRunner("Converter: unordered list") {
            let out = html("- a\n- b")
            assert(out == "<ul>\n  <li>a</li>\n  <li>b</li>\n</ul>\n", "got \(out.debugDescription)")
        }

        testRunner("Converter: link") {
            let out = html("[x](https://example.com)")
            assert(out == "<p><a href=\"https://example.com\">x</a></p>\n", "got \(out.debugDescription)")
        }

        testRunner("Converter: fenced code block with language") {
            let out = html("```swift\nlet x = 1\n```")
            assert(out == "<pre><code class=\"language-swift\">let x = 1\n</code></pre>\n", "got \(out.debugDescription)")
        }

        testRunner("Converter: GFM table") {
            let out = html("| a | b |\n|---|---|\n| 1 | 2 |")
            let expected = """
            <table>
              <thead>
                <tr>
                  <th>a</th>
                  <th>b</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>1</td>
                  <td>2</td>
                </tr>
              </tbody>
            </table>

            """
            assert(out == expected, "got \(out.debugDescription)")
        }

        testRunner("Converter: strikethrough") {
            let out = html("~~x~~")
            assert(out == "<p><del>x</del></p>\n", "got \(out.debugDescription)")
        }

        testRunner("Converter: task list") {
            let out = html("- [x] done\n- [ ] todo")
            assert(out.contains("<input type=\"checkbox\" checked=\"\" disabled=\"\" /> done"), "got \(out.debugDescription)")
            assert(out.contains("<input type=\"checkbox\" disabled=\"\" /> todo"), "got \(out.debugDescription)")
        }

        testRunner("Converter: bare URL autolink") {
            let out = html("see https://example.com now")
            assert(out == "<p>see <a href=\"https://example.com\">https://example.com</a> now</p>\n", "got \(out.debugDescription)")
        }

        testRunner("Converter: raw HTML block passes through") {
            let out = html("<div>raw <b>html</b></div>")
            assert(out == "<div>raw <b>html</b></div>\n", "got \(out.debugDescription)")
        }

        testRunner("Converter: inline raw HTML passes through") {
            let out = html("a <b>hi</b><br> c")
            assert(out == "<p>a <b>hi</b><br> c</p>\n", "got \(out.debugDescription)")
        }

        testRunner("Converter: <style> passes through (no tagfilter)") {
            let out = html("<style>p { color: red }</style>")
            assert(out == "<style>p { color: red }</style>\n", "got \(out.debugDescription)")
        }

        testRunner("Converter: typed punctuation is not smartened") {
            let out = html("\"q\" -- it's")
            assert(out == "<p>&quot;q&quot; -- it's</p>\n", "got \(out.debugDescription)")
        }

        testRunner("Converter: empty input gives empty output") {
            let out = html("")
            assert(out == "", "got \(out.debugDescription)")
        }

        testRunner("Converter: README-sized document (~400 lines; elapsed time is the speed check)") {
            let section = "## Section\n\nSome *text* with a [link](https://example.com) and `code`.\n\n- [x] done\n- [ ] todo\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n```swift\nlet x = 1\n```\n\n"
            let out = html(String(repeating: section, count: 25))
            assert(out.components(separatedBy: "<h2>").count == 26, "every section should convert")
        }

        testRunner("Indent: nested lists, loose items, and blockquotes use two spaces per level") {
            let out = html("- a\n  - b\n\n> q\n> - c")
            let expected = """
            <ul>
              <li>a
                <ul>
                  <li>b</li>
                </ul>
              </li>
            </ul>
            <blockquote>
              <p>q</p>
              <ul>
                <li>c</li>
              </ul>
            </blockquote>

            """
            assert(out == expected, "got \(out.debugDescription)")
        }

        testRunner("Indent: code block content inside a list is left untouched") {
            let out = html("- item\n\n  ```\n  line 1\n    line 2\n  ```")
            assert(out.contains("    <pre><code>line 1\n  line 2\n</code></pre>\n"), "got \(out.debugDescription)")
        }

        testRunner("Indent: raw <pre> and <script> blocks keep their own whitespace") {
            let raw = "<pre>\n  a\n</pre>\n\n<script>\n  let x = 1\n</script>"
            let out = html(raw)
            // cmark drops the blank line between blocks; whitespace inside each block is kept.
            assert(out == "<pre>\n  a\n</pre>\n<script>\n  let x = 1\n</script>\n", "got \(out.debugDescription)")
        }

        testRunner("Anchors: one per top-level block, at its Markdown line and HTML start") {
            let markdown = "# A\n\npara\n\n- x\n- y"
            let conversion = MarkdownConverter.convert(markdown)
            let html = conversion.html as NSString
            let md = markdown as NSString
            assert(conversion.anchors.map { $0.markdownOffset } == [0, 5, 11], "got \(conversion.anchors)")
            let heads = conversion.anchors.map { html.substring(from: $0.htmlOffset).prefix(4) }
            assert(heads == ["<h1>", "<p>p", "<ul>"], "got \(heads)")
            assert(md.substring(from: conversion.anchors[2].markdownOffset).hasPrefix("- x"))
        }

        testRunner("Anchors: CRLF and CR line endings and non-ASCII offsets are UTF-16") {
            let markdown = "# Zażółć 🎉\r\n\r\npara\r\rnext"
            let conversion = MarkdownConverter.convert(markdown)
            let md = markdown as NSString
            let starts = conversion.anchors.map { md.substring(from: $0.markdownOffset).prefix(4) }
            assert(starts == ["# Za", "para", "next"], "got \(starts)")
        }

        testRunner("Anchors: concatenated block output equals a whole-document render") {
            let markdown = "# T\n\n| a |\n|---|\n| 1 |\n\n- [x] t\n\n~~s~~ https://e.com\n\n<div>r</div>\n\n```\nc\n```"
            let conversion = MarkdownConverter.convert(markdown)
            let whole = HTMLIndenter.indent(MarkdownConverter.renderWholeDocumentForTesting(markdown))
            assert(conversion.html == whole, "block-wise:\n\(conversion.html)\nwhole:\n\(whole)")
        }

        testRunner("Converter: non-ASCII text round-trips") {
            let out = html("# Zażółć 🎉")
            assert(out == "<h1>Zażółć 🎉</h1>\n", "got \(out.debugDescription)")
        }
    }
}
