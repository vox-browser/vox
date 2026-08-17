# UIEvents translation status

Complete, audited translation of `Libraries/LibWeb/UIEvents` at the current
upstream revision. The implementation lives in `dom/ui_events.v` so DOM event
dispatch can identify concrete subclasses without a `dom`/`uievents` cycle.

| Upstream `.cpp` | LOC | V mapping |
|---|---:|---|
| `CompositionEvent.cpp` | 57 | `dom/ui_events.v` |
| `EventNames.cpp` | 16 | `dom/ui_events.v` constants |
| `FocusEvent.cpp` | 39 | `dom/ui_events.v` |
| `InputEvent.cpp` | 62 | `dom/ui_events.v` |
| `InputTypes.cpp` | 16 | `dom/ui_events.v` constants |
| `KeyboardEvent.cpp` | 829 | `dom/ui_events.v` |
| `MouseEvent.cpp` | 198 | `dom/ui_events.v` |
| `PointerEvent.cpp` | 150 | `dom/ui_events.v` |
| `PointerTypes.cpp` | 16 | `dom/ui_events.v` constants |
| `TextEvent.cpp` | 51 | `dom/ui_events.v` |
| `UIEvent.cpp` | 52 | `dom/ui_events.v` |
| `WheelEvent.cpp` | 71 | `dom/ui_events.v` |

- Upstream inventory: **12 `.cpp` / 1,557 LOC**, **15 `.h` / 1,155 LOC**,
  **11 `.idl` / 282 LOC**; **2,994 LOC total**.
- Physical V implementation assigned only here: **1,270 LOC** in
  `dom/ui_events.v`.
- Physical focused tests assigned only here: **252 LOC** in
  `dom/ui_events_test.v` (6 tests).
- The audit added all missing interfaces, legacy initializers, target-range
  snapshotting, extended modifiers, pointer angle/list/device fields, mouse
  button conversions, wheel/input/pointer constants and constructor trust
  behavior. Untrusted coordinates now use mathematical floor and PointerEvent
  preserves fractions for non-click event types.
- The independent audit added the upstream MouseEvent and PointerEvent
  platform-event factories and clone paths, preserving page/offset geometry,
  modifiers, subclass fields and clone trust semantics.
- Native key-code mapping and screen/page/layout coordinates enter through
  typed event initializer data; `WindowProxy` remains an opaque host handle.
