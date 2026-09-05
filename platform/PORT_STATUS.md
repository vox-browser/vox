# Platform translation status

Upstream: `Libraries/LibWeb/Platform`

| Upstream unit | V implementation |
| --- | --- |
| `EventLoopPlugin.cpp` | `event_loop_plugin.v` |
| `FontPlugin.cpp` | `font_plugin.v` |
| `ImageCodecPlugin.cpp` | `image_codec_plugin.v` |
| `Timer.cpp` | `timer.v` |

- Upstream: 4 `.cpp` files, 415 physical LOC.
- V implementation: 1,167 LOC.
- V tests: 96 LOC in 1 file.
- Status: complete.

Typed host boundaries cover event-loop driving, installed font discovery,
image decoding/animation callbacks, and timer scheduling. Singleton installation
invariants, fallback tables, decoded-image mutation, and timer state are tested.
The font boundary also exposes scaled TrueType contours for the direct
`Gfx::Path::text()` translation used by SVG layout, preserving on/off-curve
points rather than substituting generic host text drawing.

Verification: `v test platform`, `v fmt -verify platform`, and scoped
`git diff --check` pass.
