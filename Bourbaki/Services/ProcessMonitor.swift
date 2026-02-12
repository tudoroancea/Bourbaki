import Foundation

/// Checks whether an agent process is running in a given directory.
enum ProcessMonitor {

  /// Check if a `pi` or `node` process is running with the given directory as its cwd.
  static func isPiRunning(in directory: URL) async -> Bool {
    let dirPath = directory.standardizedFileURL.path

    return await Task.detached {
      let pids = findPiPids()
      guard !pids.isEmpty else { return false }

      for pid in pids {
        if let cwd = processCwd(pid: pid), cwd.hasPrefix(dirPath) {
          return true
        }
      }
      return false
    }.value
  }

  // MARK: - Private

  /// Find PIDs of processes that look like the agent (node/bun running pi).
  private static func findPiPids() -> [Int] {
    guard let output = runProcess("/bin/ps", arguments: ["-eo", "pid,comm"]) else {
      return []
    }

    var pids: [Int] = []
    for line in output.components(separatedBy: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.contains("node") || trimmed.contains("bun") || trimmed.contains("/pi") {
        let parts = trimmed.split(separator: " ", maxSplits: 1)
        if let pidStr = parts.first, let pid = Int(pidStr) {
          pids.append(pid)
        }
      }
    }
    return pids
  }

  /// Get the current working directory of a process by PID.
  private static func processCwd(pid: Int) -> String? {
    guard let output = runProcess("/usr/sbin/lsof", arguments: ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]) else {
      return nil
    }

    for line in output.components(separatedBy: "\n") {
      if line.hasPrefix("n") && !line.hasPrefix("n ") {
        return String(line.dropFirst())
      }
    }
    return nil
  }

  /// Run a process synchronously (must be called off the main thread).
  private static func runProcess(_ path: String, arguments: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
      try process.run()
    } catch {
      return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(data: data, encoding: .utf8)
  }
}
