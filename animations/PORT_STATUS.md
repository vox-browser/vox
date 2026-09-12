# Animations module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Animations`

Translation workspace: `~/code/vox2/animations`
Audited: 2026-09-12

All ten upstream Animations `.cpp` implementation units have an audited V
implementation mapping.

| Upstream implementation unit | V implementation |
| --- | --- |
| `Animatable.cpp` | `animatable.v` |
| `Animation.cpp` | `animation.v` |
| `AnimationEffect.cpp` | `animation_effect.v` |
| `AnimationPlaybackEvent.cpp` | `animation_playback_event.v` |
| `AnimationTimeline.cpp` | `animation_timeline.v` |
| `DocumentTimeline.cpp` | `animation_timeline.v` |
| `KeyframeEffect.cpp` | `keyframe_effect.v` |
| `PseudoElementParsing.cpp` | `pseudo_element_parsing.v` |
| `ScrollTimeline.cpp` | `scroll_timeline.v` |
| `TimeValue.cpp` | `time_value.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Animations/` | 10 | 5,187 | 3,972 | 1,041 | Complete |

The port covers unit-aware time arithmetic, document and scroll timelines,
effect timing normalization and progress calculation, the animation playback
state machine and promise/event lifecycle, keyframe processing and CSS value
sampling, pseudo-element parsing, composite ordering, Animatable animation
lists, CSS animation registries, and transition registries.

Ladybird uses C++ virtual inheritance and LibJS objects. The V translation uses
a tagged timeline object and typed V keyframe dictionaries. Scroll layout
supplies a `ScrollMetrics` snapshot, and `KeyframeEffect` returns sampled CSS
properties to the style layer; these typed boundaries avoid module cycles while
preserving the upstream algorithms. `AnimationPlaybackEvent` is identified by
the DOM event interface enum so normal event dispatch still works.
Document and scroll timelines register with their associated document through
the cross-module handle boundary. A document snapshots and advances every
registered timeline before its animation update callback, and reassociation or
disassociation updates that registry exactly once.
The 2026-09-11 refresh also covers compositor preparation and observation
state, task-stable observation sampling, wrapper-valued animation promises,
effect target ownership and CSS-cancellation disassociation, provisional
effects, constructor realm selection, processed keyframe inputs, and scroll
timeline staleness. The CSS-owned refresh bridge preserves animation updates
for base `display: none` targets when the effect itself animates `display`.

## Verification

Focused verification:

```text
$ /tmp/vox2-v-c3358d3.Qu9YHN/v -old-compiler -enable-globals test animations
Summary for all V _test.v files: 5 passed, 5 total.

$ python3 tools/upstream_function_delta.py --base 1d025620e3344e3cc9aee26fe815d8675e4f9810 --head 963d46a829f3e1b79f44dba9d02afb70654300fa --json
Animations unmatched definitions: 0
```
