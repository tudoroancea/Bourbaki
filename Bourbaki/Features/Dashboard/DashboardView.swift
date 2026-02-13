import AppKit
import SwiftUI

/// Dashboard shown when no worktree is currently active.
/// Displays active worktrees (with status) and recently opened worktrees.
struct DashboardView: View {
  @Bindable var tabManager: TerminalTabManager
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
            Text("Keep working on hard things")
              .font(.jetBrainsMono(size: 14))
              .foregroundStyle(RosePine.subtle)
          }

          if !activeWorktrees.isEmpty {
            activeList
          }

          if recentStore.entries.isEmpty && activeWorktrees.isEmpty {
            emptyState
          } else if !recentStore.entries.isEmpty {
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
    .onAppear {
      recentStore.pruneInvalidEntries()
    }
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

  /// Active worktrees with open tabs, paired with display info from the project store.
  private var activeWorktrees: [(path: URL, displayName: String, projectName: String, worktreeName: String)] {
    let paths = tabManager.activeWorktreePaths
    guard let store = tabManager.projectStore else {
      return paths.map { url in
        let name = url.lastPathComponent
        return (path: url, displayName: name, projectName: name, worktreeName: name)
      }
    }
    return paths.compactMap { url in
      let std = url.standardizedFileURL
      for project in store.projects {
        if let wt = project.worktrees.first(where: { $0.path.standardizedFileURL == std }) {
          let display = project.name == wt.name ? project.name : "\(project.name) · \(wt.name)"
          return (path: url, displayName: display, projectName: project.name, worktreeName: wt.name)
        }
        if project.rootPath.standardizedFileURL == std {
          return (path: url, displayName: project.name, projectName: project.name, worktreeName: project.name)
        }
      }
      let name = url.lastPathComponent
      return (path: url, displayName: name, projectName: name, worktreeName: name)
    }
  }

  /// Set of standardized paths for active worktrees (for shortcut matching in recents).
  private var activeWorktreePathSet: Set<String> {
    Set(tabManager.activeWorktreePaths.map { $0.standardizedFileURL.path })
  }

  /// Map from active worktree path → Cmd+N shortcut index (1-based).
  private var activeWorktreeShortcutIndex: [String: Int] {
    var map: [String: Int] = [:]
    for (i, wt) in activeWorktrees.prefix(9).enumerated() {
      map[wt.path.standardizedFileURL.path] = i + 1
    }
    return map
  }

  @ViewBuilder
  private func worktreeContextMenu(for path: URL) -> some View {
    Button("Open Agent Session") {
      tabManager.createTab(type: .agent, workingDirectory: path)
    }
    Button("Open Git") {
      tabManager.createTab(type: .git, workingDirectory: path)
    }
    Button("Open Diff") {
      tabManager.createTab(type: .diff, workingDirectory: path)
    }
    Button("Open Shell") {
      tabManager.createTab(type: .shell, workingDirectory: path)
    }
    Divider()
    Button("Copy Path") {
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(path.path, forType: .string)
    }
    Button("Open in Editor") {
      ExternalAppLauncher.openInEditor(path: path)
    }
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

  private var activeList: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("ACTIVE")
        .font(.jetBrainsMono(size: 11, weight: .semibold))
        .foregroundStyle(RosePine.muted)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)

      ForEach(Array(activeWorktrees.prefix(9).enumerated()), id: \.element.path) { index, wt in
        ActiveWorktreeRow(
          displayName: wt.displayName,
          path: wt.path.path,
          sessionStatus: tabManager.sessionStatus(for: wt.path),
          index: index + 1,
          onSelect: { onSelectWorktree(wt.path) }
        )
        .contextMenu { worktreeContextMenu(for: wt.path) }
      }
    }
    .padding(.top, 8)
  }

  private var recentList: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("RECENT")
        .font(.jetBrainsMono(size: 11, weight: .semibold))
        .foregroundStyle(RosePine.muted)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)

      ForEach(Array(recentStore.entries.prefix(9).enumerated()), id: \.element.id) { _, entry in
        RecentWorktreeRow(
          entry: entry,
          shortcutIndex: activeWorktreeShortcutIndex[URL(fileURLWithPath: entry.path).standardizedFileURL.path],
          isValid: recentStore.url(for: entry) != nil,
          onSelect: {
            if let url = recentStore.url(for: entry) {
              onSelectWorktree(url)
            }
          }
        )
        .contextMenu {
          if let url = recentStore.url(for: entry) {
            worktreeContextMenu(for: url)
          }
        }
      }
    }
    .padding(.top, 8)
  }
}

// MARK: - Active Worktree Row

private struct ActiveWorktreeRow: View {
  let displayName: String
  let path: String
  let sessionStatus: SessionStatus
  let index: Int
  let onSelect: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 12) {
        // Shortcut badge
        Text("⌘\(index)")
          .font(.jetBrainsMono(size: 11, weight: .semibold))
          .foregroundStyle(isHovered ? RosePine.base : RosePine.subtle)
          .frame(width: 32, height: 24)
          .background(
            RoundedRectangle(cornerRadius: 4)
              .fill(isHovered ? RosePine.iris : RosePine.highlightMed)
          )

        // Status indicator
        statusIndicator

        // Info
        VStack(alignment: .leading, spacing: 2) {
          Text(displayName)
            .font(.jetBrainsMono(size: 14, weight: .medium))
            .foregroundStyle(RosePine.text)
            .lineLimit(1)

          Text(path)
            .font(.jetBrainsMono(size: 11))
            .foregroundStyle(RosePine.muted)
            .lineLimit(1)
            .truncationMode(.middle)
        }

        Spacer()
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(isHovered ? RosePine.highlightLow : Color.clear)
      )
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }

  @ViewBuilder
  private var statusIndicator: some View {
    switch sessionStatus {
    case .running:
      Circle()
        .fill(RosePine.statusRunning)
        .frame(width: 8, height: 8)
    case .idle:
      Circle()
        .fill(RosePine.statusIdle)
        .frame(width: 8, height: 8)
    case .terminal:
      Circle()
        .fill(RosePine.statusTerminal)
        .frame(width: 8, height: 8)
    case .stopped:
      Circle()
        .strokeBorder(RosePine.statusStopped, lineWidth: 1)
        .frame(width: 8, height: 8)
    }
  }
}

// MARK: - Row

private struct RecentWorktreeRow: View {
  let entry: RecentWorktreeEntry
  /// If this recent entry is also an active worktree, show its Cmd+N shortcut index (1-based). Nil = no shortcut.
  let shortcutIndex: Int?
  let isValid: Bool
  let onSelect: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 12) {
        // Shortcut badge — always reserve the same width for alignment
        if let idx = shortcutIndex {
          Text("⌘\(idx)")
            .font(.jetBrainsMono(size: 11, weight: .semibold))
            .foregroundStyle(isHovered ? RosePine.base : RosePine.subtle)
            .frame(width: 32, height: 24)
            .background(
              RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? RosePine.iris : RosePine.highlightMed)
            )
        } else {
          Color.clear
            .frame(width: 32, height: 24)
        }

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
