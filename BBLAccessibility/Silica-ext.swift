//
//  Silica-ext.swift
//  BBLAccessibility
//
//  Created by ilo on 27/06/2017.
//  Copyright © 2017 Big Bear Labs. All rights reserved.
//

import Foundation
import Silica


// NOTE window tabs:
// an SIWindow acquired prior has correct isVisible status even after being turned into an inactive tab!


public extension SIApplication {
  
  class func application(bundleId: String) -> SIApplication? {
    if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).last {
      return SIApplication(runningApplication: app)
    }
    else {
      return nil
    }
  }
  
  
  var mainWindow: SIWindow? {
    if let mainWindowElement = self.forKey(kAXMainWindowAttribute as CFString) {
      return SIWindow(axElement: mainWindowElement.axElementRef)
    }
    return nil
  }
  
  var uncachedWindows: [SIWindow] {
    self.dropWindowsCache()
    return self.windows
  }
  
}


public extension SIWindow {
  
  class func `for`(windowNumber: UInt32) -> SIWindow? {
    
    guard let app = NSRunningApplication.application(windowNumber: windowNumber) else { return nil }
    let siApp = SIApplication(forProcessIdentifier: app.processIdentifier)
    
    // NOTE -25204 was caused by sandbox settings applied to default app template since xcode 11.3  }
    let siWindow = siApp.uncachedWindows.first(where: {$0.windowID ==  windowNumber})
    if siWindow != nil {
      return siWindow
    }
    
    
    // fallback in cases where reading the windows ax attribute results in an error.
    // e.g.
    // 2023-01-28 11:50:59.043679+0900 Zen[43434:11034094] <SIApplication: 0x600003f195f0> <Title: Finder> pid: 1388, AXApplication/(null)  file:///System/Library/CoreServices/Finder.app/: AXError -25201 getting AXWindows
    
    guard let children = siApp.children() as? [AXUIElement]
    else { return nil }
    
    for child in children {
      if SIAccessibilityElement(axElement: child).role() == kAXWindowRole {
        let siWindow = SIWindow(axElement: child)
        if siWindow.windowID == windowNumber {
          return siWindow
        }
      }
    }
    
    return nil
  }
  
  
  var isMain: Bool {
    self.bool(forKey: kAXMainAttribute as CFString)
  }
  
}

extension SIWindow {
  open override var debugDescription: String {
    let minDesc = isWindowMinimized() ? " min'ed" : ""
    let visDesc = isVisible() ? "" : " notVisible"
    let tabsDesc = tabGroup.map {
      " \($0.tabs.count) tabs"
    } ?? ""
    return self.description
      + tabsDesc
      + minDesc
      + visDesc
    
  }
}

public extension SIAccessibilityElement {
  var roleDescription: String? {
    self.string(forKey: kAXRoleDescriptionAttribute as CFString)
  }
}


// MARK: - buttons

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


// MARK: - tab groups

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
  
  public var window: SIWindow {
    SIWindow.init(for: self)
  }
  
  public override var description: String {
    "tabGroup:\(self.axElementRef.hashValue)"
  }
  
  public struct Tab: Equatable, CustomStringConvertible {
    public let title: String
    public let isSelected: Bool
    
    public let pid: pid_t
    
    public init (title: String, isSelected: Bool, pid: pid_t) {
      self.title = title
      self.isSelected = isSelected
      self.pid = pid
    }
    
    public var description: String {
      "Tab(\(title))"
    }
  }
  
}


// MARK: -

extension NSRunningApplication {
  
  class func application(windowNumber: UInt32) -> NSRunningApplication? {
    if let dicts = (CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [NSDictionary]) {
      if let matching = dicts.first(where: { $0[kCGWindowNumber] as? NSNumber == NSNumber(value: windowNumber) }) {
        let pid = Int32(truncating: matching[kCGWindowOwnerPID] as! NSNumber)
        return NSRunningApplication(processIdentifier: pid)
      }
    }
    return nil
  }
  
}



// MARK: - window focusing hack

extension SIWindow {

  ///  messy indeed.
  ///  https://github.com/ianyh/Amethyst/blob/4d0e820beb25f4bdb89088326a470a9132d89ccb/Amethyst/Model/Window.swift#L16
  public func focusBetter() {
    let pid = self.processIdentifier()
    var wid = self.windowID
    var psn = ProcessSerialNumber()
    let status = GetProcessForPID(pid, &psn)

    guard status == noErr else {
        return
    }

    var cgStatus = _SLPSSetFrontProcessWithOptions(&psn, wid, SLPSMode.userGenerated.rawValue)

    guard cgStatus == .success else {
        return
    }

    for byte in [0x01, 0x02] {
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xF8
        bytes[0x08] = UInt8(byte)
        bytes[0x3a] = 0x10
        memcpy(&bytes[0x3c], &wid, MemoryLayout<UInt32>.size)
        memset(&bytes[0x20], 0xFF, 0x10)
        cgStatus = bytes.withUnsafeMutableBufferPointer { pointer in
            return SLPSPostEventRecordTo(&psn, &pointer.baseAddress!.pointee)
        }
        guard cgStatus == .success else {
            return
        }
    }

//    guard super.focus() else {
//        return false
//    }
    self.focusOnlyThisWindow()
    
    guard UserConfiguration.shared.mouseFollowsFocus() else {
        return
    }
    
    let windowFrame = self.frame()
    let mouseCursorPoint = NSPoint(x: windowFrame.midX, y: windowFrame.midY)
    guard let mouseMoveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: mouseCursorPoint, mouseButton: .left) else {
      return
    }
    mouseMoveEvent.flags = CGEventFlags(rawValue: 0)
    mouseMoveEvent.post(tap: CGEventTapLocation.cghidEventTap)
  }
}

//// focuses the front process
//// * macOS 10.12+
@_silgen_name("_SLPSSetFrontProcessWithOptions") @discardableResult
func _SLPSSetFrontProcessWithOptions(_ psn: inout ProcessSerialNumber, _ wid: CGWindowID, _ mode: SLPSMode.RawValue) -> CGError

enum SLPSMode: UInt32 {
    case allWindows = 0x100
    case userGenerated = 0x200
    case noWindows = 0x400
}

// returns the psn for a given pid
// * macOS 10.9-10.15 (officially removed in 10.9, but available as a private API still)
@_silgen_name("GetProcessForPID") @discardableResult
func GetProcessForPID(_ pid: pid_t, _ psn: inout ProcessSerialNumber) -> OSStatus

@_silgen_name("SLPSPostEventRecordTo") @discardableResult
func SLPSPostEventRecordTo(_ psn: inout ProcessSerialNumber, _ bytes: inout UInt8) -> CGError


// MARK: -

struct UserConfiguration {
  static let shared = UserConfiguration()
  
  func mouseFollowsFocus() -> Bool {
    false
  }
}
