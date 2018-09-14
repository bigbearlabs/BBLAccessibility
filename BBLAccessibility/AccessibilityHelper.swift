import AppKit
import ApplicationServices
import BBLBasics



open class AccessibilityHelper {
  
  let lastOnlyQueue = LastOnlyQueue()

  public init() {}
  
  
  open func showSystemAxRequestDialog() {
    let promptOptionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [
      promptOptionKey: true
    ]
    _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
  }
  
  
  @discardableResult
  open func queryAccessibilityPermission(
    onPermissionFound: () -> Void,
    onPermissionReceived: @escaping () -> Void,
    onPollFindsNoPermission: @escaping () -> Void) -> Bool {
    
    // first check if we have the perm.
    let originalPerm = AXIsProcessTrustedWithOptions(nil)
    if originalPerm {
      onPermissionFound()
      return true
    }
    
    // real world situation 1.
    // no perm, so we prompt once, then poll.
    
    // 1. no perm + prompt option -> will fail, prompt.
    let promptOptionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [
      promptOptionKey: true
    ]
    _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    
    // sparsely and repeatedly check for perm.
    let shouldPoll = true
    lastOnlyQueue.pollingAsync { [unowned self] in
      
      let isPermissioned = AXIsProcessTrustedWithOptions(nil)
      
      // since we got sent to a polling queue, we stop it after one invocation.
      if !shouldPoll || isPermissioned {
        self.lastOnlyQueue.pollStop()
      }
      
      if isPermissioned {
        // we obtained the perm in the recursive call chain.
        onPermissionReceived()
      }
      else {
        onPollFindsNoPermission()
      }
    }
    
    return false
  }

  
  /***
   queries for Accessibility permission and invokes handler based on whether the app has Accessibility permissions.
   if query returns no permissions, `ifNoPermission` is invoked.
   when `shouldPoll`  = true, we repeatedly query for the permission until it is obtained.
   `whenPermissioned(isNewPermission)` is called when first check was successful, or eventually in case of a polling call when the permission is obtained.
   polling stops when permission is obtained.
   */
  open func queryAccesibilityPermission(  // OBSOLETE
    promptIfNeeded: Bool,
    shouldPoll: Bool = false,
    ifNoPermission: @escaping () -> Void,
    whenPermissioned: @escaping(_ isNewPermission: Bool) -> Void )
    -> Bool
  {
    
    // first check if we have the perm.
    let originalPerm = AXIsProcessTrustedWithOptions(nil)
    if originalPerm {
      // chiching.
      whenPermissioned(false)
      
      return true
    }
    
//    ifNoPermission()
    
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
          let _ = self.queryAccesibilityPermission(promptIfNeeded: false, shouldPoll: true, ifNoPermission: ifNoPermission, whenPermissioned: whenPermissioned)
        }
      }
    }
    
    return originalPerm
  }
  
  open var isAccessibilityPermissioned: Bool {
    return self.queryAccesibilityPermission(promptIfNeeded: false, ifNoPermission: {}, whenPermissioned: {_ in })
  }
}





