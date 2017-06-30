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

  var watcher: BBLAccessibilityObserver!
  
  var siApp: SIApplication!
  
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    print("AXIsProcessTrusted: #\(AXIsProcessTrusted())")
    
    watcher = AXObserver()
//    watcher!.watchWindows()
    
    // PoC Silica basic usage.
    DispatchQueue.global().async {
      if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").last {
        self.siApp = SIApplication(runningApplication: finder)!
        self.siApp.observeNotification(kAXApplicationActivatedNotification as CFString, with: self.siApp, handler: { (element) in
          print("bing")
        })
      }
      
//      // PoC Silica coarse-grain interface.
//      watcher.watchNotifications(forApp: finder)
      
//      // PoC WIP
//      [application observeNotification:kAXApplicationActivatedNotification
//        withElement:application
//        handler:^(SIAccessibilityElement *accessibilityElement) {
//        [blockSelf updateAccessibilityInfoForElement:accessibilityElement forceUpdate:YES];
//        
//        [blockSelf onApplicationActivated:accessibilityElement];
//        }];
//      
    }
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }

  
  // PoC requesting perms.
  @IBAction
  func action_showAxRequestDialog(_ sender: AnyObject) {
    AccessibilityHelper().maybeRequestAxPerms()
  }
}



class AXObserver: BBLAccessibilityObserver {
  override var applicationsToObserve: [NSRunningApplication] {
    get {
      let pid = NSRunningApplication.current().processIdentifier
      let excludedBundleIds = self.excludedBundleIds
      let excludedNames = self.excludedNames
      
      return super.applicationsToObserve.filter { runningApplication in
        guard
          // don't observe this app.
          runningApplication.processIdentifier != pid
            // exclude all agent apps.
            && !runningApplication.isAgent()
            // exclude everything that ends with '.xpc'.
            && !(runningApplication.bundleURL?.absoluteString.hasSuffix(".xpc") ?? false)
          else {
            return false
        }
        
        if let bundleId = runningApplication.bundleIdentifier {
          if excludedBundleIds.contains(bundleId) {
            return false
          }
        }
        
        if let appUrl = runningApplication.executableURL {
          let filename = appUrl.absoluteString.components(separatedBy: "/").last!
          if excludedNames.contains(filename) {
            return false
          }
        }
        
        return true
      }
    }
  }
  
  
  var excludedNames: [String] {
//    return (NSApp.default(forKey: .axobserver_excluded_names) as? String ?? "").components(separatedBy: ",")
    return [
//"AirPlayUIAgent.app"
//      Siri.app
//      SiriNCService.xpc
    ]
  }
  var excludedBundleIds: [String] {
//    return (NSApp.default(forKey: .axobserver_excluded_bundleids) as? String ?? "").components(separatedBy: ",")
//      +
//      // always exclude my own bundle id.
//      [ Bundle.main.bundleIdentifier! ]
    return []
  }

}
