import Foundation

/// A recently opened worktree entry.
struct RecentWorktreeEntry: Codable, Identifiable, Equatable {
  var id: String { path }

  /// Absolute path to the worktree directory.
  let path: String

  /// Display name (e.g. "project · branch").
  let displayName: String

  /// Project name.
  let projectName: String

  /// Worktree/branch name.
  let worktreeName: String

  /// Timestamp of last open.
  var lastOpened: Date
}

/// Persists recently opened worktrees to a JSON file in Application Support.
@MainActor
@Observable
final class RecentWorktreeStore {
  var entries: [RecentWorktreeEntry] = []

  /// Maximum number of recent entries to keep.
  private let maxEntries = 20

  private let storageURL: URL

  init() {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let appDir = appSupport.appendingPathComponent("Bourbaki", isDirectory: true)
    try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
    storageURL = appDir.appendingPathComponent("recent_worktrees.json")
    load()
  }

  // MARK: - Public API

  /// Record that a worktree was opened. Moves it to the top if already present.
  func recordOpen(path: URL, projectName: String, worktreeName: String) {
    let pathString = path.standardizedFileURL.path
    let displayName = projectName == worktreeName ? projectName : "\(projectName) · \(worktreeName)"

    // Remove existing entry for this path
    entries.removeAll { $0.path == pathString }

    // Insert at the beginning
    let entry = RecentWorktreeEntry(
      path: pathString,
      displayName: displayName,
      projectName: projectName,
      worktreeName: worktreeName,
      lastOpened: Date()
    )
    entries.insert(entry, at: 0)

    // Trim to max
    if entries.count > maxEntries {
      entries = Array(entries.prefix(maxEntries))
    }

    save()
  }

  /// Remove a specific entry.
  func removeEntry(_ id: String) {
    entries.removeAll { $0.id == id }
    save()
  }

  /// Clear all recent entries.
  func clearAll() {
    entries.removeAll()
    save()
  }

  /// Get the URL for an entry, if the path still exists.
  func url(for entry: RecentWorktreeEntry) -> URL? {
    let url = URL(fileURLWithPath: entry.path)
    guard FileManager.default.fileExists(atPath: entry.path) else { return nil }
    return url
  }

  // MARK: - Persistence

  private func load() {
    guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
    do {
      let data = try Data(contentsOf: storageURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      entries = try decoder.decode([RecentWorktreeEntry].self, from: data)
    } catch {
      print("[RecentWorktreeStore] Failed to load: \(error)")
    }
  }

  private func save() {
    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = .prettyPrinted
      let data = try encoder.encode(entries)
      try data.write(to: storageURL, options: .atomic)
    } catch {
      print("[RecentWorktreeStore] Failed to save: \(error)")
    }
  }
}
