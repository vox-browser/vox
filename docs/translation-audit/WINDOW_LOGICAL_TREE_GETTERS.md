# Window top and parent follow the logical Navigable tree

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/Window.cpp:1320–1330,1367–1381`,
`HTML/LocalNavigable.cpp:1476–1492`, and `HTML/Navigable.h:38`.

The V getters walked cached BrowsingContext ancestry and returned the creation
proxy when no cached parent existed. Source instead asks the Window's actual
associated Document Navigable for its logical parent or top-level traversable,
then asks that Navigable for its current active WindowProxy. The cached local
context can disagree with the logical parent or the Document currently
associated with the Window.

The actual native Window now implements the two Source getters. `top()` returns
null without a Navigable, otherwise the top-level traversable's active proxy.
`parent()` returns null without a Navigable, otherwise the logical parent's
active proxy when a parent exists, or the current Navigable's active proxy.
WindowModel delegates to these getters and resolves the returned existing
native proxy by actual identity. A missing active proxy remains null. Callers
do not inspect parent Documents or create substitute proxies.

Four cases in `html/window_logical_tree_owner_test.v` use actual navigation
Documents/Pages/Windows and verify independent cached contexts with a logical
three-level tree; a conflicting local container Document; same- and cross-
origin model property values; stable proxy identity after native Window slot
retargeting; temporary associated-Document swap/restoration; an absent active
parent Document/proxy; and no-Navigable null behavior. A top-level getter uses
the actual Navigable-owned proxy even when its current Window slot belongs to
another Window record.

Default GC passed the four cases in
`Build/audit-fixes/source-window-logical-tree-owner-default.log`.
The GC-none batch passed 5/5 files, adding existing context, child-tree, actual
proxy identity, and Navigable hierarchy regressions:
`source-window-logical-tree-owner-gc-none.log`.
Commands used `v -old-compiler -enable-globals test`, with `-gc none` for
that batch.

The V backend currently implements local Navigable proxy access. Remote-process
proxy replication/transport and the complete native JavaScriptCore WindowProxy/
global binding graph remain separate runtime work. The current model property
path reaches these translated getters; that does not certify complete public
JavaScript WindowProxy semantics. Broader cached BrowsingContext, opener,
close, and named-child algorithms remain separate translation boundaries.
