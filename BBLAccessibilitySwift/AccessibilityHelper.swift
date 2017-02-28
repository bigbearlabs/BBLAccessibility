import AppKit
import ApplicationServices
import BBLBasics


open class AccessibilityHelper {
  
  let lastOnlyQueue = LastOnlyQueue()

  public init() {}
  
  /***
   queries for Accessibility permission and invokes handler based on whether the app has Accessibility permissions.
   if query returns no permissions, `whenNoPermission` is invoked.
   when `shouldPoll`  = true, we repeatedly query for the permission until it is obtained.
   when permission is eventually granted, `whenPermissioned` is invoked and all sparse polling is stopped.
  */
  open func queryAxPerm(promptIfNeeded: Bool, shouldPoll: Bool = false, whenNoPermission: @escaping () -> Void, whenPermissioned: @escaping () -> Void) {
    
    
    lastOnlyQueue.pollingAsync { [unowned self] in

      let promptOptionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
      let options = [
        promptOptionKey: promptIfNeeded
      ]
      
      let isPermissioned = AXIsProcessTrustedWithOptions(options as CFDictionary)
      
      if !shouldPoll {
        self.lastOnlyQueue.pollStop()
      }
      
      if isPermissioned {
        if shouldPoll {
          self.lastOnlyQueue.pollStop()
        }
          
        whenPermissioned()
      }
      else {
          whenNoPermission()
        
        if shouldPoll {
          // recursively invoke, so clients don't have to implement a blocking workflow.
          self.queryAxPerm(promptIfNeeded: promptIfNeeded, shouldPoll: shouldPoll, whenNoPermission: whenNoPermission, whenPermissioned: whenPermissioned)
        }
      }
    }
    
  }
}





