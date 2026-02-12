import Foundation

/// Manages the list of registered projects, persisted to a JSON file in Application Support.
@MainActor
@Observable
final class ProjectStore {
  var projects: [Project] = []

  private let storageURL: URL

  init() {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let appDir = appSupport.appendingPathComponent("Bourbaki", isDirectory: true)
    try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
    storageURL = appDir.appendingPathComponent("projects.json")
    load()
  }

  // MARK: - Public API

  /// Add a project by its root path. Returns the project if newly added, nil if already registered.
  @discardableResult
  func addProject(path: URL) -> Project? {
    let resolved = path.standardizedFileURL
    guard !projects.contains(where: { $0.rootPath.standardizedFileURL == resolved }) else {
      return nil
    }
    let project = Project(rootPath: resolved)
    projects.append(project)
    save()
    return project
  }

  /// Remove a project by ID.
  func removeProject(_ id: Project.ID) {
    projects.removeAll { $0.id == id }
    save()
  }

  /// Move a project in the list (for reordering).
  func moveProject(from source: IndexSet, to destination: Int) {
    projects.move(fromOffsets: source, toOffset: destination)
    save()
  }

  /// Update worktrees for a specific project.
  func updateWorktrees(for projectID: Project.ID, worktrees: [ProjectWorktree]) {
    guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
    projects[index].worktrees = worktrees
  }

  // MARK: - Scanning

  /// Refresh worktrees and session status for all projects.
  /// Fast pass: discover worktrees and update UI immediately.
  /// Then: populate diff stats in the background.
  func refresh() async {
    // Fast pass: just list worktrees (one git call per project)
    for i in projects.indices {
      let project = projects[i]
      var worktrees = await GitService.listWorktrees(for: project.rootPath)
      if worktrees.isEmpty {
        worktrees = [ProjectWorktree(name: project.name, path: project.rootPath)]
      }
      // Preserve existing diff stats if worktree paths match
      let oldWorktrees = projects[i].worktrees
      for j in worktrees.indices {
        if let old = oldWorktrees.first(where: { $0.path == worktrees[j].path }) {
          worktrees[j].addedLines = old.addedLines
          worktrees[j].removedLines = old.removedLines
          worktrees[j].sessions = old.sessions
        }
      }
      projects[i].worktrees = worktrees
    }

    // Slow pass: diff stats + sessions (run in parallel per worktree)
    for i in projects.indices {
      let worktrees = projects[i].worktrees
      let results = await withTaskGroup(of: (Int, Int, Int, [PiSession]).self) { group in
        for (j, wt) in worktrees.enumerated() {
          group.addTask {
            let stats = await GitService.diffStats(for: wt.path)
            let sessions = SessionScanner.sessions(for: wt.path)
            return (j, stats.added, stats.removed, sessions)
          }
        }
        var collected: [(Int, Int, Int, [PiSession])] = []
        for await result in group {
          collected.append(result)
        }
        return collected
      }

      for (j, added, removed, sessions) in results {
        guard j < projects[i].worktrees.count else { continue }
        projects[i].worktrees[j].addedLines = added
        projects[i].worktrees[j].removedLines = removed
        projects[i].worktrees[j].sessions = sessions
      }
    }
  }

  // MARK: - Persistence

  private func load() {
    guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
    do {
      let data = try Data(contentsOf: storageURL)
      projects = try JSONDecoder().decode([Project].self, from: data)
    } catch {
      print("[ProjectStore] Failed to load projects: \(error)")
    }
  }

  private func save() {
    do {
      let data = try JSONEncoder().encode(projects)
      try data.write(to: storageURL, options: .atomic)
    } catch {
      print("[ProjectStore] Failed to save projects: \(error)")
    }
  }
}
