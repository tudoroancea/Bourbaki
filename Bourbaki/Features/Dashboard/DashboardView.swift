import AppKit
import SwiftUI

/// Dashboard shown when no worktree is currently active.
/// Displays recently opened worktrees with keyboard shortcuts to quickly reopen them.
struct DashboardView: View {
  @Bindable var recentStore: RecentWorktreeStore
  var toolSettings: ToolSettings?
  let onSelectWorktree: (URL) -> Void

  var body: some View {
    ZStack {
      // Invisible view that claims first responder so menu shortcuts work
      DashboardFocusView()
        .frame(width: 0, height: 0)

      VStack(spacing: 0) {
        Spacer()

        VStack(spacing: 24) {
          // Header
          VStack(spacing: 8) {
            HStack(spacing: 12) {
              Image("DangerousBend")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 48)
              Text("Bourbaki")
                .font(.jetBrainsMono(size: 32, weight: .bold))
                .foregroundStyle(RosePine.text)
            }
            Text("Select a worktree from the sidebar, or reopen a recent one")
              .font(.jetBrainsMono(size: 14))
              .foregroundStyle(RosePine.subtle)
          }

          if recentStore.entries.isEmpty {
            emptyState
          } else {
            recentList
          }
        }
        .frame(maxWidth: 500)

        Spacer()

        // Tool availability warnings
        if let settings = toolSettings, !settings.unavailableTools.isEmpty {
          toolWarningBanner(settings: settings)
            .padding(.bottom, 16)
            .padding(.horizontal, 24)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(RosePine.base)
  }

  private func toolWarningBanner(settings: ToolSettings) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(RosePine.gold)
        Text("Some tools are not available")
          .font(.jetBrainsMono(size: 13, weight: .semibold))
          .foregroundStyle(RosePine.text)
      }
      ForEach(settings.unavailableTools, id: \.type) { tool in
        HStack(spacing: 6) {
          Image(systemName: tool.type.iconName)
            .frame(width: 16)
            .foregroundStyle(RosePine.muted)
          Text("\(tool.type.displayName): \(tool.error)")
            .font(.jetBrainsMono(size: 12))
            .foregroundStyle(RosePine.subtle)
        }
      }
      Text("Configure commands in Settings (⌘,)")
        .font(.jetBrainsMono(size: 11))
        .foregroundStyle(RosePine.muted)
        .padding(.top, 2)
    }
    .padding(12)
    .frame(maxWidth: 500, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(RosePine.highlightLow)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .strokeBorder(RosePine.gold.opacity(0.3), lineWidth: 1)
        )
    )
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "clock")
        .font(.jetBrainsMono(size: 36))
        .foregroundStyle(RosePine.muted)
      Text("No recent worktrees")
        .font(.jetBrainsMono(size: 14))
        .foregroundStyle(RosePine.muted)
    }
    .padding(.top, 16)
  }

  private var recentList: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("RECENT")
        .font(.jetBrainsMono(size: 11, weight: .semibold))
        .foregroundStyle(RosePine.muted)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)

      ForEach(Array(recentStore.entries.prefix(9).enumerated()), id: \.element.id) { index, entry in
        RecentWorktreeRow(
          entry: entry,
          index: index + 1,
          isValid: recentStore.url(for: entry) != nil,
          onSelect: {
            if let url = recentStore.url(for: entry) {
              onSelectWorktree(url)
            }
          }
        )
      }
    }
    .padding(.top, 8)
  }
}

// MARK: - Row

private struct RecentWorktreeRow: View {
  let entry: RecentWorktreeEntry
  let index: Int
  let isValid: Bool
  let onSelect: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 12) {
        // Shortcut badge
        Text("\(index)")
          .font(.jetBrainsMono(size: 12, weight: .semibold))
          .foregroundStyle(isHovered ? RosePine.base : RosePine.subtle)
          .frame(width: 24, height: 24)
          .background(
            RoundedRectangle(cornerRadius: 4)
              .fill(isHovered ? RosePine.iris : RosePine.highlightMed)
          )

        // Info
        VStack(alignment: .leading, spacing: 2) {
          Text(entry.displayName)
            .font(.jetBrainsMono(size: 14, weight: .medium))
            .foregroundStyle(isValid ? RosePine.text : RosePine.muted)
            .lineLimit(1)

          Text(entry.path)
            .font(.jetBrainsMono(size: 11))
            .foregroundStyle(RosePine.muted)
            .lineLimit(1)
            .truncationMode(.middle)
        }

        Spacer()

        // Relative time
        Text(relativeTime(entry.lastOpened))
          .font(.jetBrainsMono(size: 11))
          .foregroundStyle(RosePine.muted)

        if !isValid {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 12))
            .foregroundStyle(RosePine.gold)
            .help("Path no longer exists")
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(isHovered ? RosePine.highlightLow : Color.clear)
      )
    }
    .buttonStyle(.plain)
    .disabled(!isValid)
    .onHover { isHovered = $0 }
  }

  private func relativeTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

// MARK: - Focus View

/// An invisible NSView that claims first responder when the dashboard is shown,
/// ensuring the window has a proper responder chain for menu keyboard shortcuts.
private struct DashboardFocusView: NSViewRepresentable {
  func makeNSView(context: Context) -> DashboardNSView {
    let view = DashboardNSView()
    // Claim first responder once the view is in the window
    DispatchQueue.main.async {
      view.window?.makeFirstResponder(view)
    }
    return view
  }

  func updateNSView(_ nsView: DashboardNSView, context: Context) {
    // Re-claim first responder on updates (e.g. when returning to dashboard)
    DispatchQueue.main.async {
      if nsView.window?.firstResponder !== nsView {
        nsView.window?.makeFirstResponder(nsView)
      }
    }
  }
}

/// Minimal NSView subclass that accepts first responder status.
private final class DashboardNSView: NSView {
  override var acceptsFirstResponder: Bool { true }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    DispatchQueue.main.async { [weak self] in
      guard let self, let window = self.window else { return }
      window.makeFirstResponder(self)
    }
  }
}
