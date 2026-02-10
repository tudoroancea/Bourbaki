import Foundation
import GhosttyKit
@preconcurrency import UserNotifications

/// Delegate that allows notifications to show even when the app is in the foreground.
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}

@MainActor
@Observable
final class TerminalTabManager {
  var tabs: [TerminalTab] = []
  var selectedTabID: UUID?

  private let runtime: GhosttyRuntime
  private let notificationDelegate = NotificationDelegate()

  init(runtime: GhosttyRuntime) {
    self.runtime = runtime
    let center = UNUserNotificationCenter.current()
    center.delegate = notificationDelegate
    center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
  }

  var selectedTab: TerminalTab? {
    guard let selectedTabID else { return nil }
    return tabs.first { $0.id == selectedTabID }
  }

  @discardableResult
  func createTab(type: TabType, workingDirectory: URL) -> UUID {
    let initialInput = type.command.map { "\($0)\n" }
    let surfaceView = GhosttySurfaceView(
      runtime: runtime,
      workingDirectory: workingDirectory,
      initialInput: initialInput
    )

    let tab = TerminalTab(
      type: type,
      title: type.displayName,
      surfaceView: surfaceView
    )

    // Wire up callbacks
    surfaceView.bridge.onTitleChange = { [weak tab] title in
      tab?.title = title
    }

    surfaceView.bridge.onCloseRequest = { [weak self, tabID = tab.id] _ in
      self?.closeTab(tabID)
    }

    surfaceView.bridge.onProgressReport = { [weak tab] state in
      switch state {
      case GHOSTTY_PROGRESS_STATE_SET, GHOSTTY_PROGRESS_STATE_INDETERMINATE:
        tab?.isRunning = true
      case GHOSTTY_PROGRESS_STATE_REMOVE:
        tab?.isRunning = false
      default:
        break
      }
    }

    surfaceView.bridge.onDesktopNotification = { [weak self, weak tab] title, body in
      guard let self, let tab else { return }
      // Mark tab as having a notification if it's not currently selected
      if self.selectedTabID != tab.id {
        tab.hasNotification = true
      }
      // Post system notification
      self.postSystemNotification(title: title, body: body)
    }

    // Wire tab navigation from ghostty
    surfaceView.bridge.onNewTab = { [weak self] in
      guard let self else { return false }
      let dir = workingDirectory
      self.createTab(type: .shell, workingDirectory: dir)
      return true
    }

    surfaceView.bridge.onCloseTab = { [weak self, tabID = tab.id] _ in
      self?.closeTab(tabID)
      return true
    }

    surfaceView.bridge.onGotoTab = { [weak self] gotoTab in
      self?.handleGotoTab(gotoTab) ?? false
    }

    tabs.append(tab)
    selectedTabID = tab.id
    return tab.id
  }

  func closeTab(_ id: UUID) {
    guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
    let tab = tabs.remove(at: index)
    tab.surfaceView.closeSurface()

    if selectedTabID == id {
      // Select the nearest tab
      if tabs.isEmpty {
        selectedTabID = nil
      } else {
        let newIndex = min(index, tabs.count - 1)
        selectedTabID = tabs[newIndex].id
      }
    }
  }

  func selectTab(_ id: UUID) {
    guard let tab = tabs.first(where: { $0.id == id }) else { return }
    selectedTabID = id
    tab.hasNotification = false
  }

  func selectNextTab() {
    guard let currentID = selectedTabID,
          let currentIndex = tabs.firstIndex(where: { $0.id == currentID }),
          !tabs.isEmpty
    else { return }
    let nextIndex = (currentIndex + 1) % tabs.count
    selectTab(tabs[nextIndex].id)
  }

  func selectPreviousTab() {
    guard let currentID = selectedTabID,
          let currentIndex = tabs.firstIndex(where: { $0.id == currentID }),
          !tabs.isEmpty
    else { return }
    let prevIndex = (currentIndex - 1 + tabs.count) % tabs.count
    selectTab(tabs[prevIndex].id)
  }

  func selectTabByIndex(_ index: Int) {
    guard index >= 0, index < tabs.count else { return }
    selectTab(tabs[index].id)
  }

  // MARK: - Private

  private func handleGotoTab(_ gotoTab: ghostty_action_goto_tab_e) -> Bool {
    switch gotoTab {
    case GHOSTTY_GOTO_TAB_PREVIOUS:
      selectPreviousTab()
      return true
    case GHOSTTY_GOTO_TAB_NEXT:
      selectNextTab()
      return true
    case GHOSTTY_GOTO_TAB_LAST:
      if let last = tabs.last {
        selectTab(last.id)
      }
      return true
    default:
      // Numeric tab indices (raw value is 1-based tab number for positive values)
      let rawValue = Int(gotoTab.rawValue)
      if rawValue >= 0 {
        selectTabByIndex(rawValue)
        return true
      }
      return false
    }
  }

  private func postSystemNotification(title: String, body: String) {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      guard settings.authorizationStatus == .authorized else {
        Task { @MainActor in
          self.postNotificationViaOsascript(title: title, body: body)
        }
        return
      }

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default

      let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
      )
      center.add(request)
    }
  }

  private func postNotificationViaOsascript(title: String, body: String) {
    let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
    let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
    let script = "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\""
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    try? process.run()
  }
}
