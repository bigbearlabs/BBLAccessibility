//
//  TabInferenceTests.swift
//  TabInferenceTests
//
//  Created by ilo on 11/07/2021.
//  Copyright © 2021 Big Bear Labs. All rights reserved.
//

import XCTest
@testable import TabInference
import BBLAccessibility



class TabInferenceTests: XCTestCase {

  let inferrer = Inferrer()

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_inferForUnambiguousTitles() throws {
      let infosAfterNewTab = [
        CGWindowInfo(pid: 1, windowNumber: "1", title: "a", isInActiveSpace: false, frame: frameA),
        CGWindowInfo(pid: 1, windowNumber: "2", title: "b", isInActiveSpace: true, frame: frameB),
      ]
      
      let tabsAfterNewTab = [
        SITabGroup.Tab(title: "a", isSelected: false, pid: 1),
        SITabGroup.Tab(title: "b", isSelected: true, pid: 1),
      ]
      
      XCTAssertEqual(
        inferrer.inferForUnambiguousTitles(
          tabs: tabsAfterNewTab,
          cgInfos: infosAfterNewTab
        ),
        .conclusive(matches: zip(infosAfterNewTab, tabsAfterNewTab).map {
          Match(tab: $0.1, cgInfo: $0.0)
        })
      )
      
      let infosWithUnmatchingTitles = [
        CGWindowInfo(pid: 1, windowNumber: "1", title: "a", isInActiveSpace: false, frame: frameA),
        CGWindowInfo(pid: 1, windowNumber: "2", title: "c", isInActiveSpace: true, frame: frameB),
      ]

      XCTAssertEqual(
        inferrer.inferForUnambiguousTitles(tabs: tabsAfterNewTab, cgInfos: infosWithUnmatchingTitles),
        .none
      )


      let tabsWithAmbiguousTitles = [
        SITabGroup.Tab(title: "a", isSelected: false, pid: 1),
        SITabGroup.Tab(title: "a", isSelected: true, pid: 1),
      ]
      let infosWithAmbiguousTitles = [
        CGWindowInfo(pid: 1, windowNumber: "1", title: "a", isInActiveSpace: false, frame: frameA),
        CGWindowInfo(pid: 1, windowNumber: "2", title: "a", isInActiveSpace: true, frame: frameB),
      ]

      XCTAssertEqual(
        inferrer.inferForUnambiguousTitles(tabs: tabsWithAmbiguousTitles, cgInfos: infosWithAmbiguousTitles),
        .none
      )

      let infosWithAdditionalAmbiguousTitles = [
        CGWindowInfo(pid: 1, windowNumber: "1", title: "a", isInActiveSpace: false, frame: frameA),
        CGWindowInfo(pid: 1, windowNumber: "2", title: "b", isInActiveSpace: true, frame: frameB),
        CGWindowInfo(pid: 1, windowNumber: "3", title: "a", isInActiveSpace: false, frame: frameB),
      ]

      XCTAssertEqual(
        inferrer.inferForUnambiguousTitles(tabs: tabsAfterNewTab, cgInfos: infosWithAdditionalAmbiguousTitles),
        .none
      )

    }

  func testXX() {
    let tabsWithAmbiguousTitles = [
      SITabGroup.Tab(title: "a", isSelected: false, pid: 1),
      SITabGroup.Tab(title: "a", isSelected: true, pid: 1),
    ]
    let infosWithAmbiguousTitles = [
      CGWindowInfo(pid: 1, windowNumber: "1", title: "a", isInActiveSpace: false, frame: frameA),
      CGWindowInfo(pid: 1, windowNumber: "2", title: "a", isInActiveSpace: true, frame: frameA),
    ]

    XCTAssertEqual(
      inferrer.inferForTabProperties(tabs: tabsWithAmbiguousTitles, cgInfos: infosWithAmbiguousTitles),
      .conclusive(matches: tabsWithAmbiguousTitles.enumerated().map { i, tab in
        Match(tab: tab, cgInfo: infosWithAmbiguousTitles[i])
      })
    )

    let infosWithAdditionalAmbiguous = [
      CGWindowInfo(pid: 1, windowNumber: "1", title: "a", isInActiveSpace: false, frame: frameA),
      CGWindowInfo(pid: 1, windowNumber: "2", title: "a", isInActiveSpace: true, frame: frameA),
      CGWindowInfo(pid: 1, windowNumber: "3", title: "a", isInActiveSpace: false, frame: frameA),
    ]

    XCTAssertEqual(
      inferrer.inferForTabProperties(tabs: tabsWithAmbiguousTitles, cgInfos: infosWithAdditionalAmbiguous),
      .none
    )


  }
  
  func testX() {
    let baselineInfos = [
      CGWindowInfo(pid: 1, windowNumber: "1", title: "a", isInActiveSpace: true, frame: frameA),
    ]
    
    // HOW in calling context, how to bookkeep this history of infos?

  }
}

struct Inferrer {
  func inferForUnambiguousTitles(tabs: [SITabGroup.Tab], cgInfos: [CGWindowInfo]) -> InferTabResult {
    assert(tabs.map { $0.pid }.uniqueValues == [tabs[0].pid])
    let pid = tabs[0].pid
    let infosForPid = cgInfos.filter { $0.pid == pid }

    func titleSpaceContainsNoDuplicates(_ titles: [String]) -> Bool {
      Set(titles).count == titles.count
    }
    
    if titleSpaceContainsNoDuplicates(tabs.map { $0.title }) {
      let sortedTabs = tabs.sorted { $0.title < $1.title }
      let sortedInfos = infosForPid.sorted { $0.title < $1.title }
      if sortedTabs.map({ $0.title }) == sortedInfos.map({ $0.title }) {
        return .conclusive(
          matches: zip(sortedTabs, sortedInfos).map {
            Match(tab: $0.0, cgInfo: $0.1)
          }
        )
      }
    }
    return .none
  }
  
  func inferForTabProperties(tabs: [SITabGroup.Tab], cgInfos: [CGWindowInfo]) -> InferTabResult {
    let focusedTabs = tabs.filter { $0.isSelected }
    assert(focusedTabs.count == 1)
    
    // same count
    if tabs.count == cgInfos.count {
      // all frames are the same
      if cgInfos.map { $0.frame }.uniqueValues.count == 1 {
        
        let sortedTabs = tabs.sorted { $0.title < $1.title }
        let sortedInfos = cgInfos.sorted { $0.title < $1.title }
        
        let nonmatches = zip(sortedTabs, sortedInfos).filter {
          let (tab, info) = $0
          return tab.title != info.title
            || tab.isSelected !=  info.isInActiveSpace
        }
        
        if nonmatches.isEmpty {
          return .conclusive(matches: zip(sortedTabs, sortedInfos).map {
            Match(tab: $0.0, cgInfo: $0.1)
          })
        }
      }
    }
    
    return .none
  }

}


let frameA = CGRect(x: 0, y: 0, width: 100, height: 100)
let frameB = CGRect(x: 10, y: 10, width: 100, height: 100)

enum InferTabResult: Equatable {
  
  // - for n tabs,
  // - there exist exactly n cg infos unambiguously matching (app, title): no duplicate titles in 'title space'
  // - or: exactly n cg infos unambiguously matching (app, title, frame)
  // - or: currently 2 tabs, 1 cg info previously visible, matching (title, frame)
  case conclusive(matches: [Match])
  
  case partial(matches: [Match])
  
  case none
  
}

struct Match: Equatable {
  let tab: SITabGroup.Tab
  let cgInfo: CGWindowInfo
}
