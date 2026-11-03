import Cocoa

/// Shared setup for the plain, monospaced, wrapping text views used by both panes.
enum TextViewFactory {
    /// Pass `textView` to use a custom NSTextView subclass; it is installed in a scroll view whose
    /// clip view never takes a `documentCursor`, so the text view alone decides the cursor.
    static func makeScrollable(editable: Bool, textView custom: NSTextView? = nil) -> (NSScrollView, NSTextView) {
        let scrollView: NSScrollView
        let textView: NSTextView
        if let custom = custom {
            scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 450, height: 600))
            scrollView.contentView = NoDocumentCursorClipView()
            let size = scrollView.contentSize
            custom.frame = NSRect(origin: .zero, size: size)
            custom.minSize = NSSize(width: 0, height: size.height)
            custom.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            custom.textContainer?.containerSize = NSSize(width: size.width, height: CGFloat.greatestFiniteMagnitude)
            scrollView.documentView = custom
            textView = custom
        } else {
            scrollView = NSTextView.scrollableTextView()
            guard let made = scrollView.documentView as? NSTextView else {
                fatalError("scrollableTextView() did not provide an NSTextView")
            }
            textView = made
        }

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]

        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = editable
        textView.isEditable = editable
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 6, height: 8)

        // Defaults follow per-user global settings, so turn every rewrite off explicitly.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false

        // Wrap long lines to the pane width and follow live resizing.
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        return (scrollView, textView)
    }
}
