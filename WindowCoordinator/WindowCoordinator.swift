import Foundation
import Silica
import BBLBasics
import BBLAccessibility


public class WindowCoordinator {
  
  public init() {}
  
  
  public func positionAsMainLayoutElement(windowNumber: UInt32) {
    
    print("AXIsProcessTrusted: #\(AXIsProcessTrusted())")

    // perm
    AccessibilityHelper().showSystemAxRequestDialog()
    
    
    if let siWindow = SIWindow.for(windowNumber: windowNumber),
      let centredFrame = siWindow.centredFrame {
      
        // centre.
        siWindow.setFrame(centredFrame)

        // activate.
        siWindow.focusOnlyThisWindow()
        
      // TODO add resizing.
    }
  }
  
  public func position(windowFramePairs: [UInt32 : CGRect], focus windowNumberToFocus: UInt32? = nil) {
    for (windowNumber, frame) in windowFramePairs {
      
      if let window = SIWindow.for(windowNumber: windowNumber) {
        
        window.setFrame(frame)
      }
    }
    
    if let n = windowNumberToFocus,
      let w = SIWindow.for(windowNumber: n) {
      // activate.
      w.focusOnlyThisWindow()
    }

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
  
  var centredFrame: CGRect? {
    if let screen = self.screen() {
      
      let frame = self.frame()
      let screenCentre = screen.frame.centre
      let newFrame = frame.offsetBy(dx: screenCentre.x - frame.centre.x, dy: screenCentre.y - frame.centre.y)
      
      return newFrame
    }
    return nil
  }
  
  class func `for`(windowNumber: UInt32) -> SIWindow? {
    if let app = NSRunningApplication.application(windowNumber: windowNumber),
      
      // NOTE -25204 was caused by sandbox settings applied to default app template since xcode 11.3  }
      let siWindow = SIApplication(forProcessIdentifier: app.processIdentifier).windows.first(where: {$0.windowID ==  windowNumber}) {
      
      return siWindow
    }
    
    return nil
  }
  
}


