import Cocoa

/// Borderless icon button that shows the arrow cursor (even over a text view) and a hover state:
/// a rounded background and a stronger tint while the mouse is over it.
public final class HoverIconButton: NSButton {
    public private(set) var isHovered = false {
        didSet { updateAppearance() }
    }

    private var hoverTrackingArea: NSTrackingArea?

    public convenience init(symbolName: String, accessibilityLabel: String, target: AnyObject?, action: Selector?) {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel) ?? NSImage()
        self.init(image: image, target: target, action: action)
        title = "" // NSButton(image:…) defaults the title to "Button" on macOS 12
        isBordered = false
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        setAccessibilityLabel(accessibilityLabel)
        wantsLayer = true
        layer?.cornerRadius = 5
        updateAppearance()
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = hoverTrackingArea { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    public var trackingOptions: NSTrackingArea.Options? {
        return hoverTrackingArea?.options
    }

    public override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    public override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSCursor.arrow.set()
    }

    public override func mouseMoved(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    public override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        contentTintColor = isHovered ? .labelColor : .secondaryLabelColor
        var background = NSColor.clear.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            background = (isHovered ? NSColor.quaternaryLabelColor : NSColor.clear).cgColor
        }
        layer?.backgroundColor = background
    }
}
