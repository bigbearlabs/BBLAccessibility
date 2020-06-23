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
    case focused(windowNumber: UInt32)
    
    case titleChanged(windowNumber: UInt32)
    
    case activated(pid: pid_t, focusedWindowNumber: UInt32?)
    
    // TODO
//    case movedIn(windowNumber: UInt32)
    
    // TODO moved out
    
    // TODO space changed
    
//    case closed(windowNumber: UInt32)
    // out of scope: no suitable ax event found.
  }
  
  var handler: (Event) -> Void = { _ in }
  
  
  var observation: Any?
  
  
  public func observeEvents(handler: @escaping (Event) -> Void) {
    
    self.handler = handler
    
//    self.observation = self.observe(\.accessibilityInfosByPid) { o, c in
//
//    }
    
    // avoid slow return.
    DispatchQueue.global().sync {
      self.watchWindows()
    }
  }
  
  func unobserveEvents() {
    // TODO
  }
  
  override public func updateAccessibilityInfo(for siElement: SIAccessibilityElement, axNotification: CFString, forceUpdate: Bool) {
    super.updateAccessibilityInfo(for: siElement, axNotification: axNotification, forceUpdate: forceUpdate)

    let siWindow = SIWindow(for: siElement)
    let windowNumber = siWindow.windowID

    var event: Event!
    switch axNotification as String {
    case kAXWindowCreatedNotification:
      event = .created(windowNumber: windowNumber)
    
    case kAXMainWindowChangedNotification, kAXFocusedWindowChangedNotification:
      event = .focused(windowNumber: windowNumber)
      // TODO confirm the id is reliable
    
    case kAXTitleChangedNotification:
      event = .titleChanged(windowNumber: windowNumber)
      
    case kAXApplicationActivatedNotification:
      let siApp = SIApplication(axElement: siElement.axElementRef)
      let pid = siApp.processIdentifier()
      let focusedWindowNumber = siApp.focusedWindow()?.windowID
      event = .activated(pid: pid, focusedWindowNumber: focusedWindowNumber)
      
    default:
      return
    }
    
    DispatchQueue.main.async {
      self.handler(event)
    }

  }
  
  
  public override var applicationsToObserve: [NSRunningApplication] {
    var apps = super.applicationsToObserve
    apps.removeAll { runningApp in
      // exclude myself.
      runningApp.bundleIdentifier == Bundle.main.bundleIdentifier
    }
    return apps
  }
  
}
