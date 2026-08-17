# Platform translation status

Upstream: `Libraries/LibWeb/Platform`

| Upstream unit | V implementation |
| --- | --- |
| `EventLoopPlugin.cpp` | `event_loop_plugin.v` |
| `FontPlugin.cpp` | `font_plugin.v` |
| `ImageCodecPlugin.cpp` | `image_codec_plugin.v` |
| `Timer.cpp` | `timer.v` |

- Upstream: 4 `.cpp` files, 415 physical LOC.
- V implementation: 394 LOC.
- V tests: 61 LOC in 1 file.
- Status: complete.

Typed host boundaries cover event-loop driving, installed font discovery,
image decoding/animation callbacks, and timer scheduling. Singleton installation
invariants, fallback tables, decoded-image mutation, and timer state are tested.

Verification: `v test platform`, `v fmt -verify platform`, and scoped
`git diff --check` pass.
