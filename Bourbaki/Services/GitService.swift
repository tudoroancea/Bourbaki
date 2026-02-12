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

  /// List all local branch names for a repository.
  static func listBranches(for rootPath: URL) async -> [String] {
    guard let output = await runGit(["branch", "--format=%(refname:short)"], in: rootPath) else {
      return []
    }
    return
      output
      .components(separatedBy: "\n")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  /// Create a new worktree. If `createBranch` is true, creates a new branch with `worktreeName`
  /// based on `baseBranch`. Otherwise checks out `baseBranch` directly.
  /// The worktree is created at `<rootPath>/.worktrees/<worktreeName>`.
  static func createWorktree(
    rootPath: URL,
    worktreeName: String,
    baseBranch: String,
    createBranch: Bool
  ) async -> Result<Void, WorktreeError> {
    let worktreeDir = rootPath.appendingPathComponent(".worktrees", isDirectory: true)
    let worktreePath = worktreeDir.appendingPathComponent(worktreeName, isDirectory: true)

    // Ensure .worktrees directory exists
    try? FileManager.default.createDirectory(at: worktreeDir, withIntermediateDirectories: true)

    var args = ["worktree", "add"]
    if createBranch {
      args += ["-b", worktreeName, worktreePath.path, baseBranch]
    } else {
      args += [worktreePath.path, baseBranch]
    }

    guard await runGit(args, in: rootPath) != nil else {
      return .failure(.commandFailed("Failed to create worktree '\(worktreeName)'"))
    }
    return .success(())
  }

  /// Check if a worktree has uncommitted changes.
  static func hasUncommittedChanges(at worktreePath: URL) async -> Bool {
    guard let output = await runGit(["status", "--porcelain"], in: worktreePath) else {
      return false
    }
    return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Delete a worktree. If `force` is true, discards uncommitted changes.
  /// If `deleteBranch` is true, also deletes the associated branch.
  static func deleteWorktree(
    rootPath: URL,
    worktreePath: URL,
    force: Bool,
    deleteBranch: Bool
  ) async -> Result<Void, WorktreeError> {
    // Get the branch name before removing the worktree
    var branchToDelete: String?
    if deleteBranch {
      // Parse the branch from `git worktree list --porcelain`
      if let output = await runGit(["worktree", "list", "--porcelain"], in: rootPath) {
        let blocks = output.components(separatedBy: "\n\n")
        for block in blocks {
          let lines = block.components(separatedBy: "\n")
          let matchesPath = lines.contains { line in
            line.hasPrefix("worktree ") && String(line.dropFirst("worktree ".count)) == worktreePath.path
          }
          if matchesPath {
            for line in lines where line.hasPrefix("branch ") {
              let ref = String(line.dropFirst("branch ".count))
              branchToDelete = ref.components(separatedBy: "/").last
            }
          }
        }
      }
    }

    // Remove the worktree
    var args = ["worktree", "remove"]
    if force { args.append("--force") }
    args.append(worktreePath.path)

    guard await runGit(args, in: rootPath) != nil else {
      return .failure(.commandFailed("Failed to remove worktree at '\(worktreePath.path)'"))
    }

    // Delete branch if requested
    if let branch = branchToDelete {
      let branchArgs = ["branch", "-D", branch]
      _ = await runGit(branchArgs, in: rootPath)
      // Ignore branch deletion failure (e.g. if it's the main branch)
    }

    return .success(())
  }

  /// Errors from worktree operations.
  enum WorktreeError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
      switch self {
      case .commandFailed(let msg): return msg
      }
    }
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
