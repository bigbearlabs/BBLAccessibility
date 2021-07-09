import Combine


public extension BBLAccessibilityPublisher {
  
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
    if let siApp = self.appElement(forProcessIdentifier: pid) {
      execAsyncSynchronising(onPid: siApp.processIdentifier()) {
        completionHandler(siApp)
      }
    } else {
      completionHandler(nil)
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
        .filter {
          // occasionally we get a corrupt instance with pid -1.
          $0.processIdentifier > 0
        }
      let newAppSubs = Dictionary(uniqueKeysWithValues: newApps.map { app in
        (
          app.processIdentifier,
          (
            app,
            app.publisher(for: \.isFinishedLaunching, options: [.initial, .new])
              .filter { $0 == true }
              .map { (app, $0) }
              .sink { app, isFinishedLaunching in
                appEventPublisher.send(.launched(app))
                self.finishedLaunchingSubsByPid[app.processIdentifier] = nil
              }
          )
        )
      })
      

      self.finishedLaunchingSubsByPid.merge(newAppSubs) { $1 }
      //  most app will signal readiness via isFinishedLaunching.
      // what of apps that never do? warn after delay?
      
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



// TODO re-implement the async dispatch method that avoids current issues:
// - global concurrent queue thread proliferation resulting in a crash as thread count hits 256 (possibly happening when any one of the critical section blocks
//
// DEFERRED wait until swift actors arrive (xcode 13).

//public extension BBLAccessibilityPublisher {
//  
//  @objc
//  func execAsyncSynchronisingOnObject(_ object: Any, block: () -> Void) {
//    
//  }
//
//}

