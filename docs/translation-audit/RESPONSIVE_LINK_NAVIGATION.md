# Responsive compact-browser link navigation

The reported case is navigation from `https://www.wikipedia.org/` through the
Italian language link. The document download already used a worker, but the
native frame that installed its response waited synchronously for initial
styles, scripts and visible images. A supporting Spanish-language navigation reproduction spent 3,819 ms in
`preload_resources`, with 4,044 ms in the complete document installation. Its
screenshot is retained as `click-before.png`; the corrected Italian link
capture is retained separately.

There was also a second commit path. Native DOM click activation called the
translated Navigable's navigation callback before the compact shell replayed
its click listener and started its own loader. This could replace the native
active document with an empty document while the shell still displayed the old
page. The shell now captures that native destination and sends it through its
own loader after compact click cancellation has been resolved. Programmatic
native navigation requests are drained by the frame loop. The app has heap
ownership because the navigable callback retains its address.

Initial resource discovery now parses into an inert, detached document on the
owning thread. It uses the destination's final URL and parser scripting mode,
including `noscript` and `<base>`, without registering another Window or running
page scripts or import maps. Resource fetches and cache-context revalidation
run in workers. The frame loop polls buffered completions while retaining the
current active document and input handling. Styles finish before the disabled-
scripting image plan is evaluated, so hidden images keep their existing
background-loading behavior.

Only the current navigation generation may commit. Replacement of a pending
cached-page preparation by its live response preserves the pending history
insertion. Completed failures are supplied to installation instead of being
retried synchronously. Newly needed successful resources replace old entries
when the bounded reusable cache is full, so image painting can still consume
the prepared response.

Bulk parsing, style/layout work and native input/rendering scopes temporarily
use a collection divisor of 4, with collection still enabled. Profiling found
repeated full collections under the aggressive idle divisor during navigation.
The scoped policy restores the preceding divisor on every exit, handles nested
scopes, and leaves explicit collector environment overrides untouched. It does
not reserve a fixed heap or change the idle policy.

This fixes the initial compact top-level resource barrier, duplicate link
commit and excessive collection during active document work. It does not make layout, script execution, arbitrary later synchronous
resource APIs, or CSS import loading asynchronous. It does not establish that
all reported intermittent crashes have the same cause.

## Verification

Focused coverage is in `main_navigation_preload_test.v` and
`main_native_navigation_test.v`. The first covers gated response handling,
failed responses without retries, superseded generations, cache capacity,
inert resource discovery, cached/live history overlap and hidden images. The
second covers native link handoff and native/compact click cancellation.

Build outputs, test logs, the before executable, live-link capture and controlled
slow-response UI heartbeat comparison are retained in
`Build/italian-navigation/`. The controlled fixture holds its stylesheet response for 3.5 seconds. In the
first production comparison, the largest main-queue heartbeat gap fell from
3,554.091 ms to 114.539 ms, with zero differing document pixels. This measures
responsiveness, not faster network completion or general rendering parity.
Final-build receipts and the corrected Italian verification are recorded in the
same directory. Intermediate clicks that hit another language or did not
navigate are not Italian-page verification.

Cadence: this audit records one completed browser fix from the task's initial
`6f49c764` checkout. Focused checks and a production build are used; this entry
does not claim a full repository or broad screenshot-suite run.
