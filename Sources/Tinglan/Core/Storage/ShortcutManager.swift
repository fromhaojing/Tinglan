#if os(macOS)
import SwiftUI
import AppKit

public struct UserShortcut: Codable, Equatable {
    public var key: String
    public var modifiers: ShortcutModifiers

    public struct ShortcutModifiers: OptionSet, Codable, Equatable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = ShortcutModifiers(rawValue: 1 << 0)
        public static let shift   = ShortcutModifiers(rawValue: 1 << 1)
        public static let option  = ShortcutModifiers(rawValue: 1 << 2)
        public static let control = ShortcutModifiers(rawValue: 1 << 3)

        public var eventModifiers: EventModifiers {
            var flags: EventModifiers = []
            if contains(.command) { flags.insert(.command) }
            if contains(.shift) { flags.insert(.shift) }
            if contains(.option) { flags.insert(.option) }
            if contains(.control) { flags.insert(.control) }
            return flags
        }

        public var nsModifierFlags: NSEvent.ModifierFlags {
            var flags: NSEvent.ModifierFlags = []
            if contains(.command) { flags.insert(.command) }
            if contains(.shift) { flags.insert(.shift) }
            if contains(.option) { flags.insert(.option) }
            if contains(.control) { flags.insert(.control) }
            return flags
        }

        public init(nsFlags: NSEvent.ModifierFlags) {
            var flags: ShortcutModifiers = []
            if nsFlags.contains(.command) { flags.insert(.command) }
            if nsFlags.contains(.shift) { flags.insert(.shift) }
            if nsFlags.contains(.option) { flags.insert(.option) }
            if nsFlags.contains(.control) { flags.insert(.control) }
            self = flags
        }
    }

    public var keyboardShortcut: KeyboardShortcut? {
        guard key.count == 1, let character = key.first else { return nil }
        return KeyboardShortcut(KeyEquivalent(character), modifiers: modifiers.eventModifiers)
    }

    public var displayString: String {
        if key.isEmpty { return String(localized: "无") }
        var str = ""
        if modifiers.contains(.control) { str += "⌃" }
        if modifiers.contains(.option) { str += "⌥" }
        if modifiers.contains(.shift) { str += "⇧" }
        if modifiers.contains(.command) { str += "⌘" }
        
        switch key {
        case " ": str += "Space"
        case "\u{F703}": str += "→"
        case "\u{F702}": str += "←"
        case "\u{F700}": str += "↑"
        case "\u{F701}": str += "↓"
        case "\u{1B}": str += "⎋"
        case "\u{F704}": str += "F1"
        case "\u{F705}": str += "F2"
        case "\u{F706}": str += "F3"
        case "\u{F707}": str += "F4"
        case "\u{F708}": str += "F5"
        case "\u{F709}": str += "F6"
        case "\u{F70A}": str += "F7"
        case "\u{F70B}": str += "F8"
        case "\u{F70C}": str += "F9"
        case "\u{F70D}": str += "F10"
        case "\u{F70E}": str += "F11"
        case "\u{F70F}": str += "F12"
        case "\r": str += "↩"
        case "\u{7F}": str += "⌫"
        default: str += key.uppercased()
        }
        return str
    }
}

public enum ShortcutAction: String, CaseIterable, Identifiable, Hashable {
    case togglePlayPause
    case nextTrack
    case previousTrack
    case cycleQueueOrder
    case cycleRepeatMode
    case toggleLike
    case toggleLyrics
    case toggleQueue
    case closeImmersive
    case volumeUp
    case volumeDown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .togglePlayPause: return String(localized: "播放 / 暂停")
        case .nextTrack: return String(localized: "下一首")
        case .previousTrack: return String(localized: "上一首")
        case .cycleQueueOrder: return String(localized: "随机播放")
        case .cycleRepeatMode: return String(localized: "切换循环模式")
        case .toggleLike: return String(localized: "喜欢 / 取消喜欢")
        case .toggleLyrics: return String(localized: "切换歌词面板")
        case .toggleQueue: return String(localized: "切换播放队列")
        case .closeImmersive: return String(localized: "关闭沉浸播放页")
        case .volumeUp: return String(localized: "增加音量")
        case .volumeDown: return String(localized: "减少音量")
        }
    }

    public var defaultShortcut: UserShortcut {
        switch self {
        case .togglePlayPause: return UserShortcut(key: " ", modifiers: [])
        case .nextTrack: return UserShortcut(key: "\u{F703}", modifiers: [.command])
        case .previousTrack: return UserShortcut(key: "\u{F702}", modifiers: [.command])
        case .cycleQueueOrder: return UserShortcut(key: "s", modifiers: [.command, .shift])
        case .cycleRepeatMode: return UserShortcut(key: "r", modifiers: [.command, .shift])
        case .toggleLike: return UserShortcut(key: "l", modifiers: [.command, .shift])
        case .toggleLyrics: return UserShortcut(key: "l", modifiers: [.command])
        case .toggleQueue: return UserShortcut(key: "u", modifiers: [.command])
        case .closeImmersive: return UserShortcut(key: "", modifiers: [])
        case .volumeUp: return UserShortcut(key: "\u{F700}", modifiers: [.command])
        case .volumeDown: return UserShortcut(key: "\u{F701}", modifiers: [.command])
        }
    }
}

// MARK: - Global shortcut defaults

// Global (system-wide) hotkeys are opt-in: nothing is registered until the user
// sets one in 快捷键 settings. This keeps Tinglan from grabbing keys like ⌥Space
// out of the box and clashing with other apps / the system. In-app shortcuts
// keep their own defaults; only the global layer starts empty. (#125)
private let globalShortcutDefaults: [ShortcutAction: UserShortcut] = [:]

@MainActor
final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager(userDefaults: .standard, registersGlobalHotKeys: true)
    
    @Published var appShortcuts: [ShortcutAction: UserShortcut] = [:]
    @Published var globalShortcuts: [ShortcutAction: UserShortcut] = [:]
    private(set) var isRecordingShortcut = false
    
    private let userDefaults: UserDefaults
    private let registersGlobalHotKeys: Bool
    private let appPrefix = "settings.shortcut."
    private let globalPrefix = "settings.globalShortcut."
    
    init(userDefaults: UserDefaults, registersGlobalHotKeys: Bool = false) {
        self.userDefaults = userDefaults
        self.registersGlobalHotKeys = registersGlobalHotKeys
        loadShortcuts()
    }
    
    private func loadShortcuts() {
        var loadedApp: [ShortcutAction: UserShortcut] = [:]
        var loadedGlobal: [ShortcutAction: UserShortcut] = [:]
        for action in ShortcutAction.allCases {
            if let data = userDefaults.data(forKey: appPrefix + action.rawValue),
               let shortcut = try? JSONDecoder().decode(UserShortcut.self, from: data) {
                loadedApp[action] = shortcut
            } else {
                loadedApp[action] = action.defaultShortcut
            }
            
            if let data = userDefaults.data(forKey: globalPrefix + action.rawValue),
               let shortcut = try? JSONDecoder().decode(UserShortcut.self, from: data) {
                loadedGlobal[action] = shortcut
            } else {
                loadedGlobal[action] = globalShortcutDefaults[action] ?? UserShortcut(key: "", modifiers: [])
            }
        }
        self.appShortcuts = loadedApp
        self.globalShortcuts = loadedGlobal
        // 加载完成后，将全局快捷键注册到系统 Hot Key
        if registersGlobalHotKeys { GlobalHotKeyManager.shared.refreshAll(from: self) }
    }

    func beginRecording() {
        isRecordingShortcut = true
        if registersGlobalHotKeys { GlobalHotKeyManager.shared.unregisterAll() }
    }

    func endRecording() {
        isRecordingShortcut = false
        if registersGlobalHotKeys { GlobalHotKeyManager.shared.refreshAll(from: self) }
    }
    
    /// 设置快捷键，采用"先注册新快捷键，成功后再替换旧快捷键"策略。
    /// 若系统注册失败，UserDefaults 不会被修改，原有快捷键保持不变。
    @discardableResult
    func setShortcut(_ shortcut: UserShortcut, for action: ShortcutAction, isGlobal: Bool) -> Bool {
        guard shortcut.key.isEmpty || shortcut.key.count == 1 else { return false }
        let shortcuts = isGlobal ? globalShortcuts : appShortcuts
        guard shortcut.key.isEmpty || !shortcuts.contains(where: {
            $0.key != action && $0.value.key.lowercased() == shortcut.key.lowercased()
                && $0.value.modifiers == shortcut.modifiers
        })
        else { return false }
        if shortcuts[action] == shortcut { return true }
        if isGlobal {
            // Clearing a binding also releases its system registration.
            if shortcut.key.isEmpty {
                if registersGlobalHotKeys { GlobalHotKeyManager.shared.unregister(action: action) }
                
                globalShortcuts[action] = shortcut
                if let data = try? JSONEncoder().encode(shortcut) {
                    userDefaults.set(data, forKey: globalPrefix + action.rawValue)
                }
                objectWillChange.send()
                return true
            }
            
            guard resolveKeyCode(shortcut.key) != nil else { return false }
            let result = registersGlobalHotKeys
                ? GlobalHotKeyManager.shared.registerForAction(action, shortcut: shortcut) : .registered
            switch result {
            case .registered:
                globalShortcuts[action] = shortcut
                if let data = try? JSONEncoder().encode(shortcut) {
                    userDefaults.set(data, forKey: globalPrefix + action.rawValue)
                }
            case .invalidShortcut, .registrationFailed:
                // 注册失败：不修改 globalShortcuts 和 UserDefaults，保留旧快捷键
                objectWillChange.send()
                return false
            }
            if isRecordingShortcut, registersGlobalHotKeys {
                GlobalHotKeyManager.shared.unregister(action: action)
            }
        } else {
            appShortcuts[action] = shortcut
            if let data = try? JSONEncoder().encode(shortcut) {
                userDefaults.set(data, forKey: appPrefix + action.rawValue)
            }
        }
        objectWillChange.send()
        return true
    }
    
    func resetToDefaults() {
        // Clear custom assignments first so one action's old key cannot block
        // another action from returning to its default.
        if registersGlobalHotKeys { GlobalHotKeyManager.shared.unregisterAll() }
        appShortcuts.removeAll()
        globalShortcuts.removeAll()
        for action in ShortcutAction.allCases {
            setShortcut(action.defaultShortcut, for: action, isGlobal: false)
            setShortcut(globalShortcutDefaults[action] ?? UserShortcut(key: "", modifiers: []), for: action, isGlobal: true)
        }
    }
    
    func shortcut(for action: ShortcutAction, isGlobal: Bool) -> UserShortcut {
        if isGlobal {
            return globalShortcuts[action] ?? globalShortcutDefaults[action] ?? UserShortcut(key: "", modifiers: [])
        } else {
            return appShortcuts[action] ?? action.defaultShortcut
        }
    }
    
    // MARK: - App-internal Key Event Matching (local monitor only)
    // Global hotkeys are handled by GlobalHotKeyManager via Carbon Event Hot Key API.
    
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        let editingText = NSApp.keyWindow?.firstResponder is NSText
            || NSApp.keyWindow?.firstResponder is NSTextView
        guard let action = action(forKey: event.charactersIgnoringModifiers ?? "",
                                  modifiers: UserShortcut.ShortcutModifiers(nsFlags: event.modifierFlags),
                                  editingText: editingText) else { return false }
        executeAction(action)
        return true
    }

    func action(forKey key: String, modifiers: UserShortcut.ShortcutModifiers,
                editingText: Bool) -> ShortcutAction? {
        guard !isRecordingShortcut, key.count == 1 else { return nil }
        return ShortcutAction.allCases.first { action in
            let shortcut = shortcut(for: action, isGlobal: false)
            if editingText, !shortcut.modifiers.contains(.command), !shortcut.modifiers.contains(.control) {
                return false
            }
            return shortcut.key.lowercased() == key.lowercased() && shortcut.modifiers == modifiers
        }
    }
    
    func executeAction(_ action: ShortcutAction) {
        Task { @MainActor in
            let player = PlayerService.shared
            switch action {
            case .togglePlayPause:
                player.togglePlayPause()
            case .nextTrack:
                player.next()
            case .previousTrack:
                player.previous()
            case .cycleQueueOrder:
                player.toggleShuffle()
            case .cycleRepeatMode:
                player.cycleRepeatMode()
            case .toggleLike:
                if let track = player.currentTrack {
                    await AccountStore.shared.toggleLike(trackID: track.id)
                }
            case .toggleLyrics:
                player.activePanel = player.activePanel == .lyrics ? nil : .lyrics
            case .toggleQueue:
                player.activePanel = player.activePanel == .queue ? nil : .queue
            case .closeImmersive:
                if player.showNowPlaying {
                    player.showNowPlaying = false
                }
            case .volumeUp:
                player.volume = min(player.volume + 0.1, 1.0)
            case .volumeDown:
                player.volume = max(player.volume - 0.1, 0.0)
            }
        }
    }
}
#endif
