import Foundation
import Silica
import BBLBasics
import BBLAccessibility


public class WindowCoordinator {
  
  public init() {}
  
  public func position(
    framesByWindowNumber: [UInt32 : CGRect],
    raise: Bool = false,
    activate windowNumberToFocus: UInt32? = nil,
    queue: DispatchQueue = coordinatorQueue
  ) {

    // TODO animations
    coordinatorQueue.async {

      for (windowNumber, frame) in framesByWindowNumber {
        
        if let window = SIWindow.for(windowNumber: windowNumber) {
          if frame == .zero {
            print("👺 window \(windowNumber) is given a zero frame; will not set.")
          }
          else if window.frame() != frame {
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
  }
  
  public func focus(windowNumber: UInt32) {
    if let w = SIWindow.for(windowNumber: windowNumber) {
      w.focusOnlyThisWindow()
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


public let coordinatorQueue = DispatchQueue.global(qos: .userInteractive)

