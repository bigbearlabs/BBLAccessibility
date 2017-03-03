import AppKit
import ApplicationServices
import BBLBasics


open class AccessibilityHelper {
  
  let lastOnlyQueue = LastOnlyQueue()

  public init() {}
  
  /***
   queries for Accessibility permission and invokes handler based on whether the app has Accessibility permissions.
   if query returns no permissions, `ifNoPermission` is invoked.
   when `shouldPoll`  = true, we repeatedly query for the permission until it is obtained.
   `whenPermissioned(isNewPermission)` is called when first check was successful, or eventually in case of a polling call when the permission is obtained.
   polling stops when permission is obtained.
   */
  open func queryAxPerm(promptIfNeeded: Bool, shouldPoll: Bool = false, ifNoPermission: @escaping () -> Void, whenPermissioned: @escaping(_ isNewPermission: Bool) -> Void) {
    
    // first check if we have the perm.
    let originalPerm = AXIsProcessTrustedWithOptions(nil)
    if originalPerm {
      // chiching.
      whenPermissioned(false)
      
      return
    }

    ifNoPermission()

    // real world situation 1.
    // no perm, so we prompt once, then poll.
    
    // 1. no perm + prompt option -> will fail, prompt.
    let promptOptionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [
      promptOptionKey: promptIfNeeded
    ]
    _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    
    // sparsely and repeatedly check for perm.
    lastOnlyQueue.pollingAsync { [unowned self] in

      let isPermissioned = AXIsProcessTrustedWithOptions(nil)
      
      // since we got sent to a polling queue, we stop it after one invocation.
      if !shouldPoll || isPermissioned {
        self.lastOnlyQueue.pollStop()
      }
      
      if isPermissioned {
        // we obtained the perm in the recursive call chain.
        whenPermissioned(true)
      }
      else {
        ifNoPermission()
        
        if shouldPoll {
          // recursively invoke, so clients don't have to implement a blocking workflow.
          // - we don't want to poll and prompt.
          self.queryAxPerm(promptIfNeeded: false, shouldPoll: true, ifNoPermission: ifNoPermission, whenPermissioned: whenPermissioned)
        }
      }
    }
    
  }
}





