# ViewTransition translation status

Source algorithms and live DOM integration for `Libraries/LibWeb/ViewTransition`
at upstream revision `963d46a829f3e1b79f44dba9d02afb70654300fa`.

| Upstream unit | LOC | V mapping |
|---|---:|---|
| `ViewTransition.cpp` | 1,046 | `view_transition.v`: capture, activation, callback scheduling/settlement, skipping, frame handling, pseudo styles and cleanup |
| `ViewTransition.h` | 171 | `view_transition.v`: phase, transition/document/element state, captured style definitions and pseudo hierarchy |
| `ViewTransition.idl` | 11 | `view_transition.v`: the three promise attributes and `skip_transition()` |
| **Upstream total** | **1,228** | **1 `.cpp`, 1 `.h`, 1 `.idl`** |

- The eight model tests in `view_transition_test.v` cover callback scheduling,
  promise settlement, phase changes, capture validation, pseudo hierarchy,
  owned rule cleanup, finishing and replacement.
- Five live fixtures in `../layout/view_transition_capture_test.v` exercise
  real DOM/layout traversal, computed styles and dimensions, actual decoded
  frame ownership, retained DOM pseudo nodes, CSSOM rule identity and cleanup,
  visibility changes between task queueing and execution, and asynchronous
  callback fulfillment/rejection on the owning document's microtask queue.
- `../dom/view_transition_bridge.v` connects the model to the actual document
  and its named elements. `../layout/view_transition_capture.v` reads computed
  properties from committed layout nodes. `../css/view_transition_style_sheet.v`
  retains the actual generated `CSSRule` objects in the document's dynamic
  stylesheet. `../html/view_transition_promises.v` installs the relevant Realm
  and promise job scheduler when the owning Window is created.
- Standalone model callers retain `run_next_dom_task()` and the optional
  `process_update_callback_promise()` adapter. Live documents use source DOM
  tasks and registered Promise reactions.

The pinned upstream retains several incomplete algorithms. These remain
explicitly source-compatible: `Element::capture_the_image()` returns a blank
1x1 premultiplied BGRA bitmap; old-state transforms remain an identity
translation; text orientation and paint-order traversal are unfinished;
generated style operands retain upstream literal placeholders; existing group
rules update only their selector; animation activity remains false. The
synthetic transition tree is retained, matching upstream, whose tree has no
layout/painting consumer at this revision.

The compact JavaScriptCore browser bridge exposes `Document.startViewTransition()`,
the direct `activeViewTransition` getter, the returned object's three stable
Promise attributes and `skipTransition()`. `../browserjs/view_transition_host.v`
retains actual DOM transitions and observes their source promises;
`../browserjs/view_transition_bootstrap.v` performs IDL conversion and preserves
JavaScript callback rejection identity. The browser replays callback mutations
into the actual document before new-state capture resumes. Skip and visibility
failures use the translated native WebIDL `DOMException` binding.

Four fixtures in `../paint/view_transition_test.v` exercise those public JSC APIs,
including a pending callback, cyclic rejection values, callback throws, receiver
branding, source property descriptors, hidden documents, omitted callbacks and
transitions first started through the typed DOM API. These bindings preserve the
upstream capture and rendering limitations listed above.
