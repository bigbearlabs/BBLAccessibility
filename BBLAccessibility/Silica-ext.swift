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
    if let childrenAxRefs = self.array(forKey: "AXChildrenInNavigationOrder" as CFString) as? [AXUIElement] {
      let siElements = childrenAxRefs.map {
        SIAccessibilityElement(axElement: $0)
      }
      return siElements
    }
    return []
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
  
  public var tabs: [Tab] {
    guard let children = self.children() as? [AXUIElement] else {
      fatalError()
    }
    
    let tabElements = children
      .map { axElem in
        return SIAccessibilityElement(axElement: axElem)
      }
      .filter {
        $0.roleDescription == "tab"
      }
    
    return tabElements.map {
      Tab(
        title: $0.title() ?? "<<tab>>",
        isSelected: $0.bool(forKey: kAXValueAttribute as CFString),
        pid: $0.processIdentifier()
      )
    }
  }
  
  public struct Tab: Equatable {
    public let title: String
    public let isSelected: Bool
    
    public let pid: pid_t
    
    public init (title: String, isSelected: Bool, pid: pid_t) {
      self.title = title
      self.isSelected = isSelected
      self.pid = pid
    }
  }
}


public extension SIAccessibilityElement {
  var roleDescription: String? {
    self.string(forKey: kAXRoleDescriptionAttribute as CFString)
  }
}
