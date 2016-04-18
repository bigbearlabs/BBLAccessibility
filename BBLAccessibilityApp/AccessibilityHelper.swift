//
//  AccessibilityHelper.swift
//  Silica
//
//  Created by ilo on 18/04/2016.
//  Copyright © 2016 SiO2. All rights reserved.
//

import Foundation
import ApplicationServices
import Silica

public class AccessibilityHelper {
  public class func complainIfNeeded() {
    let trusted = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
    let privOptions = [trusted: true]
    let accessEnabled = AXIsProcessTrustedWithOptions(privOptions)
    
    // work around the nasty hiding of the window!
//    NSApp.mainWindow?.makeKeyAndOrderFront(self);
//    NSApp.resignFirstResponder()

    // IT2 the deactivation behaviour means we have to launch this workflow from another popup.
    
    if !accessEnabled {
//      let alert = NSAlert()
//      alert.messageText = "Woops."
//      alert.informativeText = "Something went wrong."
//      alert.beginSheetModalForWindow(NSApp.keyWindow!, completionHandler: { response in
//        self.complainIfNeeded()
//      })
      
//      self.complainIfNeeded()
      
      // IT3 we ignore the potential failure here, as it's now unreliable.
      // instead, the caller should check again to see if we need to be reinvoked.
    }
    
    
//    SIUniversalAccessHelper.complainIfNeeded()
  }
}
