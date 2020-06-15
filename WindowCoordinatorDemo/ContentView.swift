//
//  ContentView.swift
//  ResizeWindowsDemo
//
//  Created by ilo on 10/06/2020.
//  Copyright © 2020 Big Bear Labs. All rights reserved.
//

import SwiftUI
import WindowCoordinator



struct ContentView: View {
  
  let windowCoordinator = WindowCoordinator()
  
  @State var targetWindowIdString = ""
  
    var body: some View {
      VStack {
    
        TextField("target window id", text: $targetWindowIdString, onCommit: {}
        )
        Button("positionAsMainLayoutElement") {
          if let windowNumber = UInt32(self.targetWindowIdString) {
            self.windowCoordinator.positionAsMainLayoutElement(windowNumber: windowNumber)
          }
        }
      }
    }
  
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
