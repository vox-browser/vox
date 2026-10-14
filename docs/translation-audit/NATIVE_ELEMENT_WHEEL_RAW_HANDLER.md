# Native compact HTML raw onwheel compilation

Initial feature: `16274a2478615619deb3ceb7f7f8f8cc55d75754`; immediate parent:
`b01cc68afc8bca10cee733c7a1a2049b6ab6ab9f`. Validated source pin:
`011900462f1a479dcaf7f54df5d214480f549eaa`. Upstream reference:
`963d46a829f3e1b79f44dba9d02afb70654300fa`. Verification date: 2026-10-14 UTC.

Ordinary compact HTML `onwheel` content attributes compile lazily through the owning
native EventTarget handler record. A getter or event delivery compiles the raw body once
and caches the actual callback; writing the raw attribute again replaces the value
without moving its activated listener. Equal-text writes replace a later IDL callback,
existing-attribute removal deactivates the slot, and absent removal remains a no-op.
Unsupported handler names and unavailable owner environments retain their raw source.
The existing Window compiler and body/frameset reflection rules remain in place; body
`onwheel` belongs to the body element.

The compiler parses the actual FunctionBody independently before creating a scoped
factory. Invalid syntax and early errors null only the handler value, retaining its
activated listener until replacement or removal. The zero-parameter outer factory uses
nested object environments and returns an ordinary anonymous function whose inferred
name is `onwheel` and whose single parameter is `event`. The factory adds no helper
variable or named-function-expression self binding. The handler's own strict directive,
arguments, this value and event parameter retain their ordinary semantics.

Identifier lookup follows the actual Element facade, then its actual form owner when
available, then the owning Document facade, then the relevant global environment. The
actual cached input/button/select/textarea model supplies the form owner at lazy
compilation; no new control model or nearest-ancestor form is fabricated. A plain div
inside a form receives no form environment. A cached function retains its captured form
object after later reassociation, while properties in each object environment remain
live. Object lookup includes ordinary property access and Symbol.unscopables.

CSP script-attribute checks remain at content-attribute mutation before replacing the
current handler. The native callback path supplies the same owner/Event wrappers,
relevant settings, Window.event lifetime, exception reporting and Page scripting gates.
Exact Boolean false sets the canceled flag directly, including passive or noncancelable
delivery; preventDefault retains its separate gates. Real software GG wheel delivery
applies callback DOM/style mutations even when cancellation blocks inner and viewport
scrolling.

The adapter requires the actual owning Document wrapper and native host identity. Media,
images, objects, fieldsets, outputs and form-associated custom elements remain outside
raw compilation because their required owner integration is not supplied by this
adapter. SVG and MathML raw-attribute activation stays at the pinned source boundary.
Raw non-wheel Element handlers, unavailable cached control models and foreign-realm
compilation remain open. Document/form named-property hooks cover only the existing
compact facade surface, not full native interface behavior.

Callback metadata retains the exact source form `function onwheel(event) {\nBODY\n}`.
JavaScriptCore's actual Function.prototype.toString shows the anonymous inner function
source; this is an explicit adapter deviation and does not change the global intrinsic.
Attribute-origin source locations and parse error reporting remain the existing source
FIXME. JavaScriptCore remains the browser backend; full HTMLElement binding parity and
physical operating-system/device wheel injection are not established.

Selected verification targets seven files /23 cases in each GC mode, including eight new
cases across the DOM availability, native binding and BrowserApp owner fixtures. The
fixtures cover optional compiler availability, lazy/cache identity, scoped lookup,
captured actual form ownership, syntax isolation, strictness, live handler-name lookup,
CSP preservation, equal-text raw/IDL order, trusted software GG cancellation, painting,
exceptions, scripting gates, runtime close and the retained Window compiler. Completed
test results: In each GC mode, initial 16274a24 records five successful files /17 cases
and two compiler failures with zero new-file body credit. The isolated 306239fa source
adds self-contained canonical 227d2137 fixtures: three owner cases pass; the browser
fixture still fails compilation on a nonexistent diagnostic API. Isolated01190046 uses
canonical ecbf42fc owning-realm diagnostics; all three browser cases pass with actual
exit 0. These source pins differ from the feature only in the two corrected test files.
Original failed full batches remain failed, and all seven selected files /23 cases are
covered without repeating completed files.

Production validation targets six stages: build, signing, startup, two exact raw handler
reftests, eleven configured screenshot smoke cases and eight exact SVG regressions.
Public raw-handler pages use untrusted author dispatch; startup checks use six software
GG injections. Completed production results: Build, strict signing, startup, two
raw-handler pages and eleven smoke cases complete with actual exit 0. The original SVG
stage passes two exact cases then encounters the retained Sokol/Metal semaphore
initialization trap twice; matching crash-report UUIDs authenticate the signed binary. A
fresh six-case continuation completes with actual exit 0 and all six pixel-exact using
the same binary. The original SVG stage and whole production attempt remain failed;
composed coverage includes all eight exact SVG cases. Source provenance and recorded
preexisting working overrides: Production and the initial tests use exact16274a24 Git
inputs plus six recorded preexisting working overrides. Private synthetic
306239fa/01190046 preserve that complete implementation and use only the canonical
self-contained/diagnostic fixture corrections. Concurrent later canonical work is
preserved and excluded from these validation pins. The authenticated regex
archive/fingerprint stamp originates from the previous successful production and remains
unchanged. Any failed or interrupted attempts and their credit limits: Missing upstream
GlobalEventHandlers.idl metadata preflight, initial independent-file fixture errors,
intermediate browser diagnostic-API error and original Sokol/Metal launch failures
remain preserved without full-attempt passing credit. Only actual successful
files/stages/cases enter the composed result.

Evidence: `Build/audit-fixes/native-element-wheel-raw-handler-evidence-v1.json` (SHA256
`4be33337de7a83da42965b579510703b820198bff349c2c11f01582d85a83090`) Frozen source/tests:
`Build/audit-fixes/native-element-wheel-raw-handler-frozen-v3.json` (SHA256
`a74a543f8ee8f509777b526c2d65876509d251cb17438d51f989bf048a157ba7`) Test receipts:
`Build/audit-fixes/native-element-wheel-raw-handler-tests-composed-v1.json` (SHA256
`d57d9c12c1645e22a29dc5bc320562d528a16be0afb150a4a9da4edf27d8c74e`) Production receipts
and retained signed artifacts:
`Build/audit-fixes/native-element-wheel-raw-handler-production-composed-v1.json` (SHA256
`526729e0d181dce69ffd711856ee0e78e6cc11c5ca1d2b3dac2157c2bd9ee391`);
`Build/audit-fixes/native-element-wheel-raw-handler-production-retention.json` (SHA256
`9f10ddacd085fe5dbd3026f44273aadb381b5b26e15b762284b0379d710e46e4`) Scoped inventory:
`Build/audit-fixes/native-element-wheel-raw-handler-inventory-scoped-v1.json` (SHA256
`423f80910bd1daaf59158dcc7525e59823a33b99d8a990321fadce36d5b8786f`) Prior evidence
preservation and cleanup:
`Build/audit-fixes/native-element-wheel-raw-handler-final-closure.json`;
`Build/audit-fixes/native-element-wheel-raw-handler-cleanup-v1.json` (SHA256
`e787067ec73169dfc24e96972c9af3a4743616b812c8278f748bfc76217d760d`)

The feature owns eight paths: three assigned DOM paths and five excluded browser/root
support paths. Verified scoped physical deltas: DOM adds one assigned file, six
implementation and 129 test physical V lines against feature parent b01cc68a. All five
browser/root paths and both later fixture-only commits are excluded; their assigned
deltas are zero. Inventory attribution is against this feature's own parent. Current
global inventory tables, pins, references, source-unit mappings and historical finding
ledgers remain intact; independent canonical changes receive no raw-wheel validation
credit.
