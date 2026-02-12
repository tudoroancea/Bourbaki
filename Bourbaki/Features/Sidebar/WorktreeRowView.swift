import SwiftUI

struct WorktreeRowView: View {
  let name: String
  let addedLines: Int?
  let removedLines: Int?
  let sessionStatus: SessionStatus
  var isMainWorktree: Bool = false
  var onDelete: (() -> Void)?

  @State private var isHovering = false
  @State private var optionHeld = false
  @State private var isHoveringDelete = false
  @State private var flagsMonitor: Any?

  /// Show the delete button only when hovering with Option held and a delete action exists.
  private var showDeleteButton: Bool {
    isHovering && optionHeld && onDelete != nil
  }

  var body: some View {
    HStack(spacing: 8) {
      // Status indicator
      statusIndicator

      // Worktree/branch name
      Text(name)
        .font(.jetBrainsMono(size: 13))
        .foregroundStyle(RosePine.text)
        .lineLimit(1)
        .truncationMode(.middle)

      if isMainWorktree {
        Image(systemName: "pin.fill")
          .font(.jetBrainsMono(size: 9))
          .foregroundStyle(RosePine.muted)
          .help("Main worktree — cannot be deleted")
      }

      Spacer()

      // Diff stats
      if let added = addedLines, let removed = removedLines, (added > 0 || removed > 0) {
        HStack(spacing: 4) {
          if added > 0 {
            Text("+\(added)")
              .font(.jetBrainsMono(size: 11))
              .foregroundStyle(RosePine.diffAdded)
          }
          if removed > 0 {
            Text("-\(removed)")
              .font(.jetBrainsMono(size: 11))
              .foregroundStyle(RosePine.diffRemoved)
          }
        }
      }

      if showDeleteButton {
        Button {
          onDelete?()
        } label: {
          Image(systemName: "xmark")
            .font(.jetBrainsMono(size: 9, weight: .bold))
            .foregroundStyle(isHoveringDelete ? RosePine.love : RosePine.subtle)
        }
        .buttonStyle(.plain)
        .help("Delete worktree")
        .onHover { hovering in
          isHoveringDelete = hovering
        }
      }
    }
    .padding(.vertical, 2)
    .contentShape(Rectangle())
    .onHover { hovering in
      isHovering = hovering
      if hovering {
        // Check current modifier state immediately on hover
        optionHeld = NSEvent.modifierFlags.contains(.option)
        startMonitoringFlags()
      } else {
        optionHeld = false
        stopMonitoringFlags()
      }
    }
  }

  // MARK: - Modifier Key Monitoring

  private func startMonitoringFlags() {
    guard flagsMonitor == nil else { return }
    flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
      optionHeld = event.modifierFlags.contains(.option)
      return event
    }
  }

  private func stopMonitoringFlags() {
    if let monitor = flagsMonitor {
      NSEvent.removeMonitor(monitor)
      flagsMonitor = nil
    }
  }

  // MARK: - Status Indicator

  @ViewBuilder
  private var statusIndicator: some View {
    switch sessionStatus {
    case .running:
      Circle()
        .fill(RosePine.statusRunning)
        .frame(width: 8, height: 8)
        .help("Agent session running")
    case .idle:
      Circle()
        .fill(RosePine.statusIdle)
        .frame(width: 8, height: 8)
        .help("Agent session idle")
    case .terminal:
      Circle()
        .fill(RosePine.statusTerminal)
        .frame(width: 8, height: 8)
        .help("Terminal open (no agent session)")
    case .stopped:
      Circle()
        .strokeBorder(RosePine.statusStopped, lineWidth: 1)
        .frame(width: 8, height: 8)
        .help("No active session")
    }
  }
}
