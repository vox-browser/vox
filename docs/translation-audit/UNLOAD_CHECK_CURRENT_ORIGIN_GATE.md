# Unload-check current-entry identity and optional-origin equality

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/LocalNavigable.cpp:4024–4050`, and
`Libraries/LibURL/Origin.h:65`.

Phase one previously compared the target to the Traversable's active entry and
entered the traverse-event branch when their origins differed. Pinned Source
compares against the inherited current entry and requires equal origins. The V
inequality helper also treated one missing origin as not different, which cannot
be inverted to translate optional equality correctly.

The branch now selects the translated shared current-entry owner, compares
target/current pointer identity, and translates optional DocumentState origin
equality. Both missing origins compare equal; one missing origin does not.
Present values use the existing typed `Origin.is_same_origin()` implementation,
matching Source URL::Origin::operator== rather than comparing origin display
strings or domain overrides. Source's non-null DocumentState precondition is
retained.

Five cases in `html/unload_check_origin_gate_test.v` use actual
navigation-created Pages/Documents/Windows/local Navigables and actual
Navigation event listeners. The existing Navigation bridge is supplied the
genuine Window-owned Navigation object in these gate fixtures. Same-origin
traversal fires beforeunload then the actual cancellable traverse event, and
retains canceled-by-navigate. A different-origin target instead uses phase two
and fires no traverse event. A target identical to the actual current entry
skips phase one even while active is a different entry. Null-origin and opaque
nonce cases observe actual queued task ownership and actual event sequences:
both absent/same nonce take phase one; one absent/different nonce take phase two.

Existing traversal tests now advance the actual event loop until their bounded
semantic completion rather than assuming the previous task count. They retain
asynchronous completion, queue-jump-while-paused, history result, fresh-navigation
preservation and close assertions. Correctly entering same-origin phase one
adds that source phase's task; the earlier timing failures and initial
test-only mutability errors remain in
`Build/audit-fixes/source-unload-check-origin-gate-default.log`.

Default GC passed 2/2 files, including all five new cases and the complete
traversable suite, in `source-unload-check-origin-gate-complete-default.log`.
The GC-none neighbor batch passed 7/7 files in
`source-unload-check-origin-gate-gc-none.log`, adding shared history-entry
ownership, phase-two task ownership, actual beforeunload, Navigation and traversal
queue coverage. Commands use `v -old-compiler -enable-globals test`, with
`-gc none` for that batch.

This slice translates the current-entry/origin branch and its event selection.
Selecting the current active Window's Navigation object and actual phase-one
global task owner remains a separate source fix; production still retains its
older optional Navigation and Document snapshots there. Bare-host creation,
session-history graph/current-step protocol, source timeout timer, Page history
executor and remote transport remain separate boundaries. It does not claim
full Window.close or native JavaScriptCore BeforeUnloadEvent bindings.
