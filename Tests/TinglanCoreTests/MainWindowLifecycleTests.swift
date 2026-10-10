#if os(macOS)
import AppKit
import Testing
@testable import TinglanCore

@MainActor
@Suite("Main window lifecycle", .serialized)
struct MainWindowLifecycleTests {
    private func makeWindow() -> NSWindow {
        _ = NSApplication.shared
        return NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                        styleMask: [.titled, .closable, .miniaturizable],
                        backing: .buffered, defer: false)
    }

    @Test func closeInterceptorPreservesTheWindowAndForwardsOtherCallbacks() {
        let window = makeWindow()
        defer { window.orderOut(nil); window.delegate = nil; window.close() }
        let original = OriginalDelegate()
        window.delegate = original
        let coordinator = MainWindowConfigurator.Coordinator()
        coordinator.attach(to: window)

        #expect(window.delegate === coordinator)
        #expect(!window.isReleasedWhenClosed)
        #expect(!coordinator.windowShouldClose(window))
        #expect(!window.isVisible)
        window.delegate?.windowDidResize?(Notification(name: NSWindow.didResizeNotification, object: window))
        #expect(original.resizeCount == 1)
    }

    @Test func reopenRestoresTheTrackedWindowInsteadOfCreatingAnotherScene() {
        let window = makeWindow()
        defer { window.orderOut(nil); window.close() }
        let delegate = AppDelegate()
        delegate.mainWindow = window
        var recreated = false
        delegate.openMainWindow = { recreated = true }

        #expect(!window.isVisible)
        #expect(!delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true))
        #expect(window.isVisible)
        #expect(!recreated)
        #expect(!delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
        #expect(delegate.mainWindow === window)
    }

    private final class OriginalDelegate: NSObject, NSWindowDelegate {
        var resizeCount = 0
        func windowDidResize(_ notification: Notification) { resizeCount += 1 }
    }
}
#endif
