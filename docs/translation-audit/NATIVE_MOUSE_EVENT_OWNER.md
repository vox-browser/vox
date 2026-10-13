# Owner-local Window MouseEvent binding

MouseEvent now exposes a public Window constructor, nineteen native getters,
getModifierState() and initMouseEvent() over actual DOM records. The retained
prototype inherits UIEvent and Event. Existing native PointerEvent, WheelEvent
and DragEvent records inherit this MouseEvent surface while their concrete
public interfaces remain separate work.

Implementation: `db342c95bc47d6e252bde99408feebd648101754`.
Parent: `baabc7f490e104ad8ab7f3e8ccce880124b5ec1c`.
Fixture-validation commit: `a03691e519f016ce7d0e4aeb7c1daa2b9efe2e20`.
Upstream pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

The focused/optimized binding proof and signed production run retain the
implementation bytes at db342c95. Final fourteen-file GC runs use a03691e5,
which changes only one preexisting callback-context test capture. All binding
implementation and six new test bytes remain identical. The records identify
their distinct commit and snapshot scopes.

## Source and implementation

The pinned references are UIEvents/MouseEvent.{idl,h,cpp}, EventModifier.idl,
PointerEvent.{h,cpp}, WheelEvent.{h,cpp}, HTML/DragEvent.{h,cpp}, and the binding
generator/parser dictionary, constructor and operation conversion algorithms.
The preceding canonical related-target correction remains intact.

The nineteen getter properties are screenX, screenY, pageX, pageY, clientX,
clientY, x, y, offsetX, offsetY, ctrlKey, shiftKey, altKey, metaKey, movementX,
movementY, button, buttons and relatedTarget. Getters and both operations are
genuine JSC native functions, with source name/length and descriptor metadata
and no [[Construct]]. The public constructor uses a JavaScript Proxy construct
trap and a native backend to create and bind an actual MouseEvent record.
It is not a translated LibJS constructor implementation.

The constructor observes newTarget.prototype once, before arity checks and
argument conversion, and uses the retained owner MouseEvent prototype when
that value is not an object. Explicit custom/subclass prototypes are retained.
Omitted and explicit undefined dictionaries reach the native converter as
undefined, so the IDL empty-dictionary default cannot read inherited author
properties. Explicit objects still use ordinary inherited property access.
Dictionary conversion visits EventInit, UIEventInit, EventModifierInit and
MouseEventInit in inheritance order, with each level's members in lexical order
and each value converted before the next Get. The six double members reject
nonfinite values and genuine ToNumber rejects BigInt/Symbol. Button and buttons
use signed and unsigned sixteen-bit conversion. Page/offset coordinates begin
at client coordinates; author pageX/offsetX/which members are not dictionary
inputs.

Native MouseEvent, WheelEvent and DragEvent coordinate getters retain trusted
fractions and floor untrusted coordinates, including negative values. Pointer
records use all eight concrete coordinate overrides: untrusted pointer types
retain fractions except click, auxclick and contextmenu. The x/y aliases also
use those virtual client getters. Movement values remain fractional. UIEvent's
inherited which getter continues to select the MouseEvent button-plus-one
override for all four families. Modifier lookup is case-sensitive and retains
the distinction between Meta and Super.

Receiver brands are checked before operation arity or author coercion. Legacy
initMouseEvent converts all fifteen positional arguments before entering the
existing dispatched guard. Successful initialization resets only the source
legacy slots and Event initialization flags; it preserves buttons, movement,
page/offset coordinates, extra modifier bits, composed and timestamp.
Its view accepts null or the actual owning WindowProxy. RelatedTarget accepts
null or a genuine native EventTarget wrapper and reads the canonical Event
slot used by dispatch retargeting and cleanup. The actual engine global is
registered as the owning Window EventTarget so its identity survives readback.

Installation covers initial and late Window ownership. It retains the original
UIEvent constructor/prototype and actual JSC global rather than consulting
author-replaced globals. Native wrapping checks cached identity and specialized
providers before selecting the retained MouseEvent prototype; other UI families
keep UIEvent. The earlier UIEvent regressions now assert this stronger chain
and MouseEvent tag for mouse-derived records. Main, DOM/Page algorithms, compact
bootstrap and dispatch algorithms do not change.

## Six focused cases

| Case | Coverage |
| --- | --- |
| Native metadata/defaults/lifecycle | Nineteen getter descriptors, two operations, nonconstructable native functions, constructor defaults, normal/custom subclassing, primitive-prototype fallback, single prototype Get and original thrown-object order, late Window exposure and original parent/global retention |
| Native dictionary/conversion | Exact twenty-eight-member inherited Get/conversion order, short/unsigned-short wrapping, finite double and BigInt/Symbol rejection, empty/default versus explicit-object dictionaries, owning Window and relatedTarget identity, original errors and no later Gets/Proxy traps |
| Native brands/live families | Actual MouseEvent, PointerEvent, WheelEvent and DragEvent wrappers, native data mutation, all modifiers, trusted fractions, untrusted negative flooring, PointerEvent click/auxclick/contextmenu exceptions and virtual x/y aliases, canonical related-target replacement/null |
| Native legacy initializer | Atomic coercion failures, positional long/short conversion, all conversions during dispatch before no-op, source flag reset and preserved nonlegacy slots/timestamp |
| Page movement/hover owner | Parsed video and created audio use actual Page platform routes, fractional screen/client values, button/modifier mapping, compatibility mouse cancellation, live DOM polling, public hover relatedTarget and untrusted redispatch of retained native records |
| Page press/release/click owner | Actual primary pointer/mouse/click sequence, native fields and initializer dispatch guard, click cancellation, live DOM polling, consumed receipt and single compact delivery |

Native test SHA256: `fce020994217ba122ca540bb63f2533bd332adf4334e632189913301921ff83b`.
Main owner test SHA256: `d5acec11d280f8bbe971f96a94bfc485a3c3f1399ae5093701bbf19d7c659f59`.

Both new files compile on the unchanged parent. All six cases fail their
initial MouseEvent availability/prototype guards there; subsequent statements
are unexecuted on that baseline. Complete post-fix runs use identical new-test
bytes and execute those later assertions.

| Run | Outcome and scope | Manifest | SHA256 |
| --- | --- | --- | --- |
| Parent baseline | 2 files / 6 initial guards fail; parent restored | `Build/audit-fixes/native-mouse-event-baseline-frozen-manifest.json` | `34667c26140a5a95699acb686d0ea4e8fee33a8eaf8e2796baa0b5c3fac0fb0b` |
| Focused | 2 files / 6 cases pass; feature bytes match db342c95 | `Build/audit-fixes/native-mouse-event-focused-manifest.json` | `d3fc1e620133fb01619f43bbac7095480a55a71c73e56a0798d7917c7beadb3f` |
| Default GC | 14/14 files pass at a03691e5 | `Build/audit-fixes/native-mouse-event-default-final-manifest.json` | `0ba8c6ccb4deaa9c7be02effadd98e276e7ae238477c37f9e6aaf3887d082459` |
| GC disabled | 14/14 files pass at a03691e5 | `Build/audit-fixes/native-mouse-event-gc-none-final-manifest.json` | `4d79369ec5a4e1d5f7ee54d2fad5f0a28fc3b9b71e423aa4912b995bdc97aae6` |
| Ordinary optimized | 2 files / 6 cases pass with `-prod -gc none` at db342c95 | `Build/audit-fixes/native-mouse-event-optimized-manifest.json` | `d598e2d3d394fda9e7b6e9479f79b4d090d76cd147fa81382545dbd23423f0ee` |

The fourteen selected files cover the new binding and actual Page owners,
inherited UIEvent/EventTarget/Window state, font-event hosts, canonical
related-target and hover regressions, movement/click owners and Page pointers.
Both committed implementation snapshots freeze 4,997 input byte hashes.
Only `browserjs/event_target_binding_test.v` changes between db342c95 and
a03691e5. Verification checks 42 selected source references, two compiler
inputs, three archives and 1,331 preserved prior artifact hashes. Production
freezes 149 source references and three compiler inputs. Manifests retain
exact commands, environments, snapshots and log hashes.

## Production evidence

All ten production stages pass at db342c95: archive precheck, build, signing,
startup, expected-page capture, two captures and their pixel comparisons,
and the eleven existing smoke cases.

Manifest: `Build/audit-fixes/native-mouse-event-production/manifest.json`, SHA256
`9a59e52523bcefe9e5141e2901a63a3654bbfe3d2fb7f166296fb844b75c038e`.
Completion receipt: `Build/audit-fixes/native-mouse-event-production/completion-receipt.json`,
SHA256 `85925da6955b927972c2633016f763b15fdd5f0f889dc58aa2d05374b3f4b5d6`.
Signed binary SHA256: `5ed2fd13294b5c36e336886015e02ac51edda19388d578ee33ec155b78bb65ff`.

Both synthetic pages are pixel-exact (zero differing pixels and zero maximum
channel error). The descriptor page constructs untrusted native MouseEvent
records and checks the public interface. The dispatch page sends untrusted
constructor records through parsed/created native media EventTargets, checking
listener/handler replacement order, cancellation and legacy initialization.
These pages complement the trusted Page tests; they do not establish physical
input or concrete PointerEvent binding parity.

All eleven smoke cases pass, eight pixel-exact. The existing AA allowances
cover `inline-node` (13 differing pixels, maximum error 1), `text-decorations`
(1,341, maximum 2), and `canvas-text` (1,994, maximum 8). All 51 current
production artifact hashes verify.

Consolidated evidence: `Build/audit-fixes/native-mouse-event-evidence.json`,
SHA256 `7500513853bce4ff63746bf055c3123cf2c3eb00c56755ab23907d34d0409c88`.

Independent verification report: `Build/audit-fixes/native-mouse-event-verified-report.json`,
SHA256 `64e2992b0acf517371840f42ded47f530c8751a52e00b98e847a74fcf3f3b266`.

Scratch cleanup receipt: `Build/audit-fixes/native-mouse-event-scratch-cleanup.json`,
SHA256 `0a3c866646b2ebde31aa991b006f3922f6f870686a136a766780caabcce92c97`.

The verified, exclusively owned `/dev/disk7` RAM image was detached after
all runs ended. An independent proof repeated after cleanup matches the
canonical report byte for byte. Persistent source, tests and evidence remain
in this repository. Earlier historical audits and evidence remain intact.

## Separate fixture correction and retained diagnosis

The first fourteen-file default-GC run at db342c95 passed thirteen files and
failed the existing callback-context test with undefined rather than true.
The original GC-disabled batch passed all fourteen. The file was retained in
the batch and reproduced independently: exact original bytes fail alone in
default GC and pass with GC disabled.

The fixture stored `voidptr(&runtime)` even though `runtime` was already a
Runtime pointer. Ignored labeled probes observed a captured address and context
that differed from the actual retained Runtime/context in both GC modes.
Changing only that capture to `voidptr(runtime)` passed all five original
EventTarget tests in default GC. Corrected direct labels observe the actual
Runtime/context, two callback entries, script/callback depths 2/1 and Boolean
true. No JavaScript evaluation occurs inside the diagnostic host callback.
Instrumentation changes stack layout and the original-capture labeled probes
also pass, so these observations do not establish a host-GC ownership defect,
an observed nil-context return mechanism or a transient production failure.

The original fixture bytes, all seven completed diagnostic runs and 412
preserved diagnostic/input hash entries are sealed at
`Build/audit-fixes/native-mouse-event-context-diagnostic/final-manifest.json`,
SHA256 `efc2fce786cf255359ecaaff9faaa076716327048e973062f347a297b1ce9add`.
The original fixture SHA256 is
`07a7eb796bdcb91ece1a310bbd397f659d2c21dec9f1b53449b9790da41d7140`;
the corrected fixture SHA256 is
`d273bac8b40675dfc0a4ebf851b8482ff6c69a059fac3db1846d1ea9dc20653f`.
Commit `a03691e5` changes only that one test line. No callback, host transport,
Window registration, binding or dispatch implementation changes accompany it.
The final `default-final`/`gc-none-final` fourteen-file runs pass at that commit.
Optimized/signed-browser proof remains at db342c95 because this preexisting
fixture is not compiled into those targets; its source snapshot remains
recorded at the implementation commit rather than retroactively relabeled.

Development history:
`Build/audit-fixes/native-mouse-event-development-runs.json`, SHA256
`e1bf6ec59902e6928a93fe22fef049b1ab4bdae9bc9dfd01a16697a2025f1dd1`.
Both diagnostic seals and earlier manifests/logs remain unchanged.

## Inventory and boundaries

The completed recount preserves all seventy-eight disjoint owners and all
2,211 assigned file byte hashes, physical newline counts and committed blobs.
Totals remain 432,871 implementation V LOC and 159,242 test V LOC. All eight
feature paths are root/browser support and remain excluded from that inventory.
Fresh snapshot: `Build/audit-fixes/source-current-module-loc-db342c95.json`,
SHA256 `8faec2d3db2fcb54835b7e6867dfbe177b498d5da213b5b5b145212b0b234522`.
The preceding dd0 inventory is preserved. Current reference updates belong
to a separate documentation commit after feature evidence is complete.

This completes the selected owner-local MouseEvent surface. Concrete
PointerEvent, WheelEvent and DragEvent constructors, prototype placement and
additional fields remain open. Native records currently expose the inherited
MouseEvent prototype/tag until those concrete bindings are translated.
Foreign WindowProxy views and engine realms, weak wrapper ownership, physical
Cocoa transport/hit testing, default actions and complete Page input-field
construction are not established by this work. In particular,
Page.handle_mousemove() retains its existing button-mask/modifier and complete
client-coordinate construction limitations; platform-pointer entry supplies
the explicit fields used by these owner tests. Raw inline element compilation,
broader media/MSE/playback and pinned load captured-task work remain open.
JavaScriptCore remains the browser engine.

Historical ledger: 32 fixed / 25 partial / 9 open.
