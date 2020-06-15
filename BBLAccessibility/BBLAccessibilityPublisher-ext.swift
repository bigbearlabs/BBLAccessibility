public extension BBLAccessibilityPublisher {
  
  var activeWindowsInCurrentSpace: [CGWindowInfo] {
//    let onScreenWindows = CGWindowInfo.query(scope: .onScreen)
//      .filter {
//        $0.isInActiveSpace
//      }
//    let onScreenPids = onScreenWindows.map{ $0.pid }
//    return self.activeWindows(pids: onScreenPids.uniqueValues)
    
    // IT2
//    return SIWindow.visibleWindows()
//      .filter { $0.isActive() }
    
//    // IT3
//    let onScreenWindows = CGWindowInfo.query(scope: .onScreen)
//      .filter {
//        $0.isInActiveSpace
//      }
//    let onScreenPids = onScreenWindows.map { $0.pid }
//      .uniqueValues
//    let onScreenApps = onScreenPids.map {
//      SIApplication(forProcessIdentifier: $0)
//    }
//    return onScreenApps
//      .flatMap { self.windows(siApp: $0) }
//      .filter { $0.isOnScreen() && $0.isVisible() }
    
    // IT4
    
    // screen recording perms
    _ = CGWindowListCreateImage(CGRect.null, [.optionOnScreenBelowWindow], kCGNullWindowID, .nominalResolution)
    
    let onScreenWindows = CGWindowInfo.query(scope: .onScreen)
      .filter {
        $0.isInActiveSpace
          && NSRunningApplication(processIdentifier: $0.pid)?.isAgent() == false
      }
    return onScreenWindows
  }
  
  func activeWindows(pids: [pid_t]) -> [SIWindow] {
    let siApps = pids.compactMap { self.appElement(forProcessIdentifier: $0) }
    let activeWindows = siApps.flatMap {
      $0.uncachedWindows
    }
    return activeWindows
  }

}
