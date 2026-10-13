# Native media event-handler attributes

Ordinary `onplay`, `onpause`, `onloadeddata` and the other selected media
handler attributes now reach the actual audio/video owner's DOM event-handler
map through native accessors. The compact wrappers previously retained these
assignments as plain JavaScript properties, so media model events could reach
ordinary listeners while bypassing the corresponding handler property.
Implementation commit: `60ef4bb2462dca7eb25e1b926f4857b685c6b552`.
Unchanged parent: `19ab28c8fd0a2cbfb85449ee46105cd836f7ecca`.
Upstream source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

This is the selected media subset of GlobalEventHandlers on the current compact
HTMLMediaElement prototype. General HTMLElement handler descriptors, including
media `onclick`, the complete HTMLElement/audio/video prototype hierarchy and
raw element handler compilation remain open.

## Native attributes and shared callback conversion

The installed HTMLMediaElement prototype exposes these 23 enumerable,
configurable attributes with native getter/setter names and lengths 0/1:
`onabort`, `oncanplay`, `oncanplaythrough`, `ondurationchange`,
`onemptied`, `onended`, `onerror`, `onloadeddata`, `onloadedmetadata`,
`onloadstart`, `onpause`, `onplay`, `onplaying`, `onprogress`,
`onratechange`, `onresize`, `onseeked`, `onseeking`, `onstalled`,
`onsuspend`, `ontimeupdate`, `onvolumechange` and `onwaiting`.
Parsed and script-created HTML audio/video wrappers inherit these descriptors
and keep their actual native DOM/EventTarget identity after insertion.

Receiver checks precede replay and callback conversion. Fake prototype
instances, primitives and a Proxy around a genuine wrapper raise the existing
typed HTMLMediaElement brand error without author Proxy traps, argument
coercion or replay. Getters replay pending DOM mutations and retrieve the
model-owned handler. Setters retain the original callback value and its
incumbent callback settings before replay, then update the actual DOM handler
slot. Valid registration does not create an own handler property.

The shared EventHandler conversion now follows
`DOM/EventHandler.idl` and the source generator's
`[LegacyTreatNonObjectAsNull]` rule. Any object, including a noncallable object
or Proxy, is accepted and retained by identity. Primitives, null and undefined
clear the nullable handler. The previous callable-only TypeError check was a
translation deviation. Its old Window regression assertion is corrected to
require acceptance, getter identity and silent dispatch of a noncallable
`window.onload` value; the earlier identity, cancellation and primitive-clear
assertions remain.

For a retained noncallable handler, WebIDL callback invocation returns
undefined before entering script/callback contexts, looking up `handleEvent`,
marking the document dirty or performing callback cleanup. This follows
`WebIDL/AbstractOperations.cpp:287–293`. It does not raise a TypeError.
Callable Proxy handlers use their actual call operation without an unrelated
property lookup. Ordinary EventListener objects continue using their existing
`handleEvent` invocation path.

DOM activation owns one listener slot per active handler. Replacement preserves
that slot's position relative to ordinary listeners. Clearing the handler
removes the slot; later reactivation appends a new slot. Repeated assignment
does not add duplicate listeners. Callbacks receive the live wrapper as
`this`, the actual Event as their argument, and the actual target/currentTarget
identity. A false return cancels a cancelable event. Saved currentTarget clears
after dispatch, and the owning Window's current event is restored.

Media `onerror` receives one Event argument, including when the actual record
is an ErrorEvent. The five-argument special signature belongs to the Window
error-handler path. The native media failure fixture verifies that the original
thrown JavaScript object reaches exception reporting unchanged and that a
later ordinary listener still executes. Actual Page scripting disablement
suppresses callback execution; runtime closure releases its engine roots and
makes retained native callback records return without reentering JavaScriptCore.

The source basis includes `DOM/EventTarget.cpp`,
`DOM/EventDispatcher.cpp`, `HTML/EventHandler.cpp`,
`HTML/GlobalEventHandlers.{h,cpp}`, `DOM/EventHandler.idl`,
`WebIDL/AbstractOperations.cpp` and
`Meta/Generators/libweb_bindings/to_idl_value.py:697–754`.
The existing media model owns event tasks and play Promise capabilities; this
slice connects its handler attributes to that machinery.

## Ten new focused cases

The native file supplies five cases, the independent shared-conversion file
one, and the ordinary compact integration file four. The integration calls use
ordinary inherited media properties rather than manually invoking prototype
accessors.

| File / case | Covered behavior |
| --- | --- |
| `browserjs/media_element_handler_host_test.v`: all descriptors / brands | All 23 metadata records and default null values on audio/video; native names/lengths; brand rejection before replay, Proxy traps or conversion |
| Native replacement / removal | Original callback identity, replacement listener order, null removal and reactivation order, one active slot, exact Event identity and false-return cancellation |
| Native legacy values / proxies | Primitive clearing; any-object identity; silent noncallable objects/Proxies with zero property reads or reports; actual callable Proxy invocation and cancellation |
| Native media error | Actual model failure delivers one trusted Event; original thrown object is reported once while a later listener runs; even an ErrorEvent keeps the media one-argument signature |
| Native Page gate / runtime closure | Actual Page scripting flag suppresses handlers; enabled callback has balanced owning contexts; closed runtime has no engine roots and retained DOM dispatch causes no reentry |
| `browserjs/event_handler_legacy_conversion_test.v`: independent shared setter | Existing setter/getter APIs retain any object and directly invoke the retained callback as undefined; no `handleEvent` or Proxy reads, no context/checkpoint/dirty entry; primitives remove the slot |
| `main_media_event_handler_owner_test.v`: parsed play | Ordinary parsed-video play/playing handlers precede fulfillment of two distinct real Promises; other audio stays silent; live trusted Event, current event and owner identity survive dispatch |
| Created audio / queued pause | Handlers installed before insertion follow the same actual owner; replacement before queued pause delivery retains slot order; pause handler and ordinary listener precede both rejections sharing one typed AbortError |
| Parsed/created readiness | Metadata, first-data and canplay handlers run only through actual owning media tasks in source order; registration and microtask checkpoints cannot deliver them early |
| Raw parsed content / IDL replacement | Raw element handler stays uncompiled and preserves source/content attribute; IDL replacement uses the same activated DOM slot without changing the attribute; null clears the map/listener while keeping the content attribute |

Parsed ready-media play order is `play,playing,first,second`. Created waiting
audio order includes the real model's poster/time transition:
`timeupdate,play,waiting,timeupdate,pause,listener,rejected,rejected`.
Readiness order is
`video:loadedmetadata,audio:loadedmetadata,video:loadeddata,video:canplay,audio:loadeddata,audio:canplay`.
The corrected implementation passes all ten cases with byte-identical tests.

## Frozen verification and retained diagnostics

The corrected parent baseline compiles all three files and fails all ten new
functions at runtime, without compiler failure or panic. Nine cases expose the
missing native handler route; the independent shared setter case reaches the
old callable-only rejection at its actual setter call. Its propagated error
is an actual JavaScript value exception, as retained in the log. The baseline
snapshot remains unchanged, including all 4,971 tracked/new-test input hashes.
The upstream checkout is clean at the source pin, with 14 source-reference
hashes and frozen compiler/native-archive hashes in the manifest.

An earlier baseline attempt retains two fixture diagnostics separately. The
native helper originally propagated Option-returning lookups from a
Result-returning fixture, causing a compiler error before its five cases
executed. The shared setup script originally ended with a Proxy assignment;
`evaluate_host` tried to stringify that result and hit the deliberately
throwing Proxy before the setter was tested. The corrected fixtures unwrap
both Options explicitly and finish the setup script with primitive 0.
The initial main integration file did compile and fail its four descriptor
assertions. That initial attempt is not the clean ten-case regression proof.

All final new-file bytes were frozen before the corrected baseline. The current
V formatter accepts them:
native `13cbdefaf474fa46baee8f2e4e2c48990ac4f11cebc2d060f2d15151dbb314e9`;
shared `00cae7a0f349d6eabf2b5d8d307b8d892b0a1bcbdca421abf151928474ba7b40`;
main `d3f38b0ac8741742350ed45c3dca62fed10d921bcf9e6b76023dffa045f44314`.

| Run | Result | Manifest under `Build/audit-fixes` | SHA256 |
| --- | --- | --- | --- |
| Initial fixture diagnostics | Native compiler failure; shared setup-coercion failure; four main runtime assertions fail | `native-media-handler-baseline-manifest.json` | `db2a79e0d10022e8c0790a11a7aca6b136b6e3f5f5ef68f671171f4c180b9ce6` |
| Corrected unchanged parent baseline | Three files compile; ten runtime failures; no panic; unchanged snapshot | `native-media-handler-baseline-corrected-manifest.json` | `53465df9be0755d6355f8909c89398e68f90352590bd7762dcc10123b410c7d0` |
| Corrected focused verification | `3/3 files, all ten cases pass; unchanged snapshot` | `native-media-handler-focused-manifest.json` | `581685c81b271d232afe2606a7de58481845314bc582d768502b7c25732ffe60` |
| Frozen selected default-GC batch | `24/24 files pass; unchanged committed snapshot` | `native-media-handler-default-manifest.json` | `187b1404fba9a06ea80047e2d43418ee4dc777f2d112c7a9bec74a7d0c3c1ee6` |
| Frozen selected GC-disabled batch | `24/24 files pass; unchanged committed snapshot` | `native-media-handler-gc-none-manifest.json` | `6b01efa67cb6a738d8301871edc6d5d3ec7bb815c0b08695fc24f33153659938` |
| Production verification | `Signed build/probe/startup, 2 exact pages, 14 exact SVG pairs and 11/11 smoke cases pass` | `native-media-handler-production/manifest.json` | `ac25ca8b08faca8b643ea6c6f906aaf2a357ebc539e419cb49d86e61928a6bda` |

Initial diagnostic log SHA256:
`94d3df14d4c361b7642bcb16fb8d0aed10e91367276d417f3d3c836229094e2b`.
Corrected baseline log SHA256:
`c702e3b95da66b201d35001bbe69398dc816890f6c246276251aed4e99038d55`.

The helper uses the preserved V dispatcher with
`-old-compiler -enable-globals`, `VJOBS=2` and unique ignored compiler
scratch directories. The selected batch contains 24 files covering the new
three, the existing main regression, listener/UI and play integrations,
Window and generic callback bindings, AbortSignal, DOM handler identity/
invocation/content hooks, and media play/load/pause/readiness model callers.
The GC-disabled command adds `-gc none`. Both batches pass on clean committed
`60ef4bb2`; their 4,971 input hashes and complete snapshots remain identical.
Source, compiler and native-archive hashes remain unchanged.

The ordinary `-prod -gc none` probe uses the byte-exact `javascript_bootstrap`
from `main.v` with the actual media/EventTarget hosts. Its active checks cover
all 23 descriptors and brands, parsed/created identity, handler-slot order and
cancellation, primitive clearing, noncallable identity and silent invocation,
callable Proxies, trusted model events, real Promise settlement and original
media error reporting. Window noncallable dispatch also verifies no property
reads, context entry, dirty flag or callback checkpoint.

Two browser pages exercise live handlers and pending-play/pause rejection
through the complete DOM replay path. Both viewports and all 14 SVG preservation
pairs are pixel-exact. All 11 configured smoke cases pass: eight are exact,
and the three fuzzy comparisons retain their earlier metrics. These model
fixtures do not establish physical decoding.

Production receipt: `Build/audit-fixes/native-media-handler-production/completion-receipt.json`, SHA256
`2fd7819e7beafe26ec0602b970fd6d102266d4ea605c3e45bbe4226915c4f131`.
Signed binary SHA256: `63b32578c51e8081778429f83d66d0e7e9e54e0d187e21dccac194bccaf30d2a`.
All 101 current artifacts and 365 prior artifact hashes verify. Earlier
source-error, native-play and ordinary-listener evidence, including diagnostic
attempts, remains intact.
Consolidated evidence: `Build/audit-fixes/native-media-handler-evidence.json`, SHA256
`4903a7137ef0c2364ebbd35e82e588097f3de62aa575e7746337d4548a0f030e`.

## Retained boundaries and inventory

Raw element event attributes already retain an uncompiled source record and
activated handler slot. The current engine adapter's inline compiler supports
the owning Window only. It cannot supply the source Document/form/element
ObjectEnvironment chain for an element handler. The raw-media regression
therefore keeps its getter null and source unchanged until an IDL assignment
replaces the value. This slice does not claim compilation of parsed
`<video onplay="...">`.

Only the listed media handlers are installed on the compact prototype.
General media `onclick` and other HTMLElement handler attributes, generic
nonmedia facade handler routing, the full inherited prototype hierarchy and
all associated interface placement remain separate work. Callback ownership
uses the runtime's actual document settings and stored callback context within
its JavaScriptCore context; automatic foreign-engine-realm discovery and
cross-realm callback parity remain open. Retained values have explicit runtime
roots; automatic weak ownership remains open.

The pinned source media load step 4 is still FIXME: promises already captured
by media tasks canceled by a later load are not immediately settled by the
cancellation path. Existing captured-batch pending behavior remains. This
slice does not replace the synchronous resource-selection model with the full
upstream asynchronous resource/readiness/seek/MSE machinery.

Enough-data autoplay, full Permissions Policy, physical playback/decoding and
arbitrary raw UTF16 MediaError storage also remain open. The browser continues
using JavaScriptCore. Physical inventory evidence:
`Build/audit-fixes/source-current-module-loc-60ef4bb2.json`, SHA256 `087ef5bb19a9b329c861227032f77769c3f552171b6a30ab496b2e37d4522a7b`; final physical counts
78 owners, 2,209 assigned files, 432,825 implementation V LOC and 158,801 test
V LOC (HTML: 69,630 / 40,284). Every assigned package hash remains unchanged. Root/browser support remains excluded under the
established module convention; physical LOC is not behavioral parity.
The historical ledger stays **32 fixed / 25 partial / 9 open**.

Previous media Promise, ordinary listener and screenshot evidence retains its
original bytes, hashes, scope and conclusions. This document records the
subsequent handler-attribute slice without rewriting older descriptions of
that then-open boundary.


The new tests and common host file pass the current formatter. Remaining
Darwin-file formatter suggestions all predate this slice; the comparison is
retained under `Build/audit-fixes/native-media-handler-format-review/`.
The initial production Cargo freshness preflight lacked the required PATH and
failed before rustc ran. The corrected preflight passed; all three cached native
archives retain identical hashes before and after production verification.
