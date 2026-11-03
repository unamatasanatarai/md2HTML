import Foundation

/// Indents cmark-gfm's line-per-block HTML by element nesting, two spaces per level.
/// Lines inside whitespace-sensitive elements (pre, textarea, script, style) are left untouched.
enum HTMLIndenter {
    static let unit = "  "

    /// Block containers cmark-gfm emits on their own lines; their contents are indented one level.
    static let containers: Set<String> = ["ul", "ol", "li", "blockquote", "table", "thead", "tbody", "tr"]

    /// Elements whose content must not be re-indented.
    static let verbatim: Set<String> = ["pre", "textarea", "script", "style"]

    private static let tagPattern = try! NSRegularExpression(pattern: "<(/?)([A-Za-z][A-Za-z0-9]*)\\b[^>]*>")

    static func indent(_ html: String) -> String {
        var depth = 0
        var verbatimTag: String?
        var output: [String] = []

        for line in html.components(separatedBy: "\n") {
            if let tag = verbatimTag {
                output.append(line)
                if closes(tag, in: line) { verbatimTag = nil }
                continue
            }
            if line.isEmpty {
                output.append(line)
                continue
            }

            let tags = scanTags(line)

            // Closing containers at the start of the line sit at their parent's level.
            var leadingClosers = 0
            var cursor = line.utf16.startIndex
            for tag in tags {
                let start = String.Index(utf16Offset: tag.range.location, in: line)
                guard line[cursor..<start].allSatisfy({ $0 == " " || $0 == "\t" }),
                      tag.isClosing, containers.contains(tag.name) else { break }
                leadingClosers += 1
                cursor = String.Index(utf16Offset: tag.range.location + tag.range.length, in: line)
            }

            output.append(String(repeating: unit, count: max(0, depth - leadingClosers)) + line)

            for tag in tags {
                if containers.contains(tag.name) {
                    depth = max(0, depth + (tag.isClosing ? -1 : 1))
                } else if !tag.isClosing, verbatim.contains(tag.name) {
                    let rest = line.utf16.count - (tag.range.location + tag.range.length)
                    let tail = String(line.utf16.suffix(rest)) ?? ""
                    if !closes(tag.name, in: tail) { verbatimTag = tag.name }
                    break
                }
            }
        }
        return output.joined(separator: "\n")
    }

    private struct Tag {
        let name: String
        let isClosing: Bool
        let range: NSRange
    }

    private static func scanTags(_ line: String) -> [Tag] {
        let ns = line as NSString
        return tagPattern.matches(in: line, range: NSRange(location: 0, length: ns.length)).map { match in
            Tag(
                name: ns.substring(with: match.range(at: 2)).lowercased(),
                isClosing: match.range(at: 1).length > 0,
                range: match.range
            )
        }
    }

    private static func closes(_ tag: String, in text: String) -> Bool {
        return text.range(of: "</\(tag)", options: .caseInsensitive) != nil
    }
}
