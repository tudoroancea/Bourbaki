import Foundation

/// Metadata about a pi session file (a .jsonl in ~/.pi/agent/sessions/).
struct PiSession: Identifiable, Hashable {
  let id: String // session file name (without extension)
  let path: URL
  var lastModified: Date
}
