# Search navigation overhead

2026-10-18. Four focused elapsed-time fixes build on asynchronous thumbnails
(`5b91e681`) and cache decoder correction (`8d0bd2c5`). No instruction-count
savings or broad native-suite reset are claimed. These are fixes 3–6 in this
search-task batch after source baseline `17328490`: timer gate (3), content
negotiation (4), script metadata (5), outgoing layout (6). The earlier two audit
entries record fixes 1–2. Historical broad-suite ownership records are unchanged.

## Changes and focused checks

- `97a4fd6a`: completed cached-page dependencies are polled before the live
  network refresh gate. Previously the 500 ms refresh deadline also held a
  ready cached document. Two native cases reproduce that delay without clock
  sleeps and verify that a newer network reply stays queued until the cached
  document has actually painted. Both fail on the control and pass with default
  GC and no-GC.
- `3439e48a`: document requests send the upstream HTML Accept value, and all
  native resource requests negotiate gzip, deflate and Brotli. The existing
  HTTP implementation decodes all three. Two focused cases check actual binary
  responses from a local server plus request-role headers in both GC modes.
  The existing Accept and HTTP/2/TLS fixtures also pass. A private live HTTP/1
  probe reduced its response from 332 KB to 66 KB with gzip; it was a login
  response and does not establish authenticated search speed.
- `06fdff11`: a non-directive ASCII first token lets strictness metadata return
  before copying a whole script to UTF-16. Comments, hashbangs, HTML comments,
  quoted directives and non-ASCII trivia keep the full lexer. All seven actual
  external search scripts qualify. Two new cases check fallback semantics and
  bounded allocation for a large non-directive program. Both mandatory full
  LibJS runs pass all 236 files, with default GC and no-GC; the unmodified AST
  corpus driver matches all 100 upstream fixtures exactly. These checks do not
  imply a translated JavaScript execution backend: the browser uses JSC.
- `549bc94f`: direct navigation performs the outgoing document's inactivity
  cleanup before a reused Window is retargeted. One native case checks layout
  release, one inactivity notification, and preservation of the new page's
  rendering in both GC modes. Ten additional HTML registry, visibility, Window
  identity and child-tree ownership cases pass with default GC.

The three native timer/lifecycle cases ran as one frozen driver in each GC mode.
Receipts are `Build/search-speed/navigation-focused{,-none}.{log,status}`.
Network receipts are `negotiation-corrected`, `negotiation-none`, and the retained
passing existing files in `negotiation-focused`. LibJS receipts are
`strict-corrected`, `libjs`, `libjs-none`, and `libjs-corpus`. Additional HTML
ownership credit comes from the passing file in `retirement-corrected.log`; that
whole selection failed its separate collection test and receives no whole-run
credit. Initial new-fixture compile/assertion failures remain retained.

## Memory investigation

Repeated warm searches still grow the managed heap. A sampled run placed 123
main-thread stacks in UTF-16 allocation/collection solely for script strictness
metadata. The metadata shortcut removes that work, but does not solve general
page retention.

A separate attempt to unregister retired documents, settings, Windows, shared
image requests and ranges passed lifecycle assertions but failed actual weak
collection checks. Clearing deleted map values was also insufficient. Heap
back-reference inspection confirmed captured owners retained through the
compatibility compiler's global closure live map. The incomplete retirement and
binding-registry changes were removed from the canonical source. Their patches,
failed logs and diagnostics remain under ignored
`Build/search-speed/incomplete-retirement/` and the adjacent investigation logs.
They receive no completed-fix, memory-reduction or successful-build credit.
