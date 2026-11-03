import Cocoa

/// Right pane: read-only, selectable HTML source with a Copy HTML icon in the top-right corner.
public final class HTMLPaneViewController: NSViewController {
    public private(set) var textView: ArrowRegionTextView!
    public private(set) var scrollView: NSScrollView!
    public private(set) var copyButton: HoverIconButton!

    /// "Copied to clipboard" pill shown just left of the copy icon after each copy.
    public private(set) var copiedFeedback: NSView!
    public private(set) var copiedLabel: NSTextField!
    /// How long the feedback stays fully visible before fading out.
    public var copiedFeedbackDuration: TimeInterval = 1.5
    public static let copiedMessage = "Copied to clipboard"

    private var feedbackGeneration = 0
    private var hideFeedbackWork: DispatchWorkItem?

    public override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 600))

        let textView = ArrowRegionTextView(frame: .zero)
        let (scrollView, _) = TextViewFactory.makeScrollable(editable: false, textView: textView)
        scrollView.frame = container.bounds
        container.addSubview(scrollView)

        // Icon-only button pinned to the top-right corner, clear of the vertical scroller.
        // Target nil: the action travels the responder chain to the window controller.
        let button = HoverIconButton(
            symbolName: "doc.on.doc",
            accessibilityLabel: "Copy HTML",
            target: nil,
            action: #selector(EditorWindowController.copyHTML(_:))
        )
        button.toolTip = "Copy HTML (⇧⌘C)"
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            button.widthAnchor.constraint(equalToConstant: 22),
            button.heightAnchor.constraint(equalToConstant: 22),
        ])

        let feedback = makeCopiedFeedback()
        container.addSubview(feedback)
        NSLayoutConstraint.activate([
            feedback.trailingAnchor.constraint(equalTo: button.leadingAnchor, constant: -6),
            feedback.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])

        // The text view underneath would otherwise show its I-beam over the icon and the pill.
        textView.arrowViews = [button, feedback]

        self.scrollView = scrollView
        self.textView = textView
        self.copyButton = button
        self.copiedFeedback = feedback
        view = container
    }

    private func makeCopiedFeedback() -> NSView {
        let pill = NSVisualEffectView()
        pill.material = .toolTip
        pill.blendingMode = .withinWindow
        pill.state = .active
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 5
        pill.layer?.masksToBounds = true
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.isHidden = true
        pill.alphaValue = 0

        let label = NSTextField(labelWithString: Self.copiedMessage)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -3),
        ])
        copiedLabel = label
        return pill
    }

    /// Fades the "Copied to clipboard" pill in, holds it, then fades it out.
    /// Copying again while it is showing restarts the hold.
    public func showCopiedFeedback() {
        _ = view
        feedbackGeneration += 1
        let generation = feedbackGeneration
        hideFeedbackWork?.cancel()

        copiedFeedback.isHidden = false
        textView.window?.invalidateCursorRects(for: textView)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            copiedFeedback.animator().alphaValue = 1
        }
        NSAccessibility.post(
            element: copyButton as Any, notification: .announcementRequested,
            userInfo: [.announcement: Self.copiedMessage, .priority: NSAccessibilityPriorityLevel.high.rawValue]
        )

        let work = DispatchWorkItem { [weak self] in self?.hideCopiedFeedback(generation: generation) }
        hideFeedbackWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + copiedFeedbackDuration, execute: work)
    }

    private func hideCopiedFeedback(generation: Int) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            copiedFeedback.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self = self, self.feedbackGeneration == generation else { return } // re-shown meanwhile
            self.copiedFeedback.isHidden = true
            self.textView.window?.invalidateCursorRects(for: self.textView)
        })
    }

    /// Replaces the output, keeping the visible scroll offset (clamped to the new content height).
    public func show(html: String) {
        _ = view
        let clip = scrollView.contentView
        let origin = clip.bounds.origin

        textView.string = html
        if let container = textView.textContainer {
            textView.layoutManager?.ensureLayout(for: container)
        }
        textView.sizeToFit()

        let maxY = max(0, textView.frame.height - clip.bounds.height)
        clip.scroll(to: NSPoint(x: 0, y: min(max(origin.y, 0), maxY)))
        scrollView.reflectScrolledClipView(clip)
    }
}
