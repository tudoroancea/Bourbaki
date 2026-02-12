import Foundation

/// Persists user-configured commands for each tool tab type and checks tool availability at startup.
@MainActor
@Observable
final class ToolSettings {
  // MARK: - User-configurable commands

  var agentCommand: String {
    didSet { UserDefaults.standard.set(agentCommand, forKey: Keys.agent) }
  }
  var gitCommand: String {
    didSet { UserDefaults.standard.set(gitCommand, forKey: Keys.git) }
  }
  var diffCommand: String {
    didSet { UserDefaults.standard.set(diffCommand, forKey: Keys.diff) }
  }

  // MARK: - Tool availability (populated at startup)

  /// Maps tool name to availability error message (nil = available).
  var toolErrors: [TabType: String] = [:]

  /// Whether a check is currently in progress.
  var isChecking: Bool = false

  // MARK: - Defaults

  static let defaultAgentCommand = "pi"
  static let defaultGitCommand = "lazygit"
  static let defaultDiffCommand = "lumen diff"

  private enum Keys {
    static let agent = "toolCommand.agent"
    static let git = "toolCommand.git"
    static let diff = "toolCommand.diff"
  }

  /// Cached shell environment (computed once at init).
  private let cachedShellEnvironment: [String: String]

  init() {
    self.cachedShellEnvironment = Self.buildShellEnvironment()
    self.agentCommand = UserDefaults.standard.string(forKey: Keys.agent) ?? Self.defaultAgentCommand
    self.gitCommand = UserDefaults.standard.string(forKey: Keys.git) ?? Self.defaultGitCommand
    self.diffCommand = UserDefaults.standard.string(forKey: Keys.diff) ?? Self.defaultDiffCommand
  }

  /// The shell command string for a given tab type, using user settings.
  func command(for type: TabType) -> String? {
    switch type {
    case .agent: return "clear && exec \(agentCommand)"
    case .git: return "clear && exec \(gitCommand)"
    case .diff: return "clear && exec \(diffCommand)"
    case .shell: return nil
    }
  }

  /// The raw executable name (first word of the command) for a tab type.
  func executableName(for type: TabType) -> String? {
    switch type {
    case .agent: return agentCommand.components(separatedBy: " ").first
    case .git: return gitCommand.components(separatedBy: " ").first
    case .diff: return diffCommand.components(separatedBy: " ").first
    case .shell: return nil
    }
  }

  /// Check all tool commands asynchronously and populate `toolErrors`.
  func checkToolAvailability() {
    isChecking = true
    let env = cachedShellEnvironment
    let checks: [(TabType, String?)] = TabType.toolTypes.map { ($0, executableName(for: $0)) }

    Task.detached(priority: .utility) {
      var errors: [TabType: String] = [:]
      for (type, exe) in checks {
        guard let exe, !exe.isEmpty else { continue }
        if !Self.isExecutableInPath(exe, environment: env) {
          errors[type] = "'\(exe)' not found in PATH"
        }
      }
      await MainActor.run {
        self.toolErrors = errors
        self.isChecking = false
      }
    }
  }

  /// Whether the given tab type's tool is available.
  func isAvailable(_ type: TabType) -> Bool {
    toolErrors[type] == nil
  }

  /// Returns all unavailable tools with their error messages.
  var unavailableTools: [(type: TabType, error: String)] {
    TabType.toolTypes.compactMap { type in
      if let error = toolErrors[type] {
        return (type, error)
      }
      return nil
    }
  }

  // MARK: - Private

  private nonisolated static func isExecutableInPath(_ name: String, environment: [String: String]) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = [name]
    process.environment = environment
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
      try process.run()
      process.waitUntilExit()
      return process.terminationStatus == 0
    } catch {
      return false
    }
  }

  /// Build environment with augmented PATH so we pick up tools from common locations.
  private nonisolated static func buildShellEnvironment() -> [String: String] {
    var env = ProcessInfo.processInfo.environment

    let extraPaths = [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/opt/homebrew/sbin",
      "\(NSHomeDirectory())/.local/bin",
      "\(NSHomeDirectory())/.cargo/bin",
      "\(NSHomeDirectory())/.bun/bin",
      "\(NSHomeDirectory())/.local/share/mise/shims",
    ]

    let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
    let combined = (extraPaths + currentPath.components(separatedBy: ":"))
      .filter { !$0.isEmpty }
    var seen = Set<String>()
    let deduped = combined.filter { seen.insert($0).inserted }
    env["PATH"] = deduped.joined(separator: ":")
    return env
  }
}

extension TabType {
  /// Tab types that correspond to configurable tools (excludes shell).
  static let toolTypes: [TabType] = [.agent, .git, .diff]
}
