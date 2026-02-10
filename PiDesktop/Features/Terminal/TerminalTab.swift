import Foundation

enum TabType: String, Codable, Hashable {
  case pi
  case lazygit
  case lumenDiff
  case shell

  var displayName: String {
    switch self {
    case .pi: return "pi"
    case .lazygit: return "lazygit"
    case .lumenDiff: return "lumen diff"
    case .shell: return "shell"
    }
  }

  var iconName: String {
    switch self {
    case .pi: return "terminal"
    case .lazygit: return "arrow.triangle.branch"
    case .lumenDiff: return "doc.text.magnifyingglass"
    case .shell: return "apple.terminal"
    }
  }

  /// The command to run in the terminal for this tab type.
  var command: String? {
    switch self {
    case .pi: return "pi"
    case .lazygit: return "lazygit"
    case .lumenDiff: return "lumen diff"
    case .shell: return nil // just opens the default shell
    }
  }
}

@MainActor
@Observable
final class TerminalTab: Identifiable {
  let id: UUID
  let type: TabType
  var title: String
  let surfaceView: GhosttySurfaceView
  var hasNotification: Bool = false
  var isRunning: Bool = false

  init(id: UUID = UUID(), type: TabType, title: String, surfaceView: GhosttySurfaceView) {
    self.id = id
    self.type = type
    self.title = title
    self.surfaceView = surfaceView
  }
}
