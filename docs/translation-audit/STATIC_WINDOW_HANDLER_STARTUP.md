# Static pages with actual Window handlers

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`HTML/BrowsingContext.cpp:174–218`, `HTML/HTMLBodyElement.cpp:105–145`, and
`HTML/HTMLParser.cpp:842–870`.

Source constructs the Window realm before Document parsing, and load dispatch
uses that actual Window even when the document has no script element. The
translation already retains that source Window/settings owner before parsing.
The compact JavaScriptCore facade was initialized only when script-source
collection was nonempty, so a static body-onload raw record never executed.

The loader now initializes its existing runtime when the actual Window has
retained handler records as well as when scripts exist. It passes the genuine
empty source list through existing native readiness dispatch. No synthetic
script or post-parse attribute mutation/replay is introduced.

Four focused cases pass with default GC and without GC. The parser case checks
the raw handler on the actual Window immediately after navigation construction
and parsing, before runtime startup or a test-only context/attribute mutation.
Native cases verify a static body's trusted load event and Document target,
actual disabled-Page raw-source retention, and an animation frame queued by
body-onload without any script element.

Logs in `Build/audit-fixes/worktrees/06-canvas-animation/Build/audit-fixes/`:

- `source-static-window-handlers-final-default.log`: four focused cases pass.
- `source-static-window-handlers-gc-none.log`: 4/4 files pass, including actual
  readiness, owning animation-frame, and script owner-gate neighbors.

The runtime remains a deferred JavaScriptCore host facade; the actual V Window
realm record precedes parsing. Complete Window/WindowProxy and Document prototype
ownership, element/form raw-handler environments, source parser task scheduling,
and LibJS browser execution remain separate audit work.
