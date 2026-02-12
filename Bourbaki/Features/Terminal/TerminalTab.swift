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
