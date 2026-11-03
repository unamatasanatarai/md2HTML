import Cocoa

public enum AppTests {
    public static func run(testRunner: (String, () throws -> Void) -> Void) {
        testRunner("AppConfig returns valid non-empty application name") {
            assert(!AppConfig.appName.isEmpty, "App name should not be empty")
        }

        testRunner("AppConfig returns valid bundle identifier") {
            assert(!AppConfig.bundleIdentifier.isEmpty, "Bundle identifier should not be empty")
            assert(AppConfig.bundleIdentifier.contains("."), "Bundle identifier should be reverse-DNS style")
        }

        testRunner("AppConfig provides version string") {
            assert(!AppConfig.version.isEmpty, "Version should not be empty")
        }

        testRunner("AppConfig provides build number") {
            assert(!AppConfig.buildNumber.isEmpty, "Build number should not be empty")
        }

        testRunner("AppDelegate quits after the last window closes") {
            assert(AppDelegate().applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
        }

        runClipboardTests(testRunner: testRunner)
        runPaneTests(testRunner: testRunner)
        runEditorTests(testRunner: testRunner)
        runScrollTests(testRunner: testRunner)
        runMenuTests(testRunner: testRunner)
    }

    /// A private, uniquely named pasteboard so tests never touch the user's clipboard.
    private static func withTestPasteboard(_ body: (NSPasteboard) -> Void) {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("md2html-test-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        body(pasteboard)
    }

    private static func runClipboardTests(testRunner: (String, () throws -> Void) -> Void) {
        testRunner("ClipboardLoader returns plain text") {
            withTestPasteboard { pb in
                pb.setString("# Hello", forType: .string)
                assert(ClipboardLoader.text(from: pb) == "# Hello")
            }
        }

        testRunner("ClipboardLoader skips concealed (password) content") {
            withTestPasteboard { pb in
                pb.declareTypes([.string, ClipboardLoader.concealedType], owner: nil)
                pb.setString("hunter2", forType: .string)
                pb.setData(Data(), forType: ClipboardLoader.concealedType)
                assert(ClipboardLoader.text(from: pb) == nil)
            }
        }

        testRunner("ClipboardLoader skips image-only content") {
            withTestPasteboard { pb in
                pb.setData(Data([0x4D, 0x4D, 0x00, 0x2A]), forType: .tiff)
                assert(ClipboardLoader.text(from: pb) == nil)
            }
        }

        testRunner("ClipboardLoader enforces the 1 MB size limit") {
            withTestPasteboard { pb in
                pb.setString(String(repeating: "a", count: ClipboardLoader.maxBytes + 1), forType: .string)
                assert(ClipboardLoader.text(from: pb) == nil)
            }
            withTestPasteboard { pb in
                pb.setString(String(repeating: "a", count: ClipboardLoader.maxBytes), forType: .string)
                assert(ClipboardLoader.text(from: pb)?.utf8.count == ClipboardLoader.maxBytes)
            }
        }

        testRunner("ClipboardLoader skips empty text") {
            withTestPasteboard { pb in
                pb.setString("", forType: .string)
                assert(ClipboardLoader.text(from: pb) == nil)
            }
        }
    }

    private static func runPaneTests(testRunner: (String, () throws -> Void) -> Void) {
        testRunner("Markdown pane: insert fires onChange, selects, and is undoable") {
            let pane = MarkdownPaneViewController()
            _ = pane.view
            var changes: [String] = []
            pane.onChange = { changes.append($0) }

            pane.insertReplacingAll("x")
            assert(changes.last == "x", "onChange should report the inserted text, got \(changes)")
            assert(pane.textView.selectedRange() == NSRange(location: 0, length: 1), "inserted text should be selected")

            // Without a running event loop all edits share one undo group, so undo once.
            pane.textView.undoManager?.undo()
            assert(pane.textView.string == "", "undo should restore empty editor, got \(pane.textView.string.debugDescription)")
            assert(changes.last == "", "undo should report the change, got \(changes)")

            pane.insertReplacingAll("abc")
            pane.insertReplacingAll("def")
            assert(pane.textView.string == "def", "insert should replace everything")
        }

        testRunner("Markdown pane: plain text, undo on, no automatic substitutions") {
            let pane = MarkdownPaneViewController()
            _ = pane.view
            let tv: NSTextView = pane.textView
            assert(tv.isEditable && tv.allowsUndo && !tv.isRichText && !tv.importsGraphics)
            assert(!tv.isAutomaticQuoteSubstitutionEnabled)
            assert(!tv.isAutomaticDashSubstitutionEnabled)
            assert(!tv.isAutomaticTextReplacementEnabled)
            assert(!tv.isAutomaticSpellingCorrectionEnabled)
            assert(!tv.isContinuousSpellCheckingEnabled)
            assert(!tv.isAutomaticLinkDetectionEnabled)
            assert(tv.font?.fontDescriptor.symbolicTraits.contains(.monoSpace) == true, "font should be monospaced")
            assert(tv.textContainer?.widthTracksTextView == true, "long lines should wrap")
        }

        testRunner("HTML pane: read-only, selectable, shows text") {
            let pane = HTMLPaneViewController()
            _ = pane.view
            pane.show(html: "<p>x</p>\n")
            assert(pane.textView.string == "<p>x</p>\n")
            assert(!pane.textView.isEditable && pane.textView.isSelectable && !pane.textView.isRichText)
            assert(pane.copyButton.action == #selector(EditorWindowController.copyHTML(_:)))
            assert(pane.copyButton.target == nil, "Copy HTML button should use the responder chain")
        }

        testRunner("HTML pane: Copy HTML icon shows the arrow cursor and a hover state") {
            let pane = HTMLPaneViewController()
            _ = pane.view
            let button = pane.copyButton!
            button.updateTrackingAreas()
            let options = button.trackingOptions ?? []
            assert(options.contains(.cursorUpdate) && options.contains(.mouseEnteredAndExited), "got \(options)")

            func event(_ type: NSEvent.EventType) -> NSEvent {
                return NSEvent.enterExitEvent(
                    with: type, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                    context: nil, eventNumber: 0, trackingNumber: 0, userData: nil
                )!
            }
            func backgroundAlpha() -> CGFloat {
                return button.layer?.backgroundColor?.alpha ?? 0
            }

            assert(!button.isHovered && backgroundAlpha() == 0 && button.contentTintColor == .secondaryLabelColor)

            NSCursor.iBeam.set()
            button.cursorUpdate(with: event(.mouseEntered))
            assert(NSCursor.current == NSCursor.arrow, "cursor over the icon should be the arrow")

            button.mouseEntered(with: event(.mouseEntered))
            assert(button.isHovered && backgroundAlpha() > 0 && button.contentTintColor == .labelColor, "hover style")

            button.mouseExited(with: event(.mouseExited))
            assert(!button.isHovered && backgroundAlpha() == 0 && button.contentTintColor == .secondaryLabelColor, "back to rest")
        }

        testRunner("HTML pane: text under the Copy HTML icon shows the arrow, not the I-beam") {
            let editor = EditorWindowController()
            editor.markdownPane.insertReplacingAll(String(repeating: "Some long paragraph text here.\n\n", count: 80))
            guard let window = editor.window else { assertionFailure("window missing"); return }
            window.layoutIfNeeded()
            let pane = editor.htmlPane
            let textView = pane.textView!
            let button = pane.copyButton!

            assert(pane.scrollView.contentView is NoDocumentCursorClipView)
            textView.isSelectable = true // NSTextView re-installs an I-beam documentCursor here
            assert(pane.scrollView.documentCursor == nil, "an I-beam documentCursor would cover the icon")

            // Cursor rects: arrow exactly over the icon, I-beam everywhere else, no overlap.
            let iconRect = textView.convert(button.bounds, from: button)
            let regions = textView.cursorRegions()
            let arrows = regions.filter { $0.cursor == NSCursor.arrow }.map { $0.rect }
            let beams = regions.filter { $0.cursor == NSCursor.iBeam }.map { $0.rect }
            assert(arrows == [iconRect.intersection(textView.visibleRect)], "got \(arrows) for icon \(iconRect)")
            assert(!beams.isEmpty && beams.allSatisfy { !$0.intersects(iconRect) }, "I-beam rects must avoid the icon: \(beams)")
            let visibleArea = textView.visibleRect.width * textView.visibleRect.height
            let coveredArea = regions.reduce(CGFloat(0)) { $0 + $1.rect.width * $1.rect.height }
            assert(abs(coveredArea - visibleArea) < 1, "regions should tile the visible text exactly")

            // Events the text view receives while the mouse is over the icon keep the arrow.
            let center = button.convert(NSPoint(x: button.bounds.midX, y: button.bounds.midY), to: nil)
            let moved = NSEvent.mouseEvent(
                with: .mouseMoved, location: center, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0
            )!
            NSCursor.iBeam.set()
            textView.mouseMoved(with: moved)
            assert(NSCursor.current == NSCursor.arrow, "mouseMoved over the icon should show the arrow")
            NSCursor.iBeam.set()
            textView.cursorUpdate(with: moved)
            assert(NSCursor.current == NSCursor.arrow, "cursorUpdate over the icon should show the arrow")

            // Scrolled down, the icon still stays excluded (it does not scroll with the text).
            let clip = pane.scrollView.contentView
            clip.scroll(to: NSPoint(x: 0, y: 400))
            pane.scrollView.reflectScrolledClipView(clip)
            let scrolledIcon = textView.convert(button.bounds, from: button)
            assert(textView.cursorRegions().filter { $0.cursor == NSCursor.arrow }.map { $0.rect } == [scrolledIcon.intersection(textView.visibleRect)])
        }

        testRunner("ArrowRegionTextView: subtracting a hole tiles the rest of the rect") {
            let rect = NSRect(x: 0, y: 0, width: 100, height: 100)
            let pieces = ArrowRegionTextView.subtract(NSRect(x: 80, y: 0, width: 20, height: 20), from: rect)
            let area = pieces.reduce(CGFloat(0)) { $0 + $1.width * $1.height }
            assert(area == 100 * 100 - 20 * 20, "got \(pieces)")
            assert(ArrowRegionTextView.subtract(NSRect(x: 200, y: 200, width: 5, height: 5), from: rect) == [rect])
        }

        testRunner("Copy HTML: shows 'Copied to clipboard' next to the icon, then hides it") {
            let editor = EditorWindowController()
            let pane = editor.htmlPane
            pane.copiedFeedbackDuration = 0.05
            func spin(_ seconds: TimeInterval) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

            assert(pane.copiedFeedback.isHidden, "hidden before any copy")
            withTestPasteboard { pb in editor.copyHTML(to: pb) }
            assert(!pane.copiedFeedback.isHidden, "shown right after copying")
            assert(pane.copiedLabel.stringValue == "Copied to clipboard")

            pane.view.layoutSubtreeIfNeeded()
            let pill = pane.copiedFeedback.frame, icon = pane.copyButton.frame
            assert(pill.maxX <= icon.minX && icon.minX - pill.maxX <= 10, "pill should sit just left of the icon: \(pill) vs \(icon)")
            assert(abs(pill.midY - icon.midY) <= 1, "pill should be vertically centered on the icon")

            spin(0.6)
            assert(pane.copiedFeedback.isHidden, "hidden after the hold and fade")
        }

        testRunner("Copy HTML: copying again while shown restarts the hold") {
            let editor = EditorWindowController()
            let pane = editor.htmlPane
            pane.copiedFeedbackDuration = 0.3
            func spin(_ seconds: TimeInterval) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

            withTestPasteboard { pb in editor.copyHTML(to: pb) }
            spin(0.2)
            withTestPasteboard { pb in editor.copyHTML(to: pb) }
            spin(0.25) // the first hold would have ended by now
            assert(!pane.copiedFeedback.isHidden && pane.copiedFeedback.alphaValue > 0.9, "second copy should keep it up")
            spin(0.7)
            assert(pane.copiedFeedback.isHidden, "eventually hides")
        }

        testRunner("HTML pane: Copy HTML is an icon in the top-right corner") {
            let pane = HTMLPaneViewController()
            pane.view.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
            pane.view.layoutSubtreeIfNeeded()
            let button = pane.copyButton!
            assert(button.title.isEmpty && button.image != nil && button.imagePosition == .imageOnly, "should be icon-only")
            assert(!button.isBordered)
            assert(button.accessibilityLabel() == "Copy HTML")
            let bounds = pane.view.bounds
            // Unflipped container: top edge is maxY.
            assert(bounds.maxY - button.frame.maxY <= 12, "should hug the top, got \(button.frame)")
            assert(bounds.maxX - button.frame.maxX <= 30, "should hug the right edge, got \(button.frame)")
        }

        testRunner("HTML pane: update keeps scroll position, clamped to new height") {
            let pane = HTMLPaneViewController()
            _ = pane.view
            pane.view.frame = NSRect(x: 0, y: 0, width: 400, height: 200)

            let long = (1...200).map { "<p>line \($0)</p>" }.joined(separator: "\n")
            pane.show(html: long)
            let clip = pane.scrollView.contentView
            clip.scroll(to: NSPoint(x: 0, y: 300))
            pane.scrollView.reflectScrolledClipView(clip)
            assert(clip.bounds.origin.y == 300, "precondition: scrolled, got \(clip.bounds.origin.y)")

            pane.show(html: long + "\n<p>more</p>")
            assert(clip.bounds.origin.y == 300, "scroll should be kept, got \(clip.bounds.origin.y)")

            pane.show(html: "<p>short</p>")
            assert(clip.bounds.origin.y == 0, "scroll should clamp to the new height, got \(clip.bounds.origin.y)")
        }
    }

    /// Top of the line containing the first occurrence of `needle` in the text view.
    private static func lineTop(of needle: String, in textView: NSTextView) -> CGFloat {
        let range = (textView.string as NSString).range(of: needle)
        precondition(range.location != NSNotFound, "\(needle) not found")
        let layoutManager = textView.layoutManager!
        layoutManager.ensureLayout(for: textView.textContainer!)
        let glyph = layoutManager.glyphIndexForCharacter(at: range.location)
        return layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY + textView.textContainerOrigin.y
    }

    private static func scroll(_ scrollView: NSScrollView, toY y: CGFloat) {
        let clip = scrollView.contentView
        clip.scroll(to: NSPoint(x: 0, y: y))
        scrollView.reflectScrolledClipView(clip)
    }

    private static func runScrollTests(testRunner: (String, () throws -> Void) -> Void) {
        testRunner("ScrollMap: interpolates between points and clamps at the ends") {
            let map = ScrollMap(points: [(0, 0), (100, 300), (200, 400)])
            assert(map.map(50) == 150)
            assert(map.map(150) == 350)
            assert(map.map(-10) == 0 && map.map(999) == 400)
            assert(map.inverted.map(350) == 150)
        }

        testRunner("ScrollMap: drops points that would make it non-monotonic") {
            let map = ScrollMap(points: [(0, 0), (100, 100), (90, 200), (150, 100), (200, 300)])
            assert(map.points.map { $0.source } == [0, 100, 200], "got \(map.points)")
        }

        // Tables grow ~4x from Markdown to HTML, so proportional scrolling would drift; anchors must not.
        let markdown = (1...40).map { "## Section \($0)\n\n| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |\n" }.joined(separator: "\n")

        testRunner("Scroll sync: scrolling Markdown to a heading brings its HTML to the top") {
            let editor = EditorWindowController()
            editor.markdownPane.insertReplacingAll(markdown)
            let input = editor.markdownPane, output = editor.htmlPane

            scroll(input.scrollView, toY: lineTop(of: "## Section 20\n", in: input.textView))
            let expected = lineTop(of: "<h2>Section 20</h2>", in: output.textView)
            let actual = output.scrollView.contentView.bounds.origin.y
            assert(abs(actual - expected) <= 2, "HTML top should be at Section 20 (\(expected)), got \(actual)")
        }

        testRunner("Scroll sync: scrolling HTML to a heading brings its Markdown to the top") {
            let editor = EditorWindowController()
            editor.markdownPane.insertReplacingAll(markdown)
            let input = editor.markdownPane, output = editor.htmlPane

            scroll(output.scrollView, toY: lineTop(of: "<h2>Section 30</h2>", in: output.textView))
            let expected = lineTop(of: "## Section 30\n", in: input.textView)
            let actual = input.scrollView.contentView.bounds.origin.y
            assert(abs(actual - expected) <= 2, "Markdown top should be at Section 30 (\(expected)), got \(actual)")
        }

        testRunner("Scroll sync: bottom follows bottom; top follows top") {
            let editor = EditorWindowController()
            editor.markdownPane.insertReplacingAll(markdown)
            let input: NSScrollView = editor.markdownPane.scrollView, output: NSScrollView = editor.htmlPane.scrollView
            func maxY(_ v: NSScrollView) -> CGFloat { return v.documentView!.frame.height - v.contentView.bounds.height }

            scroll(input, toY: maxY(input))
            assert(abs(output.contentView.bounds.origin.y - maxY(output)) <= 1, "output should be at its bottom")
            scroll(input, toY: 0)
            assert(output.contentView.bounds.origin.y == 0, "output should be at its top")
        }

        testRunner("Scroll sync: a new conversion keeps the HTML aligned and does not move the Markdown") {
            let editor = EditorWindowController()
            editor.markdownPane.insertReplacingAll(markdown)
            let input = editor.markdownPane, output = editor.htmlPane
            let target = lineTop(of: "## Section 10\n", in: input.textView)
            scroll(input.scrollView, toY: target)

            // Edit far below the viewport, through the normal edit path.
            let end = (input.textView.string as NSString).length
            input.textView.setSelectedRange(NSRange(location: end, length: 0))
            input.textView.insertText("\n\nmore", replacementRange: NSRange(location: end, length: 0))
            scroll(input.scrollView, toY: target) // insertText scrolls to the caret; return to Section 10

            assert(input.scrollView.contentView.bounds.origin.y == target, "Markdown pane should stay put")
            let expected = lineTop(of: "<h2>Section 10</h2>", in: output.textView)
            assert(abs(output.scrollView.contentView.bounds.origin.y - expected) <= 2, "HTML should stay aligned")
        }
    }

    private static func runEditorTests(testRunner: (String, () throws -> Void) -> Void) {
        testRunner("Editor: input edits produce converted HTML in the output pane") {
            let editor = EditorWindowController()
            editor.markdownPane.insertReplacingAll("# Hi")
            assert(editor.htmlPane.textView.string == "<h1>Hi</h1>\n", "got \(editor.htmlPane.textView.string.debugDescription)")

            editor.markdownPane.textView.undoManager?.undo()
            assert(editor.htmlPane.textView.string == "", "undo should clear the output too")
        }

        testRunner("Editor: window title, size, and 50/50 split") {
            let editor = EditorWindowController()
            guard let window = editor.window else { assertionFailure("window missing"); return }
            assert(window.title == AppConfig.appName)
            assert(window.contentLayoutRect.size == NSSize(width: 900, height: 600), "got \(window.contentLayoutRect.size)")
            let left = editor.markdownPane.view.frame.width
            let right = editor.htmlPane.view.frame.width
            assert(abs(left - right) <= 2, "panes should start 50/50, got \(left) / \(right)")
        }

        testRunner("Editor: launch clipboard load and Copy HTML") {
            let editor = EditorWindowController()
            withTestPasteboard { pb in
                pb.setString("**b**", forType: .string)
                editor.loadClipboard(from: pb)
            }
            assert(editor.markdownPane.textView.string == "**b**")
            assert(editor.htmlPane.textView.string == "<p><strong>b</strong></p>\n")

            withTestPasteboard { pb in
                editor.copyHTML(to: pb)
                assert(pb.string(forType: .string) == "<p><strong>b</strong></p>\n")
            }
        }

        testRunner("Editor: concealed clipboard leaves the editor empty") {
            let editor = EditorWindowController()
            withTestPasteboard { pb in
                pb.declareTypes([.string, ClipboardLoader.concealedType], owner: nil)
                pb.setString("secret", forType: .string)
                editor.loadClipboard(from: pb)
            }
            assert(editor.markdownPane.textView.string.isEmpty)
            assert(editor.htmlPane.textView.string.isEmpty)
        }
    }

    private static func runMenuTests(testRunner: (String, () throws -> Void) -> Void) {
        testRunner("MainMenu: App, Edit, and Window menus") {
            let menu = MainMenu.make(appName: "md2HTML")
            let titles = menu.items.compactMap { $0.submenu?.title }
            assert(titles == ["md2HTML", "Edit", "Window"], "got \(titles)")

            let app = menu.items[0].submenu!
            assert(app.items.contains { $0.action == #selector(NSApplication.terminate(_:)) && $0.keyEquivalent == "q" })
        }

        testRunner("MainMenu: Edit menu has standard items and Copy HTML (Shift-Command-C)") {
            let menu = MainMenu.make(appName: "md2HTML")
            guard let edit = menu.items.first(where: { $0.submenu?.title == "Edit" })?.submenu else {
                assertionFailure("Edit menu missing"); return
            }
            let actions = edit.items.compactMap { $0.action.map(NSStringFromSelector) }
            for expected in ["undo:", "redo:", "cut:", "copy:", "paste:", "selectAll:", "copyHTML:"] {
                assert(actions.contains(expected), "Edit menu missing \(expected), got \(actions)")
            }

            guard let copyHTML = edit.items.first(where: { $0.title == "Copy HTML" }) else {
                assertionFailure("Copy HTML missing"); return
            }
            assert(copyHTML.keyEquivalent.lowercased() == "c")
            let mods = copyHTML.keyEquivalentModifierMask.intersection(.deviceIndependentFlagsMask)
            assert(mods == [.command, .shift], "got \(mods)")
            assert(copyHTML.target == nil, "Copy HTML should use the responder chain")
        }
    }
}
