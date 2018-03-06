//
//  AccessibilityInfo-ext.swift
//  BBLAccessibility
//
//  Created by ilo on 30/06/2017.
//  Copyright © 2017 Big Bear Labs. All rights reserved.
//

import Foundation
import BBLBasics



extension AccessibilityInfo {
  
  public var buttonGroupRect: CGRect {
    guard let window = self.windowElement else {
      // there's no window!?
      
      return .zero
    }
    
    var revealFrame = window.closeButton?.frame()
    if let minimiseFrame = window.minimiseButton?.frame() {
      revealFrame = revealFrame?.union(minimiseFrame)
    }
    if let zoomFrame = window.zoomButton?.frame() {
      revealFrame = revealFrame?.union(zoomFrame)
    }
    
    return revealFrame?.toCocoaFrame() ?? .zero
  }
  
}
