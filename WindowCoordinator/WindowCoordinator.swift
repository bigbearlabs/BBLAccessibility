import Foundation
import Silica
import BBLBasics
import BBLAccessibility
import OrderedCollections


public class WindowCoordinator {
  
  public init() {}
  
  public func position(
    framesByWindowNumber: OrderedDictionary<UInt32, CGRect>,
    raise: Bool = false,
    activate windowNumberToFocus: UInt32? = nil,
    queue: DispatchQueue = coordinatorQueue
  ) {
    
    coordinatorQueue.async {
      
      for (windowNumber, frame) in framesByWindowNumber.reversed() {
        
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
    
    // investigating cases where call to this method didn't seem to position correctly
#if DEBUG
    coordinatorQueue.asyncAfter(deadline: .now() + 1) {
      let widTargetCurrentTuple = framesByWindowNumber.compactMap { wid, targetFrame in
        SIWindow.for(windowNumber: wid).flatMap { window in
          let actualFrame = window.frame()
          return (wid, targetFrame, actualFrame)
        }
      }
      
      let targetActualDiscrepencies = widTargetCurrentTuple.filter { wid, targetFrame, actualFrame in
        targetFrame != actualFrame
      }
      
      if targetActualDiscrepencies.count > 0 {
        
      }
    }
#endif
  }

  public func focus(windowNumber: UInt32) {
    guard let window = SIWindow.for(windowNumber: windowNumber)
    else { return }
    
    window.focusBetter()
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
