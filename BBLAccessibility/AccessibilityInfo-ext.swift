//
//  AccessibilityInfo-ext.swift
//  BBLAccessibility
//
//  Created by ilo on 30/06/2017.
//  Copyright © 2017 Big Bear Labs. All rights reserved.
//

import Foundation
import BBLBasics


public struct AxApplication {
  
  let siApp: SIApplication
  
  public init(bundleId: String) {
    self.init(siApplication: SIApplication.application(bundleId: bundleId)!)
    // improve: reuse siapp dictionary in the publisher when we can.
  }
  
  init(siApplication: SIApplication) {
    self.siApp = siApplication
  }
  
  public func focus(windowNumber: CGWindowID) {
    print("focusing window \(windowNumber)")
    let matches = self.siApp.windows.filter {
      $0.windowID == windowNumber
    }
    
    if let match = matches.first {
      match.focusOnlyThisWindow()
    }
  }
  
  public static var focused: AxApplication? {
    if let app = SIApplication.focused() {
      return self.init(siApplication: app)
    }
    return nil
  }
  
  public var pid: pid_t {
    return self.siApp.processIdentifier()
  }
}


extension AccessibilityInfo {
  
  public var buttonGroupRect: CGRect? {
    guard let window = self.windowElement else {
      // there's no window!?
      
      return nil
    }
    
    var revealFrame = window.closeButton?.frame()
    if let minimiseFrame = window.minimiseButton?.frame() {
      revealFrame = revealFrame?.union(minimiseFrame)
    }
    if let zoomFrame = window.zoomButton?.frame() {
      revealFrame = revealFrame?.union(zoomFrame)
    }
    
    return revealFrame?.toCocoaFrame()
  }
  
}
