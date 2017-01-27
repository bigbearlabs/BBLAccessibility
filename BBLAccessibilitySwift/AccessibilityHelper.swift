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
import BBLBasics


open class AccessibilityHelper {
  
  public init() {}
  
  open func queryAxPerms(promptIfNeeded: Bool, postCheckHandler: @escaping (_ isPermissioned: Bool)->()) {
    
    lastOnlyQueue.async {
      var options: [String:Any]? = nil
      
      if promptIfNeeded {
        let promptOptionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        options = [
          promptOptionKey: true
        ]
      }
      
      let isPermissioned = AXIsProcessTrustedWithOptions(options as CFDictionary?)
      
      postCheckHandler(isPermissioned)
    }
    
  }
  
  
  let lastOnlyQueue = LastOnlyQueue()
  

  // ---
  
  let modalQueue = DispatchQueue(label: "com.bigbearlabs.contexter.axpermission")

  func window(at position: CGPoint, size: CGSize) -> NSWindow {
    let window = NSWindow()
    window.makeKeyAndOrderFront(self)
    window.centre(screen: NSScreen.main()!)
    return window
  }

}



// MARK: TO EXTRACT

open class LastOnlyQueue {
  
  let queue = DispatchQueue(label: "com.bigbearlabs.AccessibilityHelper.axRequestQueue")
  var opOnStandby: (()->())?
  var poller: DispatchSourceTimer!
  
  public init() {
    // ensure the queue is operational when it's created.
    self.resume()
  }
  
  func resume(threshold: TimeInterval = 3) {
    self.poller = periodically(every: 3, queue: queue) { [weak self] in
      let op = self?.opOnStandby
      
      self?.opOnStandby = nil
      
      if op != nil { op!() }
    }
  }
  
  open func async(closure: @escaping ()->()) {
    queue.async { [unowned self] in
      if self.opOnStandby != nil {
        print("will supersede standby.")
        self.opOnStandby = closure
      }
      else {
        // just run and risk the small chance of a race.
        closure()
      }
      
    }
  }
}



extension NSWindow {
  func centre(screen: NSScreen) {
    // IMPL
  }
}


