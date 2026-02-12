import Foundation

/// Status of a pi session for a given worktree.
enum SessionStatus: String, Codable, Hashable {
  /// pi is actively processing (progress report SET/INDETERMINATE)
  case running
  /// pi process is alive but waiting for input
  case idle
  /// No pi session, but terminal tabs are open
  case terminal
  /// No active pi session or terminals
  case stopped
}
