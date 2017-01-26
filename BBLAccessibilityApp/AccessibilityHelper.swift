//
//  AccessibilityHelper.swift
//  Silica
//
//  Created by ilo on 18/04/2016.
//  Copyright © 2016 SiO2. All rights reserved.
//

import AppKit
import ApplicationServices
import Silica

open class AccessibilityHelper {
  
  public init() {
  }
  
  open func maybeRequestAxPerms() {
    
    let trusted = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
    let privOptions = [trusted: true]
    let accessEnabled = AXIsProcessTrustedWithOptions(privOptions as CFDictionary?)
    
    // make a window to show the alert on.
    let window = self.window(at:.zero, size: CGSize(width: 200, height: 80))  // add: constants for activation / positioning.
  
    // sporadic deactivation behaviour seen in some tests means 
    // we have to launch this workflow from another dialog.
    
    if !accessEnabled {
      let alert = NSAlert()
      alert.messageText = "Woops."
      alert.informativeText = "Something went wrong."
      if true {
        alert.beginSheetModal(for: window, completionHandler: { response in
          self.maybeRequestAxPerms()
        })

      } else {
        // no window, how to manage?
      }

////      self.modalQueue.async {
//        let modalResponse = alert.runModal()
////      }
//      
//      // MAYBE unless modal indicates abort...
//      
//      self.maybeRequestAxPerms()

      
      // TODO handle the errors.
    }
  }
  
  let modalQueue = DispatchQueue(label: "com.bigbearlabs.contexter.axpermission")

  func window(at position: CGPoint, size: CGSize) -> NSWindow {
    let window = NSWindow()
    window.makeKeyAndOrderFront(self)
    window.centre(screen: NSScreen.main()!)
    return window
  }

}


extension NSWindow {
  func centre(screen: NSScreen) {
    // IMPL
  }
}


