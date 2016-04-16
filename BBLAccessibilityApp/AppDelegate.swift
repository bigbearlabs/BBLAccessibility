//
//  AppDelegate.swift
//  BBLAccessibilityApp
//
//  Created by ilo on 15/04/2016.
//  Copyright © 2016 Big Bear Labs. All rights reserved.
//

import Cocoa
import BBLAccessibility


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var window: NSWindow!

  var watcher: BBLAccessibilityWindowWatcher?
  
  func applicationDidFinishLaunching(aNotification: NSNotification) {
    watcher = BBLAccessibilityWindowWatcher()
    watcher!.watchWindows()
  }

  func applicationWillTerminate(aNotification: NSNotification) {
    // Insert code here to tear down your application
  }


}

