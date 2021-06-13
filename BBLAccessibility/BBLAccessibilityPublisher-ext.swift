public typealias WindowServerState = (activeWindowInfo: CGWindowInfo?, currentScreenId: Int, windowInfoListsByScreenId: [Int : [CGWindowInfo]])


public extension BBLAccessibilityPublisher {
      
  func withCurrentState(completionHandler: (BBLAccessibility.WindowServerState) -> Void) {
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
//    let onScreenAxWindowIds = pidsForCgWindows
//      // exclude this app in order not to get stuck in certain situations.
//      .filter { $0 != NSRunningApplication.current.processIdentifier }
//      .flatMap { self.windows(pid: $0) }
//      .map { $0.windowID }
    
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

    g.wait(timeout: .now() + 0.2) // HARDCODED

    let axFilteredCgWindows = onScreenCgWindows.filter { window in
      onScreenAxWindowIds.contains { $0 == UInt32(window.windowId.windowNumber) }
//      true
    }
    
    let activeWindowInfo = axFilteredCgWindows.first
    
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
    
    completionHandler(
      (activeWindowInfo: activeWindowInfo, currentScreenId: currentScreenId, windowInfoListsByScreenId: windowInfoListsByScreenId)
    )
  }
  

  func windows(pid: pid_t, completionHandler: @escaping ([SIWindow]) -> Void) {
//    do {
      siQuery(pid: pid) { siApp in
        completionHandler(
          siApp?.uncachedWindows
          ?? []
        )
      }
//    } catch let e {
//      print("WARN \(e) acquiring windows for \(NSRunningApplication(processIdentifier: pid)?.debugDescription ?? String(pid))")
//      return []
//    }
  }

  func focusedWindow(pid: pid_t, completionHandler: @escaping (SIWindow?) -> Void) {
//    do {
      siQuery(pid: pid) { siApp in
        completionHandler(siApp?.focusedWindow())
      }
//    } catch let e {
//      print("WARN \(e) acquiring focused window for \(NSRunningApplication(processIdentifier: pid)?.debugDescription ?? String(pid))")
//      return nil
//    }
  }
  
  func focusedWindow(completionHandler: @escaping (SIWindow?) -> Void) {
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication
    else {
      completionHandler(nil)
      return
    }
    
    focusedWindow(pid: frontmostApp.processIdentifier, completionHandler: completionHandler)
  }
  
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
    
//    var result: SIQueryResult? = nil
//    let group = DispatchGroup()
//    group.enter()
    execAsyncSynchronising(onPid: NSNumber(value: pid)) { [unowned self] in
      let siApp: SIApplication?
      if let app = NSRunningApplication(processIdentifier: pid),
         self.shouldObserve(app) {
        siApp = SIApplication(runningApplication: app)
      } else {
        siApp = nil
      }
  
          completionHandler(siApp)
//      group.leave()
    }
//    _ = group.wait(timeout: .now() + timeout)
//
//    guard result != nil else {
//      throw NSError(domain: "ax-query-failure", code: -1, userInfo: nil)
//    }
//
//    return result!
  }
  
}
