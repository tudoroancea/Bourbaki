import SwiftUI

struct TerminalTabBarView: View {
  @Bindable var tabManager: TerminalTabManager

  var body: some View {
    HStack(spacing: 0) {
      // Tabs — equal width, filling available space
      HStack(spacing: 2) {
        ForEach(Array(tabManager.visibleTabs.enumerated()), id: \.element.id) {
          index, tab in
          TabItemView(
            tab: tab,
            index: index,
            isSelected: tabManager.selectedTabID == tab.id,
            onSelect: { tabManager.selectTab(tab.id) },
            onClose: { tabManager.closeTab(tab.id) }
          )
          .frame(maxWidth: .infinity)
        }
      }

      // + button to add a new tab
      Button {
        guard let dir = tabManager.selectedWorktreePath else { return }
        tabManager.createTab(type: .shell, workingDirectory: dir)
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(RosePine.subtle)
          .frame(width: 30, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .padding(.trailing, 6)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .background(RosePine.base)
  }
}

// MARK: - Tab Item

private struct TabItemView: View {
  let tab: TerminalTab
  let index: Int
  let isSelected: Bool
  let onSelect: () -> Void
  let onClose: () -> Void

  @State private var isHovering = false

  private var shortcutLabel: String? {
    guard index < 9 else { return nil }
    return "⌘⌃\(index + 1)"
  }

  var body: some View {
    HStack(spacing: 0) {
      // Close button (left side)
      Button(action: onClose) {
        Image(systemName: "xmark")
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(RosePine.muted)
          .frame(width: 18, height: 18)
      }
      .buttonStyle(.plain)
      .opacity(isHovering || isSelected ? 1 : 0)

      Spacer(minLength: 0)

      // Centered title + status indicators
      HStack(spacing: 5) {
        if tab.hasNotification {
          Circle()
            .fill(RosePine.notificationBadge)
            .frame(width: 6, height: 6)
        }

        if tab.isRunning {
          ProgressView()
            .controlSize(.mini)
            .scaleEffect(0.7)
        }

        Image(systemName: tab.type.iconName)
          .font(.system(size: 10))
          .foregroundStyle(isSelected ? RosePine.text : RosePine.muted)

        Text(tab.title)
          .font(.system(size: 12))
          .lineLimit(1)
          .foregroundStyle(isSelected ? RosePine.text : RosePine.subtle)
      }

      Spacer(minLength: 0)

      // Shortcut hint (right side)
      if let shortcutLabel {
        Text(shortcutLabel)
          .font(.system(size: 9, weight: .medium, design: .rounded))
          .foregroundStyle(RosePine.muted.opacity(0.6))
          .opacity(isHovering || isSelected ? 1 : 0)
      } else {
        // Placeholder to keep layout balanced
        Color.clear.frame(width: 18, height: 18)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(
          isSelected
            ? RosePine.surface
            : (isHovering ? RosePine.highlightLow.opacity(0.6) : Color.clear)
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(
          isSelected
            ? RosePine.highlightHigh.opacity(0.6)
            : (isHovering ? RosePine.highlightMed.opacity(0.4) : RosePine.highlightMed.opacity(0.2)),
          lineWidth: 1
        )
    )
    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .onTapGesture(perform: onSelect)
    .onHover { hovering in
      isHovering = hovering
    }
  }
}
