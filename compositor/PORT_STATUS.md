# Compositor port status

Status: **Complete** (2026-09-11)

| Upstream implementation | V translation |
| --- | --- |
| `AsyncScrollTree.cpp` | `async_scroll.v` |
| `AsyncScrollingState.cpp` | `async_scroll.v` |
| `CompositorHost.cpp` | `host.v` |
| `SmoothScrollAnimation.cpp` | `types.v` |
| `Types.cpp` | `types.v`, `codec.v` |
| `VisualAnimation.cpp` | `visual_animation.v` |

The native display-list, canvas, video, and screenshot transports remain an
explicit host boundary. Focused tests cover metadata extraction, fail-closed
wheel admission, main-thread/blocking region precedence, scroll-chain handoff,
snap deferral, smooth and momentum curves, IPC round trips and malformed-input
rejection, all visual-animation target kinds, validation and interpolation,
context forwarding, and canvas flush ordering.
