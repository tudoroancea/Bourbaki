import SwiftUI

struct SettingsView: View {
  @Bindable var toolSettings: ToolSettings

  @State private var agentDraft: String = ""
  @State private var gitDraft: String = ""
  @State private var diffDraft: String = ""

  /// Debounce tasks keyed by tab type, cancelled on each keystroke.
  @State private var debounceTasks: [TabType: Task<Void, Never>] = [:]

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("Settings")
          .font(.jetBrainsMono(size: 18, weight: .bold))
          .foregroundStyle(RosePine.text)
        Spacer()
        if toolSettings.isChecking {
          ProgressView()
            .scaleEffect(0.6)
            .frame(width: 16, height: 16)
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 20)
      .padding(.bottom, 16)

      // Section header
      HStack {
        Text("TOOL COMMANDS")
          .font(.jetBrainsMono(size: 11, weight: .semibold))
          .foregroundStyle(RosePine.muted)
        Spacer()
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 8)

      // Tool rows
      VStack(spacing: 1) {
        toolRow(
          label: "Agent",
          icon: "terminal",
          draft: $agentDraft,
          defaultValue: ToolSettings.defaultAgentCommand,
          tabType: .agent
        )
        toolRow(
          label: "Git",
          icon: "arrow.triangle.branch",
          draft: $gitDraft,
          defaultValue: ToolSettings.defaultGitCommand,
          tabType: .git
        )
        toolRow(
          label: "Diff",
          icon: "doc.text.magnifyingglass",
          draft: $diffDraft,
          defaultValue: ToolSettings.defaultDiffCommand,
          tabType: .diff
        )
      }
      .background(RosePine.surface)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .padding(.horizontal, 24)

      // Footer
      Text("The first word of each command must be an executable found in your PATH.")
        .font(.jetBrainsMono(size: 11))
        .foregroundStyle(RosePine.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 8)

      Spacer()
    }
    .frame(width: 500, height: 300)
    .background(RosePine.base)
    .onAppear {
      agentDraft = toolSettings.agentCommand
      gitDraft = toolSettings.gitCommand
      diffDraft = toolSettings.diffCommand
    }
  }

  @ViewBuilder
  private func toolRow(
    label: String,
    icon: String,
    draft: Binding<String>,
    defaultValue: String,
    tabType: TabType
  ) -> some View {
    HStack(spacing: 10) {
      // Label
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 12))
          .foregroundStyle(RosePine.subtle)
          .frame(width: 16)
        Text(label)
          .font(.jetBrainsMono(size: 13, weight: .medium))
          .foregroundStyle(RosePine.text)
      }
      .frame(width: 80, alignment: .leading)

      // Text field
      TextField(defaultValue, text: draft)
        .textFieldStyle(.plain)
        .font(.jetBrainsMono(size: 13))
        .foregroundStyle(RosePine.text)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
          RoundedRectangle(cornerRadius: 4)
            .fill(RosePine.highlightLow)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 4)
            .strokeBorder(RosePine.highlightMed, lineWidth: 1)
        )
        .onChange(of: draft.wrappedValue) { _, newValue in
          scheduleDebouncedApply(newValue, for: tabType)
        }

      // Status indicator
      statusIcon(for: tabType)
        .frame(width: 20)

      // Reset button
      Button {
        draft.wrappedValue = defaultValue
        applyImmediately(defaultValue, for: tabType)
      } label: {
        Image(systemName: "arrow.counterclockwise")
          .font(.system(size: 11))
          .foregroundStyle(RosePine.subtle)
      }
      .buttonStyle(.plain)
      .help("Reset to default")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private func statusIcon(for tabType: TabType) -> some View {
    if toolSettings.isChecking {
      Image(systemName: "ellipsis")
        .font(.system(size: 12))
        .foregroundStyle(RosePine.muted)
    } else if let error = toolSettings.toolErrors[tabType] {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 12))
        .foregroundStyle(RosePine.gold)
        .help(error)
    } else {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 12))
        .foregroundStyle(RosePine.foam)
    }
  }

  // MARK: - Debounced apply

  private func scheduleDebouncedApply(_ value: String, for tabType: TabType) {
    // Cancel any pending debounce for this tab type
    debounceTasks[tabType]?.cancel()

    debounceTasks[tabType] = Task { @MainActor in
      // Wait 500ms before applying
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled else { return }
      applyImmediately(value, for: tabType)
    }
  }

  private func applyImmediately(_ value: String, for tabType: TabType) {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    switch tabType {
    case .agent: toolSettings.agentCommand = trimmed
    case .git: toolSettings.gitCommand = trimmed
    case .diff: toolSettings.diffCommand = trimmed
    case .shell: break
    }
    toolSettings.checkToolAvailability()
  }
}
