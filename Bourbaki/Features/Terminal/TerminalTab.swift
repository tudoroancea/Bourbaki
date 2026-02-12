import Foundation

enum TabType: String, Codable, Hashable {
  case agent
  case git
  case diff
  case shell

  var displayName: String {
    switch self {
    case .agent: return "agent"
    case .git: return "git"
    case .diff: return "diff"
    case .shell: return "shell"
    }
  }

  var iconName: String {
    switch self {
    case .agent: return "terminal"
    case .git: return "arrow.triangle.branch"
    case .diff: return "doc.text.magnifyingglass"
    case .shell: return "apple.terminal"
    }
  }

  /// The command to run in the terminal for this tab type.
  /// Uses `exec` so the shell is replaced by the command — when it exits, the surface closes.
  var command: String? {
    switch self {
    case .agent: return "clear && exec pi"
    case .git: return "clear && exec lazygit"
    case .diff: return "clear && exec lumen diff"
    case .shell: return nil // just opens the default shell
    }
  }
}

@MainActor
@Observable
final class TerminalTab: Identifiable {
  let id: UUID
  let type: TabType
  /// The worktree path this tab belongs to.
  let worktreePath: URL
  var title: String
  let surfaceView: GhosttySurfaceView
  var hasNotification: Bool = false
  var isRunning: Bool = false

  init(id: UUID = UUID(), type: TabType, worktreePath: URL, title: String, surfaceView: GhosttySurfaceView) {
    self.id = id
    self.type = type
    self.worktreePath = worktreePath
    self.title = title
    self.surfaceView = surfaceView
  }
}
