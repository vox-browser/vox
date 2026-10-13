# Native media press/release handler attributes

Script-assigned `onpointerdown`, `onpointerup`, `onmousedown` and `onmouseup`
now reach the actual HTML audio/video owner's DOM event-handler map. These
properties previously became unrelated JavaScript own properties on compact
wrappers and missed the translated Page's real pointer/mouse dispatch.
Implementation commit: `9ee0685bbf286a1c1447df5e090eb1fb08df46ac`.
Unchanged parent: `e7c007a63feca63c842c61d9251079e7845e280c`.
Upstream source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

The implementation adds four names to the existing selected handler list and
updates the compact prototype's explanatory comment. It uses the completed
native handler accessors and existing Page/EventHandler dispatch; it adds no
pointer, mouse or click dispatcher and does not change compact click replay.
The earlier 23 media-event attributes remain installed. The compact prototype
therefore exposes 27 selected handler attributes, without completing the
HTMLElement/audio/video hierarchy or the rest of GlobalEventHandlers.

## Source attributes and actual owner

`DOM/EventHandler.idl` declares `onmousedown` and `onmouseup` in
GlobalEventHandlers. `UIEvents/PointerEventHandlers.idl` extends that same mixin
with `onpointerdown` and `onpointerup`. The pinned
`HTML/GlobalEventHandlers.{h,cpp}` accessors delegate to the actual EventTarget's
handler map, and `DOM/EventTarget.cpp` owns activation, replacement and removal.

The four native accessor pairs have enumerable/configurable descriptors,
getter names `get on...` and length zero, and setter names `set on...` and length
one. Parsed and script-created audio/video wrappers inherit them. Registered
receiver checks precede replay, callback conversion and author Proxy traps;
fake prototype objects, primitives and Proxy-wrapped media fail with the
existing HTMLMediaElement TypeError. Unset handlers return null, and assigning
them does not create an own property.

The existing shared legacy callback conversion is reused. Functions and
callable Proxies retain identity and execute with the actual media wrapper as
`this`. Any noncallable object or Proxy also retains identity but silently
returns undefined without property reads. Primitives, null and undefined
clear the nullable handler. Ordinary listener objects retain their separate
`handleEvent` path. Replacement preserves the activated handler listener's
position; null removes it, and later reactivation appends a new slot. Repeated
assignment does not add duplicates. Only the exact boolean false applies the
handler cancellation rule; a return value of zero is not coerced to false.

## Page press/release behavior

The integration fixtures enter actual `Page.handle_mousedown` and
`Page.handle_mouseup` using `InputTarget.from_node` on real DOM elements. The
existing EventHandler creates and dispatches actual trusted pointer/mouse
records. With uncanceled handlers, the observed order is
`pointerdown,mousedown,pointerup,mouseup,click` for both parsed video and created
audio. Handler arguments retain the live Event wrapper, target/currentTarget,
owning Window current-event state and media receiver identity. Saved
currentTarget clears and Window's current event restores after delivery.

BrowserApp's existing compact click replay runs after that actual release.
The media handlers and ordinary native click listener are absent from the
compact listener table, so invoking the real replay helper adds no duplicate
delivery. Script mutations made in the native click callback reach the owning
document through the existing replay path.

Returning false from the actual `onpointerdown` cancels that pointer event and
suppresses compatibility mousedown/mouseup through release. Pointerup and click
still dispatch, and the uncanceled click leaves `last_click_allowed` true.
Clearing and replacing the pointerdown handler restores the full sequence on
the next press. Returning false from `onmouseup` cancels the compatibility
mouseup record without preventing the later click or its Page flag. These
rules match the existing pinned Page/EventHandler translation and
`page/dom_pointer_events_test.v`; this feature exposes them through ordinary
media handler properties rather than implementing new cancellation machinery.

Created audio receives a handler before DOM insertion and retains its actual
DOM/EventTarget owner after insertion. Replacement keeps its position between
two ordinary pointerup listeners; null removes only the handler slot. The
actual owning Page's scripting flag suppresses callback execution and permits
it again after reenablement. A parsed raw `onpointerdown` string stays
uncompiled; IDL replacement uses its existing slot without changing the
content attribute, and null clears the slot while preserving that attribute.

The fixtures supply explicit DOM targets, including a disconnected created
element to exercise owner identity. They do not establish physical hit testing,
Cocoa/AppKit transport or the full MouseEvent/PointerEvent JavaScript interface.

## Five focused cases and frozen evidence

| Test file / case | Covered behavior |
| --- | --- |
| `browserjs/media_element_pointer_handler_host_test.v`: descriptors/brands | All four descriptors and default null values on audio/video; native names/lengths; brand errors precede replay, Proxy traps and conversion |
| Native owner/slot/legacy rules | Exact callback/owner/Event identity; replacement, null and reactivation order; false versus zero; primitive clearing; silent noncallable objects/Proxies; actual callable Proxy invocation and balanced contexts |
| `main_media_pointer_handler_owner_test.v`: Page sequence/replay | Parsed video and created audio receive one trusted press/release/click sequence before compact replay; replay adds nothing; currentTarget/current-event cleanup and callback mutation survive |
| Pointerdown cancellation/next press | False pointerdown suppresses compatibility mouse delivery until release while click remains; null/replacement restores the full next sequence |
| Created owner/gate/raw content | Pre-insertion identity and handler slot order; null/reactivation; actual Page scripting gate; false mouseup preserves click; raw pointer attribute remains uncompiled and independent of IDL assignment |

The final unchanged parent baseline compiles both files and fails all five
new functions at their intended runtime assertions. It has no compiler failures
or runtime panics. Both native cases and all three integration cases explicitly
guard missing descriptors/default-null behavior, so this final baseline
does not mistake a fixture exception for proof of the binding gap. Its complete
snapshot remains unchanged, including 4,974 tracked/new-test input hashes and
21 pinned source-reference hashes.

The initial native context helper captured the address of its local Runtime
pointer variable (`voidptr(&runtime)`) rather than the owning heap Runtime
pointer (`voidptr(runtime)`). The initial focused run passed the main integration
file but failed the native owner/legacy-rule case when this helper ran from a
handler. Isolated diagnostics exposed a spurious `JavaScript runtime is closed`
exception from that invalid test pointer, not a failure of the media host's
handler algorithm. Faithful checks with precreated Boolean values and a separate
correct-pointer C Boolean helper produced true guards, zero reported exceptions
and balanced zero script/callback depths. The native fixture's pointer capture
was corrected without changing the main tests or proposed host implementation.

The intermediate focused run then passed its JavaScript guard checks but failed
the final V assertion in the native owner/legacy-rule case. That fixture's
direct V loop supplied `dom.Event.create()`, an actual trusted internal record,
while its callback predicate deliberately expected the untrusted Event used by
script construction. The loop now uses `dom.Event.construct_impl()` to match
that constructor-based expectation. This corrects the fixture's input; it does
not alter host cancellation, trust state or handler algorithms. The main test
continues to exercise genuine trusted records through the actual Page path.

The initial and intermediate baseline/focused manifests, logs and isolated
probes remain separately preserved. The earlier baselines stopped at the
missing-descriptor assertions before exercising the later faulty fixture inputs;
they used earlier native test bytes. Those runs and diagnostic probes are not
counted as final-byte feature validation. The unchanged source was restored
again for the final baseline before rerunning focused verification with the
final frozen bytes.

The final new-file bytes were frozen before the final baseline and pass the current
V formatter:

- Native: `05400aa239ec8ff5b9817f64204463b1fe6a737a985225c4869aa05e77294db5`.
- Main: `e0828b1497de7ed184ce543f55a65a0de77b7e8b8752f81841de925251329475`.

The earlier native fixture SHA256 remains recorded in its initial manifests:
`8e58bbf0131ca4ac0299dc0ee9bfd17a960c616e5af1812e218767e06f5f2bb9`.
The intermediate pointer-corrected fixture hash remains in its corresponding
manifests:
`4336e9dddb80718ae62d65078c0a5c270986332be9e225ee02410cc1f54b1d98`.

All five cases pass in the final focused run with the exact final parent
baseline test bytes. The focused run precedes the implementation commit; all
four changed implementation/test hashes match committed `9ee0685b`.

| Run | Result | Manifest under `Build/audit-fixes` | SHA256 |
| --- | --- | --- | --- |
| Initial baseline diagnostic | Missing-descriptor assertions fail before the faulty context helper; earlier native fixture bytes | `native-media-pointer-handler-baseline-manifest.json` | `24c3046a68ebe4ed5ba55b892fb68b9136a57869a7ddbc22162d9d0e20dd25a4` |
| Initial focused diagnostic | Main file passes; native helper pointer fault fails its owner/legacy-rule case; not final-byte feature validation | `native-media-pointer-handler-focused-manifest.json` | `35400a083a856b677374d3f3cf329478a95d89400444835fcbd1c2e36d0650c3` |
| Intermediate baseline diagnostic | Missing-descriptor assertions fail with pointer-corrected fixture bytes; not the final trust-corrected bytes | `native-media-pointer-handler-baseline-corrected-manifest.json` | `45390ab1b8d672e1d0b9457c81bb5727343ad019de14776bf23822e47b1d41e4` |
| Intermediate focused diagnostic | JavaScript checks pass; direct V Event input violates the fixture's untrusted-event expectation; main file passes | `native-media-pointer-handler-focused-corrected-manifest.json` | `6b39eea4a454eaf930fda3627a9ff4707b3251c399a51e578078012eb0116625` |
| Final unchanged parent baseline | Both files compile; five runtime failures; no compiler errors/panics; unchanged final-byte snapshot | `native-media-pointer-handler-baseline-final-manifest.json` | `d9431df70ede7c7f89d253f7f34fd49721e360edc37b4eb155f8841148dd0104` |
| Corrected focused run | Both files and all five cases pass with byte-identical final tests | `native-media-pointer-handler-focused-final-manifest.json` | `685286d0723afe45939d19e4bece996a43d4c04b1a3f38990aecfd8233c2da67` |
| Selected default-GC run | 18/18 files pass; unchanged committed snapshot | `native-media-pointer-handler-default-manifest.json` | `2335850e536a69e8a2200f6a140e6a9d7fdb41504162f0ec6bbf89d602882959` |
| Selected GC-disabled run | 18/18 files pass; unchanged committed snapshot | `native-media-pointer-handler-gc-none-manifest.json` | `5dc84cc52f69c84374cf983ab31340eb98c611e29b603702846f0acdb5dd6477` |
| Production verification | Signed build/probe/startup; two exact pages; 14 exact SVG pairs; 11/11 smoke cases pass | `native-media-pointer-handler-production-complete/manifest.json` | `c90cb472ac81f7aff7ccd2ff5ed77c4233113f2e3b49961af18923ec8574abe2` |

Final baseline log SHA256:
`8a1c89f9b15e3939ab9dc21183e34112775c978ea11ff21c16d2d0f87a8bd351`.
Initial baseline log SHA256:
`7372c37d8a2538f6e892f76ae2a223fe420c78b7b387d68ba46edf9d13ec5871`.
Initial focused log SHA256:
`b56f50857e238fb2ddbfdd3c25429020df79aad9831ca1c40292898a5c94d327`.
Intermediate baseline log SHA256:
`4e24dc6c96cf2493c8c074e560a5209518665a620c4da2be5806409428cbcf3b`.
Intermediate focused log SHA256:
`93e5e5261cb9e666a1f672f8f8c1ba993edeb89912094f00c978f3477d30ea40`.
The isolated probes and build/runtime logs remain under
`Build/audit-fixes/native-media-pointer-handler-diagnostic/`; they diagnose the
test context helper and are separate from the frozen final test runs.
The final baseline uses the preserved V dispatcher with
`-old-compiler -enable-globals`, `VJOBS=2` and a unique ignored compiler scratch
directory. Both complete selected runs pass 18/18 files on clean committed
`9ee0685b`, including the existing 66-case main regression, the earlier handler
and listener integrations, native EventTarget/Window callers, actual Page
pointer/input tests and DOM handler identity/invocation. The GC-disabled run
adds `-gc none`. Both complete snapshots remain identical, and all four final
test runs retain unchanged inputs, exact final test bytes and frozen source/
toolchain hashes: 4,974 input hashes and
21 source references per run.

The ordinary `-prod -gc none` probe embeds the exact frozen
`javascript_bootstrap()` and uses actual native media/EventTarget hosts with
active checks. The signed browser builds, verifies its signature and passes
startup. Both 800x600 handler pages are pixel-exact against their reference;
all 14 SVG preservation pairs are exact. All 11 configured smoke cases pass,
eight exactly, with the existing fuzzy tolerances retained for the others.
The standalone probe exercises the compact bootstrap/native-owner route;
the Page fixtures and browser captures supply their separate integration
coverage. None establishes Cocoa transport or full input-interface parity.

The completed production manifest records all 13 successful steps and identical
4,974-file before/after snapshots. The binary remains
unchanged; 102 current artifact hashes and 592 previous evidence
artifact hashes verify. Earlier media evidence and the fixture diagnostics
retain their original bytes and scope. Production completion receipt:
`Build/audit-fixes/native-media-pointer-handler-production-complete/completion-receipt.json`, SHA256
`0dc014eaa71c04cbc3472e581d0421674453df0fe33d61807ea91a4bbf266202`.
Production binary SHA256: `2e41641a7f3435bd5597cc80e13a91b5838bd2a266e8fb14aae893c7a22cb1f4`.
Consolidated evidence: `Build/audit-fixes/native-media-pointer-handler-evidence.json`, SHA256
`731e05084351bfaf02fb971d45af92d992890d2b989420bcbb7dfbbcb267e2d7`.

## Retained boundaries and inventory

Raw element compilation still requires the source Document/form/element
ObjectEnvironment chain. The current native compiler accepts its genuine
owning Window only, so this feature preserves raw media strings and does not
fabricate a global-only Function replacement. Media `onclick` and the compact
copied raw-click fallback are untouched. Other pointer/mouse attributes,
pointer capture, touch/multiple-pointer behavior, complete input interfaces,
full prototype placement and general nonmedia handler routing remain open.

Foreign-engine-realm discovery and cross-realm callback parity remain open;
retained JavaScript values have explicit runtime roots rather than automatic
weak ownership. The pinned media load step 4 still leaves promises captured by
canceled tasks pending. Full resource/readiness/seek/MSE, enough-data autoplay,
Permissions Policy, physical playback/decoding and arbitrary raw UTF16
MediaError storage remain separate work. The browser continues to use
JavaScriptCore.

Physical inventory: `Build/audit-fixes/source-current-module-loc-9ee0685b.json`, SHA256 `e8b19228fb5b400542347570c7198c7314e675bdee14a05ac890e947a31e38da`.
Inventory counts: 78 owners, 2,209 assigned files, 432,825 implementation and 158,801 test V LOC (HTML: 69,630 implementation and 40,284 test V LOC); assigned package bytes and physical line counts remain unchanged. The changed implementation and tests are
root/browser support excluded under the established package convention;
physical LOC does not measure behavioral parity. The historical ledger remains
**32 fixed / 25 partial / 9 open**. Earlier media Promise, ordinary listener and
handler-attribute evidence retains its original bytes, hashes and scope.

One ignored exact-C diagnostic probe preparation also failed an import-order
parse check before compilation/runtime. Its corrected copy passed. These
probe-preparation diagnostics remain outside completed feature verification.

Earlier unsuccessful production attempts remain separate diagnostics.

The first two attempts stopped in the V precheck before any browser build or
probe execution. The first fixture reused the Page variable name `owner` for
a loop value; the second fixture read private EventHandler fields. Giving the
Page a distinct variable name and asserting public behavior corrected those
preparations.

The third attempt passed the precheck, built the ad-hoc signed browser bundle
and compiled the optimized probe, then failed an active runtime guard. Its
standalone setup omitted the existing `install_window_current_event_binding()`.
The trace order, saved-event cleanup and replacement checks were correct, but
the omitted getter left `window.event` undefined during callbacks. The actual
browser loader already installs that binding in `main.v`; it required no
implementation change. A separate optimized diagnostic that installed the
binding passed all active checks. The subsequent completed production attempt
uses that corrected setup and supplies the successful verification above.

The retained unsuccessful manifests are:

- `Build/audit-fixes/native-media-pointer-handler-production/manifest.json`: V precheck failed; build and runtime checks were not reached. SHA256
  `6127b713c445fad5a20a50333907eff49a0032fff896213b75066577f5af8891`.
- `Build/audit-fixes/native-media-pointer-handler-production-validated/manifest.json`: V precheck failed; build and runtime checks were not reached. SHA256
  `be613407ebef8b136de037aead6cebf1775f1b7439de9892b7e62bdc0a5115b6`.
- `Build/audit-fixes/native-media-pointer-handler-production-verified/manifest.json`: precheck, signed-bundle build and optimized probe compilation passed; active runtime guard failed. SHA256
  `73038da41c24cae7a0e793199158cc68ae3ed722178fdef26d333fae8dcfcad9`.

These attempts are not counted as completed production verification.
