import Cocoa

/// Keeps the Markdown and HTML panes scrolled to matching blocks, in both directions.
/// Positions between block anchors are interpolated; reaching the bottom of one pane
/// scrolls the other to its bottom.
public final class ScrollSynchronizer: NSObject {
    private let input: (scrollView: NSScrollView, textView: NSTextView)
    private let output: (scrollView: NSScrollView, textView: NSTextView)
    private var isSyncing = false

    /// Block anchors from the latest conversion.
    public var anchors: [ConversionAnchor] = []

    public init(input: (NSScrollView, NSTextView), output: (NSScrollView, NSTextView)) {
        self.input = (scrollView: input.0, textView: input.1)
        self.output = (scrollView: output.0, textView: output.1)
        super.init()
        for clip in [input.0.contentView, output.0.contentView] {
            clip.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(clipBoundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification, object: clip
            )
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Runs `body` (e.g. replacing the output text) without echoing its scroll changes.
    public func withoutSync(_ body: () -> Void) {
        let wasSyncing = isSyncing
        isSyncing = true
        defer { isSyncing = wasSyncing }
        body()
    }

    /// Scrolls the HTML pane to match the Markdown pane, e.g. after a new conversion.
    public func syncOutputToInput() {
        sync(from: input, to: output, map: scrollMap())
    }

    @objc private func clipBoundsDidChange(_ notification: Notification) {
        guard !isSyncing, let clip = notification.object as? NSClipView else { return }
        if clip === input.scrollView.contentView {
            sync(from: input, to: output, map: scrollMap())
        } else if clip === output.scrollView.contentView {
            sync(from: output, to: input, map: scrollMap().inverted)
        }
    }

    private func sync(
        from source: (scrollView: NSScrollView, textView: NSTextView),
        to target: (scrollView: NSScrollView, textView: NSTextView),
        map: ScrollMap
    ) {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let sourceY = source.scrollView.contentView.bounds.origin.y
        let sourceMax = maxScroll(source.scrollView)
        let targetMax = maxScroll(target.scrollView)

        let targetY: CGFloat
        if sourceMax > 0, sourceY >= sourceMax - 1 {
            targetY = targetMax // bottom follows bottom, even when the last block is short
        } else {
            targetY = min(max(map.map(sourceY), 0), targetMax)
        }

        let clip = target.scrollView.contentView
        guard abs(clip.bounds.origin.y - targetY) > 0.5 else { return }
        clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: targetY))
        target.scrollView.reflectScrolledClipView(clip)
    }

    /// Markdown-pane y → HTML-pane y, anchored at the top of each top-level block.
    func scrollMap() -> ScrollMap {
        var points: [(source: CGFloat, target: CGFloat)] = [(source: 0, target: 0)]
        for anchor in anchors {
            guard let inY = y(ofCharacterAt: anchor.markdownOffset, in: input.textView),
                  let outY = y(ofCharacterAt: anchor.htmlOffset, in: output.textView) else { continue }
            points.append((source: inY, target: outY))
        }
        points.append((source: input.textView.frame.height, target: output.textView.frame.height))
        return ScrollMap(points: points)
    }

    /// Top of the line containing the character, in the text view's (flipped) coordinates.
    private func y(ofCharacterAt offset: Int, in textView: NSTextView) -> CGFloat? {
        guard let layoutManager = textView.layoutManager, let container = textView.textContainer else { return nil }
        let length = (textView.string as NSString).length
        guard offset >= 0, offset < length else { return nil }
        layoutManager.ensureLayout(for: container)
        let glyph = layoutManager.glyphIndexForCharacter(at: offset)
        let rect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        return rect.minY + textView.textContainerOrigin.y
    }

    private func maxScroll(_ scrollView: NSScrollView) -> CGFloat {
        let documentHeight = scrollView.documentView?.frame.height ?? 0
        return max(0, documentHeight - scrollView.contentView.bounds.height)
    }
}
