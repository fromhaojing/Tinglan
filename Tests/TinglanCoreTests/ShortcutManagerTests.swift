#if os(macOS)
import AppKit
import Foundation
import Testing
@testable import TinglanCore

@MainActor
@Suite("Keyboard shortcut migration")
struct ShortcutManagerTests {
    private func withManager(_ test: (ShortcutManager, UserDefaults) throws -> Void) rethrows {
        let name = "TinglanShortcutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try test(ShortcutManager(userDefaults: defaults), defaults)
    }

    @Test func defaultsPreserveTypingAndLeaveGlobalKeysUnregistered() {
        withManager { manager, _ in
            #expect(manager.action(forKey: " ", modifiers: [], editingText: false) == .togglePlayPause)
            #expect(manager.action(forKey: " ", modifiers: [], editingText: true) == nil)
            #expect(manager.action(forKey: "\u{F703}", modifiers: [.command], editingText: true) == .nextTrack)
            #expect(ShortcutAction.allCases.allSatisfy { manager.shortcut(for: $0, isGlobal: true).key.isEmpty })
        }
    }

    @Test func duplicateBindingIsRejectedWithoutReplacingEitherAction() {
        withManager { manager, _ in
            let original = manager.shortcut(for: .nextTrack, isGlobal: false)
            #expect(!manager.setShortcut(UserShortcut(key: "L", modifiers: [.command]), for: .nextTrack, isGlobal: false))
            #expect(manager.shortcut(for: .nextTrack, isGlobal: false) == original)
            #expect(manager.action(forKey: "l", modifiers: [.command], editingText: false) == .toggleLyrics)
        }
    }

    @Test func clearedGlobalBindingStaysClearedAfterReload() {
        withManager { manager, defaults in
            #expect(manager.setShortcut(UserShortcut(key: "p", modifiers: [.option, .command]), for: .togglePlayPause, isGlobal: true))
            #expect(manager.setShortcut(UserShortcut(key: "", modifiers: []), for: .togglePlayPause, isGlobal: true))
            let reloaded = ShortcutManager(userDefaults: defaults)
            #expect(reloaded.shortcut(for: .togglePlayPause, isGlobal: true).key.isEmpty)
        }
    }

    @Test func resetRestoresDefaultsEvenWhenTheirKeysWereReassigned() {
        withManager { manager, defaults in
            #expect(manager.setShortcut(UserShortcut(key: "", modifiers: []), for: .toggleLyrics, isGlobal: false))
            #expect(manager.setShortcut(UserShortcut(key: "l", modifiers: [.command]), for: .nextTrack, isGlobal: false))
            manager.resetToDefaults()
            let reloaded = ShortcutManager(userDefaults: defaults)
            for action in ShortcutAction.allCases {
                #expect(reloaded.shortcut(for: action, isGlobal: false) == action.defaultShortcut)
                #expect(reloaded.shortcut(for: action, isGlobal: true).key.isEmpty)
            }
        }
    }

    @Test func recordingDoesNotExecuteAnExistingBinding() {
        withManager { manager, _ in
            manager.beginRecording()
            #expect(manager.action(forKey: "\u{F703}", modifiers: [.command], editingText: false) == nil)
            manager.endRecording()
            #expect(manager.action(forKey: "\u{F703}", modifiers: [.command], editingText: false) == .nextTrack)
        }
    }

    @Test func recorderClearsWithEscapeAndAcceptsACommandKey() throws {
        let recorder = ShortcutRecorderView.RecorderNSView()
        var recorded: [UserShortcut] = []
        recorder.onRecord = { recorded.append(UserShortcut(key: $0, modifiers: $1)) }
        let escape = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53))
        recorder.keyDown(with: escape)
        let next = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: 0, windowNumber: 0, context: nil, characters: "\u{F703}",
            charactersIgnoringModifiers: "\u{F703}", isARepeat: false, keyCode: 124))
        recorder.keyDown(with: next)
        #expect(recorded == [UserShortcut(key: "", modifiers: []), UserShortcut(key: "\u{F703}", modifiers: .command)])
    }
}
#endif
