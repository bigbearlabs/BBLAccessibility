//
//  AppDelegate.swift
//  WindowListMonitorDemo
//
//  Created by ilo on 10/06/2020.
//  Copyright © 2020 Big Bear Labs. All rights reserved.
//

import Cocoa
import SwiftUI
import BBLAccessibility


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  var window: NSWindow!


  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Create the SwiftUI view that provides the window contents.
    let contentView = ContentView()

    // Create the window and set the content view. 
    window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered, defer: false)
    window.center()
    window.setFrameAutosaveName("Main Window")
    window.contentView = NSHostingView(rootView: contentView)
    window.makeKeyAndOrderFront(nil)
    
    
    self.windowListMonitor.observeEvents { event in
      switch event {
      // new
      case let .created(windowNumber):
        print("created \(windowNumber)")

        // focused
      case let .focused(windowNumber):
        print("focused \(windowNumber)")
        
//      // moved in
//      case let .movedIn(windowNumber):
//        print("movedIn \(windowNumber)")
        
      }
      
      // IT1 poll cgwindowlist for on-space windows.
    }
  }
  
  lazy var windowListMonitor = WindowListMonitor()

}



class WindowListMonitor: BBLAccessibilityPublisher {
  
  enum Event {
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
  
  
  func observeEvents(handler: @escaping (Event) -> Void) {
    
    self.handler = handler
    
//    self.observation = self.observe(\.accessibilityInfosByPid) { o, c in
//
//    }
    
    self.watchWindows()
  }
  
  func unobserveEvents() {
    
  }
  
  override func updateAccessibilityInfo(for siElement: SIAccessibilityElement, axNotification: CFString, forceUpdate: Bool) {
    super.updateAccessibilityInfo(for: siElement, axNotification: axNotification, forceUpdate: forceUpdate)

    let siWindow = SIWindow(for: siElement)
    let windowId = siWindow.windowID

    switch axNotification as String {
    case kAXWindowCreatedNotification:
      self.handler(.created(windowNumber: windowId))
    
    case kAXMainWindowChangedNotification, kAXFocusedWindowChangedNotification:
      self.handler(.focused(windowNumber: windowId))
      // TODO confirm the id is reliable
      
    default:
      ()
    }
  }
  
}
