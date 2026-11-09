# Developer tools

Vox has Chrome-style Elements and Console panels docked below the
document. They are declared in V/UI2 like the rest of the browser chrome and
work on the document of the tab that opens them.

| Action | macOS | Linux |
| --- | --- | --- |
| Toggle the panel | Cmd+Option+I, F12, Browser > Developer Tools | Ctrl+Shift+I, F12 |
| Pick an element in the page | Cmd+Shift+C or Cmd+Option+C, the toolbar arrow | Ctrl+Shift+C |
| Inspect the element under the pointer | Right-click > Inspect | Right-click > Inspect |
| Open the console | Cmd+Option+J, Browser > JavaScript Console | Ctrl+Shift+J |
| Open with every tab | `--auto-open-devtools-for-tabs` | `--auto-open-devtools-for-tabs` |

## Elements panel

- The tree starts with `<html>` and `<body>` expanded and `<body>` selected.
  Collapsed elements show `…`; a short single text child stays on its
  element's row. Whitespace-only text is hidden and shadow roots appear as
  `#shadow-root (open)` rows.
- Hovering a row, or a page element while picking, draws the engine's
  box-model overlay (`Document::set_highlighted_node`).
- Arrow keys, Home and End move through the tree after a row is clicked.
  Left and Right collapse and expand, Delete or Backspace removes the node and
  Enter or F2 opens the inline editor. Double-clicking a row does the same.
- The inline editor edits an element as HTML (its `outerHTML`) or the text of
  a text or comment node. Cmd+Enter (Ctrl+Enter) applies and Esc cancels.
  Rejected markup keeps the editor open and shows the error in the toolbar.
- The sidebar has three tabs. **Styles** lists `element.style` and the
  matching rules, highest cascade precedence first, with their sources;
  declarations that lose the cascade are struck through. Inline and author
  declarations are edited in place (Return applies, an empty value removes
  one) and new inline properties can be added; user agent rules are
  read-only. **Computed** shows the box model and every resolved longhand,
  with a filter. **Attributes** edits, removes and adds attributes.
- Cmd+Z and Cmd+Shift+Z (Ctrl elsewhere) undo and redo panel edits while the
  tree has focus, including deletions, edit-as-HTML and style changes.
- Cmd+F (Ctrl+F) while the tree has focus searches it by text or CSS
  selector. Matches are shaded; Enter and Shift+Enter step through them.
- Row context menus also copy a node and expand or collapse subtrees. The
  breadcrumb bar selects ancestors.
- The top edge resizes the panel; the document viewport shrinks to fit it.
  Script mutations refresh the tree while the panel is open.

## Console panel

- Lists what the page logged through `console.*` and its script errors, then
  each input (`›`) and its result (`‹`), formatted as Chrome prints them:
  quoted strings, summarized arrays and objects, and nodes by tag.
- Input runs in the page as global code, so `var` and function declarations
  persist. Its DOM changes and logs replay through the compact script bridge
  as an asynchronous page task does. A script-enabled page without scripts
  gets its runtime on first use; pages with JavaScript disabled report it.
- Up and Down recall earlier input; Cmd+K (Ctrl+K) or the toolbar button
  clears the console. Navigation starts a new console.

## Structure

`devtools/` holds the model, DOM edits and UI2 declarations. Rows refer to
nodes by unique ID and are rebuilt from the live document, so a navigation
never leaves the panel holding another document's nodes.
`devtools/cssinspect` reads matched rules and resolved values from the CSS
engine and edits author rules through the CSSOM, keeping the CSS module out
of the `devtools` package. Resolved values are read only while layout is
current. `browserapp/devtools.v` connects the panel to the tab: viewport height,
picker and hover input, highlights, keys, actions and relayout after edits.

## Tests

```sh
ui2_modules=$(python3 tools/prepare_ui2.py --lease-pid "$$")
v -enable-globals -memory-limit 10G -cc clang \
  -path "$ui2_modules|.|@vmodules|@vlib" test devtools
VOX_CHROME_TEST_FILE=browserapp/devtools_test.v sh tools/test_address_bar.sh \
  -memory-limit 10G -skip-running -o Build/devtools-main-test
```

Run both through `tools/run_memory_bounded.py` as described in
[the UI2 adapter guide](../tools/ui2/README.md). The custom-renderer path
shares these declarations but has not been exercised in a Linux window.

## Not yet implemented

Network and sources panels, expandable console objects, adding declarations to author
rules, inherited styles, inline attribute editing in the tree, `<template>`
contents and iframe documents. The Styles tab shows the CSSOM serialization
of rules rather than their authored text.
