import Foundation
import Silica
import BBLBasics
import BBLAccessibility


public class WindowCoordinator {
  
  public init() {}
  
  
  public func position(
    windowFramePairs: [UInt32 : CGRect],
    raise: Bool = false,
    focus windowNumberToFocus: UInt32? = nil) {
    for (windowNumber, frame) in windowFramePairs {
      
      if let window = SIWindow.for(windowNumber: windowNumber) {
        
        if window.frame() != frame {
          window.setFrame(frame)
        }
        
        if raise {
          if windowNumberToFocus != nil
            && windowNumber == windowNumberToFocus {
            // don't raise since we will focus later
          } else {
            self.raise(windowNumber: windowNumber)
          }
        }
      }
    }
    
    if let n = windowNumberToFocus {
      
      self.focus(windowNumber: n)
    }

  }
  
  public func focus(windowNumber: UInt32) {
    raise(windowNumber: windowNumber)
    
    if let w = SIWindow.for(windowNumber: windowNumber) {
      if SIWindow.focused()?.windowID != w.windowID {
        w.focusOnlyThisWindow()
      }
    }
  }

  public func raise(windowNumber: UInt32) {
    if let w = SIWindow.for(windowNumber: windowNumber) {
      w.raise()
    }
  }
  
  // MARK: -
  
  public func frame(windowNumber: UInt32) -> CGRect? {
    return SIWindow.for(windowNumber: windowNumber)?.frame()
  }
  
}


extension NSRunningApplication {
  
  class func application(windowNumber: UInt32) -> NSRunningApplication? {
    if let dict = (CGWindowListCopyWindowInfo([.optionIncludingWindow], windowNumber) as? [[CFString : Any?]])?.first {
      let pid = Int32(truncating: (dict as NSDictionary)[kCGWindowOwnerPID] as! NSNumber)
      return NSRunningApplication(processIdentifier: pid)
    }
    return nil
  }
  
}


extension SIWindow {
  
  class func `for`(windowNumber: UInt32) -> SIWindow? {
    if let app = NSRunningApplication.application(windowNumber: windowNumber),
      
      // NOTE -25204 was caused by sandbox settings applied to default app template since xcode 11.3  }
      let siWindow = SIApplication(forProcessIdentifier: app.processIdentifier).windows.first(where: {$0.windowID ==  windowNumber}) {
      
      return siWindow
    }
    
    return nil
  }
  
}


