//
//  AppDelegate.swift
//  BBLAccessibilityApp
//
//  Created by ilo on 15/04/2016.
//  Copyright © 2016 Big Bear Labs. All rights reserved.
//

import Cocoa
import BBLAccessibility
import Silica
import ApplicationServices

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var window: NSWindow!

  var watcher: BBLAccessibilityObserver?
  
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    print("AXIsProcessTrusted: #\(AXIsProcessTrusted())")
    
    watcher = BBLAccessibilityObserver()
    watcher!.watchWindows()
  }

  func applicationWillTerminate(aNotification: NSNotification) {
    // Insert code here to tear down your application
  }

  @IBAction
  func action_showAccessibilityGrantDialog(sender: AnyObject) {
    // OUTDATED
//    AccessibilityHelper.complainIfNeeded()
  }
}

