//
//  File.swift
//  WindowListMonitor
//
//  Created by ilo on 13/06/2020.
//  Copyright © 2020 Big Bear Labs. All rights reserved.
//

import BBLAccessibility



// FIXME exclude safari tab preview, tooltip windows
// FIXME remove safari popup window after closing

public class WindowListMonitor: BBLAccessibilityPublisher {
  
  public enum Event: Equatable {
    case activated(pid: pid_t, focusedWindowNumber: UInt32?, tabGroup: SITabGroup?)
    case hidden(pid: pid_t)

    case created(windowNumber: UInt32, tabGroup: SITabGroup?)
    case closed(windowNumber: UInt32)

    case focused(windowNumber: UInt32, tabGroup: SITabGroup?)
    case tabChanged(windowNumber: UInt32, tabGroup: SITabGroup?)
    
    case titleChanged(windowNumber: UInt32, title: String?)
    case frameChanged(windowNumber: UInt32, frame: CGRect)
    
    case minimised(windowNumber: UInt32)
    case unminimised(windowNumber: UInt32)


    // TODO
//    case movedIn(windowNumber: WindowNumber)
    
    // TODO moved out
    
    // TODO space changed
    
//    case closed(windowNumber: WindowNumber)
    // out of scope: no suitable ax event found.
  }
  
  
  let handler: (Event) -> Void
  
  let handlerQueue: DispatchQueue

  
  public init(
    handler: @escaping (Event) -> Void,
    handlerQueue: DispatchQueue = DispatchQueue.main
  ) {
    self.handler = handler
    self.handlerQueue = handlerQueue
  }
  
  public func observeEvents() {
    self.watchWindows()
    
    for app in applicationsToObserve {
      let pid = app.processIdentifier
      if let siApp = appElement(forProcessIdentifier: pid) {
        for window in siApp.uncachedWindows {
          track(window: window, pid: pid)
        }
      }
    }
  }

    
    
//    self.registerForNotification()
//
//    // observe current apps.
//    let apps = self.applicationsToObserve
//    for app in apps {
////      self.observeAxEvents(for: <#T##NSRunningApplication#>)
//
//      let siApp = SIApplication(runningApplication: app)
//
//      // observe simple notifs.
//      let simpleNotifications = [
//        kAXMainWindowChangedNotification,
//        kAXFocusedWindowChangedNotification,
//        kAXWindowMovedNotification,
//        kAXWindowResizedNotification,
//        // ... and more.
//      ]
//      for notif in simpleNotifications {
//        siApp.observeAxNotification(notif, with: siApp)
//      }
//
//      // when window created,
//    }
//
//    // observe launches.
//    observeLaunch { runningApplication in
//      <#code#>
//    }
//
//    observeTerminate { runningApplication in
//      <#code#>
//    }
//  }
//
//  func unobserveEvents() {
////    self.unwatchWindows2()
//  }
  
  // bookkeep this window.
  // TODO synchronise.
  func track(window: SIWindow, pid: pid_t) {
    if !self.windowsByPid[pid, default: []].contains(window) {
      
      if let siApp = self.appElement(forProcessIdentifier: pid) {
        let result = siApp.observeAxNotification(kAXUIElementDestroyedNotification as CFString, with: window)
        print("!! watching \(window) for destruction. result:\(result.rawValue)")
      }
      else {
        print("!!!! couldn't find SIApplication for pid:\(pid); can't track window for destruction.")
      }

      self.windowsByPid[pid, default:[]].append(window)
    }
    
//    func isTracked(tabGroup: SITabGroup) -> Bool {
//      tabGroupsByWindowId.values.contains { $0.axElementRef == tabGroup.axElementRef}
//    }
//  
//    func track(tabGroup: SITabGroup, window: SIWindow) {
//      tabGroupsByWindowId[window.windowID] = tabGroup
//      
//      let siApp = appElement(forProcessIdentifier: tabGroup.processIdentifier())
//      siApp?.observeAxNotification(<#T##notification: CFString##CFString#>, with: <#T##SIAccessibilityElement#>)
//    }
//
//    if let tabGroup = window.tabGroup,
//       !isTracked(tabGroup: tabGroup) {
//      track(tabGroup: tabGroup, window: window)
//    }
  }

  
  func untrack(window: SIWindow, pid: pid_t) {
    self.windowsByPid[pid]?.removeAll { $0.axElementRef == window.axElementRef }
  }
  
  func trackedWindow(element: SIAccessibilityElement) -> SIWindow? {
    windowsByPid
      .flatMap { $0.value }
      .first { $0.axElementRef == element.axElementRef }
  }
  
  func snapshot(tabGroupElement: SIAccessibilityElement, window: SIWindow) {
    let tabGroup = SITabGroup(axElement: tabGroupElement.axElementRef)
    let tabs = tabGroup.tabs
    if tabContentsByWindow[window.axElementRef] != tabs {
      tabContentsByWindow[window.axElementRef] = tabs
      print("!! took tabs snapshot of \(window)")
    }
    
  }
  
  // TODO initially populate as much as possible.
  var windowsByPid: [pid_t : [SIWindow]] = [:]
  
  var tabContentsByWindow: [AXUIElement : [SITabGroup.Tab]] = [:]
  
  var windowsWithoutTabGroups: [SIWindow] = []
  var windowsByTabGroups: [AXUIElement: [SIWindow]] = [:]


  // TODO track window coming into radar.
  
  override public func updateAccessibilityInfo(for siElement: SIAccessibilityElement, axNotification: CFString, forceUpdate: Bool) {
//    super.updateAccessibilityInfo(for: siElement, axNotification: axNotification, forceUpdate: forceUpdate)
    // DISABLED no longer using the ax info property; don't incur the additional processing which could be quite frequent (per ax event)

    switch axNotification as String {
    case kAXWindowCreatedNotification:
      // filter out some roles.
      
      guard siElement.role() != kAXPopoverRole
      else {
        return
      }
      
      let window = SIWindow(for: siElement)
      let pid = window.processIdentifier()
      
      // observe teardown of this window.
      track(window: window, pid: pid)
      
      handle(.created(windowNumber: window.windowID, tabGroup: window.tabGroup))
    
    case kAXMainWindowChangedNotification, kAXFocusedWindowChangedNotification:
      guard siElement.subrole() == kAXStandardWindowSubrole else {
        print("\(siElement) is not a standard window; not emitting event.")
        return
      }
      
      let window = SIWindow(for: siElement)
      let windowNumber = window.windowID
      let pid = siElement.processIdentifier()
      track(window: window, pid: pid)

      let tabGroup = window.tabGroup
      
      handle(.focused(windowNumber: windowNumber, tabGroup: tabGroup))
      
      func bookkeep(_ window: SIWindow, _ tabGroup: SITabGroup?) {
        func prune(window: SIWindow) {
          windowsByTabGroups = windowsByTabGroups.mapValues {
            var ws = $0
            ws.removeAll { $0 == window }
            return ws
          }
          windowsWithoutTabGroups.removeAll { $0 == window }
        }

        if let tabGroup = tabGroup {
          // first prune.
          prune(window: window)
          // then insert.
          windowsByTabGroups[tabGroup.axElementRef, default: []].append(window)
          let tabWindows = windowsByTabGroups[tabGroup.axElementRef] ?? []
          print("!! tab group has windows: \(tabWindows)")
        } else {
          assert(window.isVisible())
          prune(window: window)
          windowsWithoutTabGroups.append(window)
        }
      }
      
      func tabContext(
        window: SIWindow) -> TabContext? {
        // state
        var visibleWindowsByPid: [pid_t : [SIWindow]] = [:]
        
        let pid = window.processIdentifier()
        let space = spaceForWindow(window.windowID)
        let priorWindows = visibleWindowsByPid[pid] ?? []
        let currentWindows = SIApplication(forProcessIdentifier: pid).windows
        visibleWindowsByPid[pid] = currentWindows
        // pre-condition: no prior windows have been closed.
        let disappearedWids =
          Set(priorWindows.map { $0.windowID })
          .subtracting(currentWindows.map { $0.windowID })
          .filter { spaceForWindow($0) == space }
          
        if disappearedWids.count == 0 {
          return nil
        } else if disappearedWids.count > 1 {
          return nil
        }
        
        if let priorTabOwner = priorWindows.first { $0.windowID == disappearedWids.first! } {
          return TabContext(priorTabOwner: priorTabOwner)
        }
        
        return nil
      }
      
      struct TabContext {
        let priorTabOwner: SIWindow
      }
      
    case kAXTitleChangedNotification:
      let window = SIWindow(for: siElement)
      let windowNumber = window.windowID
      let title = window.title()
      handle(.titleChanged(windowNumber: windowNumber, title: title))
      
    case kAXApplicationActivatedNotification:
      let pid = siElement.processIdentifier()
      
      // log just activated notif to ensure we're listening.
      print("activated pid:\(pid) (\(siElement.title() ?? "?"))")
      
      let window = SIWindow(for: siElement.focused())
      track(window: window, pid: pid)

      focusedWindow(pid: pid) { [unowned self] window in
        print("activated pid:\(pid) (\(siElement.title() ?? "?")), ax reports focused window \(window?.windowID ?? kCGNullWindowID)")
        handle(.activated(pid: pid, focusedWindowNumber: window?.windowID, tabGroup: window?.tabGroup))
      }

    case kAXApplicationDeactivatedNotification:
      focusedWindow() { [unowned self] focusedWindow in
        if let focusedWindow = focusedWindow {
          handle(.activated(pid: focusedWindow.processIdentifier(), focusedWindowNumber: focusedWindow.windowID, tabGroup: focusedWindow.tabGroup))
        }
      }

    case kAXWindowMovedNotification,
         kAXWindowResizedNotification:
      let window = SIWindow(for: siElement)
      let windowNumber = window.windowID
      let frame = window.frame()
      guard windowNumber != kCGNullWindowID,
            frame != .zero
      else { return }
      handle(.frameChanged(windowNumber: windowNumber, frame: frame))
          
      
    // TODO infer closed:
    // - compare app's windows with previous set.
    // - limitation: window set is per-space, so ensure space change doesn't create false inferences.
    case kAXUIElementDestroyedNotification:
      if let window = trackedWindow(element: siElement) {
        print("!! \(window) closed, removing from the books.")
        untrack(window: window, pid: window.processIdentifier())
        
        // TODO unobserve ax?
        
        handle(.closed(windowNumber: window.windowID))
      }
    
//    case kAXValueChangedNotification:
//      if let parent = siElement.forKey(kAXParentAttribute as CFString),
//         parent.role() == kAXTabGroupRole {
//      }

      
    case kAXWindowMiniaturizedNotification:
      let windowNumber = SIWindow(for: siElement).windowID
      handle(.minimised(windowNumber: windowNumber))

    case kAXWindowDeminiaturizedNotification:
      let windowNumber = SIWindow(for: siElement).windowID
      handle(.unminimised(windowNumber: windowNumber))

    case kAXApplicationHiddenNotification:
      let pid = siElement.processIdentifier()
      handle(.hidden(pid: pid))
    case "AXFocusedTabChanged":  // EXTRACT
      if siElement.role() == kAXWindowRole {
        let window = SIWindow(for: siElement)
        print("tab changed to wid:\(window.windowID)")
        handle(.tabChanged(windowNumber: window.windowID, tabGroup: window.tabGroup))
      } else {
        print("👺 \(siElement) is not a window; AXFocusedTabChanged will be ignored.")
      }
    default:
      return
    }
  }

  func handle(_ event: Event) {
    handlerQueue.async {
      self.handler(event)
    }
  }
    
  /**
   @return applications for which the AxObserver will register for AX notifications.
   there are factory defaults for some exclusions which are roughly on par with:
   
   ```bash
   killall cfprefsd
   defaults write com.bigbearlabs.contexter "axobserver_excluded_names" "System Events,com.apple.WebKit.WebContent,com.apple.WebKit.Networking,Google Chrome Helper,WebBuddy,Contexter"
   defaults write com.bigbearlabs.contexter "axobserver_excluded_bundleids" "com.apple.WebKit,com.apple.WebKit.Networking,com.apple.loginwindow,Karabiner_AXNotifier,com.google.Chrome.helper"
   ```
  */
  public override func shouldObserve(_ application: NSRunningApplication) -> Bool {

//    // don't observe this app.
//    guard application.processIdentifier != myPid
//    else { return false }

    // must have a bundle id.
    guard let bundleId = application.bundleIdentifier else {
      return false
    }
    
    guard let bundleUrl = application.bundleURL,
          // exclude everything that ends with '.xpc'.
          bundleUrl.absoluteString.hasSuffix(".xpc") != true
          // exclude e.g. '/System/Library/CoreServices/Siri.app/Contents/XPCServices/SiriNCService.xpc/Contents/MacOS/SiriNCService'
          && bundleUrl.absoluteString.contains(".xpc/") != true
          && bundleUrl.absoluteString.contains(".appex/") != true
    else {
      return false
    }
    
    if self.excludedBundleIdSubstrings
      .contains(where: {
        // bundle id contains the substring
        bundleId.lowercased().contains($0)
      }) {
      return false
    }
    
    if let appUrl = application.executableURL {
      let filename = appUrl.lastPathComponent
      if self.excludedNames.contains(filename) {
        return false
      }
    }
    
    return true
  }
  
  lazy var myPid = NSRunningApplication.current.processIdentifier

  lazy var excludedBundleIdSubstrings: [String] = {
    return (UserDefaults.standard.stringArray(forKey: "excludedBundleIdPatterns")  ?? [])
      + [
//        // always exclude my own bundle id.
//        Bundle.main.bundleIdentifier,
        
        "com.apple.loginwindow",

        // exclude all input methods, ui agents.
        "com.apple.inputmethod",
        ".uiagent",

        "com.apple.controlstrip",
        "com.apple.ScreenSaver.Engine",

        "com.kite.Kite",
        "at.obdev.littlesnitch.softwareupdate",
        
//        "com.apple.dt.Xcode",  // DEV to allow debugger ops while troubleshooting cases where watch setup was slow.

      ].compactMap { $0 }
  }()
  
  var excludedNames: [String] {
    return (UserDefaults.standard.stringArray(forKey: "excludedNames") ?? [])
      + [
        "Dock",
        "loginwindow",
        "WindowServer",
        "ScreenSaverEngine",
        
        "universalaccessd",
        "passd",
        "photolibraryd",

        "talagent",
        "coreautha.bundle",
        "AirPlayUIAgent",
        "CalendarAgent",
        "ARDAgent",

        "UIKitSystem",

        "Siri",
        "SiriNCService",
        "universalAccessAuthWarn",
        
        "BetterTouchTool",
        "USBserver",
        
        ".appex",
    ]
  }

  public override func handleAxObservationResults(_ axResults: [NSNumber], for application: NSRunningApplication) {
    // observe on the next opportunity.
    // when app activated?
  }

}



public func dumpCg(windowNumber: UInt32) -> Any {
  // wid -> pid
  let q1 = CGWindowInfo.query(windowNumber: windowNumber)
  if let pid = q1?.pid {
    let q2 = (CGWindowListCopyWindowInfo([.optionAll,], kCGNullWindowID) as? [[CFString : Any?]] ?? [])
      .filter {
        $0[kCGWindowOwnerPID] as? pid_t == pid
    }
    let summary = q2.map {
      [
        "wid": $0[kCGWindowNumber],
        "pid": pid,
        "title": $0[kCGWindowName],
        "onScreen": $0[kCGWindowIsOnscreen],
        "frame": String(describing: $0[kCGWindowBounds]),
      ]
    }
    return summary
  }
  return []
}


func spaceForWindow(_ windowNumber: CGWindowID) -> Int? {
  let windows: CFArray = [NSNumber(value: windowNumber)] as CFArray
  let spaces = CGSCopySpacesForWindows(_CGSDefaultConnection(), kCGSSpaceAll, windows)
  if let retval = spaces?.takeUnretainedValue() {
      return (retval as? [Int])?.first
  }
  return nil
}




extension SIWindow {
  open override var description: String {
    "wid:\(windowID) \(super.description)"
  }
}
