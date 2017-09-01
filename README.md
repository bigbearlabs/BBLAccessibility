# BBLAccessibilityApp 

## Consolidated API for macOS Accessibility 

Fronts accessibility features from existing repos such as [Silica] and [NMTest001].

    - [x] Getting information on windows for all running apps -- using Silica.
    - [x] Getting information on the selected text -- using NMAccessibility.
    - [x] Managing Accessibility (`AXUIElement`) observations.

This is for an app I'm building that manages working contexts on OS X. I wouldn't be able to make such a tool without valuable source that was open to explore, so I thought I'd share my findings with everyone. 

In the queue is refinements moved over from currently private code in the following areas. Please get in touch if you need expedited access for these features.

    - [x] Getting full text content.
    - [ ] Repositioning a window to another screen or space


Your pull requests and suggestions are welcome.

[Silica]: https://github.com/ianyh/Silica
[NMTest001]: https://github.com/invariant/NMTest001/tree/master/NMTest001

<!-- 
# ---
# doit:
#     cmd: |
#         grep -o '\[.*\]' #{file} | uniq
# ---
-->
