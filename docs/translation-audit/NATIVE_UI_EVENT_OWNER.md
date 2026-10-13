# Native UIEvent owner binding

The browser now exposes `UIEvent` in an actual Window-owned runtime and binds
its constructor, inherited prototype, `view`, `detail`, `which` and
`initUIEvent()` to actual DOM records. Previously native UI-family events
reached JavaScript only through the shared base Event wrapper, without these
inherited members. Implementation: `d1b86d815389d0a9c53802b1b40257ac0994a6da`; parent: `2fd1701b5f8e0623f6c236c4186430b1a2066819`.
Upstream pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

`UIEvents/UIEvent.{idl,h,cpp}` defines the constructor, nullable WindowProxy
view, signed-long detail, virtual unsigned-long which and legacy initializer.
`MouseEvent.h`, `KeyboardEvent.h` and `HTML/DragEvent.h` establish the which
overrides and inherited families. Generated WebIDL dictionary and operation
conversion follows `Meta/Generators/libweb_bindings/{context,to_idl_value,operations}.py`.
The V record algorithms in `dom/ui_events.v` are reused; this slice changes
browser binding and adds no Page/input dispatch algorithm.

## Actual records, exposure and initialization

The constructor wrapper delegates to a native backend and creates a genuine
untrusted `dom.UIEvent` record. `UIEvent` inherits Event, its prototype inherits
Event.prototype, and constructor subclasses keep their requested prototype.
The three getters and `initUIEvent` are actual JSC native functions with
source names, lengths zero/one and no construct behavior. Descriptors retain
the IDL enumerability/configurability and legacy method writability; each
event retains the existing nonconfigurable own `isTrusted` getter.

Exposure requires attached settings with an actual Window global. An unbound
runtime initially exposes no UIEvent; reinstalling after Window attachment
adds it to the existing Event binding. The original Event constructor and
actual JSC global are captured, so replacing Event or the script-visible
globalThis property before that upgrade cannot change the native parent or
redirect installation. The upgrade fixture uses its own Document/Window/
settings owner. Repeated installation preserves constructor identity.

Native UIEvent, MouseEvent, PointerEvent, KeyboardEvent, CompositionEvent,
FocusEvent, InputEvent, TextEvent, WheelEvent and DragEvent records receive
the retained UIEvent prototype while concrete subclass bindings remain open.
Existing wrapper caching preserves each actual record's JavaScript identity
and survives replacing the exposed UIEvent global. Getters read current
native fields rather than copied event data. The manual which dispatch
preserves the upstream virtual result: mouse/pointer/wheel/drag use
MouseEvent's button-plus-one result, keyboard uses keyCode, and the remaining
UI families return zero. Ordinary base Event and specialized existing wrapper
providers retain their prior behavior.

Constructor conversion reads the required DOMString type, validates the
optional dictionary, then reads bubbles/cancelable/composed and detail/view
in inherited and lexical order. Detail uses the signed 32-bit WebIDL long
conversion, including truncation/modulo, zero for NaN/infinities, rejection
of BigInt/Symbol and preservation of the original thrown object. Invalid
receivers and Proxy wrappers fail before author coercions or property traps.

`initUIEvent` checks receiver brand before required arity, then converts
type/bubbles/cancelable/view/detail in positional order. Conversion must
complete before any initializer mutation. Those conversions still run during
dispatch, while the existing core dispatched guard prevents record changes.
After dispatch, initialization resets type, trust, target and cancellation/
propagation state plus view/detail, while preserving composed and timestamp.

## Owner-local view adaptation

Null and undefined views map to null. A supplied non-null view must be the
actual JSC global of the runtime's owning Window; the binding stores that
Window's known native WindowProxy. Getters recognize only that same proxy or
the existing owning-Window fallback pointer and return the actual global.
Ordinary objects, Proxy(global) and other Window wrappers are rejected without
invoking Proxy traps. Unknown non-null native views raise an error rather than
being silently mapped to a different Window.

This is an explicit adapter restriction. Upstream accepts any genuine
WindowProxy, including another Window; foreign-view and cross-realm wrapper
support are not established here. No opaque WindowProxy is cast to EventTarget
or replaced by a fabricated JavaScript object.

## Six focused cases and immutable verification

| Focused file / case | Coverage |
| --- | --- |
| `browserjs/ui_event_binding_test.v`: exposure/metadata/defaults | Window-only exposure, later owner attachment, original parent/global stability, native accessor/method metadata and nonconstructability, subclasses, actual constructor record and view identity |
| Dictionary/conversion | Member order, signed-long boundaries, defaults, BigInt/Symbol rejection, original thrown-object identity and owner-local view rejection |
| Brand/legacy initializer | Proxy/invalid receiver checks before coercions; positional conversion, failed conversion without outer initialization and legacy state changes |
| Native family/dispatch | All ten native families, wrapper caching, dynamic which/live data, captured prototype after global replacement, conversion during dispatch without mutation, post-dispatch reset and balanced contexts |
| `main_ui_event_owner_test.v`: primary trusted delivery | Parsed video/created audio actual Page pointer/mouse/click/double records, view/detail/which, identity/current event, initializer guard, DOM polling and single compact replay |
| Movement/auxiliary trusted delivery | Existing Page record data through explicit non-primary platform inputs, dynamic which, auxiliary cancellation, view/identity/cleanup and live DOM polling |

Both final test files compile on the unchanged parent. All six functions stop
at their initial UIEvent availability guards, so the later constructor,
conversion and Page assertions remain unexecuted there. The final frozen
bytes are used for the successful focused and subsequent runs below.
Native test SHA256: `f8cf1ce34dfaaa230cd9662bc9fe405a4ed0ce7ac93d9026a42c3383aa0e65b9`.
Main test SHA256: `e7a897613e6fc7568990de3b7d1d883c9a203955d4c2fe294b25e642ec75cdb6`.

| Verification | Manifest under `Build/audit-fixes/` | SHA256 | Result |
| --- | --- | --- | --- |
| Final parent baseline | `native-ui-event-baseline-frozen-manifest.json` | `6b03112fa7f8acb7808f763572396791d910852ca27312d98b0f8a77a81a5f27` | Both files compile; six initial availability guards fail at runtime |
| Final focused | `native-ui-event-focused-complete-manifest.json` | `260951605fb0d2c28072e9a8dc5a963c1e784e4e3abe769bd37ce14ac7b43499` | Both files/six cases pass with final bytes |
| Selected default GC | `native-ui-event-default-manifest.json` | `7ac845f806d16732d6073bf38506934b5f1d7d7545e88df624b14d58adcce378` | 12/12 files pass on unchanged committed inputs |
| Selected GC disabled | `native-ui-event-gc-none-manifest.json` | `6fb2600c01fb08ddf06da8c17b1ec801e70895946487aa589df435d2ce3e3987` | 12/12 files pass on unchanged committed inputs |
| Ordinary optimized tests | `native-ui-event-optimized-manifest.json` | `cdeaf047c8b163174d7c1ff81a24b198fc9ecdbd1d811302db56a81ac91cd09c` | Both new files/six cases pass with `-prod -gc none`, including trusted Page fixtures |
| Signed production | `native-ui-event-production/manifest.json` | `559aabacc2ecdebcfc31cb1f6af3850cc005904ccd4d306aa6eff76b7ad8076d` | Ten stages pass, including startup, two exact synthetic-Event pages and all 11 configured smoke cases |

The selected files retain earlier Event/Window callbacks, current-event,
font-event providers, main document events, media movement/click, Page
pointer dispatch and native UI-record coverage. Final snapshots retain
4,989 input hashes and 31 selected source references.
The two full GC runs and ordinary optimized run preserve the same complete
committed source/test snapshot.

Earlier attempts remain separate evidence. An initial baseline checker
expected one space in FAIL markers while V emitted two; the tests themselves
compiled and failed all six initial guards, and the checker was corrected.
An initial focused run encountered old-V syntax restrictions on voidptr
if-expressions in array/return positions; neither file executed tests. Those
expressions were rewritten to explicit locals/branches, retaining the same
binding behavior. A later focused attempt passed the native file but main
compilation panicked with ENOSPC and executed no main tests. That filesystem
failure supplies no complete six-case passing proof. Earlier test versions
and the passing pre-fixture focused run retain their own scope; they do not
replace the final-byte baseline and retry. Diagnostic records:

- [earlier old v compile errors](../../Build/audit-fixes/native-ui-event-focused-manifest.json), SHA256 `956f96a0c4f3653e254e91a462eb01b72c08c3961156bc60666381fad7087732`.
- [earlier baseline checker](../../Build/audit-fixes/native-ui-event-baseline-diagnostic.json), SHA256 `b6c27ab0039e5643a33a1019e7c74fd13bd84f55f5398c7a9cdbccf96d89db47`.
- [disk compile failure](../../Build/audit-fixes/native-ui-event-focused-frozen-manifest.json), SHA256 `e929e972a675c8bac0880517a91baf6a49331a6af48cd7b2a7af102c7d3fa9a8`.
- [scratch preparation](../../Build/audit-fixes/native-ui-event-scratch-preparation.json), SHA256 `0d955bcd358a422fe6c0bff86e4799d05116a80564fea1434b31407937c7a2c7`.
- [Development history](../../Build/audit-fixes/native-ui-event-development-runs.json), SHA256 `72cc73b236b5ac4acf56483d076a10f3f41bf0744d1207a57a47c51a474f3da1`.

The successful retry and subsequent runs use `VJOBS=1` with compiler scratch
on the dedicated 1 GiB RAM volume `/Volumes/Vox2UIEventScratch`. Source,
logs, before/after snapshots and artifacts remain persistent in this
repository. After validation, guarded cleanup verifies the owned disk5 image,
UUID and task-only scratch entries, then detaches only that image. The
[cleanup receipt](../../Build/audit-fixes/native-ui-event-scratch-cleanup.json), SHA256 `5de35a851597276920e4dea081f7e25d2013ecb07936a7fe42461ca99f5f3185`, confirms
successful detachment and retention of persistent current/prior evidence.

The signed run's two 800x600 exact pages use untrusted synthetic UIEvent
records and provide browser binding coverage. Actual trusted Page delivery is validated
separately in the ordinary optimized tests with explicit DOM targets and
platform values. All 11 configured smoke cases pass, eight exactly; three
retain their existing fuzzy tolerances. All 51 current artifacts and 1,117
prior artifacts verify unchanged.
Earlier feature evidence remains preserved with its historical scope.
Consolidated evidence: `Build/audit-fixes/native-ui-event-evidence.json`, SHA256 `edc1a8b4e7c47dd09e1fa1580566b69098585e40f67df3eef2660848eebdb228`.
Independent [verification report](../../Build/audit-fixes/native-ui-event-verified-report.json), SHA256 `a0815cfccb7f5b38701f9a974939aafe33a42f4858761ca27d7f2b29a8cf22d3`.
Production binary SHA256: `8fd80bec2d1fd9de8f3e7afccedf361297e79d826872c5e7cb68b0ab8b69bcc5`.

## Native-data fidelity and remaining boundaries

The binding exposes the current native records; it does not correct all
platform construction. The V compatibility mousemove currently reuses the
retained mousedown click count, so the pressed-move fixture exposes detail
three. Pinned upstream handle_mousemove supplies the default count zero.
The explicit platform fixture also supplies a non-primary move button,
where normal upstream handle_mousemove supplies primary. These tests prove
record-to-wrapper fidelity, not complete Page input-field construction parity.
Existing `Page.handle_mousemove()` also ignores button-mask/modifier arguments
and does not install complete client-coordinate data.

Full MouseEvent/PointerEvent/KeyboardEvent and other concrete UI subclass
constructors, prototype placement and fields remain open, along with raw
inline element compilation, physical Cocoa input/hit testing/default actions,
foreign engine realms/views and weak wrapper ownership. The browser continues
to use JavaScriptCore. Full media/MSE/physical playback and the pinned load
captured-task FIXME remain separate work.

The inventory `Build/audit-fixes/source-current-module-loc-d1b86d81.json`, SHA256 `1d396d2178a0173ebe3f267c44e8a13bb7eac2ce5ce68cfdade2ad6ce2dfa265`, verifies the
established assigned-package hashes and physical counts: 78 owners,
2,210 files, 432,874 implementation and 158,957
test V LOC. These browser binding and root/browser test files are excluded
support. The current inventory reference is updated separately; historical
inventory and audit records remain intact. Ledger: 32 fixed / 25 partial / 9 open.
