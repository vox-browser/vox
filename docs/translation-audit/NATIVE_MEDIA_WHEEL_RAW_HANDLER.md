# Native compact media raw onwheel compilation

Feature: `ba8108a9bf1d17d12cf4f20efc1942c6e8ca26a8`; its actual parent:
`58149ba1052550c8e2db70656b0ca8765fae4b1b`. Validated implementation source:
`ba8108a9bf1d17d12cf4f20efc1942c6e8ca26a8`. Upstream reference:
`963d46a829f3e1b79f44dba9d02afb70654300fa`. Verification date: 2026-10-14 UTC.

Raw `onwheel` content attributes on compact HTML audio and video elements enter the
owning native EventTarget's existing lazy handler path. A getter or event delivery
compiles the actual FunctionBody once and caches the real JavaScriptCore callback. The
handler's inferred name is `onwheel`, its single parameter is `event`, and it retains
ordinary strictness, arguments, this and constructability. No helper variable or
named-function-expression self binding is inserted.

The combined Document compiler requires the actual owning Document wrapper, a live
same-Runtime MediaElementHost with the same Document and settings, the native
target-to-wrapper and wrapper-to-target identities, the actual cached audio/video model,
and that host's exact wrapper-to-model record. A generic EventTarget wrapper does not
supply media ownership. The Runtime retains an array of installed media hosts rather
than replacing one global or last-host record; eligibility filters that array for the
actual live owner. Host close handlers clear their records and the Runtime clears the
array on close; weak ownership and garbage reclamation guarantees remain open.

When the target has no existing wrapper, the compiler first parses the original
FunctionBody and checks early errors in isolation. Malformed bodies therefore never
invoke the JavaScript lazy resolver or manufacture a media model. A valid body may
resolve the actual compact media facade through the existing resolver. The resolver runs
in the owner's VM execution context; afterwards the compiler rechecks the handler slot
identity and raw bytes, wrapper mapping, model, Document, and matching live host.
Resolver removal or replacement cannot compile stale source.

Scope lookup follows the actual media Element facade, the actual owning Document facade,
then the relevant global. Audio and video have no form-owner environment; a nearby
ancestor form is not inserted. Cached functions retain those captured objects while
observing their live properties, including the media facade's native paused and volume
accessors and ordinary Document expandos. Object environments retain normal property
lookup and Symbol.unscopables behavior. Existing ordinary Element/form compilation and
the Window compiler remain in place.

Malformed FunctionBody syntax or early errors null the handler value while retaining its
activated native listener and original content attribute. Unavailable ownership, missing
Document wrappers, absent media hosts, mismatched model records, generic wrappers,
closed owners and unsupported handler names retain the raw source instead. A later
actual owner can retry that raw value. CSP script-attribute checks stay at
content-attribute mutation, before replacing the current callback; blocking a mutation
preserves that callback even though the DOM attribute contains new bytes.

Raw replacement preserves the existing native listener position and caches the actual
returned function. Equal-text attribute writes replace a later IDL callback. Removing an
existing attribute deactivates the slot; removing an absent attribute does not clear a
later IDL callback. Callback self-replacement changes the next delivery without adding a
duplicate native listener. Invocation uses the relevant settings, actual media and Event
wrappers, Window.event lifetime, original exception identity/reporting and the Page
scripting gate. Exact Boolean false sets the canceled flag directly, including
noncancelable delivery; preventDefault keeps its own gates. Software GG wheel delivery
applies callback DOM/style mutations and suppresses default inner/viewport scrolling
when the handler cancels.

This slice covers only raw HTML media wheel attributes. Raw non-wheel media or ordinary
Element handlers, image/object/fieldset/output/custom-owner integration, SVG/MathML raw
activation, generic or foreign-realm wrappers and unrelated media interfaces remain
outside this adapter. Missing ordinary control-owner models remain unavailable under the
existing compiler. Closing a Runtime from inside executing JavaScript or a resolver
remains unsupported; post-close access and dispatch are separate lifecycle cases.

Callback metadata keeps the exact named source `function onwheel(event) {\nBODY\n}`.
JavaScriptCore's intrinsic Function.prototype.toString still displays the anonymous
inner function source; the intrinsic is unchanged. Attribute-origin locations and
parse-error reporting remain the existing upstream FIXME. Document and form
named-property hooks expose only the existing compact facade surface. JavaScriptCore
remains the browser backend; this work does not establish full HTMLElement,
HTMLMediaElement, LibJS, physical operating-system wheel, or device injection parity.

Completed focused verification: nine files /30 cases in each of the default and gc-none
modes, including six new cases in the native media binding and BrowserApp owner
fixtures. The fixtures cover parsed and script-created audio/video, lazy/cache and
actual callback identity, native paused/volume scope access, live Element -> Document ->
Global fallback without form scope, parse-before-resolver isolation, malformed/null
versus unavailable/raw behavior, missing/mismatched/generic owners, CSP, listener order,
equal-text raw/IDL writes, strictness and live handler-name lookup, original exception
identity, Page scripting gates, Runtime close, software GG cancellation/default scroll
and DOM/style paint. Actual completed test results: Each direct default and gc-none
child exits 0 with nine successful files and all 30 source-counted cases, including the
six new binding/owner cases. Both complete before/after source snapshots are identical;
preflight compiler checks receive no runtime execution credit. Actual test input/source
provenance: The two GC executions use source epoch v1; successful production uses a
fresh exclusive source epoch v2 at the same ba8108a9 commit. Both retain all 5134
identical committed and overridden input paths, including the original six working
overrides and executable modes; all hashes are compared exactly. Source v1 and its
failed no-GC production artifacts remain intact. Successful production uses the
unchanged build script default Boehm configuration, which avoids V -prod and uses C -O2;
no implementation, compiler, override or foreign paint source is patched. The prepared
epochs authenticate compiler binaries, regex prerequisites, eight pinned upstream
references and public page bytes. Concurrent canonical work is preserved and excluded
from these source pins. Failed or interrupted attempts and their credit limits: Working
typecheck v1 exits 1 on the fixture checkpoint name and old-V expression errors; v2
exits 1 on the media cached-model if expression. They execute no test bodies or
production builds. Working typecheck v3 exits 0 after those corrections, with no runtime
credit. Preparation v1 exits 1 at the executable backup-mode preflight before cloning
prerequisites or starting tests/builds; preparation v2 exits 0 using recorded override
modes. All failed preflights remain preserved. The separate actual GC and production
child receipts alone establish execution success. The first production attempt uses gc
none and exits 1 at its sole build stage: unrelated canonical paint explicit-none
defaults become fatal compiler diagnostics under -prod. It creates no signed binary and
earns zero build, signing, startup or screen credit. Its original source, log and actual
failed child are preserved. The fresh source-v2 production with default Boehm
configuration independently completes the required stages without changing any source or
compiler.

Completed production verification: fresh build, strict signing check, non-windowed
startup, two exact public raw-media handler reftests, all eleven configured screenshot
smoke cases and eight exact SVG regressions. The public reftests use untrusted author
WheelEvent dispatch with view:window. Software GG startup/owner events remain software
injections and do not establish physical input delivery. Actual completed production
results: The direct production-v2 child exits 0 under the standard default Boehm
configuration. Build, strict signing, startup, two public media raw-handler reftests,
eleven configured smoke cases and eight SVG regressions each exit 0. Both raw pages and
all eight SVG cases are pixel-exact; eight smoke cases are exact and three retain their
configured tolerances. The private signed binary SHA256 is
`1784dfd58e8380b0c77bc5cd145c1e2667875cbc6d5af2702d3ea11a3fc645e4`; all signed artifacts
are retained independently with strict signing exit 0. The complete private source
before/after snapshots are identical. The failed production-v1 build remains failed with
zero startup credit. Canonical Build/v provides no production credit. Actual startup
injection count and evidence: The authenticated frozen main.v invokes each of the two
frozen smoke functions once; main_wheel_input_smoke.v and main_element_wheel_smoke.v
each inject three mouse_scroll GG events. Both actual success markers and the final
startup success marker are present: six software inputs are proved independently of the
aggregate production field.

Consolidated evidence:
`Build/audit-fixes/native-media-wheel-raw-handler-evidence-v1.json` (SHA256
`ee79c9b49c097ff0d29417c1cf40d2bd0a877733729eb7ae1f3d9bdee8551437`) Frozen
implementation and fixture inputs:
`Build/audit-fixes/native-media-wheel-raw-handler-frozen-v1.json` (SHA256
`fd24cc7903c3b3e974e7ad403f7333d2ef4680684beedb38433e0b3a9a88ba29`);
`Build/audit-fixes/native-media-wheel-raw-handler-prepared-v1.json` (SHA256
`bd562af4fc6ede28c4963a8f262dedf67b5cd8b34c6d3efc33b3cfd481e7a535`);
`Build/audit-fixes/native-media-wheel-raw-handler-prepared-v2.json` (SHA256
`a998cdcf7f814a22366e58ebeb34030cd69b5e1d378ecec1c837b5855a33b6b7`);
`Build/audit-fixes/native-media-wheel-raw-handler-source-epoch-equivalence-v1.json`
(SHA256 `3dbafb93107cd0764536629445846198921a496b6c29790535743427c1189f30`) Actual test
receipts: `Build/audit-fixes/native-media-wheel-raw-handler-default-child-exit-v1.json`
(SHA256 `d14433b018f1713a406d45820ca6de083c49abd97b4c17c9796f7772861e0aca`);
`Build/audit-fixes/native-media-wheel-raw-handler-gc-none-child-exit-v1.json` (SHA256
`53eab85beb52d8fb47f224883500335a5fc48aa5925cd75c361485ea8616f635`) Actual production
receipts and retained signed artifacts:
`Build/audit-fixes/native-media-wheel-raw-handler-production-v2/manifest.json` (SHA256
`fa44aa444fff285fde8efe486a478dfbfc76db2892e3ff40ad8e470120fadc67`);
`Build/audit-fixes/native-media-wheel-raw-handler-production-child-exit-v2.json` (SHA256
`2250c8ece3a568ff6b62b8966f7b2e2963177f3c1f84ba63d4e364ffebced8a4`);
`Build/audit-fixes/native-media-wheel-raw-handler-production-retention.json` (SHA256
`24ddb280987488f841242e53ace0d773766507c769dd8f81292d7b1f20a8758f`); failed initial
attempt:
`Build/audit-fixes/native-media-wheel-raw-handler-production-child-exit-v1.json` (SHA256
`4a0d64f2611431dfe6a696fece80b497e56543a11b9caed677a62d5ff7383adc`) Prior evidence
preservation and retained local compiler scratch: Prior immutable evidence is
authenticated by the consolidated record. Owned local compiler scratch is retained at
`Build/audit-fixes/native-media-wheel-raw-handler-scratch`;
`Build/audit-fixes/native-media-wheel-raw-handler-scratch.json` (SHA256
`b09cebc0af4be1b1916d278aaadba86176a5207259b42360c83e745b4ddcdbb9`). Final preservation
records: `Build/audit-fixes/native-media-wheel-raw-handler-final-closure.json`;
`Build/audit-fixes/native-media-wheel-raw-handler-final-actual-exit.json`.

The seven owned implementation/test paths are browserjs or root support paths. Each is
excluded by the sealed 78-owner assignment rules, so this feature contributes zero
assigned DOM files, implementation lines or test lines. Actual scoped counter result
against the feature's own parent: Against actual parent 58149ba1, all seven feature
paths are excluded browser/root support under the sealed 78-owner assignment. Assigned
DOM changes are zero files, zero implementation physical V lines and zero test physical
V lines. Actual scoped inventory evidence:
`Build/audit-fixes/native-media-wheel-raw-handler-inventory-scoped-v1.json` (SHA256
`db2fda4bc1e5b241de40e7d5f053316f180ca4c45baa7b99b329ac130a29ffed`) Inventory status is
committed separately from this audit. Global inventory tables, pins, references,
source-unit mappings and historical ledgers remain separately preserved; independent
canonical changes receive no raw-media validation credit.
