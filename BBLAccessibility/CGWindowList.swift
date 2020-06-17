import AppKit
import BBLBasics

public typealias WindowNumber = String // TODO make into Int.

public typealias WindowServerSessionId = String


public protocol WindowFingerprintable {
  var title: String { get }
  var frame: CGRect  { get }
  var bundleId: String { get }
  var fingerprint: String { get }
}

extension WindowFingerprintable {
  public var fingerprint: String {
    return self.bundleId
      + "__"
      + self.title
      + "__" + (self.frame.dictionaryRepresentation as NSDictionary).description
  }
}


public struct WindowId: Codable, Hashable {

  public let windowServerSessionId: WindowServerSessionId
  public let windowNumber: WindowNumber
  
  public init(windowServerSessionId: WindowServerSessionId, windowNumber: WindowNumber) {
    self.windowServerSessionId = windowServerSessionId
    self.windowNumber = windowNumber
  }
  
  
  static public func from(string: String) -> WindowId {
    let cs = string.components(separatedBy: "__")
    let windowNumberStr = cs.last!
    return WindowId.from(windowNumber: windowNumberStr)
  }
  
  // TODO consider performing once per process / windowserver session / whatever is appropriate.
  static public func from(windowNumber: WindowNumber) -> WindowId {
    var securitySessionId: SecuritySessionId = 0
    SessionGetInfo(callerSecuritySession, &securitySessionId, nil)
    
//    guard let loginWindowApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.loginwindow").first,
//      let loginWindowLaunchDate = loginWindowApp.launchDate
//      else { fatalError() }
//
//    let sessionId = "\(securitySessionId)__\(loginWindowLaunchDate)"
    
    // TODO security session id is not unique per login window.
    // CGSessionCopyCurrentDictionary / CGSSessionCopyAllSessionProperties don't help either; same info.
    // obtain the login window launch timestamp and append.
    // potentially use https://github.com/objective-see/ProcInfo.git

    let sessionId = String(securitySessionId)
    
    return WindowId(windowServerSessionId: sessionId, windowNumber: windowNumber)
  }

}

extension WindowId: CustomStringConvertible {
  public var description: String {
    return "\(windowServerSessionId)__\(windowNumber)"
  }
}

public struct CGWindowInfo: Codable, Equatable {
  
  public let pid: pid_t
  public let bundleId: String
  
  public let windowId: WindowId
  public let title: String

  public let isInActiveSpace: Bool
  
  public let windowLayer: Int?

  public let frame: CGRect
  
  let data: DebugPropertyWrapper<[String : Any?]>?
  

  init?(data: [String : Any?], debug: Bool = false) {
    guard
      let pid = (data[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
      let bundleId = data["bundleId"] as? String
        ?? NSWorkspace.shared.runningApplication(pid: pid)?.bundleIdentifier,
      let cgWindowId = data[kCGWindowNumber as String] as? NSNumber
    else {
      return nil
    }

    self.data = debug ? DebugPropertyWrapper(data: data) : nil
    
    self.pid = pid
    self.bundleId = bundleId
    self.windowId = WindowId.from(windowNumber: String(describing: cgWindowId))
    if let title = data[kCGWindowName as String] as? NSString {
      self.title = String(title)
    } else {
      self.title = ""
    }

    let boundsDict = data[kCGWindowBounds as String] as! CFDictionary
    self.frame = CGRect(dictionaryRepresentation: boundsDict)!

    self.isInActiveSpace = data[kCGWindowIsOnscreen as String] as? Bool ?? false

    self.windowLayer = data[kCGWindowLayer as String] as? Int
  }
  
  // MARK: -
  
  // RENAME screenshot -> snapshotImage
  public func screenshot() -> NSImage? {
    if let windowNumber = CGWindowID(self.windowId.windowNumber),
      let image = cgImage(windowNumber: windowNumber) {
      
      return NSImage(cgImage: image, size: .zero)
    }
    
    return nil
  }
  
  // MARK: -
  
  public static func query(
    windowId: WindowId? = nil,
    bundleId: String? = nil,
    scope: QueryScope = .allScreens)
    -> [CGWindowInfo] {
      
    if scope == .onScreen {
      // ensure arguments conform to API spec.
      guard windowId == nil else {
        fatalError()
      }
    }
      
    let cgWindowId = windowId == nil ?
      kCGNullWindowID
      : CGWindowID(windowId!.windowNumber)!
      
    guard let cgWindowInfos = CGWindowListCopyWindowInfo(
      [scope == .allScreens ?
        .optionAll
        : .optionOnScreenOnly],
      cgWindowId)
      else {
        // !?
        return []
      }
      
    guard let windowInfos = cgWindowInfos as? [[String : Any?]]
      else {
        // ?
        return []
      }
      
    let pids = bundleId.flatMap {
      NSRunningApplication.runningApplications(withBundleIdentifier: $0).map { $0.processIdentifier }
    }
      
    let results: [CGWindowInfo] = windowInfos.compactMap { e in
        // apply bid filter early.
        if let pids = pids,
          let pid = e[kCGWindowOwnerPID as String] as? pid_t {
          if !pids.contains(pid) {
            return nil
          }
        }
        
        var e = e
        if let bundleId = bundleId {
          e["bundleId"] = bundleId
        }
        
        return CGWindowInfo(data: e, debug: false) // DEBUG
      }
      
    return results
  }
  
  
  static private func queryScopeOption(_ scope: QueryScope) -> CGWindowListOption {
    switch scope {
    case .onScreen:
      return CGWindowListOption.optionOnScreenOnly
    default:
      return CGWindowListOption.optionAll
    }
  }
  
  
  public enum QueryScope {
    case onScreen
    case allScreens
  }
  
}


extension CGWindowInfo: WindowFingerprintable {
}


extension CGWindowInfo: CustomStringConvertible {
  public var description: String {
    return "\(( bundleId, windowId, isInActiveSpace ))"
  }
}


// MARK: -

struct DebugPropertyWrapper<T>: Codable, Equatable {

  let data: T?

  init(data: T?) {
    self.data = data
  }

  
  // MARK: - no-op conformance
  
  init(from decoder: Decoder) throws {
    self.init(data: nil)
  }
  
  func encode(to encoder: Encoder) throws {
  }
  
  static func == (lhs: DebugPropertyWrapper<T>, rhs: DebugPropertyWrapper<T>) -> Bool {
    return true
  }
  
}
