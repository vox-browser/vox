# Window closed and the inherited local Navigable closing flag

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/Window.cpp:980–993,1173–1185`,
`HTML/LocalNavigable.h:84–85,520`, and
`HTML/LocalTraversableNavigable.h:26`.

The V Window kept its own closed flag and consulted a cached context's discarded
state. Local Navigable and Traversable records also kept separate closing flags.
Source instead owns `m_closing`, initially false, on LocalNavigable and inherits
that one field in LocalTraversableNavigable. Window.closed reads the current
associated Document's actual context and current local Navigable's closing flag.

The native Navigable now owns that flag once. Both typed local Navigable and
Traversable getters/setters delegate to their actual native host record, and
traversable close writes the same owner. The unsupported Window closed snapshot
is removed; the legacy model close path writes the actual native closing flag
when it accepts a close. The native Window BrowsingContext getter translates
Source's associated-Document lookup and null behavior. Its closed getter
returns true without that context, without a Navigable, or while the actual
Navigable is closing; otherwise false. WindowModel delegates directly.

Four cases in `html/window_closing_owner_test.v` use real navigation
Documents/Pages/Windows and verify bidirectional native/local model state,
subclass host attachment sharing the inherited field, direct Window/model
property reads, cached context removal without actual owner changes,
associated-Document swap/restoration, absent current context/Navigable,
pre-Document Window behavior, and the existing close path writing the actual
native state. Existing traversable queue/close and full Window-context tests
pass alongside these cases.

Default GC passed 3/3 files in
`Build/audit-fixes/source-window-closing-owner-default.log`.
The GC-none batch passed 6/6 files, adding Navigable, logical Window getters,
and Window/Document identity neighbors:
`source-window-closing-owner-gc-none.log`.
Commands used `v -old-compiler -enable-globals test`, with `-gc none` for
that batch.

This slice translates the shared flag and getter ownership. The existing
Window.close implementation still immediately removes its cached context after
its legacy history/auxiliary checks. Source's actual incumbent Window,
familiarity and sandbox checks, global DOM-manipulation close task, and full
local traversable close/history-executor protocol remain separate untranslated
work. In particular prompted cancellation recovery, close-step deduplication,
forced-close mode, and UI-process history-operation completion are not certified
by this owner slice. Full native JavaScriptCore WindowProxy/global binding and
remote-process state/transport remain separate runtime boundaries.
