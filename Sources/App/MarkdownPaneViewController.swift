import Cocoa

/// Left pane: editable plain-text Markdown. Reports every user edit through `onChange`.
public final class MarkdownPaneViewController: NSViewController, NSTextViewDelegate {
    public private(set) var textView: NSTextView!
    public var onChange: ((String) -> Void)?

    public var scrollView: NSScrollView {
        return view as! NSScrollView
    }

    /// Owned by the pane so undo works whether or not the view is in a window.
    private let textUndoManager = UndoManager()

    public override func loadView() {
        let (scrollView, textView) = TextViewFactory.makeScrollable(editable: true)
        scrollView.frame = NSRect(x: 0, y: 0, width: 450, height: 600)
        textView.delegate = self
        self.textView = textView
        view = scrollView
    }

    public func textDidChange(_ notification: Notification) {
        onChange?(textView.string)
    }

    public func undoManager(for view: NSTextView) -> UndoManager? {
        return textUndoManager
    }

    /// Undoable insert that replaces everything and fires `onChange` via the normal edit path,
    /// then selects the inserted text so typing replaces it.
    public func insertReplacingAll(_ text: String) {
        _ = view
        let whole = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.insertText(text, replacementRange: whole)
        // Keep the insert as its own undo step, separate from any typing that follows.
        textView.breakUndoCoalescing()
        textView.selectAll(nil)
    }
}
