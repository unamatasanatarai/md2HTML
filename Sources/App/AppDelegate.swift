import Cocoa

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var editorWindowController: EditorWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = MainMenu.make(appName: AppConfig.appName)

        let editor = EditorWindowController()
        editor.showWindow(nil)
        editor.loadClipboard(from: .general) // once, at launch only; never on activation
        NSApp.activate(ignoringOtherApps: true)
        editorWindowController = editor

        NSLog("%@ started successfully.", AppConfig.appName)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
