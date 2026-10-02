# Scroll Promise ownership prerequisite

The local main-thread scrolling implementation now retains actual WebIDL Promise capabilities in its DOM-facing wrappers. Each capability comes from the active document's existing owning Window realm and document microtask queue. This is a prerequisite for the ancestor `scrollIntoView` caller to wait for actual scroll operations.

The reference is Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`: `HTML/LocalNavigable.cpp:4502–4524` queues resolution in the capability's realm with callbacks enabled; `6319–6406` creates distinct promises for new and coalesced scroll operations and resolves them according to the existing instant/main-thread smooth path. The V change keeps those operation, replacement, sample, and completion algorithms; it replaces their DOM-only settlement records with `dom.Promise.from_webidl()` around the actual capability.

The same document realm/job context already installed for ViewTransition is available through a generic read-only accessor. There is no second realm or duplicated Promise state. Its HTML runner supplies the source temporary execution context at queued scroll resolution and aggregate settlement. Existing exposed ViewTransition capabilities remain unchanged.

`WebIDL/Promise.cpp:401–429` creates its wait-for-all aggregate in a supplied realm and enters that realm to settle it. `get_promise_for_wait_for_all_for()` now translates this owning variant, while the old standalone entry point retains its empty-context adapter. Capability reactions preserve the same realm, scheduler, and execution-context runner. Ordered results and original rejection values still come from the existing wait-for-all algorithm.

Two WebIDL cases verify pending input order, aggregate/reaction ownership, empty input, and original DOMException identity. Two committed-layout cases verify actual Window capabilities for instant, coalesced smooth, and replaced element scrolling. All four pass with default GC and `-gc none`. Existing smooth-scroll operations (five cases), Promise adoption (six), and live ViewTransition capture (five) also pass with `-gc none`.

The existing compositor transport and user-input latching boundaries remain open. This slice uses the already translated source main-thread fallback and its real samples/completion jobs; it supplies no fabricated compositor result. Standalone models without a Window retain an explicit empty-context adapter. Public JavaScript scroll bindings are separate from this prerequisite.
