import Foundation

/// Service for querying git worktree and diff information.
enum GitService {
  /// List all worktrees for a git repository at the given root path.
  static func listWorktrees(for rootPath: URL) async -> [ProjectWorktree] {
    guard let output = await runGit(["worktree", "list", "--porcelain"], in: rootPath) else {
      return []
    }

    var worktrees: [ProjectWorktree] = []
    var currentPath: URL?
    var currentBranch: String?

    for line in output.components(separatedBy: "\n") {
      if line.hasPrefix("worktree ") {
        if let path = currentPath {
          let name = currentBranch ?? path.lastPathComponent
          worktrees.append(ProjectWorktree(name: name, path: path))
        }
        let pathStr = String(line.dropFirst("worktree ".count))
        currentPath = URL(fileURLWithPath: pathStr)
        currentBranch = nil
      } else if line.hasPrefix("branch ") {
        let ref = String(line.dropFirst("branch ".count))
        currentBranch = ref.components(separatedBy: "/").last
      } else if line == "bare" {
        currentPath = nil
        currentBranch = nil
      }
    }

    if let path = currentPath {
      let name = currentBranch ?? path.lastPathComponent
      worktrees.append(ProjectWorktree(name: name, path: path))
    }

    return worktrees
  }

  /// Get diff stats (added/removed lines) for a worktree.
  static func diffStats(for worktreePath: URL) async -> (added: Int, removed: Int) {
    guard let output = await runGit(["diff", "HEAD", "--shortstat"], in: worktreePath) else {
      return (0, 0)
    }
    return parseDiffShortstat(output)
  }

  // MARK: - Private

  /// Run a git command off the main thread, returning stdout on success.
  private static func runGit(_ arguments: [String], in directory: URL) async -> String? {
    let dir = directory
    let args = arguments
    return await Task.detached {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
      process.arguments = args
      process.currentDirectoryURL = dir
      process.environment = ProcessInfo.processInfo.environment

      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = Pipe()

      do {
        try process.run()
      } catch {
        return nil as String?
      }

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()

      guard process.terminationStatus == 0 else { return nil }
      return String(data: data, encoding: .utf8)
    }.value
  }

  /// Parse output like: " 3 files changed, 42 insertions(+), 10 deletions(-)"
  private static func parseDiffShortstat(_ output: String) -> (added: Int, removed: Int) {
    var added = 0
    var removed = 0

    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return (0, 0) }

    if let insertionRange = trimmed.range(of: #"(\d+) insertion"#, options: .regularExpression) {
      let match = trimmed[insertionRange]
      if let num = Int(match.components(separatedBy: " ").first ?? "") {
        added = num
      }
    }

    if let deletionRange = trimmed.range(of: #"(\d+) deletion"#, options: .regularExpression) {
      let match = trimmed[deletionRange]
      if let num = Int(match.components(separatedBy: " ").first ?? "") {
        removed = num
      }
    }

    return (added, removed)
  }
}
