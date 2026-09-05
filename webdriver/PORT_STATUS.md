# WebDriver module V translation — upstream algorithm coverage reviewed

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/WebDriver`

Translation workspace: `~/code/libweb_v/webdriver`
Audited: 2026-09-01

All 17 upstream implementation units and all 18 headers were cross-audited and
their algorithm entry points are represented. The
translation keeps browser-process ownership explicit: browsing contexts,
elements, JavaScript execution, event-loop time, network requests, framebuffer
capture, and PNG encoding enter through typed values or host callbacks rather
than hidden globals.

| Upstream implementation | V implementation |
| --- | --- |
| `Actions.cpp`, `InputSource.cpp`, `InputState.cpp` | `input_actions.v`, `action_algorithms.v` |
| `Capabilities.cpp` | `capabilities.v` |
| `Client.cpp`, `Screenshot.cpp` | `client_screenshot.v` |
| `Contexts.cpp`, `ElementLocationStrategies.cpp`, `ElementReference.cpp` | `elements_contexts.v`, `protocol_algorithms.v` |
| `Error.cpp`, `Response.cpp`, `Properties.h` | `error_response.v` |
| `ExecuteScript.cpp`, `HeapTimer.cpp`, `JSON.cpp` | `json_script_timer.v` |
| `Proxy.cpp`, `TimeoutsConfiguration.cpp`, `UserPrompt.cpp` | `timeouts_proxy_prompt.v` |

| Upstream source area | `.cpp` files / LOC | `.h` files / LOC | `.idl` files / LOC | Implementation `.v` files / LOC | Test `.v` files / LOC | Status |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `WebDriver/` | 17 | 18 | 0 | 9 | 4 | Present; algorithm names fully audited |

The port covers the complete error-code table, typed property/range checks,
timeouts, proxy and prompt deserialization, capability validation/merging and
matching, every HTTP route, ordered route parameters, node/shadow/window/frame
references and staleness, the portable location-strategy surfaces,
input-source allocation, action sequence transposition and validation,
JavaScript-safe numeric limits, key/pointer dispatch state, action-queue
lifetime, viewport bounds,
JSON cloning, script execution completion, one-shot timers, framebuffer
painting dimensions, and PNG base64 response encoding. It also preserves the
current upstream quirks around unknown mouse-button masks and Audio/DOM-free
protocol state.

Current upstream incomplete behavior remains visible: XPath, `pointerCancel`,
scroll dispatch, and pen/touch event dispatch reject as unsupported. Full CSS
selector evaluation, paint-tree hit testing, rendered text, element-origin
scrolling/coordinate resolution, keyboard-layout event conversion, and the
DOM/JavaScript special cases of JSON clone/deserialization require the host
DOM/JS environment. The portable selector implementation deliberately supports
ID, class, and tag selectors; element-origin pointer actions can be resolved
through `resolve_pointer_move_element_origin`. Framebuffer capture uses explicit
pixel values (RGBA rather than upstream's platform BGRA surface), and PNG
encoding is a callback boundary.

## Verification

```text
$ /Users/alex/code/v/v -enable-globals test webdriver
Summary for all V _test.v files: 4 passed, 4 total.
```

The strict repository audit reports zero unmatched WebDriver implementation
names. This is not a claim that browser-owned DOM, JavaScript VM, socket, event
loop, framebuffer, or PNG facilities are reimplemented inside this portable
module; those remain explicit typed/callback boundaries supplied by the
embedding browser.
