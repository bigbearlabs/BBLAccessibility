public extension BBLAccessibilityPublisher {
  
  var activeWindowsInCurrentSpace: [SIWindow] {
    let onScreenWindows = CGWindowInfo.query(scope: .onScreen)
    let onScreenPids = onScreenWindows.map { $0.pid }
    return self.activeWindows(pids: onScreenPids)
  }
  
  func activeWindows(pids: [pid_t]) -> [SIWindow] {
    let siApps = pids.compactMap { self.appElement(forProcessIdentifier: $0) }
    let activeWindows = siApps.flatMap {
      $0.uncachedWindows
    }
    return activeWindows
  }

}
