import Cocoa

/// Text view that shows the arrow cursor, not the I-beam, wherever an overlaid control sits on top
/// of it (e.g. the HTML pane's Copy HTML icon). Install it in a `NoDocumentCursorClipView`:
/// NSTextView puts an I-beam `documentCursor` on its clip view (e.g. when `isSelectable` is set),
/// and that clip-view cursor rect would cover the overlay again.
public final class ArrowRegionTextView: NSTextView {
    /// Views drawn over this text view where the arrow cursor must win.
    public var arrowViews: [NSView] = [] {
        didSet { window?.invalidateCursorRects(for: self) }
    }

    /// The icon stays put while the text scrolls under it, so cursor rects are rebuilt on every scroll.
    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
        guard let clip = superview as? NSClipView else { return }
        clip.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(clipDidScroll(_:)), name: NSView.boundsDidChangeNotification, object: clip
        )
    }

    @objc private func clipDidScroll(_ notification: Notification) {
        window?.invalidateCursorRects(for: self)
    }

    /// Overlay rects in this view's coordinates, clipped to the visible area.
    func arrowRects() -> [NSRect] {
        let visible = visibleRect
        return arrowViews.compactMap { view -> NSRect? in
            guard !view.isHidden, view.superview != nil else { return nil }
            let rect = convert(view.bounds, from: view).intersection(visible)
            return rect.isEmpty ? nil : rect
        }
    }

    /// Cursor rects: I-beam over the visible text except the overlays, arrow over the overlays.
    func cursorRegions() -> [(rect: NSRect, cursor: NSCursor)] {
        let holes = arrowRects()
        var beams = [visibleRect]
        for hole in holes {
            beams = beams.flatMap { Self.subtract(hole, from: $0) }
        }
        return beams.map { (rect: $0, cursor: NSCursor.iBeam) } + holes.map { (rect: $0, cursor: NSCursor.arrow) }
    }

    public override func resetCursorRects() {
        for region in cursorRegions() {
            addCursorRect(region.rect, cursor: region.cursor)
        }
    }

    public override func cursorUpdate(with event: NSEvent) {
        if isOverArrowView(event) {
            NSCursor.arrow.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    public override func mouseMoved(with event: NSEvent) {
        if isOverArrowView(event) {
            NSCursor.arrow.set()
        } else {
            super.mouseMoved(with: event)
        }
    }

    private func isOverArrowView(_ event: NSEvent) -> Bool {
        let point = convert(event.locationInWindow, from: nil)
        return arrowRects().contains { $0.contains(point) }
    }

    /// `rect` minus `hole`, as up to four non-overlapping rects.
    static func subtract(_ hole: NSRect, from rect: NSRect) -> [NSRect] {
        let cut = rect.intersection(hole)
        guard !cut.isEmpty else { return [rect] }
        let pieces = [
            NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: cut.minY - rect.minY),   // below
            NSRect(x: rect.minX, y: cut.maxY, width: rect.width, height: rect.maxY - cut.maxY),    // above
            NSRect(x: rect.minX, y: cut.minY, width: cut.minX - rect.minX, height: cut.height),    // left
            NSRect(x: cut.maxX, y: cut.minY, width: rect.maxX - cut.maxX, height: cut.height),     // right
        ]
        return pieces.filter { $0.width > 0 && $0.height > 0 }
    }
}

/// Clip view that never installs a document cursor, leaving cursor choice to its document view.
public final class NoDocumentCursorClipView: NSClipView {
    public override var documentCursor: NSCursor? {
        get { return nil }
        set {}
    }
}
