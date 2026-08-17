# ViewTransition translation status

Complete, audited translation of `Libraries/LibWeb/ViewTransition` at the
current upstream revision.

| Upstream unit | LOC | V mapping |
|---|---:|---|
| `ViewTransition.cpp` | 1,046 | `view_transition.v`: capture, activation, callback scheduling/settlement, skipping, frame handling, pseudo styles and cleanup |
| `ViewTransition.h` | 171 | `view_transition.v`: phase, transition/document/element state, captured style definitions and pseudo hierarchy |
| `ViewTransition.idl` | 11 | `view_transition.v`: the three promise attributes and `skip_transition()` |
| **Upstream total** | **1,228** | **1 `.cpp`, 1 `.h`, 1 `.idl`** |

- V implementation: **567 LOC** in 1 `.v` file.
- Focused tests: **319 LOC** in 1 `_test.v` file (8 tests).
- Tests cover the queued setup boundary, synchronous callback-queue flush,
  pending/fulfilled/rejected callbacks, promise handling and phase changes,
  oversized/duplicate capture failures, skipped ancestors, document-element
  snapshot geometry, old/new-only and paired pseudo trees, exact owned rule
  sets, in-place frame updates, selective clearing, finishing and replacement.
- DOM tasks are exposed through `TransitionDocument.run_next_dom_task()`;
  pending platform promises resume through
  `process_update_callback_promise()`. Layout traversal, bitmap capture, CSSOM
  objects and animation activity remain explicit typed host boundaries.
