//
//  Silica-ext.swift
//  BBLAccessibility
//
//  Created by ilo on 27/06/2017.
//  Copyright © 2017 Big Bear Labs. All rights reserved.
//

import Foundation
import Silica



public extension SIApplication {
  
  class func application(bundleId: String) -> SIApplication? {
    if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).last {
      return SIApplication(runningApplication: app)
    }
    else {
      return nil
    }
  }
  
  var uncachedWindows: [SIWindow] {
    self.dropWindowsCache()
    return self.windows
  }
  
}



public extension SIWindow {
  
  var closeButton: SIAccessibilityElement? {
    return self.forKey(kAXCloseButtonAttribute as CFString)
  }
  
  var minimiseButton: SIAccessibilityElement? {
    return self.forKey(kAXMinimizeButtonSubrole as CFString)
  }
  
  var zoomButton: SIAccessibilityElement? {
    return self.forKey(kAXZoomButtonAttribute as CFString)
  }
  
  
  var childrenInNavigationOrder: [SIAccessibilityElement] {
    let childrenAxRefs = self.array(forKey: "AXChildrenInNavigationOrder" as CFString) as! [AXUIElement]
    let siElements = childrenAxRefs.map {
      SIAccessibilityElement(axElement: $0)
    }
    return siElements
  }
  
  var tabGroup: SITabGroup? {
    let navChildren = self.childrenInNavigationOrder
    if let tabGroupElem = navChildren.first(where: {
      $0.role() == kAXTabGroupRole
    }) {
      return SITabGroup(axElement: tabGroupElem.axElementRef)
    }
    return nil
  }
}

public class SITabGroup: SIAccessibilityElement {
  
//  init(siElement: SIAccessibilityElement) {
//    super.init(axElement: siElement.axElementRef)
//  }
  
  public var tabs: [Tab] {
    let tabElements = self.children()
      .map { axElem -> SIAccessibilityElement in
        let axElem = axElem as! AXUIElement
        return SIAccessibilityElement(axElement: axElem)
      }
      .filter {
        $0.roleDescription == "tab"
      }
    
    return tabElements.map {
      Tab(title: $0.title() ?? "unknown tab title")
    }
  }
  
  public struct Tab: Equatable {
    public let title: String
  }
}


public extension SIAccessibilityElement {
  var roleDescription: String? {
    self.string(forKey: kAXRoleDescriptionAttribute as CFString)
  }
}
