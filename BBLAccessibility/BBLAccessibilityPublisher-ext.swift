import Combine
import AppKit



public typealias AxNotification = String



public extension BBLAccessibilityPublisher {
  
  @objc
  var axNotificationsToObserve: [AxNotification] {
    [
      kAXApplicationActivatedNotification,
      kAXApplicationDeactivatedNotification,

      kAXApplicationShownNotification,
      kAXApplicationHiddenNotification,
      
      kAXWindowCreatedNotification,

      kAXMainWindowChangedNotification,
      kAXFocusedWindowChangedNotification,
      
      kAXWindowMovedNotification,
      kAXWindowResizedNotification,
      kAXTitleChangedNotification,
      "AXFocusedTabChanged",

      kAXWindowMiniaturizedNotification,
      kAXWindowDeminiaturizedNotification,

//      kAXUIElementDestroyedNotification,  // obsreved for individual windows.
      
      kAXFocusedUIElementChangedNotification,
      
//      kAXSelectedTextChangedNotification
    ]
  }
  
}


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
  
  // MARK: -

  // NOTE #execAsyncSynchronising causes thread explosion due to its use of global concurrent queues.
  // this freaks us out every now and then when we see 100+ threads.
  //
  // But after considering many alternatives, this is still considered the best trade-off to make as of now, since:
  // - it has the least impact in the face of a blocked thread when making ax queries (e.g. Expander unzipping Xcode)
  // - the only occasions where thread explosion occurs are: a) on app launch where we need all ax subscriptions -- this is very thread-heavy, and b) space changes bring forth a lot of new apps that need to be queried -- this is moderately thread-heavy.
  //
  // in the future we may be able to reimplement this method to work on swift async operations + precise cancellations.
  // but it's still unclear whether such an approach would mitigate issues when the ax query blocks and doesn't return, which in principle can happen with any locked process currently running.
  // so, revisit when thread explosion becomes a more material issue.
//  // temp swift-impl to investigate cause of abandoned memory
//  @objc
//  func execAsyncSynchronising(onObject: NSObject, block: @escaping () -> Void) {
  // IMPL!
//  }
}

// MARK: -  ax observation of newly launched apps

public extension BBLAccessibilityPublisher {
  
  @objc
  func observeLaunch(_ handler: @escaping (_ app: NSRunningApplication) -> Void) {
    handleLaunchSubscription = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification, object: nil)
      .map { notif in
        guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else { fatalError() }
        
        return app
      }
      .sink { app in
        handler(app)
      }
  }

  @objc
  func unobserveLaunch() {
    handleLaunchSubscription = nil
  }

  @objc
  func observeTerminate(_ handler: @escaping (_ app: NSRunningApplication) -> Void) {
    handleTerminateSubscription = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification, object: nil)
      .map { notif in
        guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        else { fatalError() }
        
        return app
      }
      .sink { app in
        handler(app)
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


public actor RunningApplicationsBookkeeper {
  
  var finishedLaunchingSubsByPid: [pid_t : Any] = [:]

  public var runningApplications = NSWorkspace.shared.runningApplications {
    didSet {
      let newApps = Set(runningApplications).subtracting(oldValue)
        .filter {
          // filter out the terminated ones
          !$0.isTerminated
          // occasionally we get a corrupt instance with pid -1.
          && $0.processIdentifier > 0
        }
      
      let newAppSubs = Dictionary(uniqueKeysWithValues: newApps.map { app in
        (
          app.processIdentifier,
          (
            app,
            app.publisher(for: \.isFinishedLaunching, options: [.initial, .new])
              .filter { $0 == true }
              .sink { isFinishedLaunching in
                appEventPublisher.send(.launched(app))
                self.finishedLaunchingSubsByPid.removeValue(forKey: app.processIdentifier)
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
        self.finishedLaunchingSubsByPid.removeValue(forKey: app.processIdentifier)
      }
    }
  }
  
}

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

