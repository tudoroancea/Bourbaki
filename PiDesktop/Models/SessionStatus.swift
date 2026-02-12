import Foundation

/// Status of a pi session for a given worktree.
enum SessionStatus: String, Codable, Hashable {
  /// pi is actively processing (progress report SET/INDETERMINATE)
  case running
  /// pi process is alive but waiting for input
  case idle
  /// No active pi session
  case stopped
}
