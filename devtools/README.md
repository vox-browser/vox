# Developer tools

Vox has a Chrome-style Elements panel docked below the document. It is
declared in V/UI2 like the rest of the browser chrome and works on the
document of the tab that opens it.

| Action | macOS | Linux |
| --- | --- | --- |
| Toggle the panel | Cmd+Option+I, F12, Browser > Developer Tools | Ctrl+Shift+I, F12 |
| Pick an element in the page | Cmd+Shift+C or Cmd+Option+C, the toolbar arrow | Ctrl+Shift+C |
| Inspect the element under the pointer | Right-click > Inspect | Right-click > Inspect |
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
- The sidebar edits attribute values (Return applies), removes attributes and
  adds new ones. Row context menus also copy a node and expand or collapse
  subtrees. The breadcrumb bar selects ancestors.
- The top edge resizes the panel; the document viewport shrinks to fit it.
  Script mutations refresh the tree while the panel is open.

## Structure

`devtools/` holds the model, DOM edits and UI2 declarations. Rows refer to
nodes by unique ID and are rebuilt from the live document, so a navigation
never leaves the panel holding another document's nodes.
`main_devtools.v` connects the panel to the tab: viewport height, picker and
hover input, highlights, keys, actions and relayout after edits.

## Tests

```sh
python3 tools/prepare_ui2.py
v -enable-globals -memory-limit 10G -cc clang \
  -path 'Build/v/modules|.|@vmodules|@vlib' test devtools
VOX_CHROME_TEST_FILE=main_devtools_test.v sh tools/test_address_bar.sh \
  -memory-limit 10G -skip-running -o Build/devtools-main-test
```

Run both through `tools/run_memory_bounded.py` as described in
[the UI2 adapter guide](../tools/ui2/README.md). The custom-renderer path
shares these declarations but has not been exercised in a Linux window.

## Not yet implemented

Styles, computed values, the console, network and sources panels, undo,
inline attribute editing in the tree, `<template>` contents and iframe
documents.
