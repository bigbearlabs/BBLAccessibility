import AppKit
import ApplicationServices
import BBLBasics


open class AccessibilityHelper {
  
  public init() {}
  
  open func queryAxPerms(promptIfNeeded: Bool, postCheckHandler: @escaping (_ isPermissioned: Bool)->()) {
    
    lastOnlyQueue.async { [unowned self] in
      var options: [String:Any]? = nil
      
      if promptIfNeeded {
        let promptOptionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        options = [
          promptOptionKey: true
        ]
      }
      
      let isPermissioned = AXIsProcessTrustedWithOptions(options as CFDictionary?)
      if isPermissioned {
        self.lastOnlyQueue.pollStop()
      }
      postCheckHandler(isPermissioned)
    }
    
  }
  
  
  let lastOnlyQueue = LastOnlyQueue()
  

}





