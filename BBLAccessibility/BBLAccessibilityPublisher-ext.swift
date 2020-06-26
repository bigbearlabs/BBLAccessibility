public extension BBLAccessibilityPublisher {
  
  var activeWindowsInCurrentSpace: [CGWindowInfo] {

    // screen recording perms TODO refine acquisition flow
    _ = CGWindowListCreateImage(CGRect.null, [.optionOnScreenBelowWindow], kCGNullWindowID, .nominalResolution)
    
    let onScreenCgWindows = CGWindowInfo.query(scope: .onScreen, otherOptions: [.excludeDesktopElements])
      .filter { $0.isInActiveSpace }
    
    // reject windows not seen by ax api, e.g. transparent windows.
    let pids = onScreenCgWindows
      .filter {
        // exclude pids for status menu items or dock
        ![NSWindow.Level.statusBar.rawValue, NSWindow.Level.dock.rawValue]
        .contains($0.windowLayer)
      }
      .map { $0.pid }.uniqueValues
    let axWindowIds = activeWindows(pids: pids).map { $0.windowID }
    
    let windows = onScreenCgWindows.filter {
      axWindowIds.contains(UInt32($0.windowId.windowNumber)!)
    }
    
    return windows
  }
  
  func activeWindows(pids: [pid_t]) -> [SIWindow] {
    let siApps = pids.compactMap { self.appElement(forProcessIdentifier: $0) }
    let activeWindows = siApps.flatMap {
      $0.uncachedWindows
    }
    return activeWindows
  }

}
