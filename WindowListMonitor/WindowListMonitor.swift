//
//  File.swift
//  WindowListMonitor
//
//  Created by ilo on 13/06/2020.
//  Copyright © 2020 Big Bear Labs. All rights reserved.
//

import BBLAccessibility

public class WindowListMonitor: BBLAccessibilityPublisher {
  
  public enum Event {
    case created(windowNumber: UInt32)
    case focused(windowNumber: UInt32)  // RENAME activated
    
    case titleChanged(windowNumber: UInt32)
    
    case activated(pid: pid_t, focusedWindowNumber: UInt32?)
    case noWindow(pid: pid_t)

    case moved(windowNumber: UInt32)
    
    // TODO
//    case movedIn(windowNumber: WindowNumber)
    
    // TODO moved out
    
    // TODO space changed
    
//    case closed(windowNumber: WindowNumber)
    // out of scope: no suitable ax event found.
  }
  
  let handler: (Event) -> Void
  
  
  public init(handler: @escaping (Event) -> Void) {
    self.handler = handler
  }
  
  public func observeEvents() {
    self.watchWindows()
  }
  
  func unobserveEvents() {
    self.unwatchWindows()
  }
  
  override public func updateAccessibilityInfo(for siElement: SIAccessibilityElement, axNotification: CFString, forceUpdate: Bool) {
    super.updateAccessibilityInfo(for: siElement, axNotification: axNotification, forceUpdate: forceUpdate)

    var event: Event?
    switch axNotification as String {
    case kAXWindowCreatedNotification:
      let windowNumber = SIWindow(for: siElement).windowID
      event = .created(windowNumber: windowNumber)
    
    case kAXMainWindowChangedNotification, kAXFocusedWindowChangedNotification:
      guard siElement.subrole() == kAXStandardWindowSubrole else {
        print("\(siElement) is not a standard window; not emitting event.")
        return
      }
      
      let windowNumber = SIWindow(for: siElement).windowID
      event = .focused(windowNumber: windowNumber)
      // TODO confirm the id is reliable
    
    case kAXTitleChangedNotification:
      let windowNumber = SIWindow(for: siElement).windowID
      event = .titleChanged(windowNumber: windowNumber)
      
    case kAXApplicationActivatedNotification:
      let pid = siElement.processIdentifier()
      focusedWindow(pid: pid) { w in
        event = .activated(pid: pid, focusedWindowNumber: w?.windowID)
        DispatchQueue.main.async {
          self.handler(event!)
        }
        return
      }
    
    case kAXApplicationDeactivatedNotification:
      focusedWindow() { focusedWindow in
        if let focusedWindow = focusedWindow {
          event = .activated(pid: focusedWindow.processIdentifier(), focusedWindowNumber: focusedWindow.windowID)
          DispatchQueue.main.async {
            self.handler(event!)
          }
        }
        return
      }

    case kAXWindowMovedNotification:
      let windowNumber = SIWindow(for: siElement).windowID
      event = .moved(windowNumber: windowNumber)
    
    // TODO inferring closed.
    case kAXUIElementDestroyedNotification:
      let pid = siElement.processIdentifier()
      focusedWindow(pid: pid) { focusedWindow in
        if focusedWindow == nil {
          event = .noWindow(pid: pid)
          DispatchQueue.main.async {
            self.handler(event!)
          }
        }
        return
      }
      
    default:
      return
    }
    
    if event != nil {
      DispatchQueue.main.async {
        self.handler(event!)
      }
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
    let pid = NSRunningApplication.current.processIdentifier
        
    // must have a bundle id.
    guard let bundleId = application.bundleIdentifier else {
      return false
    }
    
    guard
      // don't observe this app.
      application.processIdentifier != pid
        
      // exclude all agent apps. except webbuddy.
      && (!application.isAgent()
        || application.bundleIdentifier == "com.bigbearlabs.WebBuddy"
        )
        
      // exclude everything that ends with '.xpc'.
      && application.bundleURL?.absoluteString.hasSuffix(".xpc") != true
      // exclude e.g. '/System/Library/CoreServices/Siri.app/Contents/XPCServices/SiriNCService.xpc/Contents/MacOS/SiriNCService'
      && application.bundleURL?.absoluteString.contains(".xpc/") != true
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
  


  lazy var excludedBundleIdSubstrings: [String] = {
    return (UserDefaults.standard.stringArray(forKey: "excludedBundleIdPatterns")  ?? [])
      + [
        // always exclude my own bundle id.
        Bundle.main.bundleIdentifier,
        "com.apple.loginwindow",
        "com.kite.Kite",
        "com.apple.controlstrip",
        
        // exclude all input methods, ui agents.
        "com.apple.inputmethod",
        ".uiagent",

//        "com.apple.dt.Xcode",  // DEV to allow debugger ops while troubleshooting cases where watch setup was slow.

      ].compactMap { $0 }
  }()
  
  var excludedNames: [String] {
    return (UserDefaults.standard.stringArray(forKey: "excludedNames") ?? [])
      + [
        "Dock",
        "loginwindow",
        "universalaccessd",
        "talagent",
        "coreautha.bundle",
        "AirPlayUIAgent",
        "Siri",
        "SiriNCService",
        "universalAccessAuthWarn",
        "BetterTouchTool",
    ]
  }

}
