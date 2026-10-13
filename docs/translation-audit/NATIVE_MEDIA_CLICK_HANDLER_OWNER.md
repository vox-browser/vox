# Native media onclick and compact replay ownership

Script-assigned `onclick` now uses the actual HTML audio/video owner's native
event-handler map. Previously assignment created an unrelated JavaScript own
property on the compact wrapper, so the actual Page click missed that handler.
The compact bridge could subsequently execute cached raw `onclick` text even
after an IDL assignment replaced or cleared its native slot.

Implementation commit: `8c567b086870d28970c915a80b708b2f771b298a`.
Unchanged parent: `9785762f90dae8824fde63d2558248ddd0fedf82`.
Upstream source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

## Source handler and actual owner

`DOM/EventHandler.idl` declares `onclick` in GlobalEventHandlers, and the
pinned `HTML/GlobalEventHandlers.{h,cpp}` delegates to the actual EventTarget
handler map. `DOM/EventTarget.cpp` owns activation, replacement, deactivation
and callback processing. `Page/EventHandler.cpp` creates the trusted click
after pointerup/compatibility mouseup and uses its dispatch result to decide
whether to run activation behavior.

The implementation adds `click` to the existing native media-handler list.
Its getter/setter descriptors are enumerable and configurable, with native
names `get onclick`/`set onclick` and lengths zero/one. Unset handlers return
null; assignment does not create an own property. Parsed and created owners
retain their actual DOM identity. Native receiver checks precede replay and
author Proxy traps, and the existing conversion captures callback settings
before replaying DOM mutations.

The existing legacy conversion preserves functions, callable Proxies and any
noncallable object by identity. Noncallable handlers silently return undefined
before context entry or `handleEvent` reads; primitive values clear the slot.
Ordinary listener objects retain their separate `handleEvent` path. Replacing
the handler preserves its listener position; null removes it, and reactivation
appends a new position. The exact boolean false cancels the real click; zero
does not. The previously installed 27 media/press/release handler attributes
remain available, for 28 selected attributes on the partial media prototype.

## Native click receipt and compact replay

Actual Page input delivers native ordinary listeners and `onclick` before
the compact replay. Parsed video and created audio observe
`before,handler,after` with the actual trusted Event, correct media receiver,
target/currentTarget and owning Window current-event state. Saved currentTarget
clears and the Window event restores after dispatch. Native false cancellation
sets the Page click flag and suppresses the browser's normal compact replay.
Explicitly calling the replay helper afterward still adds no native callback.

The Event and Page receipt is compact adapter bookkeeping added by this port;
it is not an upstream Event IDL attribute or a new source dispatch algorithm.
The Event records actual click-handler owner identities immediately before
invoking a non-null callback. This includes noncallable objects and callbacks
that mutate their own slot or throw. An unsupported raw element handler does
not produce a processed-handler marker. Each dispatch resets the receipt,
including redispatch of the same Event, and the retained owners participate
in the existing GC edge visitor.

Page publishes the original outer click only after its click/dblclick dispatch
returns, so nested `fire_click_events()` cannot replace the receipt used for
the outer release. Release and click-dispatch entry clear prior state.
`take_last_click_event()` consumes the receipt. Canceled clicks still retain
their own processed-handler receipt; a subsequent release without a new press
clears it, and a release that produces no click publishes no click receipt.

For media click replay, BrowserApp consumes the actual receipt, finalizes and
applies pending compact mutations, then clears the drained operation/log state.
The final replay snapshot still carries pending navigation. It finds the media
wrapper through the stable native bridge key and reads raw text from the
current actual DOM handler map. It permits raw fallback only when the slot is
still raw, the actual click did not process that owner, and the owning document
can run script. It does not inspect property truthiness or cached `s.onclick`.
The generic attribute helper is unchanged.

The internal `__ladybirdDispatch` media path receives that bridge key/raw-text
token. Its old two-argument form does not replay media raw text without a token.
Generic image, object and SVG compact listeners/raw click handlers keep their
existing path. Native handler replacement, null and noncallable assignment
therefore cannot revive retained raw content. If a callback clears itself,
sets a new raw attribute and forces DOM replay through a native property read,
the receipt suppresses raw text for that same click even though a new handler
record now exists. A later click can run the new raw fallback; removing the
attribute removes that fallback.

The preserved raw fallback still uses `Function("event", body)` with a plain
compact Event. It is the existing approximation, not completed inline handler
compilation or source-equivalent raw cancellation/scope semantics. Native
`onclick` assignment uses actual EventTarget processing independently of this
fallback. Real raw element compilation still requires Document/form/element
ObjectEnvironments, appropriate source ownership and CSP/parse handling.

## Eight focused cases and baseline scope

| Test file / case | Covered behavior |
| --- | --- |
| `browserjs/media_element_click_handler_host_test.v`: native descriptors/brands | Audio/video defaults, native names/lengths and descriptors; receiver checks before replay or traps |
| Native owner/slot/legacy rules | Actual synthetic Event dispatch, callback identity and owner; replacement/null/reactivation order, false versus zero, primitive clearing, object/Proxy handling and context cleanup |
| `main_media_click_handler_owner_test.v`: Page order/cancellation | Parsed video and pre-insertion created audio handlers; one trusted before/handler/after sequence, Page cancellation, mutation replay and no duplicate compact delivery |
| Native self-replacement/null/object | Replacement applies to the next event, null/noncallable/primitive clearing suppresses stale raw despite retained HTML attributes, no noncallable property reads |
| Self-set raw/removal | Callback clears its own slot, installs a new raw record and forces DOM replay; same-click raw is suppressed, next-click current raw runs, removal clears fallback |
| Untouched raw/generic preservation | Original media raw fallback remains uncompiled and hands off to IDL, Page scripting disable suppresses it, generic image/object/SVG listeners and raw handlers stay single |
| `page/media_click_replay_receipt_test.v`: outer/nested receipt | Outer owner survives nested click and dblclick delivery, consumed receipt, owner identity and same-Event redispatch reset |
| Throw/cancellation/empty release | Self-clearing callback throws or cancels yet records its owner, dropped/no-hit release clears stale state, unsupported raw has an empty processed-owner receipt |

The unchanged parent baseline compiles only the two native/main files and
fails all six functions at their intended runtime assertions. The four main
functions stop at missing `onclick` descriptor/default guards; the baseline
does not establish failure of their later actual Page sequence assertions.
The two Page tests require the new receipt APIs and are not compiled or run on
that baseline. Their exact bytes are still included in its snapshot. The
baseline has no compiler failures or runtime panics. The same final bytes pass
all eight focused cases after implementation, including the Page receipt tests.

Final test SHA256 values:

- Native: `9cf344b31c64788db7c29fabca9142820f167d1f0a658832114340e64b297dfb`.
- Main: `d7033565682b6ae254142258bbcfe837088ced2997dcffa0e6482912288b3b38`.
- Page: `9c90f93db267a20cc42fca7817db90fabba242bca62ae0c84464fdc36f755894`.

| Verification | Manifest under `Build/audit-fixes/` | SHA256 | Result |
| --- | --- | --- | --- |
| Unchanged parent baseline | `native-media-click-handler-baseline-manifest.json` | `08218d39689a005c55a3b1c7c21079b9d8292dbe12a091c210e4ad3ef92f9832` | Two files compile; six native/main functions fail at runtime; Page tests unexecuted |
| Focused final tests | `native-media-click-handler-focused-manifest.json` | `15251392af30a11d7c452729e03aaa8e1f91fc48b04ee80eb53c25de0e199f68` | Three files/eight cases pass with identical test bytes |
| Selected default GC | `native-media-click-handler-default-manifest.json` | `06723c5645bd3a9d1de5720f697eb858b6c43165eb5c1dd884a5f66b8ff75b35` | 22/22 files pass on unchanged committed inputs |
| Selected GC disabled | `native-media-click-handler-gc-none-manifest.json` | `698fa12f0172fd9f0639df314906727e521eb026bd2c155c0085ec845051a025` | 22/22 files pass on unchanged committed inputs |
| Separate optimized preflight | `native-media-click-handler-production-preflight-verified/manifest.json` | `f5be3a1b463c98be28b2f415b9ad995842737254c74755bf3a73369846fefe78` | Ordinary GC-disabled optimized probe passes; no browser bundle, signed startup or captures at this stage |
| Production | `native-media-click-handler-production-verified/manifest.json` | `8ac19c906339384b5813db4af5ffd69a95398665dda4f8c063f443187c5813c2` | Active optimized probe, signed startup, two exact pages, 14 exact SVG pairs and all 11 smoke cases pass |

Both complete selected runs include the existing 66-case main regression,
earlier media handler/listener/play integrations, native EventTarget/Window,
actual Page pointer/input and DOM handler identity/invocation/legacy dispatch
tests. The second run adds `-gc none`; both complete snapshots are identical.
All final runs retain unchanged inputs and final test bytes. Frozen full-run
snapshots contain 4,978 input hashes and 25
source references; production records 4,978 input hashes.

The ordinary `-prod -gc none` active probe uses the exact frozen compact
bootstrap and seven extracted helpers with native owners. Its standalone
public DOM fixture covers the exercised attributes, text, created media,
removal and movement. It does not reproduce full `apply_javascript_state()`;
the four main tests and browser captures supply their separate replay coverage.
The separate successful optimized preflight checks and runs that same final
probe without building a browser bundle or establishing signed startup/capture
evidence. The final production stage builds the browser, verifies its signature
and passes startup. Both 800x600 click pages and all 14 SVG preservation pairs are
pixel-exact. All 11 configured smoke cases pass, eight exactly, with existing
fuzzy tolerances retained for the other three. The complete production run
records 13 successful steps, verifies 104
current artifacts and 851 previous evidence artifacts,
and retains an unchanged binary.

Consolidated evidence: `Build/audit-fixes/native-media-click-handler-evidence.json`, SHA256 `b6cfaa3945616335650fee936b7c09ae1fb09ae7677e1d41bf54702ea8de5bf8`.
Production completion receipt: `Build/audit-fixes/native-media-click-handler-production-verified/completion-receipt.json`, SHA256
`e972f14b1a479a718421c6602bba9728b1b625cf23dc9f8b77101e0621ead9ac`.
Production binary SHA256: `419edb21e95d01211865e7648edb2cb59a0739d0e6de6ced6d10ffcd76e4759a`.

## Retained production fixture diagnostics

Four unsuccessful optimized-preflight preparations remain immutable
diagnostics. The first three stopped in the V checker before optimized build
or runtime execution; the fourth compiled and ran but stopped at a reused
pointer-fixture assertion. None built a browser bundle or supplies signed startup
or screenshot evidence. Their frozen tracked implementation and focused-test
bytes match the final feature; the corrections concern the ignored probe
fixture, not the native handler or dispatch algorithms.

The narrow public DOM fixture reused values for a nested attribute guard
inside its element-map guard. The V checker rejected the local binding and
reported parser cascades. No production build or runtime step ran.

V -check only; optimized build, active runtime, bundle, signed startup and
captures were not reached.

[Original preflight manifest](../../Build/audit-fixes/native-media-click-handler-production-preflight/manifest.json)
SHA256 `a98054921df9e7ad46f1feef5bd0b9cc0e52dcdf443dea97d2740209addb3d5b`.

The narrow fixture reused its decoded root value as a log-loop iteration
binding. The V checker rejected that local name and reported parser
cascades. No production build or runtime step ran.

V -check only; optimized build, active runtime, bundle, signed startup and
captures were not reached.

[Validated fixture preflight manifest](../../Build/audit-fixes/native-media-click-handler-production-preflight-validated/manifest.json)
SHA256 `9c10642ece22f4275b41f66dabd6150678d7fbbe88573d0594663799fb325284`.

The narrow fixture assigned its immutable Document parameter into the
mutable BrowserApp.document field in a struct literal. The V checker stopped
at that fixture assignment. No production build or runtime step ran.

V -check only; optimized build, active runtime, bundle, signed startup and
captures were not reached.

[Complete fixture preflight manifest](../../Build/audit-fixes/native-media-click-handler-production-preflight-complete/manifest.json)
SHA256 `601be356508bfd7315092954e55068de15001ef3491ba4ee9d8f3234fc783c63`.

The reused pointer fixture incorrectly expected the entire listener list to
be empty after clearing onpointerdown. This click slice gives the same raw
element an independent onclick slot, which remains present. The corrected
fixture checks removal of the pointerdown slot/listener while preserving the
raw click slot. V -check and the ordinary optimized GC-disabled build
passed; only this fixture assertion failed at runtime.

V -check and ordinary -prod -gc none build passed; active probe stopped at a
fixture assertion. Bundle, signed startup and captures were not reached.

[Ready fixture preflight manifest](../../Build/audit-fixes/native-media-click-handler-production-preflight-ready/manifest.json)
SHA256 `3485a4e4486fedde69b91c41c2d0989b53980458388765adc93f0630965c65f8`.

The separately recorded successful optimized preflight uses the final
production probe bytes and supplies its own ordinary GC-disabled active checks.
It remains distinct from the final signed-browser startup and screenshot
verification above. The four failures are not counted as successful feature
or production verification.

The earlier checked full production run passed the V precheck, browser
build, active optimized probe, signature verification and startup. Its first
order page was pixel-exact. It captured the second replay page and stopped at
that page's pixel check; SVG preservation and screenshot smoke cases were not
reached in this run.

The labeled signed-browser diagnostic reported only the third of ten checks
false. The observed order was `handler,before,after`; old/new raw counts,
ID-less owner behavior and generic image/object/SVG counts were correct.
The parser had activated the raw onclick listener before script added ordinary
listeners. IDL replacement preserved that initial slot, so the page's expected
`before,handler,after` order was incorrect. Changing that expectation alone
made all ten checks true and produced a pixel-exact diagnostic capture. The
tracked feature and focused tests retain their frozen bytes.

[Failed checked production manifest](../../Build/audit-fixes/native-media-click-handler-production-checked/manifest.json)
SHA256 `e050e2d7085c6b5d6b455d30343cd6cc7868f18cc8ea34e4b60eb42974b66be0`.

[Replay-page diagnostic](../../Build/audit-fixes/native-media-click-handler-replay-diagnostic/manifest.json)
SHA256 `0057fe9377095d2f96afafd5ab220e92573a649e32c46dc3e48cbd8e0ccb2faa`.

The checked optimized preflight preceding that failed full run had passed all
three ordinary optimized-probe stages. It supplies optimized-only history;
the later corrected full run supplies completed signed-browser and capture
verification above.

[Historical checked optimized preflight](../../Build/audit-fixes/native-media-click-handler-production-preflight-checked/manifest.json)
SHA256 `26cd0cb963e425de7ab91f8e56b037a177f6dbbdff829be079923191506618a4`.

The failed full run and its isolated corrected capture remain diagnostic
provenance. Neither is counted as the final 13-step production verification.

## Inventory and remaining boundaries

The read-only current inventory is `Build/audit-fixes/source-current-module-loc-8c567b08.json`, SHA256
`1aef0cc514a53f73405c61efa11b1400cccb54024aecb7b7479a56cdf63a458b`. 78 owners, 2,210 assigned files, 432,874 implementation and 158,957 test V LOC (DOM: 43,499 implementation and 4,694 test V LOC; Page: 6,855 implementation and 2,843 test V LOC; HTML: 69,630 implementation and 40,284 test V LOC). All assigned file hashes and physical line counts were independently recomputed and verified.
DOM receipt implementation and the Page implementation/new test affect their
assigned package counts. Root/browser support and its tests remain excluded
under the established convention. The later inventory-only record updates
current physical counts separately from this feature's evidence documentation.
Historical pointer-handler audit/evidence bytes and their contemporaneous
counts remain preserved.

Page fixtures enter translated dispatch through explicit actual DOM targets;
they do not establish Cocoa/AppKit transport, physical hit testing or complete
MouseEvent/PointerEvent JavaScript fields. Full HTMLElement/audio/video
prototype placement, other global/input handler attributes, raw inline element
compilation, foreign engine realms and automatic weak ownership remain open.
The browser still uses JavaScriptCore. Full media resource/readiness/seek/MSE,
enough-data autoplay, Permissions Policy and physical playback/decoding remain
separate work. Pinned upstream load step 4 still leaves the already-captured
batches of canceled tasks pending; this slice does not complete that FIXME.
The audit ledger remains 32 fixed / 25 partial / 9 open.
