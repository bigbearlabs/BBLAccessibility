public typealias WindowServerState = (activeWindowInfo: CGWindowInfo?, currentScreenId: Int, windowInfoListsByScreenId: [Int : [CGWindowInfo]])


public extension BBLAccessibilityPublisher {
      
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

    //  reject windows not seen by ax api, e.g. transparent windows.
    let pidsForCgWindows = onScreenCgWindows.map { $0.pid }.uniqueValues
    let onScreenAxWindowIds = pidsForCgWindows
      // exclude this app in order not to get stuck in certain situations.
      .filter { $0 != NSRunningApplication.current.processIdentifier }
      .flatMap { self.windows(pid: $0) }
      .map { $0.windowID }
    let axFilteredCgWindows = onScreenCgWindows.filter { window in
      onScreenAxWindowIds.contains { $0 == UInt32(window.windowId.windowNumber) }
    }
    
    let activeWindowInfo = axFilteredCgWindows.first
    
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
    
    return (activeWindowInfo: activeWindowInfo, currentScreenId: currentScreenId, windowInfoListsByScreenId: windowInfoListsByScreenId)
  }
  

  func windows(pid: pid_t) -> [SIWindow] {
    do {
      return try siQuery(pid: pid) { siApp in
        siApp?.uncachedWindows
          ?? []
      }
    } catch let e {
      print("WARN \(e) acquiring windows for \(NSRunningApplication(processIdentifier: pid)?.debugDescription ?? String(pid))")
      return []
    }
  }

  func focusedWindow(pid: pid_t) -> SIWindow? {
    do {
      return try siQuery(pid: pid) { siApp in
        siApp?.focusedWindow()
      }
    } catch let e {
      print("WARN \(e) acquiring focused window for \(NSRunningApplication(processIdentifier: pid)?.debugDescription ?? String(pid))")
      return nil
    }
  }
  
  func focusedWindow() -> SIWindow? {
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication
    else { return nil }
    
    return focusedWindow(pid: frontmostApp.processIdentifier)
  }
  
  /**
      @callback siAppHandler:
      - @param siAppilcation  nil when pid is not subject to ax queries (e.g. due to #shouldObserve)
   */
  func siQuery<SIQueryResult>(
    pid: pid_t,
    timeout: TimeInterval = 1,
    siAppHandler: @escaping (SIApplication?) -> SIQueryResult)
  throws -> SIQueryResult {
    
    var result: SIQueryResult? = nil
    let group = DispatchGroup()
    group.enter()
    execAsyncSynchronising(onPid: NSNumber(value: pid)) { [unowned self] in
      let siApp: SIApplication?
      if let app = NSRunningApplication(processIdentifier: pid),
         self.shouldObserve(app) {
        siApp = SIApplication(runningApplication: app)
      } else {
        siApp = nil
      }
      result = siAppHandler(siApp)
      group.leave()
    }
    _ = group.wait(timeout: .now() + timeout)
    
    guard result != nil else {
      throw NSError(domain: "ax-query-failure", code: -1, userInfo: nil)
    }
    
    return result!
  }
  
}
