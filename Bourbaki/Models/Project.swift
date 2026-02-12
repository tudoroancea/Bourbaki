import Foundation

/// A registered project (a git repository root path).
struct Project: Identifiable, Hashable {
  let id: UUID
  let rootPath: URL
  var name: String
  var worktrees: [ProjectWorktree] = []

  init(id: UUID = UUID(), rootPath: URL, name: String? = nil) {
    self.id = id
    self.rootPath = rootPath
    self.name = name ?? rootPath.lastPathComponent
  }
}

// MARK: - Codable (persist only id + rootPath)

extension Project: Codable {
  enum CodingKeys: String, CodingKey {
    case id, rootPath, name
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    rootPath = try container.decode(URL.self, forKey: .rootPath)
    name = try container.decode(String.self, forKey: .name)
    worktrees = []
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(rootPath, forKey: .rootPath)
    try container.encode(name, forKey: .name)
  }
}
