# Node scripting gates follow the current Document

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/DOM/Node.cpp:2830–2840`,
`HTML/Scripting/Environments.cpp:445–447,493–507`, and
`DOM/EventTarget.cpp:612–637`.

The V gate kept the settings from a node's creation Document across adoption.
That disagreed with the pinned `relevant_settings_object(DOM::Node const&)`
overload, which returns the current `node.document()` settings. Its relevant
Realm/global Node overloads flow through that same settings owner. The separate
`JS::Object` overload reads an object's Realm; it is not the Node call path.

The gate now reads the current Document's actual settings through its existing
lifecycle bridge on each check. The unsupported retained settings/creation
Document fields, initialization during allocation/adoption, and corresponding
GC edges are removed. Source still rejects nodes whose current Document has no
BrowsingContext first, then applies the actual Window/Page preference, exact
WebUI exception, and script sandbox. Fully-active state remains a separate
`can_run_script()` check. Node constructors no longer require a cached owner
snapshot to find settings installed later.

The corrected adoption case verifies the complete adopted element/text subtree
and a clone against current Page preference and script sandbox changes. It also
checks re-adoption to the original disabled Page and a Document without a
BrowsingContext. A late-Window case creates the node first, installs actual
Window settings afterward, and changes the current Page preference repeatedly.
The existing constructor check now verifies actual Document settings directly.

A new case in `html/raw_handler_scripting_owner_test.v` uses actual
navigation-created Documents/Pages/Windows and a parser-created raw `onclick`
handler. After adoption into a disabled Page, the Source current-Document gate
preserves the raw value and activated listener without invoking either compiler.
Enabling the current Page while disabling the original Page compiles through
the current Document hook, retains the same listener, and dispatches the
returned callback with actual cancellation. This test covers the gate and
compiler owner seam; its explicit compiler hook does not establish complete
JavaScript engine/function compilation parity.

Default GC passed the eight scripting-owner cases and the raw-handler case in
`Build/audit-fixes/source-node-current-scripting-owner-default.log` and
`source-node-current-raw-handler-default.log`.
The GC-none batch passed 6/6 files, adding the HTML and incremental parsers,
existing raw-handler compilation, and attribute hooks:
`source-node-current-scripting-owner-gc-none.log`.
Commands used `v -old-compiler -enable-globals test`, with `-gc none` for
the latter batch.

The older DOM-only adapter still permits scripting after a manually supplied
BrowsingContext when no translated settings bridge exists. Actual browser
Document construction supplies that bridge before fonts, initialization, or
parsing; it takes the real current-settings path. Full wrapper-world/LibJS
ownership and generated binding graphs remain separate runtime boundaries.
