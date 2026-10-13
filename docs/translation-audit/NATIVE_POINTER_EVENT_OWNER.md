# Owner-local Window PointerEvent binding

PointerEvent now exposes a Window constructor, thirteen native getters and
getPredictedEvents() over actual DOM PointerEvent records. Secure Window owners
also expose getCoalescedEvents(). Its retained prototype inherits MouseEvent,
UIEvent and Event. WheelEvent and DragEvent continue to inherit MouseEvent;
their concrete public interfaces remain separate work.

Implementation: `c9dc0da24fb1406f4dbd3c79b230c5fded821f3e`.
Parent: `7c3576ec9d30d5d3921bf8bc86acb79000d4a1e0`.
Ancestral baseline/focused parent: `feb97f38e693446e93eedf8830c07650c0dc666b`.
Upstream pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

The feature commit contains only the nine PointerEvent implementation/test
paths. Its preceding independent CSS commit repairs shared :has() cache
ownership and adds a 106-line regression. Final integrated validation retains
that CSS commit; ancestral parent/focused runs retain their earlier source
scope and are not relabeled as the integrated feature snapshot.

## Source and implementation

The pinned references are UIEvents/PointerEvent.{idl,h,cpp}, inherited
MouseEvent/UIEvent/EventModifier declarations and algorithms, and the binding
generator's dictionary, restricted-number, sequence, interface-brand,
constructor and SecureContext exposure conversions.

The thirteen getter properties are pointerId, width, height, pressure,
tangentialPressure, tiltX, tiltY, twist, altitudeAngle, azimuthAngle, pointerType,
isPrimary and persistentDeviceId. All getters and both sequence operations use
genuine JSC native functions with source name/length and descriptor metadata
and no [[Construct]]. The public constructor uses a JavaScript Proxy construct
trap and a native backend to create and bind an actual PointerEvent record.
It does not implement a translated LibJS constructor.

Construction observes newTarget.prototype once before arity checks and argument
conversion. Non-object prototype values use the retained owner PointerEvent
prototype; explicit custom and subclass prototypes are preserved. Omitted or
undefined dictionaries reach the native converter as undefined, without
reading inherited author properties for the empty-dictionary default. Explicit
objects retain ordinary inherited property access.

Dictionary conversion visits the twenty-eight inherited MouseEvent members
first, then fifteen PointerEventInit members in lexical order. Each Get and
conversion completes before the next member. PointerId, persistentDeviceId,
tiltX, tiltY and twist use signed thirty-two-bit conversion. Width, height and
the optional angles reject nonfinite doubles. Pressure and tangentialPressure
use finite single-precision conversion and reject float overflow. Genuine
ToNumber rejects BigInt/Symbol and preserves original author exceptions.
PointerType uses DOMString conversion; isPrimary uses Boolean conversion.

The pinned constructor keeps angle and tilt defaults independent: absent tilts
are zero, absent altitude is pi/2 and absent azimuth is zero. Explicit null
numeric values convert to zero. It does not synthesize angle/tilt values, clamp
numeric ranges, or restrict the pointerType string to known device names.
These choices follow the pinned implementation, including its float-conversion
FIXME, rather than claiming a broader normative algorithm.

Coalesced and predicted inputs require iterable objects and genuine native
PointerEvent items. The converter Gets Symbol.iterator once, calls it with the
input receiver, captures next once, and reads each result's done before value.
It validates each item immediately, preserving order, duplicates and wrapper
identity. Truthy done skips value access. Undefined sequence defaults bypass
author Array iterators. The pinned generated loop propagates iterator/item
errors through direct TRY without IteratorClose; this binding likewise does
not Get or invoke return on those abrupt completions. That omission is source
fidelity, not a claim of complete WebIDL sequence-spec conformance.

Each sequence method returns a fresh mutable ordinary Array containing the
same retained native child wrappers. Mutating the returned Array does not
change DOM-owned sequence lists. Method/getter brands reject non-Pointer
records and Proxy lookalikes without author traps; unused method arguments
are not converted. getCoalescedEvents is defined only when the existing owning
settings report a secure context, while getPredictedEvents and the constructor
remain available to all Window owners. This is prototype exposure, not a
per-call security rejection or a new secure-context algorithm.

Initial and late Window installation retain the original MouseEvent
constructor/prototype and actual JSC global. Cached wrapper identity and
specialized providers retain precedence; native PointerEvent records now use
their retained PointerEvent prototype before the inherited MouseEvent fallback.
Existing Mouse/UI/Page regressions assert the stronger Pointer chain and tag.
DOM/Page records, dispatch algorithms, main and compact bootstrap do not change.

Inherited MouseEvent coordinates still route through all eight Pointer virtual
getters, including x/y aliases. Trusted coordinates retain fractions; untrusted
Pointer records retain them except click, auxclick and contextmenu. Inherited
which remains button plus one. InitMouseEvent and initUIEvent preserve Pointer
slots and sequence lists while applying their existing source initialization
and dispatch guards.

## Seven focused cases

| Case | Coverage |
| --- | --- |
| Native metadata/defaults/lifecycle | Thirteen getters, two native operations, nonconstructable functions, defaults, custom/subclass/fallback prototypes, single newTarget Get before conversions, initial and late Window exposure, actual global/original parent retention, secure and insecure owners |
| Native dictionary/conversion | Exact forty-three-member inherited Get/conversion order, signed integers, restricted doubles/floats and overflow, optional/null distinction, independent angle/tilt defaults, signed zero, owner view/related-target identity, original exceptions and no later Gets |
| Native sequences | Captured iterator/next order, immediate item brand, duplicates and child identity, fresh Arrays and mutation isolation, undefined defaults without Array iterator access, truthy done, original iterator errors, no IteratorClose and no later dictionary conversions |
| Native brands | Thirteen getters and both methods reject fake/Proxy/base/UI/Mouse/Wheel/Drag/Keyboard receivers without traps or unused-argument coercion |
| Native live records/initializers | Retained Pointer prototype after global replacement, live slots and canonical relatedTarget, trusted and untrusted coordinate overrides, coalesced/predicted native children, inherited Mouse/UI initialization and atomic errors, dispatch conversion-before-guard and cleanup |
| Secure Page movement/hover owner | Parsed video and created audio through actual Page platform routes, native Pointer fields and empty sequence ownership, fractional movement, compatibility Mouse cancellation, hover relatedTarget, live DOM polling and untrusted redispatch |
| Insecure Page press/release owner | Actual Pointer/Mouse/click sequence, insecure coalesced-method omission, predicted arrays, preserved Mouse compatibility prototype, cancellation, live DOM polling and consumed single-delivery compact receipt |

Native test SHA256: `62dcc05241a3a0afb1d9e1a07032757e04ce7de32b886dc4e2e46732c78921ad`.
Main owner test SHA256: `d767b3a6d89b5f9b2a3d3e8db6d9f3f925b65f56a15a044d931fbf60a6c30870`.

Both new files use parent-compatible APIs and begin each case with a
PointerEvent exposure guard. The parent baseline outcome is `2 files / 7 initial availability guards fail; parent restored`.
Availability guards do not exercise later conversion or Page assertions on
that baseline; complete post-fix runs must use identical new-test bytes.

The first canonical parent run compiled both files and reached all seven
initial guards, which failed as expected. Its whole-snapshot equality check
was false solely because the unrelated untracked `css/has_result_cache_test.v`
appeared during the run. Tracked inputs and both owned new tests were unchanged.
That run is retained as development history, without complete frozen-baseline
credit. A subsequent canonical retry stopped before starting tests because
outside tracked CSS edits made the parent preflight dirty. Neither observation
is a PointerEvent conversion or Page failure.

A read-only proof attempt initially asserted equality between the transient
untracked CSS test observed during the first baseline and its later committed
version. Those outside-task bytes differ. The archived checker was actually
rerun and exited 1 at that equality assertion, without rerunning V tests or
browser stages; it receives no pass credit. The final checker verifies each
historical snapshot in its own scope instead. PointerEvent implementation and
both new test bytes were unchanged. Diagnostic:
`Build/audit-fixes/native-pointer-event-proof-css-equality-diagnostic.json`,
SHA256 `9f6d3e426aad24ab213e146687d8692fbe79b11acccfbef1c6ee9a00c092389c`;
its retained log SHA256 is
`b0a7e8a67047008700571db65e0682daaba21b3ce4a1bf3b5ccc9c67301fece8`.

The completed validation source is an isolated detached checkout at
`Build/audit-fixes/native-pointer-event-validation-source`, inside this canonical
repository. Only this slice's nine owned implementation/test paths were copied
there for the ancestral feb97f38 baseline and focused proof. The outside CSS
work was subsequently committed independently at 7c3576ec. The canonical
PointerEvent feature was committed on top of it, and the isolated checkout
was advanced to that actual integrated feature commit for both GC batches,
optimized cases and production. The CSS regression remains included in the
seventeen-file GC batch. Preparation records: `Build/audit-fixes/native-pointer-event-validation-checkout.json`,
SHA256 `3c322c903155f60abf379b179fafeaed225bf53a4f6fb01427b9b5bf7985e43c`, and `Build/audit-fixes/native-pointer-event-code-integration.json`, SHA256
`3efdc84ab1d31ea05650266f262f8cd159465e3e9354c95eca03db2a7f523ab4`. Development history: `Build/audit-fixes/native-pointer-event-development-runs.json`, SHA256
`51436a211e4e5e1f48165a51c629da6576bedbf8176f89be747f7be59eea304a`.

| Run | Outcome and scope | Manifest | SHA256 |
| --- | --- | --- | --- |
| Ancestral parent baseline | 2 files / 7 initial availability guards fail; parent restored; feb97f38 source | Build/audit-fixes/native-pointer-event-baseline-frozen-final-manifest.json | 096afa4a5508c78c37179ca9563089404720d59b81064057dd5087d47e3df239 |
| Ancestral focused | 2 files / 7 cases pass; PointerEvent bytes match feature over feb97f38 source | Build/audit-fixes/native-pointer-event-focused-manifest.json | 1ceda54162e2f0c2dcea7372d3f710f8f07461c3ead137924dc616f83c25db6a |
| Default GC | 17/17 files pass at c9dc0da2 | Build/audit-fixes/native-pointer-event-default-manifest.json | 6a5353d32f5e4b10248bb6acdf8244e73f5df13d9d193dc26fea93ff621de14c |
| GC disabled | 17/17 files pass at c9dc0da2 | Build/audit-fixes/native-pointer-event-gc-none-manifest.json | 3b5e6384e9724fd90e8dbce1f15ae3bdf8c24bc6506b428502d51b4a402aed52 |
| Ordinary optimized | 2 files / 7 cases pass with -prod -gc none at c9dc0da2 | Build/audit-fixes/native-pointer-event-optimized-manifest.json | 2f4325a127b4218c0dc989454425334a10941d9b2e839b0f2204728819992d8d |

Both integrated GC runs pass all seventeen selected files. Both new files and
all seven cases also pass ordinary optimized GC-disabled builds at c9dc0da2
from that isolated checkout. The final records freeze
`5,003` source byte hashes,
`47` selected upstream references and
`154` production references, plus compiler/archive
inputs. Actual manifests retain commands, environments, snapshots and logs.
The integrated source differs from the ancestral focused source only by its
HEAD/status and the preceding three changed CSS implementation inputs plus the
new CSS regression. Both new PointerEvent test files and all nine feature paths
remain byte-identical across those scopes.

## Production evidence

Final private-output production outcome: `all ten stages pass at c9dc0da2`, covering ten
stages, signed build and startup, two synthetic exact-page checks and all
eleven existing smoke cases. The pages construct untrusted native Pointer
records and dispatch them through actual parsed/created media EventTargets.
They complement the trusted Page tests and do not establish physical input
or concrete hardware-device parity.

Manifest: `Build/audit-fixes/native-pointer-event-production-private/manifest.json`, SHA256 `260f291ccbbef257bcbf05f6c362db62830444d02169e9cd7593a4be1759e70d`.
Completion receipt: `Build/audit-fixes/native-pointer-event-production-private/completion-receipt.json`, SHA256 `bda3f8b2035d5a899b601d50354254f3494f9103b9951bf9df5dcb94c78832ef`.
Persistent private signed binary: `Build/audit-fixes/native-pointer-event-production-private/browser-build/Ladybird.app/Contents/MacOS/Ladybird`, SHA256 `f557d8aad1051598125cecc14fc9452a1a9db4bac74f4c0e5cfd2b7a23d9d07d`.
Persistent Skia dylib: `Build/audit-fixes/native-pointer-event-production-private/browser-build/libLadybirdVSkiaText.dylib`, SHA256 `58caaa4f153941b1e941f2d73498dfe6582151a03a8e063a2aafc84c606b670e`.
Private recipe and source provenance: `Build/audit-fixes/native-pointer-event-production-provenance.json`, SHA256
`f29f36ba8b1d14df9cc2040bb0e8e33ba85c3eb920be0e4e996e434afb2ad844`.
Page metrics: `both pages: zero differing pixels / zero maximum channel error`.
Smoke metrics: `11 pass / 8 exact; inline-node 13 pixels / maximum 1, text-decorations 1,341 / 2, canvas-text 1,994 / 8`.
Current production artifacts, including the private image and dylib:
`66`.
Preserved prior artifacts: `1,859`.

The initial production attempt passed archive-cache preflight but its build
exited 101 before Rust compilation because rustc was absent from PATH after
the ignored Cargo wrapper directory was prepended. No browser stage ran, and
that attempt receives no pass credit. Its source, upstream, compiler, archives
and 1,859 prior artifact bytes remained unchanged. The separate first-attempt
record is `Build/audit-fixes/native-pointer-event-production-first-attempt.json`,
SHA256 `699f93e72df7740ee2c89e0186324f036b98bfe5ca6d792f9599fa2e9734485b`.

A subsequent shared-output run completed all ten stages and an independent
review before an external canonical build replaced the shared signed bundle.
The recorded a61c9d48 image is no longer retained, so that run has no final
persistent-image credit. Its immutable manifest, settled receipt, logs and
review are preserved separately. The late-overwrite record is
`Build/audit-fixes/native-pointer-event-production-late-overwrite.json`, SHA256
`c40a6a34161b7a820d70c810098da9f6ed62a7c6a6114d8db98c461ecbdb045f`.
These are harness/environment observations, not PointerEvent implementation
failures. Final credit comes from the independent private-output run and its
retained signed image. The private recipes leave canonical tracked tooling
unchanged by this slice and identify their pinned isolated source and output paths.

The exact c9dc0da2 source templates and the three ignored private build,
capture and comparison recipes are retained with their diffs in
`Build/audit-fixes/native-pointer-event-production-private/recipe-preparation.json`,
SHA256 `e2562362278654ce1a7504a5a1494fb7f27000a4df0960765b792598c9f16b33`.
Their changes are explicit source/output/binary/capture paths; this slice leaves the canonical
tracked tooling unchanged. The final independent production report is
`Build/audit-fixes/native-pointer-event-production-private-independent.json`,
SHA256 `3283060b3e637e317e7790fdfbb015e4b95530609ab742a98090903199ef1d1f`.
The retained signed image contains the three exact isolated source filename
literals, excludes their canonical counterparts and retains its recorded hash.
Those source bytes agree with the frozen source map and feature Git blobs.
The cached Rust/native archives retain their separately verified identities.

Consolidated evidence: `Build/audit-fixes/native-pointer-event-evidence.json`, SHA256 `4a8392c1a326542d3d395ad6da9dfc8b3d87935a0d74776dd754d33d32a191a4`.
Independent verification: `Build/audit-fixes/native-pointer-event-verified-report.json`, SHA256 `a433e85546f1bd1a398a894d43820ad1f0afba0b251fccb2350d948162f5ec4f`.
Scratch cleanup: `Build/audit-fixes/native-pointer-event-scratch-cleanup.json`, SHA256 `ba37717901c92680e314e8c10799ce9082743aff34aba6c183face6df1b20e1a`.
Cleanup outcome: `only the verified owned /dev/disk5 RAM image was detached after all runs ended; persistent source, private signed image, dylib and evidence remain intact; the independent proof repeated after cleanup matches the canonical report byte for byte`.

Before the binding changes, 390 historical MouseEvent diagnostic source
symlinks were materialized as identical byte snapshots. All 412 entries in
the previous diagnostic seal remain preserved. The separate materialization
record is `Build/audit-fixes/native-pointer-event-prior-source-materialization.json`,
SHA256 `42676dd523eb7931ff9dff5ac7bcc639c27667a73ba3b087d8fffa302dfb0c38`. This preserves the earlier diagnosis rather
than relabeling or rerunning it against newer source. Historical MouseEvent,
related-target, UIEvent and earlier media audit documents remain unchanged.

Physical inventory: `Build/audit-fixes/source-current-module-loc-c9dc0da2.json`, SHA256 `3c5062172b28d38dda0a7e9d3d842470e270a78fd45aee5f07ba0a68633c54b5`.
The helper verifies all seventy-eight owners and 2,212 assigned files, including
the isolated feature's committed byte hashes and physical newline counts.
The preserved db342c95 inventory, SHA256
`8faec2d3db2fcb54835b7e6867dfbe177b498d5da213b5b5b145212b0b234522`,
has 2,211 assigned files, 432,871 implementation lines and 159,242 test lines.
The preceding 7c3576ec CSS commit changes three assigned implementation files
with a net reduction of two physical lines and adds its 106-line test.
Integrated totals are 432,869 implementation lines and 159,348 test lines;
CSS alone moves from 188 files / 114,944 implementation / 17,636 test lines
to 189 files / 114,942 implementation / 17,742 test lines. Every other owner,
file assignment, byte hash and physical count is unchanged. All assigned
feature hashes also match the preceding CSS commit: the nine root/browser
PointerEvent feature paths are excluded. Current inventory references and
aggregate counts are updated in a separate commit.

## Validated source and later canonical work

All complete optimized and production records identify the committed c9dc0da2
source in the isolated checkout. Later canonical changes to
`layout/flex_formatting_context.v` and `layout/layout_state.v`, and the new
`layout/flex_relayout_test.v`, are separate work preserved in place. Those later
versions and the newly added test are outside the frozen c9dc0da2 source
snapshot and this proof.
These records and the inventory describe c9dc0da2. Subsequent canonical
commits and working-tree edits retain their separate scope.

## Boundaries

This completes the pinned owner-local Window PointerEvent binding surface.
Element setPointerCapture(), releasePointerCapture() and hasPointerCapture(),
physical pointer capture, touch/pen device generation, real device IDs,
coalescing/prediction generation and hardware data remain separate work.
Platform Pointer creation currently leaves pressure zero even with active
buttons, matching the pinned implementation; the binding does not invent
pressure data. Full WheelEvent/DragEvent public constructors and additional
fields remain open.

Trusted tests use explicit Page InputTargets, without claiming Cocoa event
delivery, hit testing or full physical input parity. Page.handle_mousemove()
still ignores its button-mask/modifier arguments and does not install full
client-coordinate data; the tested platform-pointer entry installs those
fields. Existing owner-local view mapping does not complete foreign-realm
Window wrappers. General weak/custom-GC ownership, raw inline element handler
compilation, full translated LibJS execution and physical media decoding remain
open. Media load's upstream task-cancellation FIXME is unchanged.

Historical ledger: 32 fixed / 25 partial / 9 open.
