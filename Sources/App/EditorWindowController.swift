import Cocoa

/// The single editor window: Markdown on the left, live HTML source on the right.
public final class EditorWindowController: NSWindowController {
    public let markdownPane = MarkdownPaneViewController()
    public let htmlPane = HTMLPaneViewController()
    public let splitViewController = NSSplitViewController()
    public private(set) var scrollSynchronizer: ScrollSynchronizer!

    private static let defaultSize = NSSize(width: 900, height: 600)

    public init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = AppConfig.appName
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 480, height: 300)
        super.init(window: window)
        setupSplitView()
        setupWiring()
        window.center()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupSplitView() {
        guard let window = window else { return }
        _ = markdownPane.view
        _ = htmlPane.view

        splitViewController.splitView.isVertical = true
        splitViewController.splitView.dividerStyle = .thin

        let markdownItem = NSSplitViewItem(viewController: markdownPane)
        let htmlItem = NSSplitViewItem(viewController: htmlPane)
        for item in [markdownItem, htmlItem] {
            item.minimumThickness = 160
            item.canCollapse = false
            item.holdingPriority = .defaultLow
        }
        splitViewController.addSplitViewItem(markdownItem)
        splitViewController.addSplitViewItem(htmlItem)

        splitViewController.view.frame = NSRect(origin: .zero, size: Self.defaultSize)
        window.contentViewController = splitViewController
        window.setContentSize(Self.defaultSize)
        window.initialFirstResponder = markdownPane.textView

        // Start split 50/50; the divider position is intentionally not persisted.
        window.layoutIfNeeded()
        let splitView = splitViewController.splitView
        splitView.setPosition((splitView.bounds.width - splitView.dividerThickness) / 2, ofDividerAt: 0)
    }

    private func setupWiring() {
        scrollSynchronizer = ScrollSynchronizer(
            input: (markdownPane.scrollView, markdownPane.textView),
            output: (htmlPane.scrollView, htmlPane.textView)
        )
        markdownPane.onChange = { [weak self] markdown in
            self?.render(markdown)
        }
    }

    /// Converts, shows the HTML without echoing its scroll change, then aligns the HTML pane
    /// with the Markdown pane using the new block anchors.
    private func render(_ markdown: String) {
        let conversion = MarkdownConverter.convert(markdown)
        scrollSynchronizer.withoutSync {
            htmlPane.show(html: conversion.html)
        }
        scrollSynchronizer.anchors = conversion.anchors
        scrollSynchronizer.syncOutputToInput()
    }

    public override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeFirstResponder(markdownPane.textView)
    }

    /// Loads qualifying clipboard text into the editor. Called once, at launch only.
    public func loadClipboard(from pasteboard: NSPasteboard) {
        guard let text = ClipboardLoader.text(from: pasteboard) else { return }
        markdownPane.insertReplacingAll(text)
    }

    /// Edit > Copy HTML (Shift-Command-C) and the pane's top-right icon. Copies the whole output.
    @objc public func copyHTML(_ sender: Any?) {
        copyHTML(to: .general)
    }

    public func copyHTML(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(htmlPane.textView.string, forType: .string)
        htmlPane.showCopiedFeedback()
    }
}
