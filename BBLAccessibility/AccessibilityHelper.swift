import AppKit
import ApplicationServices
import BBLBasics



open class AccessibilityHelper {
  
  let lastOnlyQueue = LastOnlyQueue()

  public init() {}
  
  
  @discardableResult
  open func queryAccessibilityPermission(
    onPermissionFound: () -> Void,
    onPermissionReceived: @escaping () -> Void,
    onPollFindsNoPermission: @escaping () -> Void) -> Bool {
    
    // first check if we have the perm.
    let isOriginallyPermissioned = AXIsProcessTrustedWithOptions(nil)
    if isOriginallyPermissioned {
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

  
  open func showSystemAxRequestDialog() {
    let promptOptionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [
      promptOptionKey: true
    ]
    let isPermissioned = AXIsProcessTrustedWithOptions(options as CFDictionary)
    
    if isPermissioned {
      fatalError("invalid call -- can't show system ax request dialog when we already have perms")
    }
  }

}
