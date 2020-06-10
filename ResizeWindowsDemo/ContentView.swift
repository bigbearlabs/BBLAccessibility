//
//  ContentView.swift
//  ResizeWindowsDemo
//
//  Created by ilo on 10/06/2020.
//  Copyright © 2020 Big Bear Labs. All rights reserved.
//

import SwiftUI
import Silica
import BBLBasics
import BBLAccessibility


struct ContentView: View {
  
  @State var targetWindowIdString = ""
  
    var body: some View {
      VStack {
        Text("Hello, World!")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        TextField(/*@START_MENU_TOKEN@*/"Placeholder"/*@END_MENU_TOKEN@*/, text: $targetWindowIdString, onCommit: {}
        )
        Button(action: {
          if let windowNumber = UInt32(self.targetWindowIdString) {
            api_resize(windowNumber: windowNumber)
          }
        }) {
          Text(/*@START_MENU_TOKEN@*/"Button"/*@END_MENU_TOKEN@*/)
        }
      }
    }
  
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


func api_resize(windowNumber: UInt32) {
  
  print("AXIsProcessTrusted: #\(AXIsProcessTrusted())")

  AccessibilityHelper().showSystemAxRequestDialog()
  
  if let app = NSRunningApplication.application(windowNumber: windowNumber),
    
    let siWindow = SIApplication(forProcessIdentifier: app.processIdentifier).windows.first(where: {$0.windowID == windowNumber}),
  // NOTE -25204 was caused by sandbox settings applied to default app template since xcode 11.3
  
    let centredFrame = siWindow.centredFrame {
    siWindow.setFrame(centredFrame)
  }
}



extension NSRunningApplication {
  
  class func application(windowNumber: UInt32) -> NSRunningApplication? {
    if let dict = (CGWindowListCopyWindowInfo([.optionIncludingWindow], windowNumber) as? [[CFString : Any?]])?.first {
      let pid = Int32((dict as NSDictionary)[kCGWindowOwnerPID] as! NSNumber)
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
  
}


