//
//  File.swift
//  WindowListMonitor
//
//  Created by ilo on 13/06/2020.
//  Copyright © 2020 Big Bear Labs. All rights reserved.
//

import BBLAccessibility

public class WindowListMonitor: BBLAccessibilityPublisher {
  
  public enum Event: Equatable {
    case created(windowNumber: UInt32, tabs: [SITabGroup.Tab]?)  // TODO extract leaky param type
    case focused(windowNumber: UInt32)  // RENAME activated
    case tabChanged(windowNumber: UInt32)

    case titleChanged(windowNumber: UInt32, title: String?)
    
    case activated(pid: pid_t, focusedWindowNumber: UInt32?)
    case noWindow(pid: pid_t)

    case frameChanged(windowNumber: UInt32)
    
    case minimised(windowNumber: UInt32)
    case unminimised(windowNumber: UInt32)
    case hidden(pid: pid_t)


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
  }
  
  func unobserveEvents() {
    self.unwatchWindows()
  }
  
  override public func updateAccessibilityInfo(for siElement: SIAccessibilityElement, axNotification: CFString, forceUpdate: Bool) {
    super.updateAccessibilityInfo(for: siElement, axNotification: axNotification, forceUpdate: forceUpdate)

    switch axNotification as String {
    case kAXWindowCreatedNotification:
      // filter out some roles.
      
      guard siElement.role() != kAXPopoverRole
      else {
        return
      }
      
      let window = SIWindow(for: siElement)
      let windowNumber = window.windowID
      
      // CASE window tab creation.
      // if tab group's children buttons (AXRoleDescription='tab') should has 1 new element,
      // this ia a tab creation case.
      let tabs = window.tabGroup?.tabs
      handle(.created(windowNumber: windowNumber, tabs: tabs))
    
    case kAXMainWindowChangedNotification, kAXFocusedWindowChangedNotification:
      guard siElement.subrole() == kAXStandardWindowSubrole else {
        print("\(siElement) is not a standard window; not emitting event.")
        return
      }
      
      let windowNumber = SIWindow(for: siElement).windowID
      handle(.focused(windowNumber: windowNumber))
      // TODO confirm the id is reliable
    
    case kAXTitleChangedNotification:
      let window = SIWindow(for: siElement)
      let windowNumber = window.windowID
      let title = window.title()
      handle(.titleChanged(windowNumber: windowNumber, title: title))
      
    case kAXApplicationActivatedNotification:
      let pid = siElement.processIdentifier()
      
      // log just activated notif to ensure we're listening.
      print("activated pid:\(pid) (\(siElement.title() ?? "?"))")
      
      focusedWindow(pid: pid) { [unowned self] window in
        print("activated pid:\(pid) (\(siElement.title() ?? "?")) reports focused window \(window?.windowID ?? kCGNullWindowID)")
        handle(.activated(pid: pid, focusedWindowNumber: window?.windowID))
      }

    case kAXApplicationDeactivatedNotification:
      focusedWindow() { [unowned self] focusedWindow in
        if let focusedWindow = focusedWindow {
          handle(.activated(pid: focusedWindow.processIdentifier(), focusedWindowNumber: focusedWindow.windowID))
        }
      }

    case kAXWindowMovedNotification,
         kAXWindowResizedNotification:
      let windowNumber = SIWindow(for: siElement).windowID
      handle(.frameChanged(windowNumber: windowNumber))
          
    // TODO infer closed:
    // - compare app's windows with previous set.
    // - limitation: window set is per-space, so ensure space change doesn't create false inferences.
    case kAXUIElementDestroyedNotification:
      // TODO filter using same condition as on ax focus notif.
      let pid = siElement.processIdentifier()
      focusedWindow(pid: pid) { [unowned self] focusedWindow in
        if focusedWindow == nil {
          handle(.noWindow(pid: pid))
        }
      }

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
        handle(.tabChanged(windowNumber: window.windowID))
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

    // don't observe this app.
    guard application.processIdentifier != myPid
    else { return false }

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
        // always exclude my own bundle id.
        Bundle.main.bundleIdentifier,
        
        "com.apple.loginwindow",

        // exclude all input methods, ui agents.
        "com.apple.inputmethod",
        ".uiagent",

        "com.apple.controlstrip",
        "com.apple.ScreenSaver.Engine",

        "com.kite.Kite",

//        "com.apple.dt.Xcode",  // DEV to allow debugger ops while troubleshooting cases where watch setup was slow.

      ].compactMap { $0 }
  }()
  
  var excludedNames: [String] {
    return (UserDefaults.standard.stringArray(forKey: "excludedNames") ?? [])
      + [
        "Dock",
        "loginwindow",
        "WindowServer",
        
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
