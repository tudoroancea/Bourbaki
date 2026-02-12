import SwiftUI

struct TerminalTabBarView: View {
  @Bindable var tabManager: TerminalTabManager

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 2) {
        ForEach(tabManager.visibleTabs) { tab in
          TabItemView(
            tab: tab,
            isSelected: tabManager.selectedTabID == tab.id,
            onSelect: { tabManager.selectTab(tab.id) },
            onClose: { tabManager.closeTab(tab.id) }
          )
        }
      }
      .padding(.horizontal, 8)
    }
    .frame(height: 36)
    .background(.bar)
  }
}

private struct TabItemView: View {
  let tab: TerminalTab
  let isSelected: Bool
  let onSelect: () -> Void
  let onClose: () -> Void

  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: tab.type.iconName)
        .font(.system(size: 11))
        .foregroundStyle(isSelected ? .primary : .secondary)

      Text(tab.title)
        .font(.system(size: 12))
        .lineLimit(1)
        .foregroundStyle(isSelected ? .primary : .secondary)

      if tab.hasNotification {
        Circle()
          .fill(.blue)
          .frame(width: 6, height: 6)
      }

      if tab.isRunning {
        ProgressView()
          .controlSize(.mini)
          .scaleEffect(0.7)
      }

      if isHovering || isSelected {
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(width: 16, height: 16)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovering ? Color.primary.opacity(0.05) : Color.clear))
    )
    .onTapGesture(perform: onSelect)
    .onHover { hovering in
      isHovering = hovering
    }
  }
}
