# Actual active Document identity

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`DOM/Document.cpp:4793–4797` and `DOM/EventTarget.cpp:530–558`.

Document activity now requires its actual Navigable and the existing
`active_document_is` identity boundary. A retained BrowsingContext alone cannot
make an old or detached Document active. A matching Navigable can establish
activity without relying on BrowsingContext pointer presence.

Four focused cases cover absent Navigable state, exact active-document identity,
body handler ownership after replacement, and stale-document scroll APIs.
An inactive body cannot retrieve, replace, or remove the previous Window's
handler; a replacement body's raw attributes reach its own active Window.
The source identity check also prevents old Document scroll APIs from reading
or changing the previous viewport.

The existing raw-attribute and viewport fixtures now supply their actual
Navigable. The viewport fixture uses its scrolling callback and retained
Document paintable rather than detached Window fallback fields.

Validation under `Build/audit-fixes/worktrees/06-canvas-animation/Build/audit-fixes/`:

- `source-document-active-identity-final-default.log` and
  `source-document-active-identity-final-gc-none.log`: all four focused cases pass.
- `source-document-active-viewport-final-default.log` and
  `source-document-active-viewport-final-gc-none.log`: viewport neighbor passes.
- `source-document-active-identity-gc-none.log`: native raw compiler, Navigable,
  and raw-attribute neighbors pass. The initial focused/viewport fixtures were
  corrected to supply the native viewport state and callback; the final runs
  above validate those corrections.

The Navigable boundary remains the single place for active-document identity.
This slice does not introduce direct active-Document dereferences in event
handler or scroll callers, and does not complete other pending virtual dispatch
or cross-process execution work.
