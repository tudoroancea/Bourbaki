import GhosttyKit
import Observation
import SwiftUI

@MainActor
@Observable
final class GhosttyShortcutManager {
  private let runtime: GhosttyRuntime
  private var generation: Int = 0

  init(runtime: GhosttyRuntime) {
    self.runtime = runtime
    runtime.onConfigChange = { [weak self] in
      self?.refresh()
    }
  }

  func refresh() {
    generation += 1
  }

  func keyboardShortcut(for action: String) -> KeyboardShortcut? {
    _ = generation
    return runtime.keyboardShortcut(for: action)
  }

  func display(for action: String) -> String? {
    guard let shortcut = keyboardShortcut(for: action) else { return nil }
    return shortcut.display
  }
}

extension KeyboardShortcut {
  var display: String {
    var parts: [String] = []
    if modifiers.contains(.command) { parts.append("⌘") }
    if modifiers.contains(.shift) { parts.append("⇧") }
    if modifiers.contains(.option) { parts.append("⌥") }
    if modifiers.contains(.control) { parts.append("⌃") }
    parts.append(key.display)
    return parts.joined()
  }
}

extension KeyEquivalent {
  var display: String {
    switch self {
    case .delete:
      return "⌫"
    case .return:
      return "↩"
    case .escape:
      return "⎋"
    case .tab:
      return "⇥"
    case .space:
      return "␠"
    case .upArrow:
      return "↑"
    case .downArrow:
      return "↓"
    case .leftArrow:
      return "←"
    case .rightArrow:
      return "→"
    case .home:
      return "↖"
    case .end:
      return "↘"
    case .pageUp:
      return "⇞"
    case .pageDown:
      return "⇟"
    default:
      return String(character).uppercased()
    }
  }
}
