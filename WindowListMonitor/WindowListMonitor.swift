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
    let windowId = siWindow.windowID

    switch axNotification as String {
    case kAXWindowCreatedNotification:
      DispatchQueue.main.async {
        self.handler(.created(windowNumber: windowId))
      }
    
    case kAXMainWindowChangedNotification, kAXFocusedWindowChangedNotification:
      DispatchQueue.main.async {
        self.handler(.focused(windowNumber: windowId))
      }
      // TODO confirm the id is reliable
      
    default:
      ()
    }
  }
  
}
