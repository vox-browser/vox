# Native ordinary Element wheel listeners

Wheel-listener implementation: `25c58496b06da26c9a0c542756635bace618c284`; actual immediate parent: `ae798534c2a82f85b4f36d258b1a362946ce3782`.
Bounded canonical canvas fix: `92a49f4dce4b74fa569c189906c5cee497191b48`.
Synthetic production validation: `8a0c30a36b8f5fd4f363e1b11ee5df32b489a27c` (parent `25c58496b06da26c9a0c542756635bace618c284`).
Upstream reference: `963d46a829f3e1b79f44dba9d02afb70654300fa`. Verification date: 2026-10-14 UTC.

## Bounded implementation

The compact facade keeps its existing non-wheel click/load listener behavior.
Case-sensitive `addEventListener("wheel", ...)` and matching removal use the
actual owning DOM EventTarget and captured native methods/options. Public native
dispatchEvent retains the same Event wrapper and makes author dispatch untrusted.
Receiver branding precedes author type/options/Proxy activity; the type receives
one DOMString conversion. Function callbacks use the current facade as this;
object callbacks perform live handleEvent lookup. Callback/capture identity,
deduplication, once, passive defaults/explicit false, abort and original throws
use the shared source event machinery. Listener return false does not cancel;
preventDefault respects cancelability and passive-listener gates.

Lazy target resolution preserves the canonical facade for anonymous real hits,
event.target/currentTarget and callback this without eagerly triggering image
requests. Parsed HTML/SVG/image wrappers and created generic elements retain their
native owner through replay/removal/reappend; qualified SVG names and null
namespaces use the public DOM creation path. Existing media prototypes stay owned
by their native media host. This slice adds no generic onwheel IDL, raw Element
content-handler compiler or complete HTMLElement prototype hierarchy.

## Actual verification

Each GC mode composes five unchanged files /16 passing functions from its original
six-file batch with a fresh focused corrected owner fixture /3 passing functions.
The selected total is six files /19 functions, including six new binding/owner
functions. Original owner fixture compilation fails before any owner test body
because numeric coordinates mix floating and integer arithmetic. Its original
logs/actual exit one remain preserved without full-batch or owner-body pass credit;
the first correction changes only the owner fixture. Intermediate focused retries
fail C generation for an inline conditional identity assertion and then V checking
for a conditional pointer assignment, again before any test body. Explicit pointer
initialization and assignment fix those fixture expressions. All failed versions,
compressed generated C and hashes remain preserved; final
passing retries reuse no failed-body result and leave the eight wheel inputs exact.

A follow-up CanvasHost correction synchronizes requested width/height before the
first context for an existing provider-created canvas, preserving native identity.
The exact small replacement is authenticated independently against its canonical
parent and a synthetic commit whose parent is the wheel feature. The final new
test agrees with its separately recorded canonical fixture; the eight wheel inputs
remain exact. Three
focused canvas files /10 functions pass in each GC mode, separately from the
original 19 wheel cases.

Fresh isolated signed production at this synthetic validation pin completes five
stages with actual exit zero. Startup performs six deterministic software GG wheel injections (three existing media, three
ordinary Element) through the actual BrowserApp/Page route. They verify native
ownership, cancellation before inner/viewport defaults, mutation/paint updates and
accepted scrolling. Eleven smoke screenshots pass: eight exact and three at
retained tolerances. Eight SVG image/paint-server mutation regressions are exact.
These are software input records, with no operating-system event/hardware-wheel
injection claim. Production uses a detached private validation source with exact
committed feature-plus-canvas-correction bytes plus six retained original working
overrides. Concurrent canonical source changes remain preserved outside this validation pin. The
canonical preflight retains actual exit one with no physical build credit. The
first isolated run builds, signs and passes startup, but canvas-text fails its
fourth stage: ten smoke passes, no full production pass and no SVG execution.
Its actual failure, inputs and partial-stage artifacts remain preserved. A later
interrupted build has no delivered terminal code or successful-stage credit; its
partial log is retained. The fresh corrected run supplies the complete pass.
This is not a clean-commit build.

Consolidated evidence: `Build/audit-fixes/native-element-wheel-listeners-evidence.json` (SHA256 `e4549e167e1f64286ea193aae9b4fdc4bd37a2d8bff374790e0ff603583b27db`).
Composed wheel test proof: `Build/audit-fixes/native-element-wheel-listeners-test-evidence.json` (SHA256 `627694c1e056560fe3e4dba3646d1bf5bc62d53f340120aa454ef3f25fa6d430`).
Canvas fix/actual focused tests: `Build/audit-fixes/native-element-wheel-listeners-canvas-fix-composition-v2.json` (SHA256 `361ce5f76686b42cb36a0eb20813fb22798bab8ecb10157094691ed7cd5277a5`).
Production manifest/actual exit: `Build/audit-fixes/native-element-wheel-listeners-production-v4/manifest.json` (SHA256 `5bf762a12b028f01d0a4ea10b469d811adfa086bc3e341d71b06532053d374c1`); `Build/audit-fixes/native-element-wheel-listeners-production-v4-actual-exit.json` (SHA256 `82322bc1f6694d18c8d48b0902d0ef8960c3da6cd4c23f82bffb600644b08d97`).
Retained production artifacts: `Build/audit-fixes/native-element-wheel-listeners-production-retention.json` (SHA256 `d8162449b696be380bca2a3273eaee86f82353b8c168dc7e7d8d54fc3b4877d5`).
Physical inventory: `Build/audit-fixes/native-element-wheel-listeners-inventory-current.json` (SHA256 `f27a9da741d5ab51c87a9eec381c4fbc35a38fb95fc914aed4d2854836521a7d`).
Prior records: `Build/audit-fixes/native-element-wheel-listeners-prior.json` (SHA256 `accfa814e0d0f75909098cf4d683b798a2772be1bf661b6934f762c425576f2d`) (4,704 unchanged artifacts).
Owned cleanup: `Build/audit-fixes/native-element-wheel-listeners-cleanup-actual-exit.json` (SHA256 `5de5c614c367759b5bc43e728dc8fcf2690ac16e7f4b9f07f375987a8a4adbdd`).

## Inventory and remaining work

All eight feature paths are excluded browser/root support paths. Assigned counts
at this code pin are 78 owners /2,238 files /433,415 implementation /161,056 test
physical V LOC. Current global inventory tables/references stay untouched.
The prior 33ba13ac/590ac inventory, its separate Page +46 implementation /+327 test
lines /one-file attribution and all older source-unit/history/ledger text stay
preserved. Physical LOC conveys no additional behavioral parity. Six preexisting
working overrides remain separately retained through scoped documentation merges.

Raw Element handlers, general non-wheel native listener migration, complete
HTMLElement interfaces, weak/foreign-realm ownership, visual-viewport zoom, nested
navigable wheel forwarding, snap/compositor async orchestration and physical
Cocoa/device automation remain open. JavaScriptCore remains the browser backend.
