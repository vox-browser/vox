# Animations module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Animations`

Translation workspace: `~/code/libweb_v/animations`
Audited: 2026-08-16

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
| `Animations/` | 10 | 4,381 | 2,217 | 389 | Complete |

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

## Verification

Focused verification:

```text
$ /Users/alex/code/v/v test animations
Summary for all V _test.v files: 5 passed, 5 total.

$ /Users/alex/code/v/v test .
Summary for all V _test.v files: 188 passed, 188 total.
```
