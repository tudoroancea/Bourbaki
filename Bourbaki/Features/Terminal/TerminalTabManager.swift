import AppKit
import Foundation
import GhosttyKit
@preconcurrency import UserNotifications

/// Delegate that allows notifications to show even when the app is in the foreground,
/// and routes notification taps back to the tab manager.
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  /// Called when a notification tap occurs. Passes (tabID, worktreePath).
  var onNotificationTapped: ((UUID, URL) -> Void)?

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    if let tabIDString = userInfo["tabID"] as? String,
       let tabID = UUID(uuidString: tabIDString),
       let worktreePathString = userInfo["worktreePath"] as? String
    {
      let worktreeURL = URL(fileURLWithPath: worktreePathString)
      Task { @MainActor in
        self.onNotificationTapped?(tabID, worktreeURL)
      }
    }
    completionHandler()
  }
}

@MainActor
@Observable
final class TerminalTabManager {
  /// All tabs across all worktrees.
  var tabs: [TerminalTab] = []
  var selectedTabID: UUID?

  /// The currently selected worktree path (set by sidebar selection).
  var selectedWorktreePath: URL?

  /// Tracks the last selected tab ID for each worktree, so we can restore it when switching back.
  private var lastSelectedTabPerWorktree: [URL: UUID] = [:]

  private let runtime: GhosttyRuntime
  private let notificationDelegate = NotificationDelegate()

  /// Optional reference to project store for updating session status from in-app tabs.
  var projectStore: ProjectStore?

  /// Optional reference to recent worktree store for recording opens.
  var recentWorktreeStore: RecentWorktreeStore?

  /// Tool settings for resolving commands and checking availability.
  var toolSettings: ToolSettings?

  /// Error message to show in an alert when a tool is unavailable.
  var toolErrorMessage: String?
  var showToolError: Bool = false

  init(runtime: GhosttyRuntime) {
    self.runtime = runtime
    let center = UNUserNotificationCenter.current()
    center.delegate = notificationDelegate
    center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

    notificationDelegate.onNotificationTapped = { [weak self] tabID, worktreePath in
      guard let self else { return }
      self.focusNotificationSource(tabID: tabID, worktreePath: worktreePath)
    }
  }

  /// Whether any tabs are currently open across all worktrees.
  var hasRunningTerminals: Bool {
    !tabs.isEmpty
  }

  /// Tabs for the currently selected worktree only.
  var visibleTabs: [TerminalTab] {
    guard let selectedWorktreePath else { return [] }
    return tabs.filter { $0.worktreePath.standardizedFileURL == selectedWorktreePath.standardizedFileURL }
  }

  var selectedTab: TerminalTab? {
    guard let selectedTabID else { return nil }
    return visibleTabs.first { $0.id == selectedTabID }
  }

  /// Select a worktree. Shows existing tabs, or creates a pi tab if none exist.
  func selectWorktree(_ path: URL) {
    let standardized = path.standardizedFileURL
    let previousTab = selectedTab
    selectedWorktreePath = path

    // Record in recent worktrees
    recordRecentWorktree(path: standardized)

    // Save last selected tab for the previous worktree before switching
    if let previousTab, let previousWorktreePath = previousTab.worktreePath.standardizedFileURL as URL? {
      lastSelectedTabPerWorktree[previousWorktreePath] = previousTab.id
    }

    // If the current tab is already in this worktree, keep it
    if let selectedTabID, let tab = tabs.first(where: { $0.id == selectedTabID }),
      tab.worktreePath.standardizedFileURL == standardized
    {
      return
    }

    // Try to select an existing tab in this worktree, preferring the last active one
    let worktreeTabs = tabs.filter { $0.worktreePath.standardizedFileURL == standardized }
    let targetTab: TerminalTab? = {
      if let lastID = lastSelectedTabPerWorktree[standardized],
         let lastTab = worktreeTabs.first(where: { $0.id == lastID }) {
        return lastTab
      }
      return worktreeTabs.first
    }()
    if let targetTab {
      // Notify the previous tab it lost focus before switching
      if previousTab?.id != targetTab.id {
        previousTab?.surfaceView.focusDidChange(false)
      }
      selectedTabID = targetTab.id
      targetTab.surfaceView.focusDidChange(true)
      return
    }

    // No tabs for this worktree — notify previous tab before creating a new one
    previousTab?.surfaceView.focusDidChange(false)

    // No tabs for this worktree — open an agent session by default
    createTab(type: .agent, workingDirectory: path)
  }

  /// Record a worktree open in the recent store.
  private func recordRecentWorktree(path: URL) {
    guard let store = projectStore, let recentStore = recentWorktreeStore else { return }
    for project in store.projects {
      if let worktree = project.worktrees.first(where: {
        $0.path.standardizedFileURL == path
      }) {
        recentStore.recordOpen(path: path, projectName: project.name, worktreeName: worktree.name)
        return
      }
      if project.rootPath.standardizedFileURL == path {
        recentStore.recordOpen(path: path, projectName: project.name, worktreeName: project.name)
        return
      }
    }
    // Fallback: use the directory name
    recentStore.recordOpen(path: path, projectName: path.lastPathComponent, worktreeName: path.lastPathComponent)
  }

  @discardableResult
  func createTab(type: TabType, workingDirectory: URL) -> UUID {
    // Check tool availability before creating a tool tab
    if type != .shell, let settings = toolSettings, !settings.isAvailable(type) {
      let exe = settings.executableName(for: type) ?? type.displayName
      toolErrorMessage =
        "Cannot open \(type.displayName): '\(exe)' was not found in your PATH.\n\nYou can configure the command in Settings (⌘,)."
      showToolError = true
      // Return a dummy ID — no tab is created
      return UUID()
    }

    // Set worktree path and auto-select it
    selectedWorktreePath = workingDirectory

    let command = toolSettings?.command(for: type)
    let initialInput = command.map { "\($0)\n" }
    let surfaceView = GhosttySurfaceView(
      runtime: runtime,
      workingDirectory: workingDirectory,
      initialInput: initialInput
    )

    let tab = TerminalTab(
      type: type,
      worktreePath: workingDirectory,
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
      if self.selectedTabID != tab.id {
        tab.hasNotification = true
      }
      self.postSystemNotification(title: title, body: body, tabID: tab.id, worktreePath: tab.worktreePath)
    }

    surfaceView.bridge.onNewTab = { [weak self] in
      guard let self else { return false }
      self.createTab(type: .shell, workingDirectory: workingDirectory)
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
    let closedTab = tabs.remove(at: index)
    closedTab.surfaceView.closeSurface()

    let worktreeKey = closedTab.worktreePath.standardizedFileURL
    // Clear last-selected tracking if it pointed to the closed tab
    if lastSelectedTabPerWorktree[worktreeKey] == id {
      lastSelectedTabPerWorktree.removeValue(forKey: worktreeKey)
    }

    if selectedTabID == id {
      // Select the nearest visible tab
      let visible = visibleTabs
      if visible.isEmpty {
        selectedTabID = nil
        // Clear worktree selection when no more tabs remain for it
        if let wp = selectedWorktreePath,
          !tabs.contains(where: { $0.worktreePath.standardizedFileURL == wp.standardizedFileURL })
        {
          selectedWorktreePath = nil
        }
      } else {
        selectedTabID = visible.first?.id
        if let newID = selectedTabID {
          lastSelectedTabPerWorktree[worktreeKey] = newID
        }
      }
    }
  }

  func selectTab(_ id: UUID) {
    guard let tab = tabs.first(where: { $0.id == id }) else { return }
    let previousTab = selectedTab
    selectedTabID = id
    tab.hasNotification = false

    // Track last selected tab for this worktree
    lastSelectedTabPerWorktree[tab.worktreePath.standardizedFileURL] = id

    // Propagate focus changes so terminal OSC sequences fire correctly
    if previousTab?.id != id {
      previousTab?.surfaceView.focusDidChange(false)
      tab.surfaceView.focusDidChange(true)
    }
  }

  func selectNextTab() {
    let visible = visibleTabs
    guard let currentID = selectedTabID,
      let currentIndex = visible.firstIndex(where: { $0.id == currentID }),
      !visible.isEmpty
    else { return }
    let nextIndex = (currentIndex + 1) % visible.count
    selectTab(visible[nextIndex].id)
  }

  func selectPreviousTab() {
    let visible = visibleTabs
    guard let currentID = selectedTabID,
      let currentIndex = visible.firstIndex(where: { $0.id == currentID }),
      !visible.isEmpty
    else { return }
    let prevIndex = (currentIndex - 1 + visible.count) % visible.count
    selectTab(visible[prevIndex].id)
  }

  func selectTabByIndex(_ index: Int) {
    let visible = visibleTabs
    guard index >= 0, index < visible.count else { return }
    selectTab(visible[index].id)
  }

  /// Worktree paths that have open tabs, in the order they appear in the sidebar.
  var activeWorktreePaths: [URL] {
    let activePaths = Set(tabs.map { $0.worktreePath.standardizedFileURL })
    guard let store = projectStore else {
      // Fallback: unique paths in tab order
      var seen = Set<URL>()
      return tabs.compactMap { tab in
        let std = tab.worktreePath.standardizedFileURL
        return seen.insert(std).inserted ? tab.worktreePath : nil
      }
    }
    // Return in sidebar order (projects → worktrees)
    var result: [URL] = []
    for project in store.projects {
      let paths =
        project.worktrees.isEmpty
        ? [project.rootPath]
        : project.worktrees.map(\.path)
      for path in paths where activePaths.contains(path.standardizedFileURL) {
        result.append(path)
      }
    }
    return result
  }

  /// Select an active worktree by its index among worktrees that have open tabs.
  func selectWorktreeByIndex(_ index: Int) {
    let paths = activeWorktreePaths
    guard index >= 0, index < paths.count else { return }
    selectWorktree(paths[index])
  }

  /// Check if there's an active agent tab running in the given worktree.
  func sessionStatus(for worktreePath: URL) -> SessionStatus {
    let allWorktreeTabs = tabs.filter {
      $0.worktreePath.standardizedFileURL == worktreePath.standardizedFileURL
    }
    let agentTabs = allWorktreeTabs.filter { $0.type == .agent }

    if !agentTabs.isEmpty {
      if agentTabs.contains(where: { $0.isRunning }) {
        return .running
      }
      return .idle
    }

    // No agent sessions — check for any other open terminals
    if !allWorktreeTabs.isEmpty {
      return .terminal
    }

    return .stopped
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
      let visible = visibleTabs
      if let last = visible.last {
        selectTab(last.id)
      }
      return true
    default:
      let rawValue = Int(gotoTab.rawValue)
      if rawValue >= 0 {
        selectTabByIndex(rawValue)
        return true
      }
      return false
    }
  }

  /// Focus the worktree and tab that originated a notification.
  private func focusNotificationSource(tabID: UUID, worktreePath: URL) {
    // Bring the app to front
    NSApplication.shared.activate(ignoringOtherApps: true)
    // Select the worktree first (this sets up the visible tabs)
    selectWorktree(worktreePath)
    // Then select the specific tab
    if tabs.contains(where: { $0.id == tabID }) {
      selectTab(tabID)
    }
  }

  private func postSystemNotification(title: String, body: String, tabID: UUID, worktreePath: URL) {
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
      content.userInfo = [
        "tabID": tabID.uuidString,
        "worktreePath": worktreePath.path,
      ]

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
