//
//  GenericWatcher.swift
//  BBLAccessibility
//
//  Created by ilo on 25/10/2016.
//  Copyright © 2016 Big Bear Labs. All rights reserved.
//

import Foundation
import BBLAccessibility

public class GenericWatcher: BBLAccessibilityWindowWatcher {
  
  @objc
  public var accessibilityData: NSDictionary = [:]
  
  override public func onApplicationActivated(element: SIAccessibilityElement) {
    let accessibilityData = NSMutableDictionary(dictionary: self.accessibilityData)
    accessibilityData["currentApp"] = element
    self.accessibilityData = accessibilityData
  }
  
  override public func onFocusedWindowChanged(window: SIWindow) {
    let accessibilityData = NSMutableDictionary(dictionary: self.accessibilityData)
    accessibilityData["currentWindow"] = window
    self.accessibilityData = accessibilityData
  }

  override public func onTitleChanged(element: SIAccessibilityElement) {
    let accessibilityData = NSMutableDictionary(dictionary: self.accessibilityData)
    accessibilityData["currentWindowTitle"] = element
    self.accessibilityData = accessibilityData
  }
  
  override public func onWindowMinimised(window: SIWindow) {
    if let currentWindow = accessibilityData["current_window"] as? SIWindow {
      if currentWindow.windowID() == window.windowID() {
        let accessibilityData = NSMutableDictionary(dictionary: self.accessibilityData)
        accessibilityData["currentWindow"] = nil
        self.accessibilityData = accessibilityData
      }
      
    }
  }
  
  //
  //-(void) onWindowUnminimised:(SIWindow*)window;
  //
  
  // TODO update frames.
  //-(void) onWindowMoved:(SIWindow*)window;
  //
  //-(void) onWindowResized:(SIWindow*)window;
  //
}



//
//-(void) onWindowCreated:(SIWindow*)window;
//
//-(void) onWindowMinimised:(SIWindow*)window;
//
//-(void) onWindowUnminimised:(SIWindow*)window;
//
//-(void) onWindowMoved:(SIWindow*)window;
//
//-(void) onWindowResized:(SIWindow*)window;
//
//
//-(void) onTextSelectionChanged:(SIAccessibilityElement*)element;
//

// data needs to be adequate for 'focused window' determination.
