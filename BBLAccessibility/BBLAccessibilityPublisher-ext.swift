import Combine


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
          NSWindow.Level.mainMenu.rawValue,
          NSWindow.Level.statusBar.rawValue,
//          NSWindow.Level.dock.rawValue,  // deprecated in 10.13
        ].contains($0.windowLayer)
      }

    // DISABLED further filtering based on ax queries can spin, and produces unstable results depending on ax target app responsiveness.
//    //  reject windows not seen by ax api, e.g. transparent windows.
//    let pidsForCgWindows = onScreenCgWindows.map { $0.pid }.uniqueValues
//
//    // filter down to windows reported on-screen by ax api.
//    var onScreenAxWindowIds: [CGWindowID] = []
//    let g = DispatchGroup()
//    let l = NSLock()
//    for pid in pidsForCgWindows {
//      g.enter()
//      windows(pid: pid) { windows in
//        l.lock()
//        onScreenAxWindowIds.append(contentsOf: windows.map { $0.windowID })
//        l.unlock()
//        g.leave()
//      }
//    }
//
//    _ = g.wait(timeout: .now() + 0.2) // HARDCODED

//    let axFilteredCgWindows = onScreenCgWindows.filter { window in
//      onScreenAxWindowIds.contains(CGWindowID(window.windowId.windowNumber)!)
//    }
    
    let axFilteredCgWindows = onScreenCgWindows
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


// MARK: -  ax observation of newly launched apps

public extension BBLAccessibilityPublisher {
  
  @objc
  func observeLaunch(_ handler: @escaping (_ app: NSRunningApplication) -> Void) {
    _ = runningApplicationsSubscription
    
    handleLaunchSubscription = appEventPublisher.sink { event in
      switch event {
      case .launched(let app):
        handler(app)
      default: ()
      }
    }
  }

  @objc
  func unobserveLaunch() {
    handleLaunchSubscription = nil
  }

  @objc
  func observeTerminate(_ handler: @escaping (_ app: NSRunningApplication) -> Void) {
    _ = runningApplicationsSubscription

    handleTerminateSubscription = appEventPublisher.sink { event in
      switch event {
      case .terminated(let app):
        handler(app)
      default: ()
      }
    }
  }

  @objc
  func unobserveTerminate() {
    handleTerminateSubscription = nil
  }
}


var handleLaunchSubscription: Any?
var handleTerminateSubscription: Any?


enum AppEvent {
  case launched(NSRunningApplication)
  case terminated(NSRunningApplication)
}


let appEventPublisher = PassthroughSubject<AppEvent, Never>()

class RunningApplicationsBookkeeper {
  var finishedLaunchingSubsByPid: [pid_t : Any] = [:]

  var runningApplications = NSWorkspace.shared.runningApplications {
    didSet {
      let newApps = Set(runningApplications).subtracting(oldValue)
      for app in newApps {
        let sendOnFinishedLaunching = app.publisher(for: \.isFinishedLaunching, options: [.initial, .new])
          .filter { $0 == true }
          .map { (app, $0) }
          .sink { app, isFinishedLaunching in
            appEventPublisher.send(.launched(app))
            self.finishedLaunchingSubsByPid[app.processIdentifier] = nil
          }
        self.finishedLaunchingSubsByPid[app.processIdentifier] = sendOnFinishedLaunching
        //  most app will signal readiness via isFinishedLaunching.
        // what of apps that never do? warn after delay?
      }
      
      let terminatedApps = Set(oldValue).subtracting(runningApplications)
      for app in terminatedApps {
        appEventPublisher.send(.terminated(app))
      }
    }
  }
  
}

let runningApplicationsSubscription: Any? =
  NSWorkspace.shared.publisher(for: \.runningApplications)
  .removeDuplicates()
  .assign(to: \.runningApplications, on: runningApplicationsBookkeeper)


let runningApplicationsBookkeeper = RunningApplicationsBookkeeper()

