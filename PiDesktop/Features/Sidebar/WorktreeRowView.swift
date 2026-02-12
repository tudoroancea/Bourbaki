import SwiftUI

struct WorktreeRowView: View {
  let name: String
  let addedLines: Int?
  let removedLines: Int?
  let sessionStatus: SessionStatus

  var body: some View {
    HStack(spacing: 8) {
      // Status indicator
      statusIndicator

      // Worktree/branch name
      Text(name)
        .font(.system(size: 13))
        .lineLimit(1)
        .truncationMode(.middle)

      Spacer()

      // Diff stats
      if let added = addedLines, let removed = removedLines, (added > 0 || removed > 0) {
        HStack(spacing: 4) {
          if added > 0 {
            Text("+\(added)")
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.green)
          }
          if removed > 0 {
            Text("-\(removed)")
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.red)
          }
        }
      }
    }
    .padding(.vertical, 2)
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private var statusIndicator: some View {
    switch sessionStatus {
    case .running:
      Circle()
        .fill(.green)
        .frame(width: 8, height: 8)
        .help("Pi session running")
    case .idle:
      Circle()
        .fill(.yellow)
        .frame(width: 8, height: 8)
        .help("Pi session idle")
    case .stopped:
      Circle()
        .strokeBorder(.secondary.opacity(0.5), lineWidth: 1)
        .frame(width: 8, height: 8)
        .help("No active session")
    }
  }
}
