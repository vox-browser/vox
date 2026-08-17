# Internals module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Internals`

Translation workspace: `~/code/libweb_v/internals`
Audited: 2026-08-16

All seven upstream implementation units, their headers, and six IDL files are
represented. The module imports the translated Gamepad API and does not keep a
second, incompatible model of virtual-controller state.

| Upstream implementation | V implementation |
| --- | --- |
| `InternalsBase.cpp` | `internals_base.v` |
| `Internals.cpp` | `internals.v` |
| `InternalAnimationTimeline.cpp` | `internal_animation_timeline.v` |
| `InternalGamepad.cpp` | `internal_gamepad.v` |
| `WebUI.cpp` | `web_ui.v` |
| `FakeXRDevice.cpp`, `XRTest.cpp` | `xr_testing.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Internals/` | 7 | 951 | 826 | 220 | Complete |

`PlatformState` is the explicit Page/PageClient/test-runner boundary. It makes
test completion, metadata, input synthesis, URL/time-zone overrides, cache and
cookie controls, zoom/DPR, dumps, hit testing, highlighting, WebUI messages,
and SDL event pumping observable without inventing native rendering services.
Layout and paint tree serialization therefore return an explicit host-boundary
marker when a node exists and the normal upstream no-tree result otherwise.
IDL input methods retain their element target and run the translated focus
operation before recording the host action. URL overrides accept absolute
non-hierarchical URLs such as `about:blank`, accessibility helpers use the
translated ARIA/name computation, and `clear_element()` invokes the translated
form-control clear algorithm without deleting DOM children.

The animation timeline delegates to `animations.AnimationTimeline` and updates
associated animations. `InternalGamepad` owns a typed `gamepad.Device`, so
button, axis, trigger, disconnect, exposure, and rumble behavior are exercised
end to end. The IDL `setAxis()` path handles both stick axes and trigger IDs,
and a disconnected virtual gamepad removes itself from Internals ownership.
Fake XR methods resolve and invoke callbacks but deliberately do not register,
disconnect, or configure hardware, matching the current upstream FIXMEs.

## Verification

```text
$ /Users/alex/code/v/v test internals
Summary for all V _test.v files: 3 passed, 3 total.
```
