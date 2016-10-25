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
  public var accessibilityData: NSMutableDictionary = [:]
  
  override public func onApplicationActivated(element: SIAccessibilityElement) {
    accessibilityData["current_app"] = element
  }
  
  override public func onFocusedWindowChanged(window: SIWindow) {
    accessibilityData["current_window"] = window
  }

  override public func onTitleChanged(element: SIAccessibilityElement) {
    accessibilityData["current_title"] = element
  }
  
  override public func onWindowMinimised(window: SIWindow) {
    if let currentWindow = accessibilityData["current_window"] as? SIWindow {
      if currentWindow.windowID() == window.windowID() {
        accessibilityData["current_window"] = NSNull()
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
