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
import WindowListMonitor

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
    
    
    self.windowListMonitor.observeEvents { [unowned self] event in
      
      print("event: \(event)")
      
      // IT1 poll cgwindowlist for on-space windows.
      self.currentSpaceWindows = self.windowListMonitor.activeWindowsInCurrentSpace
      let dump = self.currentSpaceWindows.flatMap { e -> [[String : String]] in
        let (screen, windows) = e
        return windows.map {[
          "screen": screen.description,
          "title": $0.title,
          "app": $0.bundleId,
          ]
        }
      }
      
      print(try! ["currentSpaceWindows": dump].jsonString())
    }
  }

  var currentSpaceWindows: [Int : [CGWindowInfo]] = [:]
  
  lazy var windowListMonitor = WindowListMonitor()

}
