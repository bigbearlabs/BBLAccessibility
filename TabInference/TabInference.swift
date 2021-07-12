import BBLAccessibility



enum InferTabResult {
  
  // - for n tabs,
  // - there exist exactly n cg infos unambiguously matching (app, title): no duplicate titles in 'title space'
  // - or: exactly n cg infos unambiguously matching (app, title, frame)
  // - or: currently 2 tabs, 1 cg info previously visible, matching (title, frame)
  case conclusive(matches: [Match])
  
  case partial(matches: [Match])
  
  struct Match {
    let tabs: [SITabGroup.Tab]
    let cgInfos: [CGWindowInfo]
  }
}

func inferTabs(tabs: [SITabGroup.Tab]) -> InferTabResult {
  fatalError()
}
//  
//if let tabs = tabs {
//  inferTabs(tabs: tabs)
//}


