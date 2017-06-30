//
//  AccessibilityInfo-ext.swift
//  BBLAccessibility
//
//  Created by ilo on 30/06/2017.
//  Copyright © 2017 Big Bear Labs. All rights reserved.
//

import Foundation
import BBLAccessibility



extension AccessibilityInfo {
  
  public var buttonGroupFrame: CGRect {
    guard let window = self.windowAxElement else {
      // there's no window!?
      
      return .zero
    }
    
    let revealFrame = window.closeButton?.frame()
      .union(window.minimiseButton?.frame() ?? .zero)
      .union(window.zoomButton?.frame() ?? .zero)
      ?? .zero
    
    return revealFrame
  }
  
}
