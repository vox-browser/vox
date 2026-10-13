# Owner-local Window DragEvent binding

DragEvent now exposes its Window constructor and read-only native dataTransfer
getter over actual HTML DragEvent records. The retained prototype inherits
MouseEvent, UIEvent and Event. This completes that owner-local interface with
nullable actual DataTransfer identity; the public DataTransfer interface remains
separate work.

Implementation: `682a782721ea769c4da5ee56a19033bf40a92fd5`.
Separate identity prerequisite / immediate parent: `6296e27c135f0913fe58576d481e7d1c09898312`.
Identity immediate parent: `a951e9fc1c4621bde6ed3f449c24562c51d8e89b`.
Ancestral identity validation source: `ddf7e24047b30799fc94b8598772c0c17165d750`.
Upstream pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

The prerequisite changes three excluded browser support/test paths. The DragEvent
commit changes nine paths: seven excluded root/browser paths, the existing HTML
record and its new focused constructor test. No Page drag dispatcher, main
bootstrap, media handler surface or DataTransfer operation is changed.

## Source and implementation

Pinned HTML/DragEvent.{idl,h,cpp} defines the constructor, MouseEvent inheritance
and sole nullable DataTransfer attribute. The generated dictionary conversion
reads the twenty-eight inherited MouseEvent members before dataTransfer. Each
Get and conversion completes before the next member. Null/undefined transfer
values produce null; a nonnull value requires this runtime's actual native
DataTransfer wrapper. Ordinary objects, forged prototypes, primitives and Proxy
lookalikes fail without author property or prototype inspection.

The public constructor uses a Proxy construct trap and native record backend.
It reads newTarget.prototype once before arity and argument conversion, retaining
custom/subclass prototypes and the captured owner prototype for primitive/null
fallback. Omitted, undefined and null dictionaries bypass inherited author Gets;
explicit objects retain ordinary inherited property access. Original conversion
exceptions propagate without reading later dictionary members.

The getter is a genuine nonconstructable JSC native function, named
`get dataTransfer`, with length zero and an enumerable/configurable read-only
descriptor. Receiver brands require an actual DragEvent record. Other event
families, fake receivers and Proxies fail without author traps or conversion of
ignored arguments. Native wrappers retain their original DragEvent prototype
after public globals are replaced; cached wrappers and specialized providers
keep their existing precedence.

The bounded DataTransfer identity adapter caches one protected wrapper per actual
record and owning runtime. Its private prototype supplies a DataTransfer tag,
without installing a public constructor, operations or item/file-list surface.
Repeated attributes and constructor inputs retain the same record and wrapper;
different records remain distinct. Foreign-runtime wrappers fail the local
registry brand. Runtime close clears its retained identity maps; automatic weak
wrapper-world and collector ownership remain outside this slice.

The HTML constructor now explicitly marks its record untrusted. Its retained
page/offset geometry comes from the client coordinates. Untrusted inherited Mouse
geometry follows the existing flooring path, while raw native slots and movement
remain fractional. JavaScript construction timestamps after conversion against
the owner's existing time origin. Internal create remains trusted in this V
model. initMouseEvent/initUIEvent/initEvent retain DataTransfer and timestamp;
their existing atomic conversion and dispatch guards remain intact.

## Focused and integrated validation

Five native binding cases cover metadata/lifecycle, exact dictionary conversion,
transfer identity and brands, concrete native family prototypes and live records
with inherited initializers. Two main owner cases use actual parsed video and
script-created audio targets, native addEventListener, factory/constructor
dispatch, relatedTarget, current-event identity, cancellation, redispatch, DOM
polling and single delivery. Two HTML cases cover constructor trust/geometry and
internal-create/initializer preservation. The separately committed identity
prerequisite has three native cache/brand/close cases.

| Test file | Cases | SHA256 |
| --- | ---: | --- |
| `browserjs/drag_event_binding_test.v` | 5 | `cced5ce44130c5ba4351cba392855e24c8770bb76df4d35ec84dd5361a1adb30` |
| `main_drag_event_owner_test.v` | 2 | `0dde96b4d303784e76e580ed7e6c46c1293ff4fe04ae45cc7e3f177f8a8089ab` |
| `html/drag_event_constructor_test.v` | 2 | `f830ea10f1f5c4bcb03ed81995ac72b6cb8ef0233cee9363a72d92a5831a2046` |
| `browserjs/data_transfer_identity_test.v` | 3 | `dfcc055ba59fa84f5466a542178c24c3e683c47f2ba7fd917fc2171b5225d8ea` |

Three files compiled. Five browserjs and two actual-owner cases failed initial
DragEvent availability guards; their later assertions were unexecuted. One
HTML constructor case failed its initial untrusted-state assertion; later
constructor assertions were unexecuted. The second HTML internal-create and
initializer preservation case did not fail. All nine cases pass after
implementation.

Final focused, optimized and integrated runs retain identical new-test bytes.
The prerequisite passing runs used ancestral DDF plus the identity feature.
README and production GC-diagnostics commits were integrated before its commit;
only those two non-V files differ, and all V source/test bytes remain identical.
The final selected batch validates the identity adapter again at the committed
DragEvent source.

| Run | Outcome | Manifest | SHA256 |
| --- | --- | --- | --- |
| identity-default | 1 file / 3 identity cases pass at ancestral DDF with final identity bytes | `Build/audit-fixes/native-data-transfer-identity-default-final-manifest.json` | `20d99ac600aedda2fc412f8470d5052322c59682ce11e088fcd9f2b35b9af7fd` |
| identity-gc-none | 1 file / 3 identity cases pass with GC disabled at ancestral DDF | `Build/audit-fixes/native-data-transfer-identity-gc-none-final-manifest.json` | `04c5053ea2d25f92713b3a67facf6201310d2d42cce27ba1f201dd146754c6d1` |
| baseline | 3 files compile; 8 initial assertions fail; 1 preservation case passes | `Build/audit-fixes/native-drag-event-baseline-manifest.json` | `7d063dc80113aac22c237984ad210e661c6dd9167211feadebc13f2678307a65` |
| focused | 3 files / 9 cases pass with final implementation/test bytes | `Build/audit-fixes/native-drag-event-focused-manifest.json` | `3620aff5ccc78ff728d30e6f309daf828fedf3e4d8ba9d0fbe0d6305a5ab35ea` |
| default | 21/21 files pass at 682a7827 | `Build/audit-fixes/native-drag-event-default-manifest.json` | `98cfccd1eb58c39095415377c2ef60a6bb2f4e92e5cc2d67147df9cc82dcde24` |
| gc-none | 21/21 files pass with GC disabled at 682a7827 | `Build/audit-fixes/native-drag-event-gc-none-manifest.json` | `70f60aab40bda9e266a7a428663d5e2480300ef3558d57db5199cc9511f36173` |
| optimized | 3 files / 9 cases pass with -prod -gc none at 682a7827 | `Build/audit-fixes/native-drag-event-optimized-manifest.json` | `45d16e2349ad427b7e8aa788feaedf7fe8c808a6c7c04e370ccfa9fc9ae80709` |
| production | 10 completed stages; 2 exact pages; 11 smoke cases | `Build/audit-fixes/native-drag-event-production-private/manifest.json` | `161418ab673cc608e8ef158a41715188062ac2b34979964ce110f74e4c080da6` |

The isolated validation source is `/Users/alex/code/vox2/Build/audit-fixes/native-drag-event-validation-source`.
Final snapshots verify 5,019 exact Git
inputs, 55 selected / 166
production upstream references, 3 production compiler
inputs and 3 native archives. Commands, environments,
before/after snapshots and complete settled logs remain retained.

## Production, interrupted attempts and preservation

The frozen private browser passes strict signing/startup, two pixel-exact pages
and all eleven screenshot smoke cases, using the explicit
`-old-compiler -enable-globals -prod -gc none` diagnostic override. Both DragEvent
pages use null transfer; focused native/actual-owner tests establish genuine
nonnull transfer identity. These pages use native listeners rather than pending
media ondrag handler attributes.

This production image was built from 682a7827, whose exact recipes still name
the bundle Ladybird. That historical output is retained privately and is not the
current branded bundle. Current build instructions use `Build/v/Vox.app` and
`Build/v/Vox.app/Contents/MacOS/Vox`; later branding work is outside the pinned
production source and is preserved separately.

Persistent signed binary: `Build/audit-fixes/native-drag-event-production-private/browser-build/Ladybird.app/Contents/MacOS/Ladybird`
(SHA256 `b9def5f441dc44877584d525434da9f4485d830dae055e9d20381a720c66ee77`).
Persistent Skia dylib: `Build/audit-fixes/native-drag-event-production-private/browser-build/libLadybirdVSkiaText.dylib`
(SHA256 `58caaa4f153941b1e941f2d73498dfe6582151a03a8e063a2aafc84c606b670e`).
The verified closure retains 70 current and
2,087 prior artifact hashes.

Both original prerequisite runs compiled and failed two final zero-context
assertions. Identity, brand and lifecycle assertions reached before those
failures passed; no passing file credit is assigned. The later foreign final
VM assertion was unexecuted after the local guard failed. Corrected fixtures
require their exact initial running realm, stack length one and interpreter
depth zero.

Three initial CLI test runs ended without terminal manifests or summaries;
their exit codes and termination cause are unknown. All exact log bytes are
retained, including one observed FileAPI completion in each broad run, and
earn no passing-file credit. Detached supervisors reran the frozen commands
and recorded actual terminal exit zero after complete immutable manifests and
summaries.

The original production attempt completed its cache precheck but ended while
its build was incomplete, without a signed browser, final manifest, receipt or
known terminal exit. Its 26 persistent files and one shared-cache symlink
literal remain unchanged and earn no completed-production credit. A fresh
private output, preserved recipe/page helpers, one exact scratch-tag
substitution and a strengthened previously unexecuted provenance verifier were
supervised through actual recipe, production and provenance child exits; all
three must exit zero.

The first partial independent production proof used a nonexistent
EventDispatcher file path and failed with KeyError before completion. The
exact frozen helper and a retained reproduction with actual exit one remain
unchanged and earn no proof credit. Only the verification path was corrected
to the existing EventDispatcher implementation in dom/events.v; both that
source and page/page.v must remain byte-identical to the previous Wheel
evidence. No feature implementation, test, runner or production helper
changed.

Interrupted attempts have unknown terminal exit codes and receive no pass credit.
Detached recovery supervisors recorded actual zero terminal exits for complete
manifests, test summaries and production/provenance stages. No implementation or
test change was made for these retries. Only the verified owned scratch volume
was detached after completion; persistent source, signed image and evidence
remain retained, and final proof repeated after cleanup.

## Evidence and inventory

Consolidated evidence: `Build/audit-fixes/native-drag-event-evidence.json` (SHA256 `4d25a5a50607546dc653b9c4faabd55a5b87b444524f9e6d58f9b158cad6d2c8`).

Independent verification: `Build/audit-fixes/native-drag-event-verified-report.json` (SHA256 `384c4cb1b3fc9507076ef8a3b353ff74b3c342f2ec387f00c54752920fec0f30`).

Completion receipt: `Build/audit-fixes/native-drag-event-production-private/completion-receipt.json` (SHA256 `52c9f184b0593ec54c4426dc6045d8c72fe0d71528b0591e9a062a85c4ff2cf3`).

Private recipes: `Build/audit-fixes/native-drag-event-production-private/recipe-preparation.json` (SHA256 `f83913b76b4623822c3a8699b5fe3849fe6dddd108838a7c901d79e3dfaf0a60`).

Binary provenance: `Build/audit-fixes/native-drag-event-production-private/provenance.json` (SHA256 `0da90a1a969148f82b1c6fefb1abed0d4a2b56fa992b58fc0f21c68b3e6d90b8`).

Scratch cleanup: `Build/audit-fixes/native-drag-event-scratch-cleanup.json` (SHA256 `b99b5d6f9fef08feac2a972330e77f203fa1858ddfe5ff5110a29035889aeb40`).

Physical inventory: `Build/audit-fixes/source-current-module-loc-682a7827.json` (SHA256 `1e30f605ac80b9e550e7749cc1c62330556e8491793952db1de86a8b2b54a9a3`).

Initial identity test archive: `Build/audit-fixes/native-data-transfer-identity-test-before-vm-fixture-correction.v` (SHA256 `d668608a97fce4494c155abcdf003cf71101dcc94da2317be88e92a39a123e2e`).

Interrupted tests: `Build/audit-fixes/native-drag-event-tests-interruption.json` (SHA256 `9cefe37a644cbc84affee49e8186ff7f8d762451a44beb012a8f8132a4ff8f68`).

Interrupted production: `Build/audit-fixes/native-drag-event-production-interrupted/interruption-diagnostic.json` (SHA256 `ee45fcf2856a801606b8133532c4f353f5c5ce2f494a4674b35a90914c4f0fa6`).

Verification-only path correction: `Build/audit-fixes/native-drag-event-proof-event-dispatcher-path-failure.json` (SHA256 `8e9c831237f2e25b7d1a8dfed6070bfecd315018fff04a4e5aa72ce2c8fbbeab`).

The inventory verifies 78 disjoint owners and
2,216 assigned files with
432,960 implementation /
159,684 test V physical LOC.
CSS selectors.v changes bytes with zero physical LOC change; DOM contributes
+2 implementation / +71 test lines and 1 new assigned file; Painting
contributes +14 implementation / +43 test lines and 1 new assigned file;
DragEvent HTML contributes +2 implementation / +101 test lines and one new
assigned constructor-test file.
The identity prerequisite and intervening README/build-script integration change
no assigned bytes, counts or ownership. Prior inventories remain immutable.
Inventory table/reference changes belong to a separate documentation commit.

## Boundaries

Public DataTransfer constructor, operations, DataTransferItem/List and
file-list exposure remain separate work.

Physical Page/Cocoa drag generation, store mode transitions, default actions
and media ondrag handlers remain open.

Both screenshot pages use null transfer; genuine nonnull identity/lifecycle
use focused native owner tests.

Native event, transfer and WindowProxy wrappers remain owner-local; foreign
realms and weak ownership remain pending.

JavaScriptCore remains the browser engine; full LibJS runtime and media/MSE
parity remain open.

Later concurrent canonical implementation and tooling edits are outside these
frozen sources.

The earlier MouseEvent, related-target, UIEvent, PointerEvent, WheelEvent and
media evidence documents remain unchanged. This completes the pinned DragEvent
interface, without changing the broader historical ledger: 32 fixed / 25 partial
/ 9 open.
