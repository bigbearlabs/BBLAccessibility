public extension BBLAccessibilityPublisher {

  typealias State = [Int : [CGWindowInfo]]

  
  func withCurrentState(completionHandler: (State) -> Void) {
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

    //  reject windows not seen by ax api, e.g. transparent windows.
    let pidsForCgWindows = onScreenCgWindows.map { $0.pid }.uniqueValues

    // filter down to windows reported on-screen by ax api.
    var onScreenAxWindowIds: [CGWindowID] = []
    let g = DispatchGroup()
    let l = NSLock()
    for pid in pidsForCgWindows {
      g.enter()
      windows(pid: pid) { windows in
        l.lock()
        onScreenAxWindowIds.append(contentsOf: windows.map { $0.windowID })
        l.unlock()
        g.leave()
      }
    }

    _ = g.wait(timeout: .now() + 0.2) // HARDCODED

    let axFilteredCgWindows = onScreenCgWindows.filter { window in
      onScreenAxWindowIds.contains(CGWindowID(window.windowId.windowNumber)!)
    }
    
    // group by screen based on frame
    
    let screens = NSScreen.screens
    let windowInfoListsByScreenId = Dictionary(
      grouping: axFilteredCgWindows.map { windowInfo -> (Int, CGWindowInfo) in
        for (i, screen) in screens.enumerated() {
          if windowInfo.frame.intersects(screen.frame) {
            return (i, windowInfo)
          }
        }
        // no intersection; assume belonging to first screen.
        return (0, windowInfo)
      },
      by: { screenId, _ in screenId }
    )
      .mapValues {
        $0.map { screenId, windowInfoLists in
          windowInfoLists
        }
      }
    
    completionHandler(windowInfoListsByScreenId)
    
  }
  

  // MARK: -
  
  func windows(pid: pid_t, completionHandler: @escaping ([SIWindow]) -> Void) {
    siQuery(pid: pid) { siApp in
      completionHandler(
        siApp?.uncachedWindows
        ?? []
      )
    }
  }

  func focusedWindow(pid: pid_t, completionHandler: @escaping (SIWindow?) -> Void) {
    siQuery(pid: pid) { siApp in
      completionHandler(siApp?.focusedWindow())
    }
  }
  
  func focusedWindow(completionHandler: @escaping (SIWindow?) -> Void) {
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication
    else {
      completionHandler(nil)
      return
    }
    
    focusedWindow(pid: frontmostApp.processIdentifier, completionHandler: completionHandler)
  }
  
  
  // MARK: -
  
  /**
      @callback siAppHandler:
      - @param siAppilcation  nil when pid is not subject to ax queries (e.g. due to #shouldObserve)
   
   */
  // FIXME will get stuck with e.g. Archive Utility expanding an Xcode xip, so shouldn't call on main thread.
  // WORKAROUND aggressively short timeout to reduce impact of blocks from AX API calls.
  func siQuery(
    pid: pid_t,
    timeout: TimeInterval = 1,
    completionHandler: @escaping (SIApplication?) -> Void
  ) {
    
    execAsyncSynchronising(onPid: NSNumber(value: pid)) { [unowned self] in
      let siApp: SIApplication?
      if let app = NSRunningApplication(processIdentifier: pid),
         self.shouldObserve(app) {
        siApp = SIApplication(runningApplication: app)
      } else {
        siApp = nil
      }
  
      completionHandler(siApp)
    }
  }
  
}
