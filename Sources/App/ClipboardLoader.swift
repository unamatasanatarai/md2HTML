import Cocoa

/// Decides whether the clipboard's content may be loaded into the editor at launch.
public enum ClipboardLoader {
    /// Marker that password managers put on copied secrets.
    public static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    /// Clipboard text larger than this (in UTF-8 bytes) is skipped so launch stays instant.
    public static let maxBytes = 1_000_000

    /// Returns the text to load, or nil when the clipboard is concealed, has no plain text,
    /// is empty, or is too large. Undoability and launch-only reading live in the callers.
    public static func text(from pasteboard: NSPasteboard) -> String? {
        if pasteboard.types?.contains(concealedType) == true { return nil }
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return nil }
        guard text.utf8.count <= maxBytes else { return nil }
        return text
    }
}
