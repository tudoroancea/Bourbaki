import Foundation

/// Scans `~/.pi/agent/sessions/` for pi session files associated with projects.
enum SessionScanner {

  /// Base directory for all pi sessions.
  private static let sessionsBaseURL: URL = {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".pi/agent/sessions", isDirectory: true)
  }()

  /// Find pi sessions associated with a given worktree path.
  static func sessions(for worktreePath: URL) -> [PiSession] {
    let fm = FileManager.default
    let sessionDirs = findSessionDirectories(for: worktreePath)

    var sessions: [PiSession] = []
    for dir in sessionDirs {
      guard let contents = try? fm.contentsOfDirectory(
        at: dir,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
      ) else { continue }

      for fileURL in contents where fileURL.pathExtension == "jsonl" {
        let name = fileURL.deletingPathExtension().lastPathComponent
        let modified = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
        sessions.append(PiSession(id: name, path: fileURL, lastModified: modified))
      }
    }

    sessions.sort { $0.lastModified > $1.lastModified }
    return sessions
  }

  /// Determine the session status for a worktree based on whether a pi process is active.
  static func sessionStatus(for worktreePath: URL) async -> SessionStatus {
    return await ProcessMonitor.isPiRunning(in: worktreePath) ? .idle : .stopped
  }

  // MARK: - Private

  private static func findSessionDirectories(for worktreePath: URL) -> [URL] {
    let fm = FileManager.default
    let basePath = sessionsBaseURL

    guard fm.fileExists(atPath: basePath.path) else { return [] }

    guard let contents = try? fm.contentsOfDirectory(
      at: basePath,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    let worktreeAbsPath = worktreePath.standardizedFileURL.path

    return contents.filter { url in
      let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
      guard isDir else { return false }

      let dirName = url.lastPathComponent

      // Direct path encoding: dashes replacing slashes
      let encoded = worktreeAbsPath.replacingOccurrences(of: "/", with: "--")
      if dirName.contains(encoded) || dirName == encoded {
        return true
      }

      // Also check if the worktree path's last component matches
      let projectName = worktreePath.lastPathComponent
      if dirName.contains(projectName) {
        return true
      }

      return false
    }
  }
}
