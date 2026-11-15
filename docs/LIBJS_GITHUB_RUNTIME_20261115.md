# GitHub compiled-JavaScript continuation, 2026-11-15

**Verification is on hold at the user's request.** The running r16 sweep was
stopped; subsequent work uses source inspection and compiler-only checking.
The later implementation checkpoint below has no runtime, hydration, speedup or
pixel acceptance. Tests and page comparisons must remain held until the GitHub
parity implementation is ready for final verification.

**Pixel-perfect GitHub rendering remains unachieved.** A full native LibJS
capture completes under the repository's default 12 GiB browser guard, but
module failures leave loading placeholders and prevent commit links from
hydrating. Earlier 3 GiB runs are retained small-budget diagnostics; the
scope correction below explains why they cannot block a full browser capture.
The follow-up records WeakMap,
arguments, parameter, inheritance and parser-allocation work after the original
283-file checkpoint; the earlier failing cohorts remain historical evidence.

The native compiler first appeared in `5ed3e8155`, despite that commit's
object-literal title: concurrent staged native-tier work was included. Persistent
first-instruction reuse across visits was added in `7ec82b601`; parsed-source
reuse across document visits followed in `07902ae2d`. The earlier cache cohort
and its limited performance scope are in [the revisit report](LIBJS_REVISIT_CACHE.md).

## Completed runtime work

| Commit | Behavior | Remaining boundary |
| --- | --- | --- |
| `d925de78e` | Set construction, SameValueZero keys, ordered mutation, live iterators, callbacks and abrupt iterator closing. | Set algebra methods. |
| `bf068d688` | Map construction, access/mutation and live ordered iteration using the same native storage. | Grouping and getOrInsert extensions. |
| `056f35f47` | Async declaration/expression creation retains source, names, length and async prototype identity without evaluating bodies. | Async calls, Promise/await execution and the AsyncFunction constructor link. |
| `a8c7ba38c` | `element.style` uses the real retained native CSS declaration block; property accessors, priorities, serialization, indexed declarations, mutations and feature detection are live. | Full CSS interface constructor/prototype ancestry and custom-element reaction wrapping. |
| `1ec8f2467` | Base-class construction, static/instance methods, accessors, strict computed keys, immutable inner names, mutable outer declarations and cached native execution. | Heritage, fields, private methods, super, static blocks and anonymous assignment-name inference. |

These are partial translations, without JavaScriptCore fallback. Async calls
remain unsupported. The follow-up below implements WeakMap with native weak
keys, retaining the upstream collector model for values.

The Set/Map and class tests execute the same scripts in two fresh VMs. The second
VM uses `/usr/bin/false` as its compiler, attaches persisted native entries and
executes dynamic operations through the runtime helpers. Each feature's focused
checks pass with default GC and with GC disabled. Native CSSOM checks pass in
both modes; the original Hacker News script's four DOM/event checks also pass,
including restoration of all 101 archived comment rows.

## Original-response initialization diagnostic

The unchanged `https://github.com/vlang/v` fixture retains its original HTML,
scripts, imports and response headers. Its manifest is SHA-256
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`;
the HTML is `a0f615f45a8745e26aa57443182e238ddcb678f19aa2915c69d5ef66ff7b1a08`.
The existing Brave PNG remains
`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
Neither reference nor pixel tolerance was changed.

`tools/libjs_github_revisit.v` was rebuilt from the canonical checkout with
single-unit C/clang and literal `-prod`. Its SHA-256 is
`b3ab3d085b98cc79b0365833c1406a4a4a9cdfab2950f33c8366d81be927edbf`.
Compilation took 114.33 seconds under the 12 GiB guard, with sampled aggregate
RSS 7,423,426,560 bytes; compiler and guard exited zero.

One functional first/reopened pair has the same title, 33 directory rows,
**zero commit links**, console diagnostics and five module errors on both visits.
All five errors are `ReferenceError: 'WeakMap' is not defined`, in the original
polyfill and React bundles. The first visit compiled 119 executables; the second
reused all 119, reused 51 parsed sources, had zero cache/parser misses and invoked
no compiler. Neither VM initialized JSC. Binary and fixture hashes remain stable.
Process/guard exits are zero; sampled aggregate RSS is 2,902,016,000 bytes.

This harness has no window, CSS layout or paint. Its one pair supplies no timing,
rendering or successful-hydration acceptance. Local raw commands, pins, host
readings, logs and results are in
`docs/performance/libjs-github-classes-20261115/`. Earlier collection/style probes
are retained separately; their temporary executables disappeared before final
identity capture, so they receive no pinned-build or performance credit here.

## Native browser observations

Fresh processes use private profiles, original-origin offline HTTPS replay,
the test display, a 1024×768 document viewport and a 30-second observation timer.
The same PID registries are supplied to the memory guard and launch controller;
PID adoption succeeded. The sampled budget remains 3,221,225,472 bytes (3 GiB).

| Attempt | Build / PID | Result | Sampled aggregate RSS |
| --- | --- | --- | ---: |
| LibJS, unprofiled | `85fc5781…`, 83830 | Guard terminates before audit/PNG; controller 137, guard 125. | 4,074,831,872 |
| LibJS, separate stack diagnostic | `3bbd530b…`, 88986 | Guard terminates before audit/PNG or completed stack sample; controller 137, guard 125. | 3,589,029,888 |
| JSC control, unprofiled | `3bbd530b…`, 90023 | Complete native document: 33 rows, 56 commit links, latest commit and README; no script diagnostics; browser/controller/guard zero. | 2,505,080,832 |

The full executable identities are
`85fc578181ef2fdc0ec6e614797219095d6558d9fea66036241668b96de7557f` and
`3bbd530be52f4115c39e0b98709de61f7b653ef953291eb86565d03b7828ad82`.
The latter contains the base-class code; the former predates it. Both are shared
single-unit C `-prod` production bundles. The LibJS runs do not establish browser
terminal status after controller termination. No failed attempt was discarded.
The first controller attempt, under system Python 3.9, failed before launching
a browser because `hashlib.file_digest` is unavailable; Python 3.11 supplied
the subsequent attempts. The first LibJS observation overlapped the broad
GC-disabled suite; the later LibJS diagnostic and JSC control did not.

The successful JSC control uses the default engine and supplies no LibJS credit.
Its retained directory rows, latest commit, README and commit-link text/identities
also pass the existing `github_hydrated_render.validate` check against the fixed
Brave audit, without changing the expected content.
Its PNG is a whole-window diagnostic, not a document-only pixel comparison.
At this historical checkpoint no LibJS PNG was available. The later default-budget
capture below supersedes that limitation; hydration and pixel equality remain open.

## Verification checkpoint

The complete package passes **283/283 files with default GC** and **283/283 with
GC disabled**. The unchanged canonical AST driver passes **100/100 exact upstream
fixtures**. All 721 recorded LibJS/Unicode source/fixture/compiler inputs remain
unchanged across the final sweeps and AST check. Checks use current V, the C
backend, `-memory-limit 10G` and memory guards; no compatibility-compiler result
is claimed. The pin set includes the shared checkout's in-progress module-audit
slice; this is a tested worktree checkpoint, not a clean commit-only receipt.
Both broad guard/process exits are zero; sampled peaks are
6,276,988,928 and 6,193,430,528 bytes respectively under the 12 GiB budget.

The initial broad sweep is retained: 280 passed and three failed. `779068b32`
corrects the old IteratorStep test, which incorrectly required a value getter;
IteratorStepValue still checks and preserves that getter's exception.
`bcccde804` separates UTC/ISO round trips from native GMT offset precision. A
pinned Node 26.13.0 control also parses the 1900 Moscow GMT+0230 string 17 seconds
later than the original instant. The in-progress module-audit test was corrected
to compare observation generations after linking and to link before evaluation.
Those corrections precede the two complete passing sweeps.

Local receipts are in `docs/performance/libjs-classes-checkpoint-20261115/`;
native observations are retained under
`~/Library/Caches/Vox/benchmarks/libjs-runtime-20261115/`. These checks do not
reset the browser's unresolved memory, hydration or pixel-conformance gates.

## Runtime and allocation follow-up

| Commit | Behavior | Remaining boundary |
| --- | --- | --- |
| `8243d460f` | WeakMap construction, weak object/non-global-symbol keys, core operations and upsert methods; retired interpreter/context slots clear conservative roots. | Like upstream's current collector model, values are visited strongly. Dead-key pruning runs at VM checkpoints or subsequent collection operations after a GC epoch. WeakSet, WeakRef and finalization APIs remain pending. |
| `2de9dbe08` | Ordinary function arguments objects, mapped sloppy parameters, strict isolation, descriptor detachment, escaped environments and the intrinsic Array iterator. | Direct eval and its effects on function instantiation remain pending. |
| `ab92c7d3b` | Speculative scope rollback discards its private buffer tail in place, preserving capacity and clearing retired roots. | Does not establish that native GitHub fits the memory guard. |
| `52b684734` | Array concat preserves holes, live getters, spreadability, custom species, data descriptors and the shared instruction budget. | The shared species helper's foreign-intrinsic exception and Proxy exotics remain pending. |
| `493847550` | Default, rest and destructured parameters initialize in order with TDZ and a separate body environment; non-simple arguments stay unmapped. | Async/generator execution, direct eval and spread call arguments remain pending. |
| `ccb9484f9` | Derived construction, superclass/prototype validation, inherited statics, super calls, new.target, return rules and native-cache reuse. Synthetic default constructors forward actual arguments without Array iteration. | Public/private fields, super property references, static blocks and remaining native-builtin subclass behavior remain pending. |
| `66daa8c55` | Regex, template and private-name AST payloads have explicit heap ownership instead of occupying space in every expression node. | Reduces cumulative allocations; the GC-managed RSS trials below regress. |
| `ff7b5b1be` | Fixed ASCII parser comparisons avoid decoding the same keyword for every token and scope entry, preserving escaped identifier behavior. | General UTF-16 comparisons and names retain their existing semantics. |
| `740285c56` | Empty public fields retain computed keys once and define own data properties before base bodies, after derived super calls, and after static method installation. | Field initializers, private elements and static blocks remain pending. |
| `8e12522ec` | Event construction creates real native DOM Events, supports subclass prototypes, dictionary flags, constants, native methods, unforgeable trust and WTF-8 type round trips. | Foreign-realm WebIDL prototype fallback, EventTarget construction/dispatch binding and the remaining Event interface remain separate work. |
| `987f12637` | Object literal getters, setters and concise methods execute with computed keys and native cache reuse; methods are enumerable and nonconstructible. | Object spread and super property references remain pending. |
| `20339c56b` | Array fill snapshots length, converts observable bounds, and performs ordinary ascending Set operations with budget checks. | Proxy exotics remain pending. |
| `9d7364e13` | Window add/remove listeners use the associated native Window, including node propagation, callback objects, capture/once/passive options and cleanup. | AbortSignal options, Window handler attributes and EventTarget construction/dispatch bindings remain pending. |
| `83e9e1e2d` | Ordinary template substitutions convert with the string hint, preserving evaluation order, abrupt completion and UTF-16. | Tagged template call-site objects remain pending. |
| `39d44e548` | Public field initializers retain class environments, run per receiver with their own this/new.target, and preserve base/super/static ordering and anonymous function names. | Anonymous class name inference, super properties and static blocks remain pending. |
| `5e45435c9` | Private fields, methods, accessor pairs, lexical brands, read/write/update/in, optional access and abrupt private-scope restoration execute. | Static blocks and super property references remain pending. |
| `89e30cc73` | Native Headers groups names in one pass, combining ordinary values and retaining separate Set-Cookie values in sorted iteration. | Does not supply a GitHub load or performance result. |
| `15d2848f0` | Headers construction, ByteString and iterable/record conversion, guards, live iteration, forEach, native identity and cleanup bind directly to Fetch records. | Fetch, Request, Response and foreign-realm WebIDL prototype fallback remain pending. |
| `8d370c84a` | Promise construction, shared once-only resolving functions, thenable adoption, FIFO reactions, then/catch, resolve/reject, generic species capabilities and native settlement execute. Nested checkpoints finish the current reaction before draining another job. | Finally, combinators, async/await and DOM rejection events remain pending. |

Focused checks pass in both GC modes. Each runtime feature's cache test uses a
fresh second VM with its compiler set to `/usr/bin/false`. Arguments include
descriptor and duplicate-parameter cases; parameter tests include abrupt iterator
closing and default closures that cannot see body declarations. Existing parser
heritage tests remain intact beside the new execution tests.

### Parser measurements

These are parser-only diagnostics for all 86 unique original GitHub JavaScript
bodies (5,287,700 source bytes), with recursion limit 256. Fresh single-unit C
`-prod` processes use dynamic Boehm; filesystem caches are retained. No VM,
document window, layout or paint runs. Both cohorts retain every alternating
unprofiled attempt; the allocation samples come from separate instrumented runs.
Executable, collector, sampler and original response hashes remain unchanged
within each comparison, and every process returns the same parser output.

| Change | Unprofiled control seconds | Candidate seconds | Control maximum RSS bytes | Candidate maximum RSS bytes |
| --- | --- | --- | --- | --- |
| Scope rollback | 3.035, 3.167 | 1.450, 1.415 | 2,828,861,440; 3,182,329,856 | 1,219,035,136; 1,273,004,032 |
| Rare literal records | 1.108, 0.942 | 1.035, 0.833 | 1,327,054,848; 1,183,711,232 | 1,405,698,048; 1,503,608,832 |
| Fixed ASCII comparisons | 0.907, 0.882 | 0.961, 0.762 | 1,441,742,848; 1,405,698,048 | 1,206,550,528; 1,188,577,280 |

Sampled cumulative allocation falls from **29,908,533,248** to **4,610,588,672**
bytes after scope rollback. Separately allocating regex, template and private-name
payloads reduces that to **3,645,898,752** bytes; fixed keyword comparisons reduce
it further to **3,400,531,968** bytes. These payloads previously occupied
space in every expression node. The second change's GC-managed RSS regresses in
both trials; reduced cumulative allocations do not guarantee a lower resident
peak. The first ASCII candidate also regresses in elapsed time. Host load and
concurrent compilation are recorded locally; these cohorts
supply no browser rendering, instruction-count or completed-page speedup credit.

The initial static-collector interposer captured no samples and is explicitly
invalid. A direct-wrapper build then failed to link and supplies no runtime
evidence. The validated profiles use V's supported `-d dynamic_boehm` mode and
nonzero allocation samples. Raw commands, identities, host readings, outputs and
receipts remain local in `docs/performance/libjs-scope-rollback-20261115/` and
`docs/performance/libjs-ast-storage-20261115/` and
`docs/performance/libjs-parser-ascii-20261115/`.

### Additional native observations

The completed production executable
`5171fc6f3e1a086aaf72b11bcae0379e5a8bc7b7eaa74bc970f9b034619b2f89`
uses single-unit C, literal `-prod`, and `-prealloc -gc none`. Its sealed source
manifest contains WeakMap, arguments and the scope rollback fix, verified against
`ab92c7d3b`; it predates the literal-record storage change.

| Attempt | PID | Sampled aggregate RSS bytes | Result |
| --- | ---: | ---: | --- |
| Fresh LibJS, unprofiled | 77497 | 3,597,287,424 | Guard 125; controller 137; no audit or PNG. |
| Separate early stack diagnostic | 95439 | 3,411,394,560 | Same guard outcome; completed one-second stack sample includes LibJS imported-module parsing. |

Both use private profiles and the unchanged original-origin replay. PID adoption
succeeds, and all launch-pinned inputs still match after guard termination.
The browser's terminal exit status is unavailable after the controller is killed.
Neither failed attempt is excluded. The sampled guard can overshoot its unchanged
3,221,225,472-byte budget between observations. Local records are in
`docs/performance/libjs-scope-native-20261115/` and the persistent benchmark cache.

### Full browser scope correction and capture

The 3 GiB limit above belongs to focused engine/runtime checks. Applying it as
the blocker for a full windowed browser capture was a protocol error: repository
instructions specify a default 12 GiB aggregate guard for broader work. The
earlier failures remain valid small-budget observations. Changing the capture
scope earns no memory or performance optimization credit.

Executable `1497b1a1214ceb7e04b03e6048cf289e110a64dfbb6e85e72e58f93ce5fb1a6d`
contains the literal-payload changes, verified against the sealed manifest.
Its 3 GiB observation (PID 42277) still fails: peak 3,788,668,928 bytes,
controller 137, guard 125, no audit/PNG. A separate injected mapping trace
(PID 44918) also fails that budget. Its 1,057 anonymous mapping events record
4,497,736,752 bytes of **virtual capacities**, not live allocations or RSS.
Arena-block creation stacks cannot attribute all subsequent allocations in
those blocks; the trace does not establish a memory optimization.

The fresh full-browser capture of the same executable (PID 47567) completes
under the default 12,884,901,888-byte guard. Browser/controller/guard exits are
zero; sampled aggregate RSS peaks at 4,617,912,320 bytes. Executable, libraries,
observer and archive pins match throughout the controller's bundle lease.
Later bundle publication changes the executable on disk after the run; the
controller's completed in-lease identity checks remain the run boundary.

The active document is the original GitHub URL, visible and complete, with a
1024×768 viewport, 33 directory rows and one README. Latest-commit content and
commit links are both absent. LibJS reports execution generation 477 and 51
module records, including five rejected entries with the class-field error;
JSC's native context stays uninitialized. A zero native-error counter does not
erase those module/console errors. Strict retained-content validation against
the unchanged Brave audit (`708ab912…`) fails with `GitHub script/native errors`.
The whole-window PNG shows placeholders and supplies no pixel-conformance credit.

Local observations, the full-window PNG, trace and summaries are under
`~/Library/Caches/Vox/benchmarks/libjs-weak-map-20261115/`; validation and receipts
are local in `docs/performance/libjs-native-full-20261115/`. Capturing subsequent runtime fixes in a newer production bundle remains pending.

A diagnostic crop of that full-window image differs from the unchanged Brave PNG
in **142,851 of 786,432 pixels (18.1644%)**, with maximum channel error 242,
MAE 3.1072 and RMSE 16.0078. The crop includes the native toolbar boundary
overlay at its first row and is not a canonical document-only capture. The failed
content audit independently prevents conformance acceptance. The existing pixel
tool was pinned and checked on identical and one-pixel controls after its old
verification receipt was found to describe a different executable. No reference,
tolerance or capture offset was adjusted to obtain a pass.

### Updated core verification

The final core sweep passes **291/291 package files in each GC mode**, with
**783 unchanged source/fixture/compiler inputs** across the checks. The exact
AST driver passes all **100/100** upstream cases after the parser changes.
Literal ownership also passes AddressSanitizer with stack-use-after-return
detection and GC disabled. The Event binding and its three focused cases run
as separately compiled binaries under the 3 GiB runtime guard in both GC modes;
all four original Hacker News native DOM/event cases still pass in both modes,
including restoration of all 101 archived comment rows.

The earlier full follow-up sweeps each retain 288 passes and one failure: the
old unsupported-program test still expected `class extends Object` to fail.
`93314e7f2` changes both obsolete examples to untranslated private fields while
retaining the pre-execution rejection assertions. Focused checks pass in both
modes, followed by both complete 291-file sweeps. Raw source pins, all attempts
and guard/process exits remain local in
`docs/performance/libjs-runtime-checkpoint-20261115-r2/` and `-r3/`.

### Subsequent original-response diagnostics

Every functional pair retains all original responses, unchanged input pins and
both failing visits. The compiler is `/usr/bin/false` on the second opening;
JSC remains uninitialized. The progression below is diagnostic evidence, not
completed-page timing or rendering acceptance.

| Runtime checkpoint | Reused native executables | First remaining failure |
| --- | ---: | --- |
| WeakMap | 120 | Arguments objects and class heritage. |
| Arguments | 124 | Array concat and class heritage. |
| Parameters and heritage | 134 | Public class fields. |
| Empty public fields | 135 | Missing Event. |
| Native Event | 140 | Object literal accessors. |
| Object methods | 158 | Missing Array fill. |
| Array fill | 158 | Missing Window addEventListener. |
| Native Window listeners | 159 | Ordinary template literals. |
| Template literals | 159 | Class field initializers. |
| Public field initializers | 159 | Private class methods. |
| Private class elements | 161 | Missing Fetch binding. |

All pairs retain 33 directory rows and zero commit links. The latest fill binary
uses unoptimized single-unit C/clang for functional diagnostics; earlier binaries
use literal `-prod`. Their timings cannot be compared as a performance cohort.
The subsequent core features have focused default/GC-disabled passes, in addition
to the preceding 291-file full checkpoint. Window listeners have three focused
cases passing as standalone binaries in each GC mode. Their original failed
compile (a helper in a different test file was unavailable) and test crash
(calling a released host closure after close) remain retained. Tests now stop
entry into retired bindings, as required by the embedding lifecycle. Raw results remain local under
`docs/performance/libjs-{event,object-methods,fill-debug,window,template}-github-20261115/`.
Completed job guard receipts are preserved locally under
`docs/performance/libjs-runtime-followup-20261115/guards/`; their Build scratch
files and locks are removed after completion.

The public-field initializer selection passes seven focused cases, empty-field,
heritage and class execution neighbors in both GC modes, plus AddressSanitizer
with stack-use-after-return detection. The original fixture reused a top-level
class name in separate scripts in the same VM; those attempts correctly failed
with redeclaration errors and are retained. Independent cases now use fresh VMs.
Private-element checks cover nine cases, with eight neighboring files passing
in each GC mode. Both features execute cached native entries in fresh second VMs
with the compiler disabled. The subsequent complete checkpoint passes **296/296 files in both GC modes**,
with **790 unchanged source/fixture/compiler inputs**, at `5e45435c9`. The two
sweeps take 231.65 and 234.49 seconds; test/controller/guard exits are zero,
and sampled aggregate RSS peaks at 6,790,791,168 bytes under the default
12 GiB guard. All attempts remain local in
`docs/performance/libjs-runtime-checkpoint-20261115-r4/`.
The latest original-response pair still has five module errors, 33 directory rows
and zero commit links; no complete GitHub or pixel-perfect rendering claim follows.

### Native private-class capture and Fetch prerequisites

The subsequent production executable
`411d96ea582ed2b7e49017b078ae5030ed27e1a4c1056907a72697940c3edb61`
contains all 18 required implementation changes since the parser checkpoint,
verified against `5e45435c9` and the sealed source manifest. Fresh PID 17078
completes under the default 12 GiB guard, with peak aggregate RSS 4,398,170,112
bytes and browser/controller/guard exits zero. Pins match throughout the run.
Its visible, active 1024×768 original GitHub document retains 33 rows and one
README, but no latest commit or commit links. LibJS execution generation is 477;
JSC stays uninitialized. The five errors now report missing fetch, matching the
source-only diagnostic. Strict content validation against the unchanged Brave
audit still fails with `GitHub script/native errors`. This whole-window capture
supplies no document-pixel or completed-load performance acceptance.
Local records are in `docs/performance/libjs-private-native-20261115/` and
`~/Library/Caches/Vox/benchmarks/libjs-weak-map-20261115/native-private/`.

Headers' six focused cases pass in both GC modes; the native Fetch Headers
model's five cases pass in both modes. The initial GC-disabled stress run is
retained: the 3 GiB guard stops it at 3,306,700,800 sampled bytes. The same input
passes after grouping sorted values in one pass, with 349,011,968 sampled bytes
in the GC-disabled run. These focused, differently contended diagnostics are
not a browser or page-performance acceptance cohort. No budget, input or guard
was changed to obtain that pass.

Promise's nine focused cases and five neighboring VM/realm/module files pass
in both GC modes. The nine cases also pass AddressSanitizer with stack-use-after-
return detection. Early failed fixtures retain their original receipts: the
native capability now obtains the constructor through the explicit realm record
accessor, and the rejection observer retains a heap log instead of a copied
array capture. Fresh second VMs execute all three cached script/callback entries
with the compiler disabled. These checks follow the complete 296-file checkpoint;
a complete 297-file sweep is not claimed. Fetch was still unbound at that
checkpoint, so its full-browser rendering result remains a failure.

### Fetch and DOM interface continuation

`bfc166ab1` defers Promise checkpoints until an entire host entry returns,
including the exceptional path. Unsupported job failures remain VM roots until
consumed and now reach the document's LibJS diagnostics. Four focused VM cases
and a browser integration case pass in both GC modes, alongside the Promise/VM
neighbors. The initial browser compile rejected a mutable array alias; messages
are now appended before the existing take/reset boundary. Its failed compile
and unsuccessful launch of the absent binary remain retained.

`94c6a27a6` binds Fetch to the module loader's actual transport and relevant
settings. Native Request/Response records retain guarded Headers and stream
bodies. Constructors, cloning, request dictionary conversion, text/JSON/
ArrayBuffer consumption, network rejection and native stream completion execute
without JSC. Eight cases pass in each GC mode and with AddressSanitizer's stack-
use-after-return detection. Their cache case reopens in a fresh VM with its
compiler disabled and executes all three cached script/callback entries.
AbortSignal exposure, DataView/Blob/FormData/URLSearchParams body variants,
ReadableStream wrappers, remaining Body methods and Response static factories
remain pending; this is not complete Fetch/WebIDL parity.

`7a99d17ca` extends the source-only diagnostic to read and authenticate every
requested response body, including archived non-script responses, and waits for
native Fetch operations before completing. Its pair reuses 172 native entries
and 51 frontend sources with zero compiler invocations on reopening. It still
retains five module failures, now missing Element, 33 rows and zero commit links.
The input pins now include every archived response body. This expanded functional
scope is not a matched performance comparison with earlier initialization runs.

`85e6878f6` exposes Node, Element and Document interface objects on the exact
native wrapper prototype graph, plus Node constants and standalone XML Document
construction/subclassing. Two focused cases pass in both GC modes. The original
cleanup assertion failed because finalize alone does not destroy a document;
owned documents now run destroy before finalization at Host.close. The first
interface source pair predates that cleanup correction and supplies no final-
teardown credit. It reuses 162 entries and next fails at missing HTMLElement:
exposing Document activates an earlier polyfill branch, changing the executed
cohort. This smaller cache count does not establish a speedup. All visits retain
33 rows and zero commit links. Raw records remain local under
`docs/performance/libjs-{fetch,interfaces}-github-20261115/` and the benchmark cache.

`1e7f2eb4f` adds the native HTMLElement wrapper prototype and constructor ancestry;
XML elements remain ordinary Element wrappers. Both interface cases pass in each
GC mode. Its authenticated source-only pair reuses 162 native entries and 51
frontend sources without starting the compiler. The next missing global is
customElements. It still has five module failures, 33 rows and zero commit links.
Raw records are local in `docs/performance/libjs-html-interface-github-20261115/`.

`aa0b098ca` binds the real html.CustomElementRegistry,
constructor metadata/validation, scoped definitions, native upgrade queues,
autonomous HTMLElement construction and captured lifecycle callbacks. Registry
errors use actual webidl.DOMException records and whenDefined uses real LibJS
Promises. Six registry cases pass in both GC modes and AddressSanitizer with
stack-use-after-return detection. Two DOMException cases pass in both modes.
The fresh-VM cache case executes the constructor/field/callback entries with the
compiler disabled. Specialized customized-built-in interface constructors,
cross-realm wrapper worlds and complete CEReactions stack semantics remain
separate work; this uses the existing native backup reaction queue boundaries.

The initial failed constructor test incorrectly expected a failed state after
the precustomized transition. The unchanged upstream algorithm retains that
state; the corrected test checks cleared definition/reactions and reported
exception. The initial sanitizer launch preceded compilation and found no
binary. The completed sanitizer execution passes; both attempts remain retained.
No DOM algorithm, guard, fixture or reference was changed to satisfy the tests.
DOMException, DOM interface and original Hacker News regression files also pass
in both GC modes, with unchanged binding source hashes throughout those checks.

The next authenticated original-script pair reuses 178 native entries and all
51 frontend sources, with zero compiler calls and no JSC context. Both visits
still retain five module failures, now missing navigator, 33 rows and zero commit
links. Local records are in
`docs/performance/libjs-custom-elements-github-20261115/`. These are failed
initialization diagnostics without a native window, layout or paint, and are
not completed-page performance or pixel acceptance results.

`69706e3ce` binds Navigator ID, language preferences, system-state getters and
the replaceable clientInformation alias to the owning native Window's Navigator.
Its three cases pass in both GC modes. Frozen language arrays retain their prior
values across preference changes. Clipboard/Permissions capability placeholders
are not exposed as functional APIs. The first fixture incorrectly constructed a
second Window; the next entered the VM after Host.close had retired its closure
storage. Those failed attempts are retained. The corrected teardown check inspects
retired host storage without entering the closed VM, as the embedding requires.
Its authenticated source-only pair reuses 191 native entries and all 51 frontend
sources, with no compiler invocations or JSC context; five module failures now
report missing DocumentFragment, still with 33 rows and zero commit links.

Two newer shared production bundles have also been observed in fresh processes:

| Sealed feature / executable SHA-256 | Native observation | Result |
| --- | --- | --- |
| HTMLElement `1e7f2eb4f` / `eab1011ace894dc97cdcfe08231f7496fc0127941491abe0b9a065a63ee58da1` | PID 70187, 31.194 s, 4,370,055,168 sampled peak bytes | 33 rows, README, zero latest/commit links; five missing-customElements failures; LibJS generation 428, JSC context absent |
| Registry `aa0b098ca` / `ab8a3e6d913f5d696656f7054358c2394c792664fad04dc0708a5298865821a4` | PID 77570, default 12 GiB guard, 4,400,250,880 sampled peak bytes | 33 rows, README, zero latest/commit links; missing navigator; LibJS generation 428, JSC context absent |

All selected 283/286 Darwin engine/binding implementation inputs respectively
match their sealed source manifests. Both browser/controller/guard executions
exit zero, with unchanged executable/native/resource inputs and adopted browser
PIDs. Both documents are visible, fully active and complete at 1024×768. The
unchanged retained Brave content validator rejects script/native errors; the
whole-window captures visibly retain loading placeholders. These observations
remain failed correctness diagnoses, not pixel or performance acceptance. Host
load and simultaneous compilation are retained in the raw records. Local evidence
is in `docs/performance/libjs-{html-interface,custom-elements}-native-20261115/`
and the corresponding `native-*` benchmark cache directories. Neither production
bundle contains the subsequent Navigator/fragment changes.

`3a74c8699` binds actual DocumentFragment construction/subclassing, native
document factories, prototype identity, child transfer and scoped ID lookup.
The initial selector extension was committed before its failed results were
inspected: it reached the DOM-only matcher without installing the CSS bridge.
`4ae038303` installs the real CSS query hook before fragment scope matching.
All three fragment cases now pass in both GC modes, including native child
identity and SyntaxError DOMException behavior. The original failing executions
remain retained; neither selector inputs nor expected results were weakened.
The final fragment source pair authenticates unchanged inputs and reuses 191
native entries plus 51 frontend sources. Its next missing interface is
HTMLButtonElement; rows/commit links remain 33/0.

`70a9a1677` gives native HTML tags their public interface prototypes, including
the HTMLMediaElement ancestry of audio/video and HTMLUnknownElement identity.
The constructor path also validates registered customized built-in subclasses
against their native local name. Two focused cases and the DOM interface,
custom-element, fragment and original Hacker News files pass in both GC modes;
all binding sources remain unchanged throughout those regression checks. The
earlier generic-div assertions now require HTMLDivElement identity because the
wrapper has its actual public tag interface. Specialized interface members,
named constructors and cross-realm wrapper worlds remain incomplete.

Its authenticated original-script pair reuses 192 native entries/51 frontend
sources, without compiler calls or JSC, and next rejects an array spread in the
popover polyfill. Both visits still retain five module failures and 33/0 rows/
commit links. Local records remain in
`docs/performance/libjs-{fragment,specialized-html}-github-20261115/`.

`d1651fb8f` lowers array spread into the existing budgeted synchronous-iterator
bytecode. Elisions remain holes, yielded holes become undefined properties,
Unicode strings follow their iterator, and native cached loops execute in a fresh
VM with the compiler disabled. Five cases pass in both GC modes and sanitizer.
The initial recovery assertion used the still-unbound Array.reduce; the corrected
fixture sums the actual resulting elements. The script-evaluation regression now
checks array spread's runtime failure after earlier declarations, while retaining
pre-execution rejection checks for genuinely unsupported constructs.

`90f48579f` binds actual ParentNode append/prepend/replaceChildren algorithms,
including full variadic Node-or-string conversion before mutation, native
hierarchy errors and custom reactions. Three cases pass in both GC modes.
`faf86aab0` binds native static querySelectorAll lists and live childNodes,
stable wrapper identity and value iteration; three cases pass in both modes.
The existing host-property adapter conservatively keeps indexed properties
non-configurable; complete WebIDL indexed define/delete semantics remain pending.

`59317d4bf` adds ordered enumerable-own-property copying for object spread,
sharing the budgeted copy path with object rest. Nullish sources, UTF-16 string
indices, symbols, getter ordering, live descriptor changes, original exceptions
and __proto__ data properties are covered by five cases in both GC modes and
sanitizer. Four neighboring runtime/cache files pass in each mode. Initial paired
cache checks failed their unchanged compiler-call assertion; isolated diagnostic
checks and the complete five-file reruns pass in both modes. The assertion retains
its cold-one/warm-zero requirement and now includes failure details. Those early
failures remain retained; no cache requirement was relaxed.

`0e61c1934` binds native MutationObserver/MutationRecord records and delivery
queues to the VM's FIFO beside Promise reactions. Native HTML microtasks also
checkpoint changes originating outside JS. Callback budgets, native record and
NodeList identity, option dictionary order, observer retirement and error reporting
have six cases passing in both GC modes and sanitizer. Custom-element and NodeList
regressions also pass in both modes with unchanged binding inputs. Record wrapping
uses persistent storage; host teardown retires native delivery before releasing
callback closures. Cross-realm wrapper worlds and complete inactive-realm job
policy remain separate work.

The authenticated source-only pairs after array spread, variadic mutations,
object spread and MutationObserver respectively reuse 193, 197, 198 and 200 native
entries on reopening, with all 51 frontend sources cached, zero compiler calls,
no JSC context and no changed archived input. Every visit still has 33 rows,
zero commit links and five module failures. The newest failure is a missing
String.prototype.includes call in the selector polyfill. Raw records remain local
in the corresponding `docs/performance/libjs-*-github-20261115/` directories.
These changing, failed initialization workloads establish no completed-page
performance or pixel acceptance.

A further fresh production observation uses executable
`bd5bd15774faf21c35bbb34e99829569c93d3c2d6866bc87ea65bd7d797795ee`;
all 291 selected Darwin implementation files match sealed `59317d4bf` inputs.
PID 45140 observes a visible, fully active 1024×768 document for 30 seconds.
Browser/controller/guard exits are zero, identities remain unchanged, browser
adoption succeeds and sampled aggregate peak RSS is 4,421,500,928 bytes under the
default 12 GiB guard. LibJS generation is 437 over 51 modules; JSC remains absent.
Five missing-MutationObserver failures leave 33 rows, README and zero commit/
latest links, and the unchanged Brave content validator rejects the capture.
The bundle predates the observer feature. Local evidence is in
`docs/performance/libjs-object-spread-native-20261115/` and the
`native-object-spread` benchmark cache. Its whole-window PNG supplies no canonical
document-pixel gate or page-performance acceptance.

The broad follow-up retains all failed/interrupted attempts. The eight-worker
299-file run (`r5`) exceeds 12 GiB at 12,908,249,088 sampled bytes. The four-worker
`r6` default run completes at 297/299: its two obsolete fixtures omit Promise
and still reject array spread. The unfinished GC-disabled sweep is deliberately
stopped before correcting them; the guard records child exit 143 and owns the
remaining-child cleanup. `f0ca8aaec` adds Promise to the expected installed globals;
the array feature updates the obsolete unsupported fixture and adds its positive
runtime-error regression. Both corrected files pass in both modes. The later
six-worker 300-file attempt (`r7`) exceeds the same 12 GiB cap at 12,971,819,008
sampled bytes. No memory budget or guard is weakened.

The final four-worker `r8` checkpoint passes **300/300 files in both GC modes**,
with 796 unchanged source/fixture/compiler inputs, no changed inputs, and all
browser-independent test/guard exits zero. Default/no-GC sweeps take 767.406 and
761.726 seconds; the guard records 1,529.825 seconds and 9,489,645,568 sampled peak
bytes within the unchanged 12 GiB cap. This includes the original cache-counter
gate. All 100 unchanged upstream AST fixtures also match exactly; later changes
affect execution/bindings, not parsing. AST actuals, guard receipts and failed
cohorts remain local. Complete LibJS/WebIDL parity, production validation of the
observer feature, live-site behavior and pixel-perfect Brave rendering remain open.

## Further native runtime and DOM work

The following focused features are committed; each includes tests in the same
commit. Native-cache checks use fresh VMs and `/usr/bin/false` on reopening.

| Commit | Implemented behavior | Focused cases per GC mode |
| --- | --- | ---: |
| `b59499634` | UTF-16 String includes/startsWith/endsWith, RegExp rejection and observable coercion order. | 5 |
| `453f59df3` | Native WeakSet weak membership, iterable construction and abrupt iterator closing. | 6 |
| `84c2b99fd` | Generator/async-generator function creation, source, metadata and prototypes; execution still unsupported. | 5 |
| `3739b0af9` | Array.map species construction, holes, live indices and budgeted callbacks. | 6 |
| `d39962621` | Native EventTarget construction, Node ancestry, identity and real dispatch/cancellation. | 5 |
| `075ad4108` | DOMRectReadOnly constructor, dictionary conversion, coordinates and toJSON object. | 5 |
| `7f554067c` | Native IntersectionObserver/Entry, frozen thresholds and actual layout notifications. | 5 |
| `1fe700a56` | Native ResizeObserver/Entry/Size, live content/border geometry and frozen size arrays. | 5 |
| `1c433e094` | Live native classList DOMTokenList identity, indexed properties and token mutations. | 5 |
| `c6915db72` | Namespace-aware element creation, native validation and WebIDL registry/is options. | 5 |
| `248dbd33f` | Native template content fragments, SameObject/inert ownership and cross-document adoption. | 4 |
| `1fc47aafd` | Explicit spread super calls, ordered iterator evaluation and superclass capture; default derived constructors retain direct argument forwarding. | 6 |

WeakSet, EventTarget, IntersectionObserver, ResizeObserver, DOMTokenList,
element-factory and template-content cases also pass AddressSanitizer with GC
disabled. DocumentFragment, element factories
and custom elements pass in both modes with unchanged binding inputs. The initial
adoption assertion exposed an existing missing native adopting-step call; the
fix connects the existing template routine to Element.adopted_from, retaining the
failed attempt before the successful checks. Neighboring
core or DOM selections pass in both modes. Observer callbacks use the shared
bounded VM callback entry and retire native registrations before host teardown.
Resize tests check actual 100×50 to 140×50 layout changes and distinguish content
from border observations. Token lists retain native state and atomic validation;
part/relList and complete indexed WebIDL define/delete behavior remain pending.
Full Window ancestry, cross-realm wrappers and specialized HTML members remain
incomplete. DOMRect.toJSON tests inspect the actual returned object; JSON.stringify
is not implied by this binding. Failed early fixture/compile attempts remain local.

Authenticated source-only original-response pairs preserve all archived bytes,
the fixed Brave references and all attempts. All still have 33 rows, zero commit
links, five module errors and no JSC context. Reopening uses 51 cached frontend
sources, zero compiler calls and the following native-entry counts:

| Stage | Warm entries | Next first module failure |
| --- | ---: | --- |
| String predicates | 230 | WeakSet |
| WeakSet | 235 | Generator function creation |
| Generator creation | 247 | Array.map |
| Array.map | 253 | EventTarget |
| EventTarget | 253 | IntersectionObserver |
| IntersectionObserver | 253 | ResizeObserver |
| ResizeObserver | 324 | classList |
| DOMTokenList | 324 | createElementNS |
| Element factories | 324 | HTMLTemplateElement.content |
| Template content | 365 | requestAnimationFrame |
| Spread super calls | 373 | requestAnimationFrame |

These are changing, failed initialization workloads without a window, layout or
paint. Cold compilation versus warm loading is not completed-page performance.
Raw pins, commands, host contention, results and failures remain local under the
matching `docs/performance/libjs-*-github-20261115/` directories.

Three further fresh production observations use the unchanged 1024×768 replay
and fixed Brave content audit. Browser, controller and default-12-GiB guard
exits are zero; PID adoption succeeds and inputs remain unchanged.

| Sealed source stage | Executable SHA-256 | PID | Sampled peak bytes |
| --- | --- | ---: | ---: |
| MutationObserver (`0e61c1934`, 292 selected V files) | `4ce4867393f550712384f955ae053e74a39a7cde15e0ed927c90cd4a54d1ebef` | 63793 | 4,420,009,984 |
| WeakSet (`453f59df3`, 295 selected V files) | `249852422e761432035a5a00a8b5451162aaf7d3afdc2ee3837500d379309960` | 95498 | 4,480,204,800 |
| DOMTokenList (`1c433e094`, 306 consumed V/header files) | `9b7f8053037f5c05a935b8e12d7ff2d43ceae36912ee685e3ff17221af3cc229` | 32262 | 4,620,173,312 |

All are single-C-unit literal `-prod` bundles. Source stages come from sealed
consumed buffers, not receipt HEAD: the WeakSet bundle contains changes newer
than its recorded HEAD. Each has 33 rows, zero latest/commit links and one README;
the unchanged strict content gate rejects every capture. The first two expose
String.includes and generator-creation failures respectively. The DOMTokenList
native capture exposes **spread super arguments not translated**, a compiler
failure also present in the source-only JavaScript messages. Its 31.086-second
observation and whole-window PNG are diagnostics, not canonical document-pixel
or page-performance acceptance. Local records are in the mutation-observer,
strings and class-list native directories. No pixel tolerance changed.

The later core sweeps retain an important identity limitation. The four-worker
`r9` default mode passes **304/304 files** in 899.905 seconds. The combined guard
then times out at 1,800 seconds partway through no-GC (child 137); all 805 inputs
still match immediately after termination. The separate `r10-none` run passes
**304/304 no-GC files** in 1,104.408 seconds, but the wrapper exits 1 because
another session commits `59ce2c848`, changing `libjs/float16.h` during the run.
Its raw source audit remains failed. Sampled peaks are 9,914,613,760 and
9,830,514,688 bytes respectively, within the unchanged cap.

Clang's old/new Float16 helper LLVM IR is byte-identical at both O0 and O2; the
raw preprocessing differs by one blank line. The two affected numeric test files
pass again in both GC modes with the new header. A fresh canonical AST run matches
all 100 upstream cases exactly, with 805 current inputs stable across these
follow-up checks. This targeted recovery and code-equivalence proof do not turn
the failed raw identity audit into a source-stable dual-mode checkpoint.
The compatibility attempt stops before testing because the 0.5.2 compiler rejects
the required `-memory-limit` flag; no compatibility pass is claimed. Raw receipts
remain in `libjs-runtime-checkpoint-20261115-r9` and `r10-none` locally.

Spread-super cases and all five array-spread regressions pass in both GC modes
and sanitizer. Heritage, field initializers, parameters and native-cache neighbors
pass in both modes. A separate native integration case constructs EventTarget and
custom-element subclasses using explicit rest/spread constructors, dispatches a
real event and reopens with persisted code and the compiler disabled. It passes
in both GC modes. Early attempts with unavailable cross-test helper functions,
a mistyped neighbor filename, and disk-full linking remain retained. Completed
scratch binaries/generated C were removed after recording their hashes; receipts
remain local. The GitHub spread-super compiler diagnostic disappears; a separate
TypeError and missing requestAnimationFrame/setTimeout still prevent hydration.

## Animation frames, async continuations and labelled control

`e8967afbc` connects requestAnimationFrame/cancelAnimationFrame to the owning
native Window driver. Five cases pass in both GC modes and sanitizer: native
timestamps, callback receivers, cancellation during a batch, next-frame
registrations, conversion/branding, shared budgets, errors, teardown and warm
cache reuse. Native delivery under a temporary arena verifies persistent
retirement storage. Completed JS roots are cleared before native trampolines are
released at the next safe provider entry. Window-event, Hacker News and explicit
native-super neighbors pass in both modes. These are document engine services;
no browser UI or JavaScriptCore fallback was added.

`b66628766` implements ordinary async function calls and await continuations.
Calls return intrinsic Promises, execute the initial body synchronously, copy
suspended contexts outside the bounded interpreter stack, and acquire checked
frames when Promise jobs resume them. Internal PerformPromiseThen bypasses
replaced then/species methods. Saved lexical/private scopes, this/arguments,
live reference operands, original rejection values and catch handlers survive
suspension. Return adopts thenables through Promise resolution. Nine focused
cases pass in both GC modes and sanitizer. Creation/checkpoint/context fixtures
and six runtime neighbors pass in both modes. A separate native case awaits a
real animation frame, inserts actual template contents, and reopens with the
compiler disabled; both modes and sanitizer pass. The initial compilation failure
required a heap-owned Promise capability annotation. Top-level await, generators,
try/finally and complete HTML unhandled-rejection event integration remain open.

`bd76cf441` adds Array.find/some with live Get/HasProperty semantics, length
snapshots, ordered callback arguments, short-circuiting and shared budgets.
Find visits holes; some skips absent indices. Six cases pass in both modes and
sanitizer, with Array.map/concat regressions and persisted callbacks.

`aa8666f5c` adds labelled blocks and loop break/continue, including nested labels,
for/while/do/for-in/for-of, var hoisting and lexical unwinding. Abrupt transfers
close crossed for-of iterators in order; continuing the target iteration keeps
its iterator open. Close failures escape body-local catches and reach enclosing
handlers. Six cases pass in both modes and sanitizer, including cached async
continuations; for-in, for-of, catch and async neighbors pass. Retained early
attempts exposed the frontend's synthetic block wrappers and distinct for-in/of
source positions. The final classifier reads their original start token without
mutating AST data. Annex B labelled function execution remains separate work.

The unchanged-response source-only pairs after animation frames, async/await and
Array predicates reuse **451, 467 and 471 native entries**, respectively. Every
warm visit also reuses 51 frontend sources, invokes no compiler, initializes no
JSC and preserves fixture hashes. All retain 33 rows and zero commit links. The
first failures progress from async execution to Array.find/some and then
window.matchMedia. Missing setTimeout and a separate early TypeError remain in
the JavaScript diagnostics. No completed-page timing or pixel credit follows.

A fresh native observation uses executable
`ab304f1f122ee2350d541ad5c2c0893b7abfe45cdc83671f7f2107f5ef2c628f`,
PID 61724, with browser/controller/guard exits zero, unchanged inputs and
4,851,122,176 sampled peak bytes. All 309 selected sources match `e8967afbc`
except its two persistent-scope lines, absent from the completed bundle; the raw
mismatch and exact pre-follow-up source hash qualification are retained. This
baseline contains animation frames and predates async/await. It has 33 rows,
zero latest/commit links, one README and script errors; the unchanged Brave
content validator rejects it. Native frame execution additionally exposes the
labelled loop at pb.js:136:144079. Its whole-window PNG was inspected against the
fixed Brave document PNG, with loading placeholders still plainly visible.
This supplies neither canonical pixel nor new-async-code validation.

The subsequent `r11-default` sweep passes **305/305 files** with **806 unchanged
inputs**, test/wrapper/guard zero, 977.395 seconds and 9,883,107,328 sampled peak
bytes. This is a source-stable default-GC checkpoint, not a new dual-mode claim.
The later 308-file `r12` checks run GC modes sequentially under separate guards
with explicit 1,800-second timeouts. All 308 no-GC files pass in 944.477 seconds
(peak 9,864,298,496 bytes). The default sweep passes 306 files and fails two
compilations solely from disk exhaustion, retaining test/wrapper/guard exit 1
(1,090.845 seconds, peak 9,852,764,160). The two files, typed_array_sources and
uint8_array_hex, then pass under a separate 3-GiB guard in 43.881 seconds
(peak 2,603,483,136). All 812 inputs remain stable across both sweeps and recovery.
A fresh canonical AST run matches 100/100 cases exactly. This is a source-stable
functional union, not a clean single default-GC sweep; the original failure is
retained. The local r12-recovery composite ledger records all component exits.


## Native media queries and cancellation

`4bb817026` binds matchMedia to native CSS query evaluation and MediaQueryList
EventTarget delivery. Legacy listeners and onchange share the native listener
path; typed MediaQueryListEvent records preserve constructor/prototype ancestry.
Five cases pass with default GC, GC-none and AddressSanitizer, plus animation
frame, Event and EventTarget neighbors in both modes. Its original-response pair
reuses 476 native entries before reaching missing AbortController.

`5b9350011` binds native AbortController/AbortSignal, default DOMException reasons,
static abort/timeout/any, throwIfAborted and abortable event listeners. Arbitrary
JavaScript reason values retain identity without string conversion; dependent
signals share native reason records. Abort removes both native listeners and VM
roots; teardown removes owned abort algorithms before releasing closures. Native
Window timers deliver timeout signals. Six cases pass in both GC modes and
AddressSanitizer; EventTarget, media-query and DOMException neighbors pass in
both modes. Fetch RequestInit.signal is still rejected explicitly.

Disk exhaustion interrupted initial compilation, native-cache linking and one
Git index write; these failures remain recorded. Completed task-owned generated
C and binaries were removed with hash ledgers, and canonical pruning removed
idle scratch according to its existing policy. The final focused checks use
private 512-MiB RAM scratch for generated compiler output, with unchanged
12-GiB build and 3-GiB runtime RSS guards. This adds 512 MiB of scratch RAM
capacity outside sampled process RSS. No sources or browser bundles were copied;
each newly allocated volume was verified and detached after its job.

The first Abort-stage original-response pair exits 1 during disk-full cache
linking and produces no visits. Its retained retry uses a private RAM-backed
native cache and passes with unchanged inputs: the second fresh VM reuses
**526 native entries and 51 frontend sources, with zero compiler invocations**.
Neither VM initializes JSC. Both retain 33 rows, zero commit links and five
module errors, now headed by missing URLSearchParams. Missing setTimeout and
an earlier TypeError also remain. These changing, incomplete initialization
workloads provide no completed-page speedup or rendering acceptance.

The latest completed production executable remains
`4a0da515ac045c10ee2349a1ee9ad4b1efb52385971278a42f7cc5effa5b55fd`.
Its sealed source audit at the media-query stage mismatches animation_frames.v,
events.v, host.v and media_queries.v among 313 selected paths. It cannot validate
the current native bindings. Automatic commit rebuild requests remain coalesced;
pixel-perfect GitHub, live behavior and completed-page performance stay open.


## Query parameters, Array.from and tagged templates

`b4b764394` exposes the actual native URLSearchParams parser/serializer, ordered
record and iterable initialization, USVString conversion, optional-value methods
and live iterators/forEach. URL.searchParams keeps its native identity as href
and search change, and parameter mutations update the owning URL. Six focused
cases pass in default GC, GC-none and AddressSanitizer. Headers and three native
URL/query neighbor files pass in both modes. Early attempts with a test variable
shadowing the error binding and an unavailable Number global are retained.
This binding does not establish full URL/Location or Fetch-body parity.

`17da110f4` implements both Array.from branches, generic constructor calls, mapper
ordering, dense array-like Get, live iterable stepping, shared budgets and the
required IteratorClose paths. Array construction now respects NewTarget's
prototype, including Array subclass fields and intrinsic fallback. Eight cases
pass in both modes and sanitizer; four Array/iterator/heritage neighbors pass
in both modes. An early fallback fixture relied on the still-uninstalled Reflect
global; the final fixture invokes the actual constructor operation from V.

`1dbb4439d` adds GetTemplateObject and tagged calls. Realm-local caches retain the
actual parsed site, so repeated calls and separate closures share one frozen
array, separately parsed sites differ, and another realm gets fresh objects even
with a shared frontend tree. Raw/cooked code units, invalid cooked escapes,
member/private receivers, evaluation order and uncoerced substitutions survive;
await also preserves the template operand. Native creation bypasses author
constructors, freeze methods and inherited setters. Six cases pass in both modes
and sanitizer, plus five template/call/async/cache/frontend neighbor files in
both modes. The opcode participates in the existing native-cache ABI hash.

| Original-response stage | Warm native entries | Next first module failure |
| --- | ---: | --- |
| URLSearchParams | 605 | Array.from in pb.js UUID helper |
| Array.from | 613 | tagged template in Turbo defaultCSS |
| Tagged templates | 615 | Array.reduce in the CSS template tag |

Each pair has unchanged inputs, exit zero, 51 warm frontend hits, zero warm
compiler invocations and no initialized JSC. All retain five module failures,
33 rows and zero commit links. Missing setTimeout and an earlier TypeError remain
in that recorded workload. These numbers count executed/compiled paths up to
failure, not all functions in GitHub's bundles or a completion percentage.
Number's default primitive-prototype wiring also remains incomplete; passing
the UUID helper's startup call is not a UUID semantic-conformance result.

A fresh native Abort-stage observation uses executable
`73cc5a369ba8dcf011521ec9ea5bb00038a62a82a1f8f0c926fca57f8f48e54b`.
All 315 selected consumed sources match `5b9350011`; PID 23336, browser/controller/
guard exits zero, unchanged inputs and 5,040,603,136 sampled peak bytes are
recorded. It has 33 rows, zero latest/commit links and one README; the unchanged
Brave content validator rejects its script/native errors. The whole-window PNG
was inspected and still shows commit placeholders; no canonical pixel acceptance
follows. The later completed production executable
`2e08971261e0625d26c1005f1dcd859421619ae6b19ff16c9e9f2459e7d256fc`
has all 317 selected consumed sources matching the Array.from commit; that
source audit alone is not a rendering check or tagged-template validation.

The 310-file r13 sweep stops after 25 completed files with no final exit receipt.
Its interruption audit finds all 816 pinned inputs unchanged; it remains an
incomplete attempt. The subsequent r14 modes run sequentially with the same
12-GiB guards and 1,800-second limits, using a durable controller; results remain
pending. A fresh canonical AST run matches all 100 cases exactly, with all
816 current inputs unchanged; its guard exits zero and peaks at 632,242,176
bytes. Host load subsequently reaches about 94–102 on 18 CPUs with no swap,
so these runs supply correctness checks only. Full execution, live behavior,
completed-page speedup and zero-pixel Brave conformance remain open.


## Window timers and current verification limits

`13e0a3efc` adds setTimeout/setInterval and the shared clear methods through the
actual WindowOrWorkerGlobalScope timer owner. Native HTML retains clocks, queued
tasks, nesting, clamping, CSP and ClassicScript base URLs. The bridge preserves
Window receivers and argument values, ignores callback thenables, shares bounded
VM entry, retires running closures safely and removes owned roots on cancellation
and close. String callbacks execute through LibJS without a JSC context.

Eight focused cases pass in both GC modes. The first sanitizer build fails
creating object files because the main disk is full; its private 512-MiB RAM
scratch recovery builds and runs successfully, then detaches its verified volume.
`a0994d536` additionally keeps source-timer exception boxes and converter roots
outside native temporary arenas. Its ninth case retires an actual scratch arena
and verifies original JavaScript reason identity afterward. The final nine cases
pass in default GC, GC-none and AddressSanitizer with unchanged memory guards;
the second private volume also detaches successfully. Initial integer-index and
private-field fixture compilation failures remain recorded.

The recorded 615-entry GitHub pair predates these timer bindings. Its Array.reduce
startup failure and zero hydrated commit links remain the latest original-script
result; there is no new full-page or pixel acceptance claim. The timer commits
request the usual coalesced rebuild, and current production validation remains
open. A full runtime completion percentage cannot be inferred from cached entries.

The r14 no-GC attempt is now terminal: the 1,800.072-second guard expires with
child 137 and controller 125, peaking at 9,754,132,480 bytes. It records 164 passes,
87 failures before any recorded test runtime, and 59 files without a completed
result. The log contains 124 disk-full diagnostics; default GC never starts. All
816 pinned inputs still match after termination. This is a failed, incomplete
checkpoint, not a replacement for the earlier source-stable 308-file functional
union. Resource failures and all raw component receipts remain local.

## Implementation checkpoint with runtime verification held

The last original-response observations precede the user's test hold:

| Stage | Commit | Warm native entries | Next first module failure |
| --- | --- | ---: | --- |
| Array reductions | `799ada300` | 623 | GitHub's wrapper accesses missing Node.insertBefore |
| Native tree insertion | `cb906c1f9` | 672 | missing history in Turbo initialization |

Both pairs preserve the original fixture and executable inputs, reuse 51 frontend
sources, invoke no compiler on reopening and initialize no JSC. Both still have
33 rows, zero commit links and five cascading module failures. An earlier
TypeError also remains. These are incomplete initialization diagnostics, with no
window/layout/paint, completed-page speedup or rendering acceptance.
Local evidence is `docs/performance/libjs-reduce-github-20261115/` and
`docs/performance/libjs-tree-github-20261115/`.

Before the hold, six Array reduction cases and six native tree cases pass in
both GC modes and AddressSanitizer. Reduction checks also cover three neighboring
Array files per mode; native tree checks cover ParentNode mutations, templates
and MutationObserver in both modes. Native insertion uses pre-insert/replacement,
actual fragment adoption, observer records and custom-element reactions, with
real first/last/previous sibling getters.

The r15 no-GC sweep has 818 stable inputs and 310/311 passing files. Its single
failure is a stale negative assertion expecting tagged templates to be unsupported.
`f9ec58b89` removes that expectation, adds normal script execution coverage and
replaces the deprecated usize cast rejected by strict production compilation.
Tagged templates pass both GC modes, sanitizer and literal `-n -prod -prealloc
-gc none`; script evaluation passes both GC modes. The r16 sweep then stops at the
user's request: 103 passes, no completed failures, child 137/controller 125, no
default-GC start and no completed source-stability acceptance. The guard reports
remaining children during cancellation; a subsequent process inventory finds no
owned test processes. Its private RAM volume detaches successfully. This is an
interrupted checkpoint, not a passing broad suite.

The following implementations were committed after the hold. Their focused
regression cases are written but have not been executed in their final form.

| Commits | Implemented surface | Remaining boundary |
| --- | --- | --- |
| `24adf7825` | Owning Window History entries, push/replace, native security and navigation cancellation, stable cloned-state identity, live Location reads. | Storage cloning currently supports primitives, ordinary objects and arrays; unsupported internal-slot/platform families throw DataCloneError. Traversal scheduling remains separate. |
| `eb14b5022`, `3bdb68fa5` | Number constructor/predicates/constants, intrinsic boxing, radix and fixed formatting; original parse-function identities exist before host realm hooks. | Scientific decimal and Intl adapters remain uninstalled. |
| `8d6b94558` | Native CharacterData/Text/Comment factories and prototypes, text mutation/splitting, nodeValue, containment, roots, cloning and ChildNode operations. | Native character storage's existing surrogate normalization is unchanged; broader DOM interfaces remain incomplete. |
| `2751e5fa7` | Generic RegExp replacement with observable flags/exec, ordered captures, callbacks, substitutions and bounded empty-match advancement. | Other RegExp symbol methods remain separate. |
| `4868f3ce5` | Spread in ordinary/new/optional calls, retaining receivers and iterator ordering through both execution tiers. | Generator execution and other language gaps remain; the following continuation adds cleanup and super references. |
| `3b5caae3e` | Default-realm Reflect installs all thirteen existing translated methods. | This does not add Proxy exotic behavior. |
| `dfe44a124` | Promise.finally species and cleanup chaining. | Runtime verification held. |
| `099055fdb`, `fa2d2f10d`, `f46d7a14a`, `0ab92f02a` | Generic Promise.all/race/allSettled/withResolvers, ordered aggregation, once guards and abrupt iterator closing. | Promise.any and later proposals remain pending. |
| `1becbb753`, `7f82decfd` | Actual document focus, visibility, title, cookies and Window aliases; checked matches/closest with retained scoping root, attribute names and toggles. | Other document/element APIs remain incomplete. |
| `d87c25778` | Existing UTF-16 trim/pad/repeat/concat/normalize, character and well-formed-string algorithms are installed, with identical trimming aliases. | Intl locale operations remain separate. |
| `3cde7b553`, `fce1def67`, `780e1c19a` | Species-aware filter, live sparse every and SameValueZero includes. | Runtime verification held. |
| `64215da63`, `42a06afbb`, `ff5d3428b`, `467482ddd` | Sparse shift/reverse, stable sorting with shared budgets, directional searches and indexed access. | Runtime verification held. |

One initial History run before the hold fails its temporary-arena fixture, which
incorrectly allocates the surrounding test script and its later property writes
inside the retired arena. The replacement fixture calls the actual native
binding with preexisting values and checks retained roots; it remains unexecuted.
That earlier failure is preserved and is not counted as a passing History check.

Compiler-only `v -b c -check` completes successfully for the initialization tool
and its native DOM/LibJS dependencies after each integration checkpoint. The
latest check exits zero under the default 12-GiB guard, peaking at 5,230,526,464
sampled process-tree RSS bytes. It executes no JavaScript or tests. Earlier
FastC check-mode rejection, two wiring errors, a 3-GiB compiler limit and an
undefined constant are retained; corrected C checks pass. Raw compile logs and
commands remain in the local benchmark cache. Fifty-eight completed guard
receipts were preserved byte-for-byte under the local follow-up evidence and
removed with their job locks from Build; no source/app copies were made there.

The latest inspected completed production executable is
`78558628ea0b9c1b1adfb76793e32afbc1151bdd747526913a13fdd27fb76dc4`,
single-unit C with literal V `-prod`. Its sealed-source comparison against
`467482ddd` finds 13 differences among 343 selected paths, including the latest
Array/String and document/selector bindings. It cannot validate those changes.
No browser was launched after the hold. Commit rebuild requests remain coalesced;
full GitHub hydration, live validation, completed-page speed and unchanged
zero-pixel Brave conformance remain unachieved.

## Control-flow and class compilation continuation

The verification hold remains in effect. This continuation inspects the native
compiler/runtime and the local upstream algorithms, without running tests,
executing page JavaScript or launching a browser.

| Commit | Implementation | Pending verification/boundary |
| --- | --- | --- |
| `f580c2779` | Try/finally routes normal, thrown, returned and labelled loop-control completions through one finalizer body. It restores lexical depth, preserves pending values across await, and orders cleanup relative to nested iterator closing. A finalizer's abrupt completion replaces the pending one. | Eight focused cases are written but unexecuted, including async cleanup and compiler-disabled native-cache reuse. |
| `7a66f90fb` | Switch evaluates its discriminant once, performs strict case selection, defers default until all failed tests, and falls through without evaluating later tests. Case-block lexical bindings and strict function declarations initialize in their native scope; continue targets an iteration instead of the switch break context. | Six focused cases are written but unexecuted. Sloppy Annex B switch function declarations remain explicitly unsupported. |
| `ff4321800`, `82f5392ab` | Function home objects are retained for ordinary/object-literal/private/class methods, constructors and field initializers. Super reads/writes/updates, optional/tagged calls and extracted methods use the actual receiver. Delete rejects a Super Reference before key coercion. | Six focused cases are written but unexecuted, including observable computed-key ordering and native-cache reuse. |
| `02e9c7bfb` | Strict hidden static-block functions retain class this, super and private scope, isolate their var declarations and run in order among static fields after method installation. Abrupt completion stops later initialization; no synthetic constructor property is created. | Four focused cases are written but unexecuted. |
| `7e2e788a6` | Catch object/array patterns reuse native binding-pattern bytecode for defaults, computed keys, rest, TDZ bindings and required iterator closing before the catch body. Initialization errors reach outer catches/finalizers. | Four focused cases are written but unexecuted. |

Super reference lowering follows the current
[ECMAScript evaluation and MakeSuperPropertyReference algorithms](https://tc39.es/ecma262/multipage/ecmascript-language-expressions.html#sec-super-keyword-runtime-semantics-evaluation):
the receiver is obtained before evaluating a computed expression; the home
prototype is read afterward, and key coercion remains at the consuming
operation. This also avoids copying a method's new receiver into its home object.
The existing reference deletion algorithm rejects super before coercion or
null-base conversion. No JavaScriptCore or host-script fallback was added.

Compiler-only checking of `tools/libjs_github_revisit.v` and its native runtime/
DOM dependencies succeeds after integration: V C backend, `-n -check`,
`-memory-limit 10G`, default 12-GiB process-tree guard, child/guard exit zero,
19.559 seconds and sampled peak RSS 5,238,226,944 bytes. These are compiler costs,
not JavaScript or browser timings. Earlier passes cover finally, switch and
super integration separately. A bool-to-Value wiring error and a static-block
local-name collision fail the initial compiler attempts; their logs are retained
alongside the corrected passes. All seven completed guard reports were copied
byte-for-byte into local `docs/performance/libjs-language-implementation-20261115/`
evidence before their Build reports and job locks were removed. Compiler logs
remain in the local benchmark cache.

The new instruction layouts participate in the existing native-cache ABI hash;
second-VM compiler-disabled cases are prepared, not claimed as passing. No new
runtime, AST-corpus, GC/ownership, hydration, live-site, speedup or pixel result
is available under this hold. The last actual GitHub observation is still the
672-entry incomplete initialization pair above; it cannot validate these later
language implementations or establish a completion percentage. Dynamic imports,
generator execution, top-level await, remaining assignment forms/builtins and
Web APIs still require work before the requested GitHub/Brave parity outcome.

## Assignment, dynamic loading and native API continuation

The user's verification hold remains in effect. This continuation performs
source inspection and compiler-only checking of the normal
`tools/libjs_github_revisit.v` program. It does not execute the diagnostic,
JavaScript tests, AST fixtures, browser captures or comparison cohorts.

| Commit | Implementation | Prepared verification |
| --- | --- | --- |
| `467a0628f` | Object/array destructuring assignment retains identifier and member references before getters or iterator steps, applies defaults/rest/nesting, returns the original RHS and closes iterators on abrupt completion. For-in/of assignment resolves outer lexical bindings and supports private/super targets. | Reference ordering, abrupt identity, sparse iteration, lexical scope and compiler-disabled native-cache cases remain unexecuted. |
| `10dd04645` | Object.fromEntries consumes actual iterators, reads both entry properties before key conversion, defines ordinary own data properties and closes on entry-processing errors. | Symbol/prototype keys, getters, iterator failures and budgets remain unexecuted. |
| `17dc548bd` | Dynamic import emits native bytecode and returns an intrinsic Promise. Attribute conversion, host loading, graph loading, linking, evaluation and namespace resolution use native records and promise continuations. | Deferred root/dependency completion, live namespaces, error identity, attributes, filesystem gating and native reuse remain unexecuted. Non-JavaScript module namespace support and top-level await remain separate. |
| `1c911eabf` | Document-bound LibJS promise reactions enter the owning HTML microtask queue. They retain FIFO order with native microtasks, restore currentScript, check document execution permission and share a bounded job budget. Imports use the existing Fetch/import-map/module-map host. | Browser cases wait for native event-loop progress without evaluate() polling, which could conceal stalled reactions. These cases remain unexecuted. |
| `dc27037f9`, `7442d00c0` | Array.flatMap/flat share native FlattenIntoArray with live sparse reads, species targets, data-property writes, safe index bounds and stack/execution budgets. Mapping applies only at the root; flat converts depth before species creation. | Sparse/live reads, aliasing species targets, inherited setters, recursive depth and budgets remain unexecuted. Proxy IsArray behavior remains pending with Proxy exotics. |
| `c1f963f97` | Array.toSorted uses the translated stable sorter, reads through holes into a dense intrinsic array and avoids source writes or species access. | Validation/getter ordering, stable comparison, sparse input and abrupt identity remain unexecuted. |
| `75a333592` | The native CSS namespace exposes CSS.escape and both CSS.supports overloads. Escaping preserves raw UTF-16, including lone surrogates; support decisions use the existing document CSS parser. | Code-unit boundaries and overload conversion cases remain unexecuted. This does not add CSS.registerProperty or change existing parser support. |
| `bb216bb7e` | WeakRef construction/deref uses the existing disappearing-link collector adapter. Successful targets stay strongly kept through the complete microtask checkpoint; cleanup clears retained backing slots and runtime shutdown roots. | Brand, prototype ordering, symbol identity, collector lifetime and compiler-disabled reuse cases remain unexecuted. |
| `771c58991` | History storage cloning rejects the WeakRef internal slot before invoking any own enumerable getters. Direct or nested weak references cannot silently become ordinary objects. | The state-preservation and getter-side-effect regression remains unexecuted. |

WeakRef's collector adaptation uses an explicit per-job kept-object list in
place of upstream WeakRef's generation-conditioned tracing edges. The HTML
queue clears that list after all reactions, while standalone VM checkpoints
clear it after draining their own queue. Non-collecting builds retain encoded
target identity and do not simulate collection. The already existing weak-cell
adapter's historical checks do not validate these new WeakRef lifetime paths.

A read-only textual scan of the unchanged original fixture finds 29
Object.fromEntries call matches in nine bodies, 25 flatMap matches in eleven,
ten flat matches in seven, one toSorted match, two dynamic-import matches,
six CSS.escape matches in four, six CSS.supports matches in three and four
WeakRef constructor matches in four. These are source occurrences, not executed
or reachable coverage. The same scan finds six Proxy constructor matches,
eleven generator declarations, nineteen Intl references and three matchAll
calls. Proxy exotics, generator execution, Intl, remaining RegExp operations,
top-level await and other Web APIs still require work. No completion percentage
can be inferred from these counts.

The final native import-graph compiler-only check exits zero with default GC
(26.415 seconds, sampled peak RSS 5,243,879,424 bytes). The preceding WeakRef
integration also checks successfully with `-gc none` (23.750 seconds,
5,241,487,360 bytes). Both use V's C backend, `-n -check`,
`-memory-limit 10G` and the default 12-GiB process-tree guard; neither emits or
runs a test executable. Fifteen completed guard reports are retained
byte-for-byte in local
`docs/performance/libjs-assignment-imports-implementation-20261115/` before their
Build reports/locks are removed. The three failed attempts are retained:
dynamic-import lowering initially shadows its expression parameter, and two
CSS binding checks use private UTF-16 APIs before switching to the existing
public code-unit boundary. Compiler logs remain in the local benchmark cache.
These compiler durations are not JavaScript or browser performance results.

The latest statically inspected completed production executable is
`395539f070321dc8cb06f44467d591253d9dafffe61d55687bd37c08ba2b0859`,
single-unit C with literal V `-prod`. Its sealed input manifest differs from
`771c58991` on eleven of 359 selected implementation paths, including WeakRef,
checkpoint cleanup, CSS bindings and History cloning. It cannot validate those changes. Commit
requests remain coalesced under the managed production worker; no additional
manual build or browser launch was requested by this continuation.

The original fixture manifest, source map and Brave PNG hashes remain unchanged.
The last actual GitHub source-pair observation remains the historical 672-entry
incomplete initialization run: 51 frontend hits, zero compiler invocations,
33 rows and zero commit links. It does not identify the current first failure
or validate subsequent implementations. Completed hydration, live-site
behavior, final GC/ownership checks, completed-page cache speedup and unchanged
zero-pixel Brave conformance remain open.

## Generator and regexp execution continuation

The verification hold is unchanged. This continuation inspects the implementation
and local upstream sources, writes regressions and checks the normal
`tools/libjs_github_revisit.v` import graph with V `-check`. It runs no JavaScript
tests, page initialization probes, browser captures or performance cohorts.

| Commits | Implemented native behavior | Unexecuted verification |
| --- | --- | --- |
| `54a87750f` | Synchronous generator parameters initialize at call time, while body execution waits for next. Saved frames retain locals, this, arguments, private scope and method homes independently of the bounded interpreter stack. Next/throw/return handle reentry, completed state, catches, finalizers and iterator cleanup. | Independent frames, injected completions, suspending finalizers, private/super methods, budgets and compiler-disabled cached resumption. Async generator execution and dynamic generator constructors remain separate. |
| `09e034e64`, `f3bbae84c` | Yield delegation caches next, looks up throw/return live, preserves delegate result identity without prematurely reading value, closes when throw is absent and forwards return completions through outer cleanup. | Recursive delegation, exact call arguments/receivers, missing methods, close errors, result getters and native-cache reuse. |
| `7ae42c503` | The saved frame owns the creating function while suspended; completion releases it without retaining that function's lexical environment through a separate record field. Escaped author closures retain their own environment. | Completed-frame ownership and escaped closures. |
| `eef85d906` | Generator returns from destructuring defaults or computed targets close active pattern iterators before enclosing for-of iterators and finalizers. The for-of cleanup context covers LHS initialization. | Binding/assignment defaults, suspension before iterator stepping, nested closing order and close errors overriding a pending return. |
| `e0de13b38` | RegExp construction shares observable IsRegExp with String predicates, checks call identity, copies original native slots, reads generic source/flags in order and resolves NewTarget prototype before coercion. The native species getter supports subclasses. | Constructor identity, generic getters, subclass prototypes and abrupt coercion. |
| `4db05a6e1` | String.matchAll and RegExp@@matchAll create lazy native RegExp string iterators. They use species, copy lastIndex, preserve exec result identity, advance Unicode empty matches and validate global flags before delegation. History storage rejects iterator internal slots. | Lazy/custom exec, species ordering, flags, captures/indices, Unicode, retry after abrupt next, native reuse and History rejection. |
| `6591f4c40` | String.replaceAll validates global regex flags before delegating the original receiver. Literal matching gathers non-overlapping UTF-16 positions, then runs callbacks or substitutions with bounded output growth. | Receiver/argument identity, empty searches, substitutions, conversion errors and native reuse. |
| `15b1b91f3` | String.search delegates before receiver coercion; RegExp@@search preserves raw lastIndex with SameValue semantics and restores it before reading a successful result index. Abrupt exec propagates directly. | Signed zero, read-only zero, raw result indices, restoration order and thrown identity. |
| `fb45c35ed` | RegExp@@split supplies the existing String.split symbol path with a species-created sticky matcher. Native RegExpExec drives Unicode progress, raw captures, limits and empty-input behavior without changing source regexp state. | Regex separators, capture values, zero/finite limits, species/limit ordering, subclass exec and compiler-disabled native reuse. |

Both dispatch tiers recognize generator suspension as a control transfer. Saved
frames and iterator records are VM-owned values; cached libraries contain code
and layout rather than saved realm pointers. The instruction/native-dispatch
changes participate in the existing native-cache ABI hash. New two-VM cache
cases are prepared, not claimed as passing.

The original delegation feature commit was made before its failed compiler
result was noticed; its commit message's pass claim is incorrect. The retained
failure reports an unchecked numeric-to-enum cast and misuse of release_error
on a non-result completion. `f3bbae84c` corrects both: resume-kind selection is
validated and IteratorClose releases only a thrown completion. The corrected
compiler-only check passes. Shared history was not rewritten.

Thirteen completed compiler guard reports are retained byte-for-byte locally
under `docs/performance/libjs-generator-regexp-implementation-20261115/`,
including that failure; their Build reports and locks have been removed. The
final default-GC check exits zero in 19.941 seconds with sampled peak RSS
5,260,296,192 bytes. The final production/preallocation GC-none check also exits
zero: `-n -prod -prealloc -b c -no-parallel -cc clang -check -gc none
-memory-limit 10G -enable-globals`, 35.537 seconds and 5,421,613,056 bytes. Both
use the default 12-GiB process-tree guard. These type checks emit/run no test
binary and establish no JavaScript, GC, rendering or speed result.

A textual scan of the unchanged original script bodies finds eleven function*
declarations in five bodies, seven yield-delegation occurrences in one, three
matchAll calls in two, eighteen replaceAll calls in eight, nineteen literal
regex-separator split calls in ten and nine .search calls in five. Receiver
types and execution reachability are not established by those counts. Six
Proxy constructor occurrences and nineteen Intl references remain in the same
source scan. Proxy exotics, Intl, async generators, top-level await, remaining
Web APIs and full browser integration still require work.

At implementation revision `0b81687bc`, the latest completed production
executable inspected statically is
`a7918541efb0271c0388a5f7319ef8b8e00234bb13a5fed1c8bac5a0b2de9589`,
single-unit C with literal V `-prod`. Six of 366 selected implementation paths
differ from its sealed manifest: array binding/assignment and for-of cleanup,
RegExp installation, search and split. This subset comparison cannot validate
those changes or the entire browser. Managed rebuild requests remain coalesced;
no additional manual build or browser launch was requested here.

The fixture manifest, source map and Brave reference PNG hashes are unchanged.
The last executed GitHub observation remains the historical 672-entry pair with
33 rows and zero commit links. All new focused, ownership, cache-revisit and
pixel checks remain held. Completed hydration, live-site behavior, whole-page
speedup and zero-pixel GitHub/Brave parity remain unachieved.

## Proxy, JSON serialization and scheduling continuation

**Implementation progressed; GitHub/Brave parity is still incomplete.** The
user's test hold remains in force. No new JS execution, initialization probe,
focused or broad test, browser launch, capture, pixel comparison or performance
trial was run for these changes. The new regression cases are prepared source,
not passing runtime evidence. Compiler-only checks below compile a normal
program's import graph and do not include `_test.v` files.

The focused implementation commits are:

- `9317e0ac2`: native `Proxy` and `Proxy.revocable`, all thirteen internal
  operations, callable/constructor forwarding and immutable-property,
  extensibility, descriptor and own-key invariants. Revocation clears target
  and handler; a revoker releases its captured proxy after the first call.
  Trap lookup, argument receivers, post-trap validation and abrupt values are
  preserved. A VM-local depth guard bounds transparent recursive forwarding.
- `a84553026`: proxied arrays participate in ArraySpeciesCreate, including
  constructor/species getters, instead of falling through to ordinary arrays.
- `ccfb036bf`: native `JSON.stringify`, with `toJSON`, function/array replacers,
  primitive-wrapper conversion, property-list deduplication, indentation,
  key/length snapshots, live getters, array holes, cycle detection, BigInt
  errors/hooks and UTF-16 quoting. This uses VM operations and a bounded UTF-16
  builder; no host JSON serializer or JSC execution is introduced.
- `8e0506849`: charge JSON quoting budget after crossing each chunk boundary,
  including surrogate pairs following an odd-length prefix. Exact-index modulo
  checks could otherwise skip all later boundaries on that input.
- `a00a085b3`: native Window `queueMicrotask` uses the owning HTML microtask
  queue. HTML Tasks can explicitly take ownership of one-shot captured steps;
  execution or pending-task discard releases them after safe native return.
  Closing a host discards its pending microtasks and clears their JS roots.
- `45515baf6`: native Window `requestIdleCallback`/`cancelIdleCallback`, using
  the existing Window scheduler, timeouts, unsigned handle/dictionary conversion
  and native `IdleDeadline` arithmetic. Deadline objects retain the current
  period's end; timed-out callbacks report zero remaining time. Cancellation,
  callback completion and host close retire callback roots and trampolines.

Object operations that can now invoke traps have checked entry points carrying
VM exceptions, with separate descriptor/prototype absence. Script-visible
Reflect/Object methods, operators, arrays, destructuring/spread, dynamic import
options, descriptor conversion, binding/super/instanceof operations and Headers/
URLSearchParams record conversion use them. Concrete engine-record storage and
side-effect-free diagnostics retain ordinary helpers. `for…in` now obtains each
prototype level lazily and checks descriptors without inventing `has` calls;
breaking a loop does not invoke later traps. History cloning rejects proxies
before invoking their getters or traps. The thirteen trap implementations are
source translations of the local upstream `Runtime/ProxyObject.cpp`; their
correct execution is still awaiting the held regressions.

Native scheduling callbacks use bounded VM entry, document/script policy,
callback setup/cleanup and exception reporting. Results are ignored without
thenable adoption. Microtasks temporarily clear `document.currentScript` and
restore the previous value. The browser's external Promise-job scheduler and
`queueMicrotask` enqueue into the same HTML FIFO. All of these integration and
ordering claims describe the implementation, not executed assertions.

There are 41 newly prepared regression functions: fifteen Proxy/DOM cases,
twelve JSON cases, eight owned-task/microtask cases and six idle-callback cases.
They include compiler-disabled second-VM native-cache checks, trap exceptions
and ordering, ownership across temporary arenas, callback policy, shutdown,
cooperative instruction limits and native idle-period delivery. They remain
unexecuted, including the new test files' own compilation.

Compiler-only checks used current V, `V3_STR_CAP=1`, `VJOBS=1`, C backend,
`-no-parallel -cc clang -check -memory-limit 10G -enable-globals` against
`tools/libjs_github_revisit.v`. Production checks additionally used
`-prod -prealloc -gc none`. Each ran through its own default 12 GiB memory
guard. Checker elapsed time and RSS below are **not** browser performance:

| Compiler-only attempt | Exit | Seconds | Sampled peak RSS bytes |
| --- | ---: | ---: | ---: |
| Proxy normal | 0 | 20.919 | 5,261,361,152 |
| Proxy production/prealloc/no-GC | 0 | 20.065 | 5,416,812,544 |
| Proxy array species | 0 | 15.041 | 5,265,227,776 |
| JSON first normal attempt | 1 | 16.293 | 1,512,030,208 |
| JSON corrected normal | 0 | 31.377 | 5,262,540,800 |
| JSON production/prealloc/no-GC | 0 | 24.013 | 5,425,905,664 |
| Microtasks first normal attempt | 1 | 15.038 | 1,512,439,808 |
| Microtasks corrected production/prealloc/no-GC | 0 | 26.992 | 5,431,443,456 |
| Microtasks corrected normal | 0 | 28.023 | 5,257,920,512 |
| Idle callbacks normal | 0 | 26.369 | 5,254,152,192 |
| Idle callbacks production/prealloc/no-GC | 0 | 27.463 | 5,422,481,408 |
| JSON surrogate budget production/prealloc/no-GC | 0 | 26.479 | 5,425,070,080 |

Both failed attempts are retained. The first JSON check rejected a mutable
array alias; it was replaced with a property-list clone. The first microtask
check caught an accidental pointer-to-pointer cast; it was changed to the
explicit Document pointer cast. The corrected normal and production checks
passed before their respective feature commits. All twelve completed guard
reports, including these two failures, were copied byte-for-byte into local
`docs/performance/libjs-proxy-json-scheduling-20261115/`; their hashes and
commands are recorded there. Only this continuation's completed Build reports
and locks were then deleted. No required runtime test is being reported as run.

A static scan rehashed all 164 original-response entries and left the pinned
manifest, HTML, source map and Brave reference unchanged. Across 86 distinct JS
bodies it finds six `new Proxy` occurrences in three bodies, 108
`JSON.stringify` references in 26, twenty `queueMicrotask` occurrences in eleven
and 35 `requestIdleCallback` occurrences in nine. Those textual counts establish
neither reachability nor successful execution. `Intl` remains untranslated:
nineteen references occur in five bodies, including eleven DateTimeFormat
references and top-level constructor calls. Other Intl formats, async generators,
top-level await, remaining Web APIs and complete browser rendering still need
work; adding these APIs does not establish complete GitHub initialization.

At implementation revision `8e0506849713d8d1c27212677158a03191330f50`, the latest
completed production executable inspected statically was
`b5ecb480052a760c2d5214455068605f45e22418a1b8cf2ea7d0ceba464949b9`,
single C unit with literal V `-prod`. Its sealed parsed-source buffers match
366 of 373 selected macOS implementation paths. Seven differ or are absent:
`html/event_loop.v`, `libjs/collection_intrinsics.v`, `libjs/json_parse.v`,
`libjs/json_stringify.v`, `libjsdom/host.v`, `libjsdom/idle_callbacks.v` and
`libjsdom/microtasks.v`. The raw all-platform selection additionally records two
expected absent Linux/Windows stack-info files; they are excluded from the
macOS counts. The newer bundle contains the Proxy source slice, but cannot
validate the latest species/JSON/scheduling changes. No fresh process was
launched. Each commit requested a managed coalesced rebuild through the normal
hook; no duplicate manual build was scheduled.

The last actual GitHub observation remains the historical native-cache pair
with 672 warm native entries, 51 frontend hits, zero compiler invocations,
33 rows, zero commit links and five cascading module errors. It predates all
these changes. Completed hydration, live behavior, a faster compiled revisit
and zero differing pixels against Brave remain unachieved and unmeasured for
the new source. The original strict content and pixel gates are unchanged.
