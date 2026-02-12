import Foundation

/// A git worktree belonging to a registered project.
struct ProjectWorktree: Identifiable, Hashable {
  /// Unique ID derived from the worktree path.
  var id: String { path.path }

  /// Display name (branch name, or folder name if detached).
  let name: String

  /// Absolute path to the worktree directory.
  let path: URL

  /// Lines added since last commit (from `git diff --shortstat`).
  var addedLines: Int?

  /// Lines removed since last commit (from `git diff --shortstat`).
  var removedLines: Int?

  /// Pi sessions associated with this worktree.
  var sessions: [PiSession] = []
}
