import AppKit
import BBLBasics



private var debug = false
//debug = false  // DEBUG


public typealias WindowNumberString = String // TODO make into Int.

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
  public let windowNumber: WindowNumberString
  
  public init(windowServerSessionId: WindowServerSessionId, windowNumber: WindowNumberString) {
    self.windowServerSessionId = windowServerSessionId
    self.windowNumber = windowNumber
  }
  
  
  static public func from(string: String) -> WindowId {
    let cs = string.components(separatedBy: "__")
    let windowNumberStr = cs.last!
    return WindowId.from(windowNumber: windowNumberStr)
  }
  
  // TODO consider performing once per process / windowserver session / whatever is appropriate.
  static public func from(windowNumber: WindowNumberString) -> WindowId {
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
  public let windowId: WindowId
  public let title: String

  public let isVisible: Bool
  
  public let windowLayer: Int?

  public let frame: CGRect
  
  let rawData: DebugPropertyWrapper<[CFString : Any?]>?
  

  init?(data: [CFString : Any?], debug: Bool = false) {
    guard
      let pid = data[kCGWindowOwnerPID] as? pid_t,
      let cgWindowId = data[kCGWindowNumber] as? NSNumber
    else {
      return nil
    }

    self.rawData = debug ? DebugPropertyWrapper(data: data) : nil
    
    self.pid = pid
    self.windowId = WindowId.from(windowNumber: String(describing: cgWindowId))
    if let title = data[kCGWindowName] as? NSString {
      self.title = String(title)
    } else {
      self.title = ""
    }

    let boundsDict = data[kCGWindowBounds] as! CFDictionary
    self.frame = CGRect(dictionaryRepresentation: boundsDict)!

    self.isVisible = data[kCGWindowIsOnscreen] as? Bool ?? false

    self.windowLayer = data[kCGWindowLayer] as? Int
  }
  
  
  public init(pid: pid_t, windowNumber: WindowNumberString, title: String, isVisible: Bool,
              frame: CGRect,
              windowLayer: Int? = nil
  ) {
    self.pid = pid
    self.windowId = WindowId.from(windowNumber: windowNumber)
    self.title = title
    self.isVisible = isVisible
    self.windowLayer = windowLayer
    self.frame = frame
    self.rawData = nil
  }
  
  
  // MARK: -
  
  public var bundleId: String {
    return
//      data["bundleId"] as? String
//      ??
        NSWorkspace.shared.runningApplication(pid: pid)?.bundleIdentifier
          ?? "<nil bid>"
  }

  // RENAME screenshot -> snapshotImage
  public func screenshot() -> NSImage? {
    if let windowNumber = CGWindowID(self.windowId.windowNumber),
      let image = cgImage(windowNumber: windowNumber) {
      
      return NSImage(cgImage: image, size: .zero)
    }
    
    return nil
  }
  
  // MARK: -
  
  public static func query(windowNumber: UInt32) -> CGWindowInfo? {
    self.query().first { $0.windowId.windowNumber == String(windowNumber) }
  }
  
  public static func query(
    bundleId: String? = nil,
    scope: QueryScope = .allScreens,
    otherOptions: CGWindowListOption = [])
    -> [CGWindowInfo] {
      
    var options = otherOptions
    options.formUnion([
      scope == .allScreens ? .optionAll : .optionOnScreenOnly,
    ])
      
    guard let cgWindowInfos = CGWindowListCopyWindowInfo(options, kCGNullWindowID) else {
      // !?
      return []
    }
      
    guard let windowInfos = cgWindowInfos as? [[CFString : Any?]] else {
      // ?
      return []
    }
          
    let pidsForBundleId = bundleId.flatMap {
      NSRunningApplication.runningApplications(withBundleIdentifier: $0)
        .map { $0.processIdentifier }
    }
      
    let results: [CGWindowInfo] = windowInfos.compactMap { e in
      // reject transparent windows.
      if e[kCGWindowAlpha] as? CGFloat == 0.0 {
        return nil
      }
      
      // apply bid filter early.
      if let pids = pidsForBundleId,
        let pid = e[kCGWindowOwnerPID] as? pid_t {
        if !pids.contains(pid) {
          return nil
        }
      }
      
      var e = e
      if let bundleId = bundleId {
        e["bundleId" as CFString] = bundleId
      }
      
      return CGWindowInfo(
        data: e,
        debug: debug
      )
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
    return "\(windowId)(\(pid),\(isVisible ? "visible" : ""))"
  }
}

extension CGWindowInfo: CustomDebugStringConvertible {
  public var debugDescription: String {
    let bundleId = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "<no bundle id>"
    return "\(windowId) '\(title)' (\(pid),\(bundleId),\(isVisible ? "visible" : ""),\(frame),l:\(windowLayer != nil ? String(describing: windowLayer!) : "?" )"
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

