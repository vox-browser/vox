# Native media raw ended and resize handlers

Implementation `6d5662976108f747e81109774bb0625a958d9a1b` extends lazy raw-handler compilation and ordered compact
attribute replay to `onended` / `onresize` on actual owner-local HTML
audio/video elements. Existing HTML namespace, media-model, Runtime, Document,
settings and forward/reverse wrapper ownership checks remain in force.
The browser continues to use JavaScriptCore. The final test/source epoch
`056556523cd2de75a2918f2cdfc3eee22afc832f` repairs only fixture quoting in one owner test file; it does not
add another translation feature. Both initial v1 owner-failed two-GC logs,
helpers and the initial source remain retained without owner pass credit.

FunctionBody validation precedes lazy native wrapper resolution and rechecks
the requested raw slot/source after resolver reentry. Lookup follows actual
Element -> Document -> Global scope, excluding ancestor forms. Inferred names
have no handler self binding. Equal-text writes replace IDL callbacks while
retaining their slot/listener; present removals clear callbacks and absent
removals preserve IDL-only state. Native ended getters and their captured
prototype identity remain readonly; no new public media-model API is added.

Six focused cases in two new files pass in both default and no-GC modes.
Binding tests cover parsed, created and lazily resolved audio/video wrappers,
readonly ended scope against conflicting sentinels, cache/prototype identity,
independent malformed handlers, early errors, resolver mutation, CSP,
foreign adoption/unavailable owners, original strict exceptions, scripting
gates and close. Those direct author Event probes carry no native-task credit.

Actual-owner tests use a controlled translated endpoint with metadata
readiness, duration/current position 1 and paused false. V defines playback
completion using the playback-position equality; pinned upstream uses its
PlaybackManager Ended state after consuming data. A microtask checkpoint
does not expose the native ended flag; the existing event-loop step does.
This boundary is preserved without claiming backend or playback-manager parity.

The existing native video model receives controlled 320x180 dimensions,
suppresses equal dimensions and empty intrinsic dimensions, then queues a
second resize when the nonempty dimensions return. Both resize callbacks see
the final native intrinsic/natural dimensions through a host-only probe.
Audio does not produce native resize events here, although its raw onresize
binding is exercised with author Events. JavaScript videoWidth/videoHeight
bindings, decoded frames and real media resource loading receive no credit.

Two trusted video resize tasks run before the video and audio end tasks.
Each end task delivers timeupdate, then pause with paused already true,
then ended. Callback probes retain actual native Event/target identity,
one Event argument, nonbubbling/noncancelable flags, window.event and
Element/Document/Global scope. Returning exact false sets defaultPrevented
on these native Events despite cancelable=false, preserving existing
translated handler behavior. Native objects and callback caches stay stable,
realm/context stacks balance and DOM/style changes reach retained painting.

Equal raw writes after IDL create fresh callbacks while preserving each
slot/listener. Prequeued resize/end tasks use the latest raw bodies. The
resize callback changes the raw ended body, flushes ordered replay through
a paused getter, queues another native resize and changes its own slot to
IDL. The ended callback changes to IDL and queues another native end task.
Those later tasks use the latest IDL callbacks. Repeated controlled end
calls deliver timeupdate/ended but emit pause only while previously unpaused.
Present removal suppresses queued handlers; subsequent absent removal leaves
IDL handlers intact. This is controlled task reentry, with no promise,
source-generation cancellation, loop-policy or backend playback credit.

A closed scripting gate dispatches native tasks while retaining raw strings
without invoking JavaScript. Reopening delivers a strict ended callback whose
original thrown object is reported exactly once and whose self-clear remains
visible through the live inferred name. A later ended listener still runs;
a subsequent native resize callback paints its DOM mutation. Realm/context
stacks balance, and no exception substitute is introduced.

The ten-fix broad batch uses the final repaired committed detached source epoch as the
focused tests, plus only the six authenticated original working overrides.
The initial remaining 41-file native batches each exit 1 because the existing
Window invocation fixture calls an unavailable actual-global listener method.
Their logs authenticate exactly 40 successful files / 126 cases and that sole
failed five-case file; the failed batches receive no wholesale pass credit.
Fixture commit bd5f9137e3972ec8b3b6e41276ad882e00f9b2db changes two setup calls to borrow
EventTarget.prototype.addEventListener on the same actual Window. It adds no
runtime API or eleventh translation fix. A fresh detached original 05655652
HEAD/index receives the same six original overrides plus only the committed
test override. Every other tracked runtime/dependency byte and mode matches
the original broad source. The corrected one-file/five-case fixture passes
both GC modes. Its canonical foreign-parent runtime receives no credit.
Combining the original passing 40/126 with repaired 1/5 gives 41/131; the
separately completed focused 2/6 makes 43 files and 137 cases per mode.
No successful native subset or big native suite is repeated. The fresh focused cases are not run again. The
selection includes all completed raw media slices, the prior lifecycle/wheel
baseline, DOM compilation/identity/invocation/attribute hooks, JSC conversion
and Window bindings, static Window and scripting-owner regressions.

Both original full LibJS jobs exit 0 with 234/234 summaries. No-GC retains
all 234 explicit successful file rows. The default log retains 232 explicit
rows; padding and iterator positions 173/174 are absent. Only those unchanged
two files / three cases are observed again in default mode on the exact
original source, producing two positive rows and actual exit 0. The disjoint
232+2 default union and complete no-GC rows authenticate all 234 test files
per mode. No full LibJS or no-GC repeat is run. The official unmodified AST
driver compares all 100 pinned input/expected fixtures exactly after its
existing terminal CR/LF trimming, with no case overrides. This does not imply
full LibJS parity or replace JavaScriptCore: pending interpreter/builtin/module
work and the parser's existing boundaries remain outside this media slice.

A fresh default-Boehm production bundle passes strict signing and headless
startup, two retained raw-wheel public pages pixel-exact, all 11 default smoke
comparisons with their unchanged established fuzzy/macOS allowances
(eight pixel-exact), and all eight SVG regressions pixel-exact. These are 21
comparisons/38 serial document viewport captures. The public pages exercise
wheel author Events; native ended/resize generation is proven by the owner
fixtures. No no-GC production, physical media backend or full browser/interface
parity is claimed. The complete repository translation suite is not selected.

Evidence: `Build/audit-fixes/native-media-completion-raw-handler-evidence-v1.json` (SHA256 `f5116360958d20012e7e760c19494e056cf17f49b7c371e11c1f1e6dab935f0b`).
Actual broad receipt: `Build/audit-fixes/native-media-completion-raw-handler-broad-actual-exit-v3.json` (SHA256 `6cf995bd0f4e8d97642b1cc0d25845c170f198696b666c7d7df1fe6dd4fbe18c`).
The receipt authenticates every actual stage terminal and log,234 pinned
upstream fixture artifacts (34 screenshot assets and 200 AST inputs/expected),
retained handler pages, source/toolchain/regex prerequisites, signed bundle,
pixels and scratch. Native compiler scratch remains on the freshly allocated
owned 8GiB HFS+ RAM volume. Device, mount point and VolumeUUID match the
allocation record; every file/directory in the retained compiler subtree is
authenticated, while filesystem metadata outside that subtree is excluded.
Permanent source/build/pixel/evidence artifacts remain in this repository.
The original five-path implementation transaction and one-path fixture
quoting repair are authenticated separately against their actual parents.
The original 05655652 runtime receives focused/broad credit; invocation
fixture credit uses its byte-identical runtime plus the explicit test override.
The one-path verification fixture physical delta is recorded independently
in the broad receipt and remains outside assigned DOM ownership. Both test
repairs remain part of the same tenth slice.

All 141,887 prior artifact records, earlier private sources/helpers/scratch,
failed/interrupted attempts and unrelated current work remain retained.
Actual failures retain their terminal/log records without wholesale failed
batch credit. Initial owner failures receive no pass credit; the separate
native passing subsets are explicit in the recovery receipt. The original
LibJS default successful terminal/full summary is retained alongside its
focused evidence-gap observation. Final closure and independently observed actual terminal
receipt are `native-media-completion-raw-handler-final-closure.json` and `native-media-completion-raw-handler-final-actual-exit.json` under
Build/audit-fixes.

All five feature hashes authenticate the committed/private tested source.
Four current owned files match exactly; two unique owned main gates include
onended/onresize and stay byte-exact outside all changed Git line ranges.
Proof phases retain stable full main snapshots, observed committed HEAD
context, foreign commit traces and exact diffs. Runtime/build credit belongs
to the tested committed feature epoch; current full main and foreign edits
receive no separate pass credit. The strict original-six three-way
preservation rule remains unchanged.

Physical accounting: `Build/audit-fixes/native-media-completion-raw-handler-inventory-scoped-v2.json`
(SHA256 `94636fc4d955f1876457b225e9670258514bded337ed9c9dbdc0bd7c8a805730`). All five browser/root paths remain outside
the sealed 78-owner assigned DOM inventory, adding zero assigned files,
implementation lines or test lines. Global tables, pins, mappings and
historical ledgers stay preserved; counting confers no behavior/test credit.

The tenth fix closes the user's verification cadence only after the actual
selected broad stages pass. Broad baseline advances from aa6f0246 to
`056556523cd2de75a2918f2cdfc3eee22afc832f` and the next ten-fix batch starts at 0/10. Documentation commits
do not increment that count. Raw onerror and remaining unselected handler
names, partial named-property exposure, intrinsic anonymous JSC source,
foreign/weak ownership, close during active JavaScript, real network/decoder
and complete media promise/playback/interface parity remain open.
