public extension BBLAccessibilityPublisher {
  
  var activeWindowsInCurrentSpace: [CGWindowInfo] {

    // screen recording perms TODO refine acquisition flow
    _ = CGWindowListCreateImage(CGRect.null, [.optionOnScreenBelowWindow], kCGNullWindowID, .nominalResolution)
    
    let onScreenWindows = CGWindowInfo.query(scope: .onScreen, otherOptions: [.excludeDesktopElements])
      .filter { $0.isInActiveSpace }
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
