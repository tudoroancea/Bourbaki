import Foundation

/// Status of an agent session for a given worktree.
enum SessionStatus: String, Codable, Hashable {
  /// Agent is actively processing (progress report SET/INDETERMINATE)
  case running
  /// Agent process is alive but waiting for input
  case idle
  /// No agent session, but terminal tabs are open
  case terminal
  /// No active agent session or terminals
  case stopped
}
