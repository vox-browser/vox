# Unload-check native Navigable vector ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/LocalNavigable.cpp:3983–3988,4005–4053,4188–4209`.

Source's full unload-check entry point takes LocalNavigables, an optional
Traversable, optional target entry and user involvement, initial prompt state,
and a result/prompt completion pair. Its start phase captures each supplied
Navigable's active Document. Earlier V methods accepted a Document list and
only supported a retained Traversable with a non-optional involvement value.

The module now exposes the actual full Source entry point on existing native
local Navigable identities. The state retains optional Traversable and user
involvement, initializes the Source timer and callback, and collects each native
host's actual active Document when invoked. Those selected Documents stay
retained for the queued phase-two tasks; a later host replacement does not
substitute another Document into that already-started check.

When a Traversable is supplied, Source's target/user/current-entry
preconditions are retained. Target/current identity and optional-origin
equality select phase one. Whether it needs beforeunload is determined by
native Traversable identity in the supplied vector, and only the first matching
active Document is removed from phase two, matching Source. The actual native
path requires its real active Window and uses the previously translated global
task owner. Without a Traversable, the state proceeds directly to phase two and
can retain an initial Yes prompt flag. A distinct V name implements Source's
result-only overload with initial No and the explicit completion projection.

The native hosts must have existing registered local NavigableModels and active
Documents, representing Source's LocalNavigable static-type/non-null input
preconditions. This adds no synthetic Navigable, Window, Document or Page and
does not cast remote records to local owners. Remote/local selection remains a
Source caller responsibility.

Six cases in `html/unload_check_navigable_vector_test.v` use real
navigation-created Pages, Documents, Windows, native hosts, local models and
actual beforeunload/Navigation events. They prove that retaining a native host
before real navigation and invoking afterward selects its replacement
Document; navigation after invocation retains and skips the original inactive
Document; a two-host check without a Traversable retains initial Yes; containing
the actual native Traversable fires its beforeunload once before Navigation and
the remaining supplied Document; omitting it fires only Navigation and the
supplied Document; and the native result-only overload preserves actual prompt
cancellation.

Default GC passed the new vector, prompt and timeout files, 3/3, in
`Build/audit-fixes/source-unload-check-navigable-vector-default.log`. GC-none
passed 10/10 files in `source-unload-check-navigable-vector-gc-none.log`, adding
actual active Window owners, current-entry/origin gates, phase-two tasks,
complete Traversable, prompted-close, beforeunload and event-loop coverage.
Commands use `v -old-compiler -enable-globals test`, adding `-gc none` for the
ownership batch.

Existing Document-list methods and their hook remain separate compatibility
adapters. The older history continuation still gathers only its translated
top-level document transition. Actual prompted-close input collection
subsequently uses this API in
[its separate caller slice](TRAVERSABLE_PROMPTED_CLOSE_OWNERSHIP.md). Native
history-job integration remains separate; this commit does not pretend those
adapters supply Source's complete vector. Full UI history jobs,
Page history executor, session-history graph/current-step protocol, remote
transport and native JavaScriptCore bindings remain separate boundaries.
