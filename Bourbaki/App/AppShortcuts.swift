import SwiftUI

struct AppShortcut {
  let key: Character
  let modifiers: EventModifiers

  var keyEquivalent: KeyEquivalent {
    KeyEquivalent(key)
  }

  var keyboardShortcut: KeyboardShortcut {
    KeyboardShortcut(keyEquivalent, modifiers: modifiers)
  }

  /// Ghostty keybind string for unbinding, e.g. "ctrl+super+g"
  var ghosttyKeybind: String {
    let parts = ghosttyModifierParts + [String(key).lowercased()]
    return parts.joined(separator: "+")
  }

  var display: String {
    let parts = displayModifierParts + [String(key).uppercased()]
    return parts.joined()
  }

  private var ghosttyModifierParts: [String] {
    var parts: [String] = []
    if modifiers.contains(.control) { parts.append("ctrl") }
    if modifiers.contains(.option) { parts.append("alt") }
    if modifiers.contains(.shift) { parts.append("shift") }
    if modifiers.contains(.command) { parts.append("super") }
    return parts
  }

  private var displayModifierParts: [String] {
    var parts: [String] = []
    if modifiers.contains(.command) { parts.append("⌘") }
    if modifiers.contains(.shift) { parts.append("⇧") }
    if modifiers.contains(.option) { parts.append("⌥") }
    if modifiers.contains(.control) { parts.append("⌃") }
    return parts
  }
}

enum AppShortcuts {
  // File menu — open tabs
  static let newTerminal = AppShortcut(key: "t", modifiers: [.command])
  static let openPi = AppShortcut(key: "p", modifiers: [.command])
  static let openLazygit = AppShortcut(key: "l", modifiers: [.command])
  static let openLumenDiff = AppShortcut(key: "d", modifiers: [.command])
  static let openInZed = AppShortcut(key: "o", modifiers: [.command])
  static let closeTab = AppShortcut(key: "w", modifiers: [.command])
  static let closeWindow = AppShortcut(key: "w", modifiers: [.command, .shift])

  // Tab navigation
  static let nextTab = AppShortcut(key: "]", modifiers: [.command, .control])
  static let previousTab = AppShortcut(key: "[", modifiers: [.command, .control])

  // Sidebar
  static let toggleSidebar = AppShortcut(key: "b", modifiers: [.command])
  static let focusSidebar = AppShortcut(key: "0", modifiers: [.command, .control])

  // Worktree switching (Cmd+Opt+1-9)
  static let selectWorktree1 = AppShortcut(key: "1", modifiers: [.command, .option])
  static let selectWorktree2 = AppShortcut(key: "2", modifiers: [.command, .option])
  static let selectWorktree3 = AppShortcut(key: "3", modifiers: [.command, .option])
  static let selectWorktree4 = AppShortcut(key: "4", modifiers: [.command, .option])
  static let selectWorktree5 = AppShortcut(key: "5", modifiers: [.command, .option])
  static let selectWorktree6 = AppShortcut(key: "6", modifiers: [.command, .option])
  static let selectWorktree7 = AppShortcut(key: "7", modifiers: [.command, .option])
  static let selectWorktree8 = AppShortcut(key: "8", modifiers: [.command, .option])
  static let selectWorktree9 = AppShortcut(key: "9", modifiers: [.command, .option])

  // Tab switching (Cmd+1-9)
  static let selectTab1 = AppShortcut(key: "1", modifiers: [.command])
  static let selectTab2 = AppShortcut(key: "2", modifiers: [.command])
  static let selectTab3 = AppShortcut(key: "3", modifiers: [.command])
  static let selectTab4 = AppShortcut(key: "4", modifiers: [.command])
  static let selectTab5 = AppShortcut(key: "5", modifiers: [.command])
  static let selectTab6 = AppShortcut(key: "6", modifiers: [.command])
  static let selectTab7 = AppShortcut(key: "7", modifiers: [.command])
  static let selectTab8 = AppShortcut(key: "8", modifiers: [.command])
  static let selectTab9 = AppShortcut(key: "9", modifiers: [.command])

  static let worktreeShortcuts: [AppShortcut] = [
    selectWorktree1, selectWorktree2, selectWorktree3,
    selectWorktree4, selectWorktree5, selectWorktree6,
    selectWorktree7, selectWorktree8, selectWorktree9,
  ]

  static let tabShortcuts: [AppShortcut] = [
    selectTab1, selectTab2, selectTab3,
    selectTab4, selectTab5, selectTab6,
    selectTab7, selectTab8, selectTab9,
  ]

  /// All shortcuts that need to be unbound from ghostty so the app can handle them.
  static let all: [AppShortcut] = [
    newTerminal,
    openPi,
    openLazygit,
    openLumenDiff,
    openInZed,
    closeTab,
    closeWindow,
    nextTab,
    previousTab,
    toggleSidebar,
    focusSidebar,
    selectWorktree1,
    selectWorktree2,
    selectWorktree3,
    selectWorktree4,
    selectWorktree5,
    selectWorktree6,
    selectWorktree7,
    selectWorktree8,
    selectWorktree9,
    selectTab1,
    selectTab2,
    selectTab3,
    selectTab4,
    selectTab5,
    selectTab6,
    selectTab7,
    selectTab8,
    selectTab9,
  ]
}
