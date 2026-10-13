# Owner-local Window WheelEvent binding

WheelEvent now exposes its Window constructor, seven native getters and three
delta-mode constants over actual DOM WheelEvent records. Its retained prototype
inherits MouseEvent, UIEvent and Event. Concrete DragEvent bindings remain open.

Implementation: `813dd838fcf6ac88f216e27a88a6a185a9750125`.
Parent: `368ef4c71d36909daebc1bfe9c45d14772bd104b`.
Upstream pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

The feature commit contains seven root/browser implementation/test paths. It changes
no DOM/Page algorithm, main bootstrap, media event-handler surface or assigned
package. The committed source already includes preceding independent Layout and CSS
work.

## Source and implementation

Pinned references include UIEvents/WheelEvent.{idl,h,cpp}, inherited
MouseEvent/UIEvent/EventModifier declarations, AK/Math.h round-to-even behavior and
the binding generator's constructor, attributes, constants and dictionary
conversions.

The own fields are deltaX, deltaY, deltaZ, deltaMode, wheelDeltaX, wheelDeltaY and
wheelDelta. Getter name/length and configurable/enumerable/read-only descriptors use
genuine JSC native functions without [[Construct]]. DOM_DELTA_PIXEL, DOM_DELTA_LINE
and DOM_DELTA_PAGE are immutable enumerable constants on both constructor and
prototype, with values zero, one and two.

The public constructor uses a JavaScript Proxy construct trap and a native record
backend. It observes newTarget.prototype once before arity and argument conversion,
retaining object/function custom prototypes and the original WheelEvent prototype for
primitive/null fallback. Omitted/undefined/null dictionaries bypass author properties
for the empty default; explicit objects retain ordinary inherited property access.

Twenty-eight inherited MouseEvent dictionary members convert first, followed in
lexical order by deltaMode, deltaX, deltaY, deltaZ, wheelDeltaX and wheelDeltaY. Each
Get and conversion completes before the next member. Delta mode uses unsigned
thirty-two-bit wrapping, and legacy deltas use signed thirty-two-bit wrapping. Delta
doubles reject NaN/infinity; numeric conversion rejects BigInt/Symbol and propagates
the original author exception. No recognized-mode restriction or delta-range clamp is
added.

A nonzero explicit legacy X/Y value wins; zero falls back to the negated
corresponding delta. That fallback rounds ties to even and clamps to signed
thirty-two-bit limits. wheelDelta returns the vertical legacy value when nonzero and
otherwise the horizontal value. Delta Z does not contribute. These are the pinned
native record algorithms, including their zero/default behavior.

Getter brands require a genuine WheelEvent record. Other native families, forged
prototypes and Proxy lookalikes fail without author traps; ignored getter arguments
are not converted. Initial and late owner installation retain the original MouseEvent
constructor and actual JSC global. Cached wrappers and specialized providers retain
precedence; Wheel records receive their retained Wheel prototype ahead of the Mouse
fallback.

Inherited coordinates remain DOM-owned: trusted records retain fractions, while
untrusted Wheel records use the MouseEvent flooring path. Movement deltas remain
fractional; which exposes button plus one as an unsigned thirty-two-bit value.
Canonical relatedTarget stays live.
initMouseEvent/initUIEvent preserve Wheel slots, timestamp and their existing
dispatch/atomic-conversion guards.

## Seven focused cases

| Case | Coverage |
| --- | --- |
| Native metadata/defaults/lifecycle | Seven native getter descriptors and nonconstructable functions, constants on constructor/prototype, defaults, custom/subclass/fallback prototypes, one newTarget prototype Get, initial/late Window exposure and retained original global/parent |
| Native dictionary/conversion | Exact thirty-four-member inherited Get/conversion order, owner view/relatedTarget identity, original author exceptions, nullish defaults without inherited Gets and no later Gets on errors |
| Native numeric/legacy values | Restricted double rejection, signed zero, unsigned mode and signed long wrapping, BigInt/Symbol rejection, round-to-even/clamped legacy fallback, vertical-before-horizontal wheelDelta and read-only slots |
| Native receiver brands | Fake, Proxy, base/UI/Mouse/Pointer/Drag/Keyboard records rejected by all seven getters without author traps or unused-argument conversion |
| Native live records/initializers | Retained Wheel prototype after public-global replacement, live native fields, trusted/untrusted inherited geometry, canonical relatedTarget, atomic inherited initializer errors and dispatch guards |
| Native platform factory owner | Actual translated factory records dispatched through parsed video/created audio EventTargets, trust/fractional coordinates, cancellation, wrapper identity, untrusted redispatch, DOM polling and no duplicate compact delivery |
| Constructed owner dispatch | HTTP owner construction/dispatch, inherited Mouse/UI initializers preserving all Wheel slots, live media targets, cancellation and single native delivery |

Native test SHA256: `4d00159a5065f2629763f6588660e1a701ad7a15c6160e313410bf1d3e97cd77`.
Main owner test SHA256: `f430c399a1e5e3637987a5785cb92a0ab0b053ac5e8b37e71434dee5d9a49e39`.

Both new files compiled on parent 368ef4c7, and all seven cases failed their initial
WheelEvent availability guards. Later conversion, field and owner assertions were
unexecuted on that baseline. The final focused and optimized runs use identical
new-test bytes. Focused implementation bytes match committed 813dd838 while its
recorded HEAD remains the parent until the feature commit.

| Run | Outcome | Manifest | SHA256 |
| --- | --- | --- | --- |
| baseline | 2 files / 7 initial availability guards fail | Build/audit-fixes/native-wheel-event-baseline-manifest.json | c7f7346397ea43028c5d77dd246e78cbdd6ac57dd12d2d711d0a84febc601c71 |
| focused | 2 files / 7 cases pass; final implementation bytes | Build/audit-fixes/native-wheel-event-focused-manifest.json | 23f32cb9abb18722f2462cc3a45216c0a3a938624f0adbb3d1963559a9cdce11 |
| default | 20/20 files pass at 813dd838 | Build/audit-fixes/native-wheel-event-default-manifest.json | 2ea30ab373fbaad8564c0991f524f2ae0935ef6a32faf270807e9beeac86f26e |
| gc-none | 20/20 files pass with GC disabled at 813dd838 | Build/audit-fixes/native-wheel-event-gc-none-manifest.json | 76d058dba7c1213400644492dcb7f991f1f6c2facfb0938adae27ebb04dd13cf |
| optimized | 2 files / 7 cases pass with -prod -gc none at 813dd838 | Build/audit-fixes/native-wheel-event-optimized-manifest.json | bf0d8c6ca99c7dd28d7085f4e549989fe6f2ace7d12d1a769e39259c3c8d8ec8 |

The committed isolated source is
/Users/alex/code/vox2/Build/audit-fixes/native-wheel-event-validation-source. Final
snapshots verify 5,009 exact Git byte hashes, 51 selected upstream references, 160
production references, 3 production compiler inputs and 3 cached native archives.
Baseline retains 5,007 inputs: parent source plus the two identical new tests.
Manifests retain actual commands, environments, before/after snapshots and settled
logs.

## Production evidence and retained failed probe

The final corrected private recipe exits nine steps successfully: one verifies the
retained frozen build, and eight freshly verify strict signing, startup,
expected-page capture, two native Wheel page captures with exact pixel comparisons,
and the eleven-case smoke batch. Ten logical production checks include the original
archive-cache precheck and completed build. The retained browser was built with the
explicit -old-compiler -enable-globals -prod -gc none override. No implementation
changes or rebuild occurred between the failed page probe and this final
verification.

The original private attempt passed archive precheck, production build, signing,
startup and descriptor pixels, then its owner-dispatch pixel check failed. Its page
incorrectly assumed compact HTMLMediaElement.onwheel was native; that accessor is
outside the existing compact media handler subset. The corrected page uses native
addEventListener("wheel", ...) and preventDefault(). This changes only ignored test
input, and does not implement media onwheel or a physical Page wheel route.

All 43 original failed-attempt artifacts remain immutable, including the settled
manifest/receipt, source recipes, logs, pixels, private signed binary and Skia dylib.
Failed owner-page pixels receive no pass credit. Final verification reuses exactly
that passed-build binary, with source hashes, build flags, strict signature and
isolated source-string lineage independently checked.

Final production manifest: `Build/audit-fixes/native-wheel-event-production-final/manifest.json` (SHA256 `483290899170e91c9f4aa554f4d142b54537d95cc57fe494accfbdfe209c413f`).
Final completion receipt: `Build/audit-fixes/native-wheel-event-production-final/completion-receipt.json` (SHA256 `cae581ea56ee9008658eef09b20857b8a1e90ad188787cab5e76b72140d46a5a`).
Retained original build manifest: `Build/audit-fixes/native-wheel-event-production-private/manifest.json` (SHA256 `922314a3ccbd74d9b28f4bb24d40437fa2224de2f7dfb0d45bd4592216259f16`).
Failed-attempt preservation: `Build/audit-fixes/native-wheel-event-production-final/failed-attempt-preservation.json` (SHA256 `97454c1988c4b0cdb7ae30fc3dead3d44c7671638bd002a6084a83e6f49313dc`).
Persistent signed binary: `Build/audit-fixes/native-wheel-event-production-private/browser-build/Ladybird.app/Contents/MacOS/Ladybird` (SHA256 `9f1523abc867f834d12c38cc020f8f31b241bad45031a3173062c8b4f66eb37b`).
Persistent Skia dylib: `Build/audit-fixes/native-wheel-event-production-private/browser-build/libLadybirdVSkiaText.dylib` (SHA256 `58caaa4f153941b1e941f2d73498dfe6582151a03a8e063a2aafc84c606b670e`).
Private recipe preparation: `Build/audit-fixes/native-wheel-event-production-final/recipe-preparation.json` (SHA256 `4dd56e27d8c69640572cd483ac7a7707d1670cb434207b210a8c1735876d64ff`).
Binary source provenance: `Build/audit-fixes/native-wheel-event-production-final/provenance.json` (SHA256 `632503913f71546451fe187a7fba366f53713b83c80388d1b02d7fdf870eb64a`).

Both corrected Wheel pages have zero differing pixels and zero maximum channel error.
All eleven smoke cases pass, eight pixel-exact. Existing toleranced cases retain
inline-node 13 pixels / maximum 1, text-decorations 1,341 / 2, and canvas-text 1,994
/ 8. The exact current artifact closure verifies 102 entries; 1,960 prior evidence
hashes remain unchanged.

## Evidence, cleanup and inventory

Consolidated evidence: `Build/audit-fixes/native-wheel-event-evidence.json` (SHA256 `62acadfa4802e481055569c6beb3cb11c001c4543453c909740d60378ff990a4`).
Independent verification: `Build/audit-fixes/native-wheel-event-verified-report.json` (SHA256 `ace546caba4d7e6b83203b61ea99903cab67ac5310d8ce3d828e6786e0f91df4`).
Scratch cleanup: `Build/audit-fixes/native-wheel-event-scratch-cleanup.json` (SHA256 `714d7bffe4fa6c05f033829e11e2483e8858d1b0ffa5615bc3a5fc7d8f785195`).

Only the verified owned RAM volume was detached after all runs ended. Persistent
source, signed image, dylib and evidence remain retained. The independent proof was
repeated after cleanup; canonical concurrent workspace work is outside its isolated
input pin.

Physical inventory: `Build/audit-fixes/source-current-module-loc-813dd838.json` (SHA256 `7d2154cc1ce69f1ea0dda25e8eda6f2df52c76abc7df473c463da13e8ca1cce5`).

All seventy-eight disjoint owners and 2,213 assigned files match committed hashes and
physical newline counts: 432,942 implementation / 159,469 test V LOC. The prior
c9dc0da2 inventory remains immutable. Preceding a031fa8f Layout work contributes +56
implementation / +58 test lines and one new file; preceding 8221067c CSS work
contributes +17 implementation / +63 test lines. All assigned bytes/counts also match
parent 368ef4c7; the seven WheelEvent feature paths are excluded root/browser
support. Current inventory references and table counts belong to a separate commit.

## Boundaries

This completes the pinned owner-local Window WheelEvent constructor/getter/constants
surface. The browser still uses JavaScriptCore. Concrete DragEvent public bindings,
foreign realms/views, WindowProxy weak ownership, automatic collector retention,
complete translated LibJS runtime, physical media/MSE behavior and the pinned load
captured-task FIXME remain open.

Native owner tests explicitly dispatch translated platform-factory records through
the actual DOM and separately construct JavaScript WheelEvents. Page wheel entry
points currently retain routing metadata; main Cocoa scrolling uses
paintables/viewport scrolling. Hardware input dispatch, physical hit testing, default
scrolling, asynchronous compositor transactions and native compact media onwheel
exposure are not established by these synthetic owner tests or exact pages. Element
pointer capture and hardware/coalescing/prediction generation remain separate work.

Later canonical README, build tooling and DOM Node work remain preserved outside the
frozen 813dd838 validation source. Historical MouseEvent, related-target, UIEvent,
PointerEvent and earlier media audit documents remain unchanged. The broader audit
ledger remains 32 fixed / 25 partial / 9 open.
