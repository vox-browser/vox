# Yandex Maps rendering comparison

Target: <https://yandex.ru/maps/2/saint-petersburg/?ll=30.248557%2C59.948999&z=15.04>.
Pixel-perfect live parity with Brave remains **incomplete**. The browser uses
JavaScriptCore; these changes do not establish LibJS runtime parity.

## Completed fixes

The compact script bridge now preserves native input values, replaces children
when assigning the same `textContent`, implements connectedness and containment,
forwards scrolling, installs Fetch on the actual browser window, and reports
native asynchronous script errors in capture audits. Focused tests accompany
these changes (`4e440d3d`, `403f9f9c`, `2648cd49`, `96fd0e16`, `a5fa0120`,
`6d9b3ab7`, `1302403f`, `e756b683`, `40d9edf3`).

`053c8cc0` keeps Chromium-policy U+2010/U+2011 hyphens in the selected macOS
font when CoreText supplies a synthesized glyph absent from its raw cmap.
Existing cmap glyphs, Unicode clusters, advances, cache lifetimes, and the
LibWeb policy remain covered by focused tests. This corrects the Yandex heading
and the weather widget's horizontal position.

`e55a6d22` retains full-opacity compositor surfaces for the Chromium policy's
transform, translate, rotate, scale, perspective and transform-style
`will-change` hints. The hints are suppressed below `will-change: contents`,
including through unboxed ancestors and shadow-DOM slots. Existing 3D-transform
surfaces survive that suppression; opacity and hint surfaces coalesce.
This follows Chromium's
[compositing reason selection](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/third_party/blink/renderer/core/paint/compositing/compositing_reason_finder.cc).
The new `will-change-transform-shadows` fixture improves from 13,134 differing
pixels to zero at 800 × 600, scale 1. This independently verified correction
does not reduce the archived map's remaining 4,967 differing pixels.

## Latest reproducible archived comparison

Both browsers render the same script-free archived DOM at 1024 × 768 logical
pixels, backing scale 1, with an eight-second settle period. External resources
still use the network; this is not an offline fixture or a live-site acceptance
run. Every capture starts a new process and private profile.

| Measurement | Matched pre-Cyrillic baseline | Cyrillic + raster correction |
| --- | ---: | ---: |
| Differing pixels / 786,432 | 4,968 | 4,533 |
| Differing fraction | 0.63171% | 0.57640% |
| Mean absolute channel error | 0.0140351 | 0.0030543 |
| Maximum channel error | 64 | 8 |

The heading's rectangle now matches Brave at `(24, 73, 164.140625, 24)`;
the weather widget starts at `x = 196.140625`. The remaining differences are
mostly one-level channel differences around map-control shadows. Of the
remaining differing pixels, 4,512 have maximum error 1, twenty have error 2,
and one footer-text pixel has error 8. These counts are exact pixel
comparisons, not a perceptual similarity score.

Local evidence under `Build/yandex-maps/`:

- `coretext-hyphen-recovery-1792979076217380000/`: both screenshots, heatmap,
  pixel metrics, final DOM audit, source-scope receipt, process receipts, and
  executable/native-library identities.
- `production-1792973150463471000/maps-live-brave-fetch-direct.html`: archived
  DOM, SHA-256 `13df4839bc5bb7158ed84806bc432fdb188aa79f1b779313b03c41ea8d210383`.
- `coretext-hyphen-production-1792978459674938000/Vox.app`: preserved tested
  bundle; executable SHA-256
  `a00aee0a9130b0cb57bd66f83af3a4eb404bfddfc2b4df0bc14517ea78f009f0`.

The four changed font files stayed identical through build and capture.
Unrelated source files changed during the shared-checkout build; the
`source-scope.json` receipt records this limitation. The preserved bundle and
its native libraries, rather than the later working tree, identify the result.

## Validation and limits

All six focused font test files pass; the four new hyphen tests also pass with
`-gc none`. Production build, startup smoke check and code signature pass.
All nine SVG image/paint-server mutation comparisons remain pixel-exact. The
installed/file-backed hyphen rendering reftest is exact at 400 × 180.

The original production validation exceeded the default 12 GiB RSS guard while
loading a large base64 font fixture and was killed. Its failed guard receipt is
retained as `coretext-hyphen-production-guard.json`. Retrying with the same font
in a separate file and the verified preserved bundle completed successfully;
`coretext-hyphen-recovery-guard.json` records exit 0 and peak sampled process-tree
RSS of 9,599,107,072 bytes. The budget was not raised.

Fresh headless Brave live captures have returned a robot check or an empty
title without the map. Their pixels are excluded from acceptance metrics. Vox loaded the map, but that
alone cannot prove matching live state or pixel-perfect rendering. A valid
fresh live reference and zero differing pixels are still required.

## Transform-hint verification

The nine transform-surface tests pass with both Boehm and `-gc none`; the
raster-layer tests also pass. Production build, startup and signature checks
pass. All six controlled map-shadow palette cases and the existing
`box-shadow-blur`, `opaque-box-shadow` and `scroll-overlap-gradient-layer`
references are pixel-exact. Broader suites are not credited for this slice.

Evidence is retained in `transform-hints-focused-1792982221259709000/` and
`transform-hints-production-1792982479436352000/` under `Build/yandex-maps/`.
Their guard receipts record exit 0 and peak sampled process-tree RSS of
8,374,091,776 and 9,641,984,000 bytes respectively. The tested implementation
and fixtures stayed unchanged. One unrelated CSS test changed during the
production build; the source-scope receipt records it. The preserved tested
executable's SHA-256 is
`235819c3007251306a780a235bf810494a72272651e444215f211992b4eafd8e`;
`identity.json` also records its native libraries.

The same archived DOM still differs at 4,967 / 786,432 pixels, with MAE
0.0140216 and maximum channel error 64. The fresh live Brave reference again
returned the robot check and is excluded from acceptance metrics.

## Cyrillic context shaping

`e2e364fc` extends Chromium-policy shaping across soft word boundaries to
single-script Cyrillic runs. A hyphen can now retain its kerning context in
“Что-то”, including inside an LTR isolate. Mixed scripts, font changes, hard
breaks and unsupported scripts retain segmented shaping. Runs whose glyphs
repeat a multi-glyph cluster's UTF-16 span also retain segmented shaping;
summing those spans cannot identify safe chunk boundaries.

The focused checks pass eight context-shaping cases in both Boehm and
`-gc none`, plus the precise-inline-advance regression in Boehm: 17 executed
cases. The controlled `cyrillic-context` fixture improves from 2,312 differing
pixels to zero against a fresh Brave capture at 800 × 600, scale 1. Its
file-backed test font contains original rectangular glyphs and a deliberate
cross-boundary kerning pair; it avoids depending on installed-font kerning.
The font generator reproduces SHA-256
`dc9d355e69cdfa05e0a40227d8c548bdb1270d2e42a05844f0f845c1fdf14e5f`.

Evidence is retained under `Build/yandex-maps/` in
`cyrillic-context-focused-1792988060569311000/` and
`cyrillic-context-cluster-focused-guard.json`. Compilation, actual test
execution and captures exited zero; the guard's sampled peak RSS was
8,410,120,192 bytes. The six implementation/test/fixture source hashes stayed
unchanged. The exact fixture capture used the preceding preserved Cyrillic
bundle; the final multi-glyph-cluster fallback is covered by the focused
runtime checks. The rebuilt production bundle has now repeated that exact
fixture result; the production evidence is recorded below.

The production comparison retained fresh baseline/reference captures in
`cyrillic-context-production-1792988556062138000/`, then exceeded its
900-second build deadline during C compilation. Its guard reports child exit
1, `remaining_children`, and peak sampled RSS 6,988,578,816 bytes; no production
pass is credited for that attempt. Recovery completed compilation but signing
failed because an abandoned `.Vox.*` compiler directory remained in the bundle.
After checking that its owning process had exited, that directory was retained
separately and the preserved bundle was ad-hoc signed. Strict signature
verification, startup, and all controlled text captures then passed. The
original failed guard receipts remain retained; recovery does not change their
exit codes.


## Unused perspective raster contexts

`5e6cc65b` delays the whole-document raster fallback until a paint command
actually uses a perspective or scroll-compensation context. Unsupported state
propagates through descendant contexts, so painted perspective descendants
still use the conservative root fallback. Empty perspective containers no
longer disable independent scroll layers; their own backgrounds retain the
ordinary parent context. Reusing the planner clears the retained state.

All ten raster-layer cases pass with both Boehm and `-gc none`, including three
new cases for unused perspective, painted descendants, and referenced versus
unused scroll compensation. Compilation and actual execution exit zero; the
three implementation/test hashes stay unchanged. Evidence is retained in
`Build/yandex-maps/unused-raster-context-1792990767506049000/focused-1792992189956745000/`.
The preceding attempt failed during C compilation because the private staged
harness omitted a sibling native-header path; no tests ran in that attempt.

The preserved production bundle now exercises this path: a separate LLDB
diagnostic records 44 plans, 44 independent-layer plans and zero root fallbacks.
The matched baseline recorded 45 plans and 45 root fallbacks. These loading
counters establish eligibility, not scrolling performance.

## Production recovery and remaining pixels

`cyrillic-context-production-1792988556062138000/` retains the matched
reference/baseline/candidate images, region metrics, process identities and
source-scope receipts. Its executable SHA-256 is
`2a18f0222c6856fe7552751524951f4220c87616f3cc9ed7651eb4885932e6a3`;
`identity.json` pins its native libraries. The compiled Cyrillic and raster
inputs match their focused receipts. Subsequent unrelated checkout changes,
including inline-iterator changes, are recorded separately and receive no
credit from this preserved executable.

The Cyrillic fixture and three text regressions are pixel-exact. The sidebar
message improves from 244 differing pixels (maximum error 64) to seventeen
(maximum error 1). The map-controls region regresses slightly from 4,045 to
4,101 differing pixels, retaining maximum error 2; that regression remains
included in the full-map totals above.

The eleven-case screenshot smoke check on this preserved bundle reports seven
exact comparisons and `canvas-text` within its existing sparse bounds.
`inline-node`, `ordered-list`, and `text-decorations` fail. This executable
predates `bb4ae5c5`, which repairs explicit layout-test font selection under
the Chromium policy. The new production validation must verify that fix;
there is no full screenshot-batch pass for this bundle, and its SVG group did
not run after the smoke failure. No tolerances were changed.

## Native document title binding

`0ca27dc3` removes the compact document's cached own `title` property and stale
snapshot title replay. The existing native `Document.prototype.title` accessor
now reads the live DOM, and its setter invalidates cached title content and
notifies the owning document. Titles inserted into the head by
`insertAdjacentHTML` survive subsequent queries and finalization. Character
data edits, tree order, title creation, DOMString conversion and detached
documents have focused coverage.

The selected main-package checkpoint executes 37 cases in both Boehm and
`-gc none`, including three new title cases. Compilation and actual test
execution pass. Own title sources stayed unchanged; an unrelated native
Graphite header changed during the no-GC check. Evidence is retained in
`map-regression-batch-1792994476858141000/`. The following browserjs compile
failed because the private staging harness omitted its package-native header;
no browserjs tests executed in that attempt. Remaining package checks resume
with the corrected harness rather than repeating the passing main cases.

The rebuilt production bundle passes the native title probe: a title inserted
as a head fragment, including non-breaking spaces, entities and Russian text,
agrees between JavaScript and the native DOM. Build, signing and startup also
pass. Evidence is retained in
`native-title-production-1792995978219967000/`; its executable SHA-256 is
`a06e5e600e77f7428ec572219bc249207a2aa61c5b5ddd6f33d5812eb967dc3b`.
An unrelated Graphite raster-cache header changed during that build and is
recorded in its source-scope receipt.

The archived map differs from Brave at 4,533 pixels, with maximum channel error
8. The fresh live Vox capture loads the requested map but differs at 427,427
pixels from a valid windowed Brave reference. Brave initializes its interactive
map while Vox retains the server-rendered view. The headless Brave robot-check
response is excluded. Seven screenshot smoke cases are exact and `canvas-text`
stays within its existing bounds; `inline-node`, `ordered-list` and
`text-decorations` still fail, including with the explicit layout-test font fix
present. All nine SVG mutation comparisons are exact. The enclosing production
check therefore fails; no tolerances were changed.

## Independent-layer box shadows

`fccd848d` rasterizes independent-layer box shadows against transparency. Only
the root raster path may incorporate an opaque destination backdrop; doing so
inside an independent layer rounds colors before the layer is composited and
darkens control edges.

The native regression checks 36 independent-layer combinations at scales 1 and
2, with padded destination rows, three clip shapes, three alpha values and both
paint modes. Another 36 exact comparisons against the preserved old native
library verify unchanged root output. The pre-fix control fails the new
independent-layer assertion. The isolated native suite passes all 72 shadow
comparisons, 15 clip cases, 720 composite comparisons, 6,240 glyph-cache
comparisons, 864 GPU-backdrop comparisons and 288 tiled-image cases.

Evidence is retained in `shadow-isolated-1792997298517100000/`. The native
suite's guard records actual execution exit 0 and sampled peak RSS of
407,044,096 bytes under its 3 GiB budget. Its immutable source hashes remain
unchanged. The enclosing private harness later failed on a signed-executable
identity assertion, so that attempt receives no production validation pass.
Matched compiled-library captures are queued with corrected identity checks;
the earlier injected-shadow diagnostic's improvement from 4,533 to 424 pixels
is not yet a production result. Pixel-perfect live rendering and LibJS runtime
parity remain open.

## Dynamically inserted classic scripts

`7d2c8a73` adds external classic-script loading to the compact native browser.
Previously it collected only the initial scripts, leaving bundles inserted by
Yandex's startup code unexecuted. Requests now belong to individual script
elements, with bounded background fetching, default async completion order,
`async = false` ordering, native trusted completion events and live
`document.currentScript`. Duplicate URLs share an in-flight fetch but execute
for each element. Chained bundles keep the document's load event pending;
navigation releases those delays and discards the outgoing requests.

The focused suite executes twelve cases with both Boehm and `-gc none`: 24
passing cases. Coverage includes late `src` and type changes without a tree
mutation, buffered out-of-order async responses, duplicate URLs, removal and
adoption, navigation cancellation, already-started clones, a real local-file
fetch, chained load handlers, the eight-request concurrency bound, and initial
inline/deferred-script identity. All ten recorded implementation/test hashes
stay unchanged. Evidence is retained in
`dynamic-scripts-1793002425304678000/`; the enclosing guard records child exit
0 and sampled peak process-tree RSS of 7,132,839,936 bytes under its default
12 GiB budget. Both test binaries actually execute under separate 3 GiB guards.

The browser fixture `dynamic-script-loading.html` checks two ordered elements
sharing a URL and a bundle inserted by a load handler. It turns green only
after all three execute, their events have the expected identity, and
`window.load` follows the complete chain. The native fixture reaches
`Dynamic scripts PASS`, has no JavaScript diagnostics or native errors, and
matches the independently captured Brave reference at all 800 by 600 pixels.
The reference is retained in `Tests/Browser/Brave/expected/` (`a08fba2f`).
The adjacent nine script-load-event, scheduling and asynchronous-image tests
also compile and execute successfully; their runtime guard records exit 0
and sampled peak RSS of 169,951,232 bytes under 3 GiB. Evidence is in
`dynamic-script-regressions-1793005878480323000/`.
Dynamic inline scripts and module fetching/linking remain outside this slice.

## Images extending above the root raster

`e994661a` bounds the output copy from a root image tile. Negative document
rows belong to tile zero, but their derived tile-row indices are negative.
The input copy already excluded those rows; the output copy did not. The
archived map reproducibly crashed in that copy with SIGBUS before this fix.
An AddressSanitizer control reports a heap-buffer-overflow in the same path.
The fixed implementation passes 42 exact comparisons against an independent
full-root draw, covering two scales, three tile heights and seven vertical
origins, including negative origins. The native raster suite also passes its
15 clip cases, 720 composite, 36 shadow-layer, 6,240 glyph-cache, 864 GPU
backdrop and 288 tiled-image comparisons. The enclosing 3 GiB guard records
exit 0 and sampled peak RSS of 559,235,072 bytes. Evidence is in
`image-root-rows-1793005472614057000/`.

The production check reuses the source-pinned V executable built in
`Build/hn-small-text/font-policy-production-2/` and rebuilds its native renderer
from committed headers plus this fix. Independent native glyph experiments
in the shared checkout are excluded. The preserved bundle is signed and
verified, passes headless startup, and keeps the dynamic-script fixture exact.
Its fresh-process archived-map capture succeeds with 424 differing pixels
and maximum channel error 8 against the unchanged Brave reference. This is a
compiled native-library result, confirming the earlier injected-shadow
observation. It does not establish pixel-perfect rendering.

The fresh live capture reaches the requested Yandex Maps title and complete
readiness, but still has no map canvas. A valid windowed Brave capture has a
canvas; their 1024 by 768 viewport comparison differs at 328,981 pixels with
maximum channel error 255. The nine SVG source/paint-server mutation reftests
remain exact. The smoke batch retains the existing inline-node, ordered-list
and text-decorations failures; seven other cases are exact and canvas-text
stays within its existing sparse allowance. No tolerances changed.

Evidence is in `image-root-production-1793005715607370000/` and
`map-visual-batch-1793005985563844000/`. An injected startup diagnostic hit the
default 12 GiB memory guard (sampled 12,946,128,896 bytes, child exit -9),
interrupting the first enclosing run after its successful native captures.
The resumed comparison/regression run completes, with guard child exit 1
because the recorded diagnostic interruption and existing smoke failures
remain failures; sampled peak RSS is 7,197,294,592 bytes. It is not an overall
passing acceptance run. The live map and LibJS parity goals remain open.

## Shared native session cookies

`25ed7179` and `c4c986ce` give navigation, native Fetch/XHR and
`document.cookie` one session cookie store. Previously response cookies were
not available consistently to later requests or scripts. The startup
diagnostic recorded successful recommendation responses followed by handled
`Invalid csrf token` rejections. The signed production build with shared
cookies now renders the recommendation heading and photo cards.

The store matches host/domain, path, expiry, Secure, HttpOnly and SameSite;
protects cookie prefixes and existing secure/HttpOnly values; and respects
Fetch's credentials flag for both sending and accepting cookies. Navigation
stores each redirect response's repeated Set-Cookie fields before following
the redirect. Script reads query the current store rather than a stale
document snapshot. Retained data survives production scratch-arena resets.
The adapter remains process-local: disk persistence, partitioned cookies and
the full ancestor-context treatment of SameSite are still absent.

The focused validation executes eleven store cases in each of Boehm and
production `-prealloc -gc none` modes, a credentials-flag case, and twelve
combined browser cases. The latter include two end-to-end local-server cases
covering redirect cookies, HttpOnly exclusion, fresh Document reads, script
writes, Fetch's three credentials modes, native XHR and credentialed CORS.
Existing document-state, script-event and scheduling cases also pass.
Evidence is in `session-cookies-1793008179516107000/`; the enclosing guard
records actual exit 0 and sampled peak RSS of 7,092,928,512 bytes under 12 GiB.
The combined test executable's separate 3 GiB runtime guard records exit 0
and peak RSS of 155,074,560 bytes.

Production validation builds committed master `c4c986ce` with current V and
the production allocator, excluding independent uncommitted renderer/CSS
experiments. Its preserved native libraries include the preceding raster and
shadow fixes. The bundle passes signature verification and headless startup;
all captured source and executable/library hashes remain unchanged. A fresh
process and private profile load the requested live map at 1024 by 768,
scale 1, with a twelve-second settle period. The document reaches its expected
Russian title and complete readiness, with no native errors and only the two
expected advertising/metrics script blocks. Recommendations render, but the
map still has no canvas and uses raster tiles. The dynamic-script fixture
remains exact against the unchanged Brave reference at all 800 by 600 pixels.

Evidence is in `cookie-production-1793008682465484000/` and
`session-cookie-production-1.guard.json`. That guard records actual exit 0,
sampled peak RSS of 10,036,199,424 bytes under 12 GiB and elapsed time of
200.241 seconds. This validates the cookie change; it does not establish
pixel-perfect live rendering. The browser still executes scripts through
JavaScriptCore; translated LibJS runtime parity remains open.

The follow-up startup probe records Yandex's own vector feature report:
`supported:false`, with the sole reason `WindowPropertyNotExist-Worker`.
Its WebGL draw test, shader precision, vertex-array extension, WebGL 2 and
WebAssembly checks pass. The discovery feed returns HTTP 200 without the
previous handled CSRF rejection. This identifies native worker execution as
the next startup blocker; declaring an unimplemented constructor would not
validate vector rendering. Diagnostic evidence is in
`dynamic-script-startup-bounded-1793013308086133000/`.

The unchanged production bundle also retains nine pixel-exact SVG mutation
reftests. Its eleven-case screenshot smoke batch keeps the three existing
failures, seven exact cases and the existing canvas-text allowance. A fresh
windowed Brave reference attempt reaches Yandex's CAPTCHA, so its image is
rejected and supplies no live comparison metric. The enclosing follow-up
guard exits 1, with sampled peak RSS of 10,145,693,696 bytes under 12 GiB;
this is not a passing acceptance run. Results and actual step exit codes are
in `cookie-followup-1793013308051869000/` and
`map-visual-batch-1793013325215588000/`.

## Worker execution foundations

`9c530b92` adds a bounded, nonblocking process transport for an isolated script
agent. Frames preserve arbitrary binary bytes, limit retained output, and make
progress in bounded event-loop turns. Termination reaps the child; a separate
parent-lifetime pipe also shuts down an orphaned agent. No V, DOM or
JavaScriptCore heap is shared across these processes. This is transport only;
it does not expose a JavaScript `Worker` constructor.

`16bb0a12` installs the native `MessageEvent` binding in actual worker realms.
Its event target and scripting environment belong to that worker, without
installing Window messaging globals. Tests cover constructor behavior,
receiver identity, trusted structured-clone delivery and exception handling.

Evidence is in `worker-process-v-1793015825524307000/` and
`worker-process-v-3.guard.json`. The native transport passes five grouped cases
in each of normal and AddressSanitizer/UndefinedBehaviorSanitizer builds. The
V transport, worker/window MessageEvent and MessageChannel selection passes
eleven cases in each of Boehm and `-prealloc -gc none` modes, including poisoned
caller/sender/receiver scratch scopes. Both modes compile their own private
native helper. Recorded input hashes remain unchanged. The outer guard exits
0, with sampled peak RSS 7,541,293,056 bytes under 12 GiB; the two 3 GiB runtime
guards also exit 0. Independent CSS edits are excluded through a recorded
committed snapshot.

These checks establish native runtime components, not live-map acceptance.
Script loading, agent startup and browser integration must work before the
site can select its vector renderer. The last valid live comparison remains
328,981 differing pixels, and the archived fixture retains 424 differing
pixels with maximum channel error 8. No new screenshot parity or LibJS runtime
parity is claimed.

Dependency inspection on October 26 retrieves the previously recorded Yandex
content-provider worker entry with HTTP 200. The 966,384-byte script has SHA-256
`78b9e7c2d957e78562824931f68ef988957b85d401deae4a0ef14304820eb301`;
its body and response receipt are retained in
`worker-entry-inspection-1793024580858316000/`. It installs worker-global message
handlers, batches messages with transfer lists, fetches binary resources and
instantiates WebAssembly. Worker startup therefore needs working message
delivery and ArrayBuffer transfers as well as script execution. The current
MessageChannel binding still rejects nonempty transfer lists. This inspection
uses the saved `yandex.com` worker URL; it neither executes the script nor
establishes acceptance for the requested live `yandex.ru` page.

Launcher inspection follows the saved page's `base` bundle through
`vector-map-engine` and `ymaps-vector`. The base bundle combines the configured
base URL with the content-provider worker's pathname; the communicator calls
`new Worker(url)` without module options, assigns `onmessage`, registers an
`error` listener and flushes message batches with their transfer lists. Its
nested-worker relay likewise constructs workers from URLs. These inspected
construction paths use classic URL workers; the bundle's Blob URL helpers
serve image decoding rather than these worker constructors.

The retrieved launcher has SHA-256
`42be67c0ca1987be6cc555c1ed110242ee6f8dfeade7adde192e4cd39c41a200`.
HTTP receipts, source bodies and bounded call-site excerpts are retained in
`worker-loader-inspection-1793028304307830000/` and
`worker-launcher-inspection-1793028387826668000/`. This is source inspection
only; it adds no worker execution or screenshot acceptance credit.

The same worker entry was also retrieved directly from the requested
`yandex.ru` origin on October 26. It returns HTTP 200 without a redirect and
has the same 966,384-byte body and SHA-256 as the inspected `yandex.com` entry.
The response receipt and body are retained in
`worker-ru-entry-inspection-1793031667552697000/`. This verifies the entry on
the requested host; execution and the live visual comparison remain pending.

Worker prerequisite validation on October 26 fixes three independently checked
issues. `5a8a08f5` corrects the Runtime pointer captured by the writable-stream
callback test; `3e391318` attaches WorkerLocation to the concrete dedicated or
shared worker scope instead of its copied base; `f4624a11` seeds structured-clone
serialization and deserialization memories in transfer-list order. The latter
preserves references, cycles, views and unused transfer entries without itself
performing native transfers or detaching buffers.

The frozen-source results in
`Build/yandex-maps/worker-runtime-corrected-1793034313234967000/` retain 36
passing HTML cases in each of Boehm and preallocated/no-GC modes, including
seven WorkerLocation cases and four transfer-memory cases. The browser selection
passes 50 cases under Boehm; an isolated four-case writable-stream selection also
passes without GC. All source and toolchain hashes in that receipt remain
unchanged. These focused successes do not make the complete run pass: the
browser no-GC selection exits 138 during the poisoned worker-fetch scratch
lifetime check, and the outer guard exits 1. Its sampled process-tree peak is
7,844,511,744 bytes under the 12 GiB budget.

The failure identifies native callbacks retaining stream-wrapper lookup tables
allocated in a temporary arena. A persistent-allocation boundary and actual
ArrayBuffer transfer tests are pending a fresh guarded browser run. The worker
agent is still not installed as a browser Worker constructor; these component
checks add no live-map or screenshot acceptance credit. The last valid live and
archived differences remain 328,981 and 424 pixels respectively.

`fce731f9` routes MessagePort delivery through the receiving environment's
event loop and realm, including worker-owned ports. The JavaScriptCore
MessageChannel binding now uses its actual scripting environment instead of
requiring a Window. Queued transport records and binding registrations retain
their storage across scratch-arena resets.

The unchanged inputs are recorded in
`Build/yandex-maps/message-port-commit-evidence-1793051170072685000.json`.
Three focused HTML ownership cases pass in both allocator modes, and three
worker MessageChannel cases pass in the Boehm browser selection. The later
worker-fetch failure still prevents claiming an overall browser no-GC pass.
Classic worker startup, process messaging and native browser integration are
pending their expanded validation; this commit adds no live screenshot result.

An October 27 native JavaScriptCore probe isolates a second transfer blocker.
`JSObjectGetArrayBufferBytesPtr` leaves an otherwise ordinary ArrayBuffer
non-detachable: a subsequent native `transfer(0)` retains its original bytes
and live view. Calling only `JSObjectGetArrayBufferByteLength` preserves normal
detachment. The probe then executes the pending clone bridge's captured byte
operations, borrows only a private copy's pointer, and verifies the bytes
`0,128,255` plus successful detachment of both source and reconstructed buffers.
It also poisons author constructors, species, iterators and byte-copy methods.

The native diagnostic exits 0 under the 3 GiB guard, with sampled peak RSS of
18,432,000 bytes. Its results and actual guard exit are retained in
`Build/yandex-maps/native-transfer-20261027-results.json` and
`Build/yandex-maps/native-transfer-20261027-guard.json`. This checks the captured
JavaScript operations and C API behavior; the changed V serializer and complete
Worker stack still require their queued component tests. The available
production bundle predates those changes and supplies baseline evidence only.

The expanded Worker component run in
`Build/yandex-maps/worker-child-1793056940063085000/` compiles the Boehm
browser selection successfully, then exits 1 in the clone-detachment fixture.
That fixture reused a read-only host-callback global, so its next iteration
received the first, already-detached clone. The pending corrections give each
clone case a distinct callback and each resizable-transfer case its own realm.
Formatting and diff checks pass; their runtime rerun is queued under
`worker-child-retry-4-20261027-guard.json`. The real Yandex worker probe runs
only after a complete component pass. Neither correction has runtime or visual
acceptance credit yet. The same run's old-bundle startup check passes, but its
Worker fixture remains pending and its live capture exceeds the 3 GiB guard;
that interrupted capture supplies no comparison result.
