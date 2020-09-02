public typealias WindowServerState =  (activePid: pid_t?, currentScreenId: Int, windowInfoListsByScreenId: [Int : [CGWindowInfo]])


public extension BBLAccessibilityPublisher {
  
  var activeWindowsInCurrentSpace: (currentScreenId: Int, windowInfoListsByScreenId: [Int : [CGWindowInfo]]) {
    let currentState = self.currentState
    return (currentState.currentScreenId, currentState.windowInfoListsByScreenId)
  }
    
  var currentState: WindowServerState {
    let cgWindows = CGWindowInfo.query(scope: .onScreen, otherOptions: [.excludeDesktopElements])
    // TODO scope needs to change to 'all' in order for dock to show up during mission control activation.
    let onScreenCgWindows = cgWindows
      .filter { $0.isInActiveSpace }
      .filter {
        // exclude pids for status menu items or dock
        ![
          NSWindow.Level.statusBar.rawValue,
//          NSWindow.Level.dock.rawValue
        ].contains($0.windowLayer)
      }

    // reject windows not seen by ax api, e.g. transparent windows.
    let pidsForCgWindows = onScreenCgWindows.map { $0.pid }.uniqueValues
    let axWindowsForPids = pidsForCgWindows.map { self.siWindows(pid: $0) }.flatMap { $0 }
    
    let axFilteredCgWindows = onScreenCgWindows.filter { window in
      axWindowsForPids.contains { $0.windowID == UInt32(window.windowId.windowNumber) }
    }
    
    let activePid = axFilteredCgWindows.first?.pid
    
    // group by screen based on frame
    
    let windowInfoListsByScreenId = Dictionary(
      grouping: axFilteredCgWindows.map { windowInfo -> (Int, CGWindowInfo) in
        let screens = NSScreen.screens
        for (i, screen) in screens.enumerated() {
          if windowInfo.frame.intersects(screen.frame) {
            return (i, windowInfo)
          }
        }
        // no intersection; assume belonging to first screen.
        return (0, windowInfo)
      },
      by: { screenId, _ in  screenId })
    .mapValues { ts in
      ts.map { $0.1 }
    }
    
    let currentScreenId: Int = {
      if let firstWindow = axFilteredCgWindows.first,
        let currentScreenId = windowInfoListsByScreenId.first(where: {
          $0.value.contains(firstWindow)
        })?.key {
        return currentScreenId
      } else {
        print("defaulting currentScreenId to 0")
        return 0
      }
    }()
    
    return (activePid: activePid, currentScreenId: currentScreenId, windowInfoListsByScreenId: windowInfoListsByScreenId)
  }
  
  var currentAppAccessibilityInfo: AccessibilityInfo? {
    guard let pid = SIApplication.focused()?.processIdentifier() else {
      return nil
    }
    
    let axDataForPid = self.accessibilityInfosByPid[NSNumber(value: pid)]
    return axDataForPid
  }


  func activeWindows(pids: [pid_t]) -> [SIWindow] {
    let siApps = pids.compactMap { self.appElement(forProcessIdentifier: $0) }
    let activeWindows = siApps.flatMap {
      $0.uncachedWindows
    }
    return activeWindows
  }


  func siWindows(pid: pid_t) -> [SIWindow] {
    // IT1
//    SIApplication(forProcessIdentifier: pid).uncachedWindows
    
    // IT2 version that doens't risk blocking calling thread.
    var windows: [SIWindow]? = nil
    let serialisingSemaphore = DispatchSemaphore(value: 0)
    let siApp = SIApplication(forProcessIdentifier: pid)
    execAsyncSynchronising(on: siApp) {
      windows = siApp.uncachedWindows
      serialisingSemaphore.signal()
    }
    serialisingSemaphore.wait() // MAYBE provide a timeout

    guard windows != nil
      else { fatalError() }
    
    return windows!
  }

}


