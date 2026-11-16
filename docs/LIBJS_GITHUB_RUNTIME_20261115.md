# GitHub compiled-JavaScript continuation, 2026-11-15

**Automated test suites remain held at the user's request.** Browser and native
initialization diagnostics resumed on November 16; see the
[runtime continuation](#browser-diagnostics-resumed-2026-11-16). Historical
source-only checkpoints below retain their original verification boundaries.
No completed hydration, speedup or pixel acceptance is claimed.

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

## Native Intl locale, date and list continuation

**The compiled-JS GitHub/Brave task remains incomplete.** The user's runtime-test
hold remains in force. No new JavaScript execution, page-initialization probe,
focused/broad test, AST-corpus run, browser launch, capture, pixel comparison or
performance trial was launched for this continuation. All new test functions,
including their own `_test.v` compilation, remain unexecuted. The shared managed
production worker runs independently; its receipts are not substitute page or
runtime verification for this task.

The implementation commits are:

- `86d0e3506`: pinned Unicode CLDR JSON data and native Unicode locale grammar,
  canonical alias rules, extension ordering and lazy per-realm locale data.
- `2ffaea8d0`: native `Intl.getCanonicalLocales` and `Intl.Locale`, including
  checked list access, coercion/error ordering, option getters, native slots,
  likely-subtag maximize/minimize and History clone rejection.
- `8866109e1`: native Gregorian/ISO `Intl.DateTimeFormat`, construction and option
  ordering, styles/fields, numbering digits, hour cycles, fractional seconds,
  TZif time zones, localized zone names, bound `format`, `formatToParts`,
  `resolvedOptions` and `supportedLocalesOf`.
- `c913a7b04`: native `Intl.ListFormat`, resolved/supported locales, CLDR
  conjunction/disjunction/unit patterns and styles, checked iterable strings,
  abrupt iterator completion, UTF-16 output and iterative string/part emission.
  It includes the UTS #35 Spanish/Hebrew contextual list conditions.
- `e3eeefaf4`: preserve single-hour, dot-separated and separator-free CLDR GMT
  patterns; retain directional marks and seconds. A system zone without an IANA
  name reports and uses a consistent fixed offset.

This replaces the missing namespace and several source-visible Intl classes
with real VM implementations. It does not install NumberFormat, RelativeTimeFormat
or a host/JSC formatter substitute. Calendar support is currently Gregorian and
ISO only; unsupported valid calendar/numbering-system requests negotiate to
supported data. Date range methods, other Intl classes, additional Locale
metadata APIs and ICU-equivalent matching remain open. Best-fit currently uses
the BasicFormatMatcher policy. The embedding default locale is `en-US` unless
`Realm.intl_default_locale` is changed. TZif data comes from the host/V loader;
future cohorts must pin locale, default time zone and actual rule-file identity.
See [native Intl scope and data design](LIBJS_INTL.md).

The data is generated from [Unicode CLDR JSON 48.2.0](https://github.com/unicode-org/cldr-json/tree/bb334e8d6250c9363e957e131bf7e6d08ec72f91),
commit `bb334e8d6250c9363e957e131bf7e6d08ec72f91`. The downloaded source archive is
86,340,353 bytes with SHA-256
`651c9700cf1ffb545299e50cedc968ae056b5f3913524b31009cbfa00c3bcd50`;
it remains in the local cache, not Git or Build. `libjs/intl_data/SOURCES` records
all consumed original file hashes and the Unicode license is retained. The final
core index is 329,709 bytes and locale records are 7,411,174 bytes. There are
766 data records and 1,121 locale identifiers including default-content aliases.
Parent deltas avoid embedding the full repeated locale trees; only requested
locale data is decoded. The generator performs no host locale queries, JS
execution or page-fixture substitutions.

Runtime implementation code stays in V, using `vunicode` properties and the V
TZif reader. The source-only `tools/check_unicode_dependency.py` scan passed.
No executable was supplied to that scanner, so this is not a binary/symbol
verification claim. The bound date-format function uses a traced FunctionObject
and native callee context. It does not capture the formatter in a V closure
whose trampoline registry would retain it after its JS lifetime. Locale and
formatter data are allocated outside temporary arenas. List partitioning uses
an explicit stack, preserving individual UTF-16 elements without native-stack
recursion. These are implementation properties, not executed ownership evidence.

Thirty-four regression functions were prepared: language/data ownership and
canonicalization cases, Locale option/brand cases, date patterns/parts/time-zone
cases, list/iterator/UTF-16 cases and three History clone regressions. They include
three second-VM cache-reuse cases with the compiler set to `/usr/bin/false`.
None of those cases ran. Their expected results must still be validated in both
GC modes and the relevant ownership/sanitizer and browser checks after the hold.

Compiler-only checks used the current V with `V3_STR_CAP=1`, `VJOBS=1`,
`-b c -no-parallel -cc clang -check -memory-limit 10G -enable-globals` against
the normal program `tools/libjs_github_revisit.v`. Production checks additionally
used `-prod -prealloc -gc none`. Every attempt used a separate default 12 GiB
sampled memory guard. These times and RSS are checker costs, not JS/browser
performance, and do not establish successful C linking or execution:

| Compiler-only attempt | Exit | Seconds | Sampled peak RSS bytes |
| --- | ---: | ---: | ---: |
| Locale data, first attempt | 1 | 16.746 | 3,120,021,504 |
| Locale data, corrected normal | 0 | 21.046 | 5,269,979,136 |
| Locale data, production/prealloc/no-GC | 0 | 20.496 | 5,467,062,272 |
| Locale API, normal | 0 | 24.286 | 5,268,291,584 |
| Locale API, production/prealloc/no-GC | 0 | 26.257 | 5,468,160,000 |
| DateTimeFormat, first attempt | 1 | 13.622 | 1,514,881,024 |
| DateTimeFormat, second attempt | 1 | 12.963 | 1,514,569,728 |
| DateTimeFormat, corrected normal | 0 | 23.835 | 5,266,833,408 |
| DateTimeFormat, production/prealloc/no-GC | 0 | 24.619 | 5,467,045,888 |
| DateTimeFormat, period/width correction | 0 | 25.803 | 5,465,735,168 |
| DateTimeFormat, traced bound-function ownership | 0 | 26.386 | 5,475,581,952 |
| ListFormat, normal | 0 | 15.176 | 5,268,979,712 |
| ListFormat, production/prealloc/no-GC | 0 | 15.538 | 5,453,348,864 |
| GMT patterns, production/prealloc/no-GC | 0 | 15.561 | 5,461,655,552 |
| GMT patterns and zone fallback, final production | 0 | 18.014 | 5,471,977,472 |

All fifteen attempts are retained. The first data check selected the removed
`json` module; it was corrected to `json2`. The first DateTimeFormat check found
reserved `char` variable names and a copied optional map; the second still found
the map copy, which was changed to an explicit clone. Corrected checks passed
before their feature commits. Twelve attempts pass and three fail; none is
silently discarded. Completed guard receipts were copied byte-for-byte into
local `docs/performance/libjs-intl-implementation-20261115/`, with commands and
receipt hashes, then only this continuation's completed Build reports/locks
were deleted. No broad suite or runtime pass is claimed.

The pinned original-response fixture still has 164 verified response entries
and 86 distinct JS bodies. Textual scans find eleven `Intl.DateTimeFormat`
references in five bodies, two `Intl.ListFormat` references in two and one
`Intl.Locale` reference in one. Three RelativeTimeFormat references in one body
and two NumberFormat references in two bodies remain. These are source matches,
not receiver, reachability or execution coverage. Module initialization contains
DateTimeFormat constructor calls, but there is no new execution result proving
which earlier or later blocker is now first.

At implementation revision `e3eeefaf489852612680147f8d99c3b4ad4d9be3`, the latest completed
production executable inspected statically is
`c19672aeee65b4f3124a25ee13490f450616c040cb1ce4106a0f08f1eb2a5e41`,
single C unit with literal V `-prod`. Its sealed consumed-input manifest matches
385 of 386 selected macOS implementation/data paths. The remaining
1 paths are:

- `libjs/intl_time_zone.v`

The raw audit also records the expected absent Linux/Windows stack-info files,
which are excluded from those macOS counts. Embedded CLDR assets are included
in the sealed-input comparison, not inferred from the receipt's HEAD. The bundle
cannot validate these latest changes, and no fresh process was launched. Each
commit requested its normal coalesced managed production rebuild; no duplicate
manual build or wait for a newer bundle was introduced.

The fixture manifest, original HTML, source map, Brave reference PNG and Brave
content-audit hashes are unchanged. The last actually executed GitHub result is
still the historical 672-entry warm native pair with 51 frontend hits, zero
compiler calls, 33 rows, zero commit links and five cascading module errors.
No new hydration count, warm-revisit speedup, live behavior or zero-pixel
GitHub/Brave match is established. Strict content and pixel acceptance gates
remain unchanged.

## Native number, relative-time and locale-case continuation

**The compiled-JS GitHub/Brave task remains incomplete.** The user's test hold
remains in force. This continuation did not execute JavaScript, initialization
probes, tests, AST fixtures, browsers, screenshots or performance trials. New
`_test.v` files were neither compiled nor run. Compiler-only checks of the
normal `tools/libjs_github_revisit.v` import graph are not runtime evidence.

Implementation commits:

- `1486157d9`: native `Intl.NumberFormat`, exact decimal mathematical values and
  rounding, CLDR number data, parts, bound format, resolved/supported locales,
  Number.toLocaleString and History rejection of NumberFormat state.
- `f0bff63a5`: native `Intl.RelativeTimeFormat`, numeric-auto literals, styles,
  plural-sensitive past/future patterns, signed zero, parts with singular units,
  retained NumberFormat intrinsic and History rejection.
- `67a72a49e`: String.toLocaleLowerCase/toLocaleUpperCase using canonical locale
  lists and the existing native Unicode contextual mappings. Only the first
  requested language is used after validating the entire list; receiver
  coercion precedes locale-list effects, including for unchanged ASCII text.

The pinned CLDR generator now consumes number symbols/patterns, compact forms,
currencies and fraction digits, sanctioned units, relative date fields and
cardinal/ordinal rules. Generated parent-delta records cover the same 1,121
locale identifiers: 21,477,685 locale bytes and 347,131 core bytes. Tables remain
lazy, per-realm, generated source assets with consumed-file hashes and Unicode
license. No direct ICU, host formatter, JSC or V8 bridge was added. A source-only
Unicode-dependency scan succeeds; no library/symbol audit was run.

Number inputs follow the current
[ToIntlMathematicalValue algorithm](https://tc39.es/ecma402/#sec-tointlmathematicalvalue),
starting from their shortest decimal spelling. BigInts and finite decimal
Strings retain their digits. Native decimal arithmetic implements the nine
rounding modes, fraction/significant priorities, sanctioned increments and
trailing-zero display. Plural modulo/comparison does not narrow large integer
digits to binary64, and visible fraction zeroes remain plural operands. Bound
number-format functions use traced records and their own callee contexts rather
than escaping formatter-capturing V closures. Number.toLocaleString retains the
intrinsic constructor even if the author replaces Intl.NumberFormat.

Twenty-seven new regression functions are prepared but uncompiled/unexecuted:
three decimal/plural cases, ten NumberFormat cases, seven relative-time cases,
five locale-case cases and two History cases. They include original GitHub
compact options, localized grouping/digits, exact large values, rounding/signs,
parts, abrupt coercion ordering, arena retention and compiler-disabled native
cache revisits. These are pending assertions, not measured cache hits or passes.

Eleven memory-guarded compiler-only attempts are retained byte-identically under
local `docs/performance/libjs-intl-number-20261115/`, with raw logs and a hashed
receipt index. Eight completed successfully and three failed before correction:
the decimal/plural syntax attempt used an invalid tuple expression, the digit
options attempt used nonexistent unqualified min/max functions, and the first
NumberFormat attempt omitted explicit clones when unwrapping nested maps. Each
was corrected before the implementing feature commit. Selected receipts:

| Compiler-only check | Child exit | Seconds | Peak sampled RSS bytes |
| --- | ---: | ---: | ---: |
| Decimal/plural corrected normal | 0 | 15.031 | 5,282,201,600 |
| Digit options corrected normal | 0 | 15.123 | 5,259,788,288 |
| NumberFormat corrected normal | 0 | 17.263 | 5,284,544,512 |
| NumberFormat production/prealloc/no-GC | 0 | 17.934 | 5,545,050,112 |
| RelativeTimeFormat normal | 0 | 17.789 | 5,279,449,088 |
| RelativeTimeFormat production/prealloc/no-GC | 0 | 18.139 | 5,543,329,792 |
| Locale case production/prealloc/no-GC | 0 | 17.536 | 5,551,800,320 |
| Locale case final normal | 0 | 17.580 | 5,269,667,840 |

The common check uses `V3_STR_CAP=1 VJOBS=1`, the 12-GiB sampled process-tree
guard, current V, `-w -n -b c -no-parallel -cc clang -check -memory-limit 10G
-enable-globals tools/libjs_github_revisit.v`. Production checks also pass
`-prod -prealloc -gc none`. All guards report `reason=completed`; the table
records the actual child exit. No C compilation/link or JS evaluation is implied.
Completed job locks/reports were removed from Build after preserving evidence.

The static scan of the original archived JS still finds five Intl constructor
names: DateTimeFormat (11 references in five bodies), ListFormat (two/two),
NumberFormat (two/two), RelativeTimeFormat (three/one) and Locale (one/one).
Each now has a native binding. Source matches are not reachability or execution
coverage. The source's compact-count call requests en-US, compact notation,
maximumFractionDigits=1 and maximumSignificantDigits=2. Relative-time code calls
the native formatter directly and uppercases a date label's first character.

The same scan exposes a separate unfinished API: six `localeCompare` calls in
four bodies (primer-react, app-runtime, gl and ekd). Native collation and
String.localeCompare remain missing; a lexical stub was not installed. Public
PluralRules, number/date ranges, complex compound-unit/currency-spacing details,
legacy chained NumberFormat construction, other Intl APIs, async generators,
top-level await and remaining Web behavior are still open. See
[the Intl implementation scope](LIBJS_INTL.md) for limits. No new execution
establishes which missing behavior is now the first GitHub failure.

At implementation revision `67a72a49e9f83ad9948bbfc07ffcf382f82e65c5`, the latest
completed production executable inspected statically is
`a29214bc09337794f4f8e15f94a51670fe39281e43c304228e7ee376f46f0bf2`, single C unit
with literal V `-prod`. Its receipt is
`Build/production-build/receipts/20261115-204745-385a0d38/frozen-compile.json`.
The actual executable hash matches that receipt. Its sealed consumed-input
manifest matches nine of 28 selected Intl assets/implementation/adaptor files;
the 19 differing or missing paths include the new formatter/case files, updated
CLDR assets, object/realm bindings, Number adapters and History projection.
The exact selected paths/hashes are in local `production-source-verification.json`.
The older bundle cannot exercise or validate this new code, and no process was
launched. Commits requested coalesced rebuilds through the managed hook; the
pending request records `67a72a49e`, and no duplicate manual build was queued.

The original fixture manifest and Brave PNG were rehashed unchanged:
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`
and `649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
The last executed GitHub observation remains the historical 672 warm native
entries, 51 frontend hits, zero compiler calls, 33 rows, zero commit links and
five module errors, predating these changes. The strict gates remain 33 rows,
56 commit links, the current README, active controls, no errors, the unchanged
Brave content audit and zero differing pixels. Compiled revisit speed and
GitHub/Brave pixel parity remain unmeasured and unachieved for the new source.

## Native collation and URL continuation

**The compiled-JS GitHub/Brave task remains incomplete.** The user's runtime-test
hold remains in force. This continuation did not launch tests, JavaScript
evaluation, initialization probes, AST corpora, browsers, screenshots, pixel
comparisons or performance trials. New and corrected `_test.v` files remain
uncompiled as well as unexecuted. The managed production worker runs
independently; its build activity does not substitute for this task's pending
runtime and page acceptance.

Implementation commits:

- `27c3c4f6a`: native CLDR-root collation engine and pinned generated data,
  canonical normalization, contractions/expansions, implicit weights, exact
  numeric runs, shifted punctuation and sensitivity/case settings.
- `6e7636eed`: native Intl.Collator, traced bound compare functions, checked
  construction/options/locales, resolved/supported locales, retained
  String.localeCompare/default cache and History rejection.
- `417654f27`: native URL.canParse/parse, prototype component accessors/setters,
  string/JSON serialization, lazy live searchParams, subclass prototypes, USV
  conversion/argument ordering and owned wrapper maps cleared at Host.close.
  Location exposes live component reads; navigation setters remain pending.
- `9e3309e1b`: correct JavaScript lone-surrogate escapes in two older pending
  Intl cases and add native/bound locale-comparison surrogate coverage. This
  source correction was not a test compilation or execution pass.

Collation is implemented in V using
[CLDR release-48](https://github.com/unicode-org/cldr/tree/acd6d88ae493633240e19a87a721076a8a75c310),
commit `acd6d88ae493633240e19a87a721076a8a75c310`, and official Unicode 17 UCD
inputs. The generator checks six fixed input hashes and preserves the Unicode
license/provenance. The data contains 39,761 mappings, 39,762 trie nodes, 45,860
collation elements, 770 decimal digits and eight implicit ranges. The root asset
is 1,529,016 bytes, decimal digits 6,160 bytes and implicit ranges 128 bytes.
Immutable little-endian lookup tables do not require decoding an entire JSON
map in each VM. No ICU, system formatter/collator, JSC or V8 bridge was added.
The source-only Unicode dependency scan passes; no linked-binary audit ran.

The engine follows
[UCA 17 normalization/matching/weight comparison](https://www.unicode.org/reports/tr10/tr10-53.html)
and the
[CLDR case parameters](https://www.unicode.org/reports/tr35/tr35-77/tr35-collation.html#Case_Parameters).
Normalization charges for canonical reordering and contraction work against the
VM budget. Numeric runs use significant decimal digits and lengths, preserving
large values and cross-script equality without binary64 conversion. Shifted
punctuation also skips following primary-ignorable elements. Bound functions
retain ordinary traced collator/realm edges and establish their callee contexts.
String.localeCompare converts both arguments before locale/options effects;
explicit options are processed even for identical strings. Only the no-options
path caches a collator, keyed by the embedding's current default locale.

This is a partial collation implementation. The available set is en, en-US and
en-GB, whose standard order inherits the CLDR root. English regional requests
can negotiate to en; other languages fall back to an implemented default.
Supported-locales queries use this actual smaller set. Other language/alternate
tailorings, search-specific tailorings, Han radical/stroke ordering and a full
collation corpus remain open. Search usage currently uses root comparison and
variant sensitivity. No full Intl, ICU or Brave collation equality is claimed.

The URL bindings use the existing native DOMURL/LibURL parser, including failure
for an invalid base even with an absolute input. Required arguments and USV
conversion precede parser execution. Construction reads NewTarget.prototype
after argument conversion and before parser failure. Native component getters
and setters validate the receiver before author conversion. SearchParams is a
lazy SameObject projection of the retained native URL; href/search replacements
update its live list. URL wrappers use shared prototype callbacks and
host-scoped native/wrapper maps, rather than per-instance callback captures.
The maps are released at Host.close. Cross-realm fallback details, Location
navigation setters, Blob constructors and object-URL APIs remain pending; no
full URL/WebIDL conformance claim is made.

Twenty-eight new regression functions are prepared: six collation-engine cases,
eleven Collator/String cases, nine URL cases and two History cases. They cover
GitHub-style name/entry sorting, numeric precision, Unicode levels and
contractions, USV conversion, coercion/prototype ordering, lazy query identity,
fixed callback counts, arena retention, native-work budgets, brand checks and
compiler-disabled revisits. Every new assertion remains pending under the hold.

Eight compiler-only attempts and raw logs are preserved byte-identically in
local `docs/performance/libjs-collation-20261115/`, with a hashed receipt index.
Seven succeeded; the first production binding attempt rejected a Value-map read
without an explicit missing-key branch. That access was corrected before the
binding commit, and both compiler modes then passed:

| Compiler-only check | Child exit | Seconds | Peak sampled RSS bytes |
| --- | ---: | ---: | ---: |
| Root collation normal | 0 | 15.250 | 5,278,138,368 |
| Root collation production/prealloc/no-GC | 0 | 15.234 | 5,559,484,416 |
| Collator bindings initial normal | 0 | 18.449 | 5,269,356,544 |
| Collator bindings first production | 1 | 10.388 | 1,796,505,600 |
| Collator bindings corrected production | 0 | 22.928 | 5,556,256,768 |
| Collator bindings final normal | 0 | 24.739 | 5,281,710,080 |
| URL bindings normal | 0 | 16.270 | 5,263,949,824 |
| URL bindings production/prealloc/no-GC | 0 | 18.250 | 5,559,517,184 |

Each guarded check uses `V3_STR_CAP=1 VJOBS=1`, current V,
`-w -n -b c -no-parallel -cc clang -check -memory-limit 10G -enable-globals
tools/libjs_github_revisit.v`; production mode adds `-prod -prealloc -gc none`.
All guards report `reason=completed` with the actual child exits above. These
normal-program import checks exclude `_test.v`, C compilation/linking and
JavaScript execution. Completed per-job Build reports/locks were removed after
preserving their evidence. Compiler times are not JavaScript performance data.

The static original-source audit still finds six localeCompare call matches in
four bodies; that missing native binding is now implemented. URL.canParse has
four direct call matches in one original dp schema-validation body, now bound
to the native parser. A wider source scan finds 24 Uint8Array call matches in
five bodies, three Float64Array matches in two and 18 BigInt matches in two.
The production typed-array and BigInt constructor graphs are still pending,
despite retained translated records/helpers. These are source-level gaps, not
runtime reachability counts or a measured first initialization failure. Remaining
Intl/Web APIs, async generators, top-level await and full page behavior are
also open.

At implementation revision `9e3309e1b3031d5471463d252d48233249e32ba2`, the latest
completed production executable inspected statically is still
`a29214bc09337794f4f8e15f94a51670fe39281e43c304228e7ee376f46f0bf2`, single C unit
with literal V `-prod`. Its actual executable hash matches the receipt at
`Build/production-build/receipts/20261115-204745-385a0d38/frozen-compile.json`.
The sealed consumed-input manifest matches zero of the 18 selected changed
implementation/data/provenance paths. The raw audit retains every selected
committed/sealed hash. The available bundle cannot exercise this new code; no
fresh process was launched. Each commit requested the managed coalesced rebuild,
and no duplicate manual build or long wait for publication was introduced.

The original fixture manifest remains
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`.
Brave references, tolerance and strict content gates were not changed. The last
actually executed GitHub observation remains the historical 672 warm native
entries, 51 frontend hits, zero compiler calls, 33 rows, zero commit links and
five module errors, before these implementation slices. Acceptance still needs
33 rows, 56 commit links, the current README, active controls, no errors, the
unchanged Brave content audit and zero differing pixels, followed by matched
performance evidence. New GitHub hydration, native-cache speed and Brave pixel
parity remain unmeasured and unachieved.

## Native BigInt, typed-array and text-encoding continuation

This continuation keeps the user's test hold in force. No regression source
was compiled or run, no JavaScript was evaluated and no browser process,
capture, comparison or performance trial was launched for this work. The
shared automatic production worker operates independently; its activity is
not validation of these changes.

Four focused implementation commits are complete:

| Commit | Implemented native surface |
| --- | --- |
| `4a0e92b45` | Install BigInt's global, ordinary prototype, primitive boxing and methods. Locale formatting uses the retained native NumberFormat and propagates errors. BigInt cells copy arbitrary-precision magnitude storage before it can escape a temporary arena. |
| `399153a3f` | Install all twelve concrete typed-array constructors and their abstract constructor/prototype ancestry, accessors, species, iterators, copying and Uint8Array encoding methods. Creator realm and element kind are traced constructor fields. Native storage records persist, temporary synchronous factories/comparators are released, lengths are checked before narrowing, and native loops/copies/dense key enumeration charge VM limits. |
| `c85bcb788` | Bind TextEncoder/TextDecoder to the existing native encoding records. Encoding produces actual intrinsic Uint8Arrays and encodeInto respects destination offsets and complete scalar boundaries. Decoder input copies follow option getters; streaming/BOM/fatal state is retained in the native decoder. Fixed-length WebIDL checks, shared byte access, brand checks and host teardown are explicit. |
| `747f63540` | Expose atob/btoa through the existing HTML binary-string codecs, sharing the pure codec without creating a Window. Preserve DOMString coercion, required arguments, Window receivers, all Latin-1 byte values, forgiving base64 validation and InvalidCharacterError DOM exceptions. |

The original cached GitHub response bodies contain 15 TextEncoder textual
references in twelve distinct bodies and four TextDecoder references in three.
The dp bundle has a top-level TextEncoder construction; its hashing helpers
also use Uint8Array and BigInt. The same frozen bodies contain six atob
references in four bodies and four btoa references in four. This is a static
source audit, not runtime reachability or a measured first initialization
failure. The raw scan retains original response-body hashes and contexts in
local `docs/performance/libjs-binary-intrinsics-20261115/`.

Forty-two regression functions are prepared: six BigInt, fifteen typed-array,
one History typed-array rejection, twelve text-encoding and eight binary-string
codec cases. Coverage includes metadata/brands, coercion and getter ordering,
foreign NewTarget fallback, integer and BigInt storage, resizable native
typed-array witnesses, WebIDL fixed-length restrictions, live buffer aliases,
shared windows, native-work budgets, temporary-arena ownership, decoder
streaming/reset, invalid UTF-16 replacement, DOM exceptions, fixed callback
counts, host close and second-VM revisits with `/usr/bin/false` as compiler.
Every assertion remains pending; the proposed cache-hit assertions are not
observed cache hits.

Fourteen compiler-only attempts and logs are preserved byte-identically with
a hashed index. Twelve succeeded. The first typed-array production attempt
needed three explicit unsigned-width casts; the first text-encoding check
referred to a nonexistent property-attribute constant. Both errors were fixed
before their implementation commits; all failures remain in the evidence.

| Compiler-only check | Child exit | Seconds | Peak sampled RSS bytes |
| --- | ---: | ---: | ---: |
| BigInt initial normal | 0 | 14.427 | 5,275,238,400 |
| BigInt production/prealloc/no-GC | 0 | 16.740 | 5,553,438,720 |
| BigInt final normal | 0 | 15.485 | 5,264,228,352 |
| Typed-array initial normal | 0 | 18.528 | 5,286,641,664 |
| Typed-array first production | 1 | 10.200 | 1,797,521,408 |
| Typed-array corrected production | 0 | 17.115 | 5,562,466,304 |
| Typed-array native limits normal | 0 | 17.733 | 5,277,941,760 |
| Typed-array final production | 0 | 27.146 | 5,566,824,448 |
| Text-encoding initial normal | 1 | 15.712 | 1,521,025,024 |
| Text-encoding corrected normal | 0 | 19.122 | 5,285,494,784 |
| Text-encoding initial production | 0 | 17.987 | 5,567,021,056 |
| Text-encoding final production | 0 | 19.976 | 5,567,381,504 |
| Binary-string codecs final normal | 0 | 28.200 | 5,282,430,976 |
| Binary-string codecs final production | 0 | 25.524 | 5,570,330,624 |

The command shape is `env V3_STR_CAP=1 VJOBS=1 sh tools/run_v_tool.sh
run_memory_bounded --lock Build/UNIQUE.lock --report Build/UNIQUE.json --
/Users/alex/code/v/v -w -n -b c -no-parallel -cc clang -check
-memory-limit 10G -enable-globals tools/libjs_github_revisit.v`, with
`-prod -prealloc -gc none` for production checks. Each guard used its default
12 GiB process-tree RSS limit and reports `reason=completed` with the child
exit above. These are normal-program checks excluding `_test.v`, native
linking and execution. The final codec checks include the committed encoding
restrictions. Compiler durations are not JS speed measurements. Completed
per-job Build locks/reports were removed after evidence preservation.

At implementation revision `747f635401b6b591141a2e9f34e0225fe632e341`, the latest
completed production executable inspected statically has SHA-256
`48b7a9440fd5c1ae8b1b57080e347fe365adb604348327438438bf33c4577854`.
Its actual hash matches
`Build/production-build/receipts/20261115-220911-056313d0/frozen-compile.json`;
the receipt uses one C unit and literal V `-prod`. The sealed consumed-input
manifest matches zero of the 41 selected current implementation paths.
Executable/latest identities stayed unchanged throughout this audit. The
available bundle cannot exercise the new code. All four commits requested the
managed coalesced production rebuild; no duplicate manual build was queued
and no fresh browser was launched.

The typed-array algorithms retain the translated buffer representation's
32-bit bounds and existing maximum-byte policy. This is not complete agent,
GC or SharedArrayBuffer parity. The encoder/decoder bridge reuses the existing
codec coverage and does not establish complete legacy-encoding or foreign-realm
WebIDL conformance. Remaining native encoding helper work is not universally
budgeted. Blob construction/object URLs, Fetch AbortSignal/body-stream bindings,
additional Web/Intl behavior, async generators and top-level await remain open.

The original fixture manifest is still
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`,
and the unchanged Brave PNG is
`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
The last executed GitHub observation is still the historical 672 warm native
entries, 51 frontend hits, zero compiler calls, 33 rows, zero commit links and
five module errors, predating these slices. Acceptance still requires 33 rows,
56 commit links, current README, active controls, zero errors, the unchanged
Brave content audit and zero differing pixels, followed by matched performance
evidence. Full GitHub execution, faster compiled revisits and Brave pixel parity
remain unverified and unachieved.

## Native Blob, object-URL and Fetch continuation

The user's test hold remains active: no test source was compiled or run,
no JavaScript was evaluated, and no browser process, capture, comparison or
performance cohort was launched. The following four implementation slices
were committed separately:

| Commit | Implemented behavior |
| --- | --- |
| `112982c70` | Bind native Blob construction, sequence/union conversion, USV strings, line endings, type normalization, view windows, clamped slicing and metadata. Byte copies follow later option/prototype getters. text()/arrayBuffer()/bytes() queue owned FileReading tasks and return actual native Promise/buffer results; host close discards pending tasks and roots. |
| `2b0cf1295` | Bind URL.createObjectURL/revokeObjectURL to the existing native store with actual document settings and partition checks. Entries retain native Blob bytes independently of VM wrappers and are removed by native document unloading or revocation. |
| `f584a58f7` | Bind Blob, DataView and URLSearchParams Fetch bodies. Preserve conversion order and defer native snapshots until after dictionary and NewTarget prototype getters. Request/Response bytes() and blob() return intrinsic Uint8Array/Blob results with MIME type and body-use rules. |
| `25487fa1a` | Bind Request.signal and Fetch AbortSignal input, including explicit-null signal independence. Pre-aborted requests reject before transport; active aborts stop the native controller and preserve arbitrary author reasons. Unread response bodies retain their signal association after network delivery. Completion/close removes hooks, retired abort trampolines wait for native return, and synchronous Fetch settlement captures are released. |

The frozen original scripts contain five direct new-Blob matches in three
distinct bodies, four URL.createObjectURL call matches in three, and five
URL.revokeObjectURL matches in two. There are 64 AbortController textual
references across twelve bodies and four AbortSignal references across two.
Two .blob() call matches occur in two bodies; three .bytes() matches occur in
two, without attributing those method names to a particular receiver. This
static audit retains body hashes and contexts in local
`docs/performance/libjs-blob-bindings-20261115/static-source-scan.json`.
These counts do not establish runtime reachability or a first failure.

Thirty-six focused regression functions are prepared: twelve Blob, six object
URL, nine Fetch binary, eight Fetch signal and one typed Request-null-signal
case. They cover native storage and MIME values, UTF-16 replacement, getter/
iterator ordering and closing, buffer/prototype mutation, detached/shared/
resizable restrictions, clamped slices, Promise task timing, intrinsic results,
VM/arena/document lifetime, original object/symbol/BigInt abort reasons,
post-delivery unread bodies, signal cleanup and second-VM revisits with the
compiler disabled. Every assertion remains uncompiled and unexecuted.

All ten compiler-only attempts completed with child exit zero. Raw logs and
reports were preserved byte-identically with a hashed index before removing
their completed per-job Build reports and locks:

| Compiler-only check | Child exit | Seconds | Peak sampled RSS bytes |
| --- | ---: | ---: | ---: |
| Blob normal | 0 | 27.892 | 5,291,229,184 |
| Blob production/prealloc/no-GC | 0 | 26.119 | 5,571,624,960 |
| Object URLs normal | 0 | 27.971 | 5,285,822,464 |
| Object URLs production/prealloc/no-GC | 0 | 33.723 | 5,566,251,008 |
| Fetch binary normal | 0 | 30.414 | 5,296,046,080 |
| Fetch binary production/prealloc/no-GC | 0 | 27.483 | 5,566,251,008 |
| Fetch signal initial normal | 0 | 21.601 | 5,286,674,432 |
| Fetch signal initial production | 0 | 26.149 | 5,567,594,496 |
| Fetch signal final normal | 0 | 25.705 | 5,285,756,928 |
| Fetch signal final production | 0 | 26.140 | 5,565,857,792 |

The command is the normal-program import check `/Users/alex/code/v/v -w -n
-b c -no-parallel -cc clang -check -memory-limit 10G -enable-globals
tools/libjs_github_revisit.v`, using `V3_STR_CAP=1 VJOBS=1` and a unique
`run_memory_bounded` lock/report with its default 12 GiB process-tree budget.
Production adds `-prod -prealloc -gc none`. Final checks include the controller
assignment/reentry cancellation guard and all preceding implementation slices.
They exclude `_test.v`, C linking and execution; compiler durations are not
JavaScript performance measurements.

At implementation revision `25487fa1ad1098085f0aaba60b92e33e51da6f72`, the latest
completed production executable inspected statically is still
`48b7a9440fd5c1ae8b1b57080e347fe365adb604348327438438bf33c4577854`.
The actual executable hash matches
`Build/production-build/receipts/20261115-220911-056313d0/frozen-compile.json`,
using one C unit and literal V `-prod`. None of eleven selected current
implementation files matches its sealed consumed-source manifest. Both the
latest receipt and executable identities stayed unchanged during the audit.
This bundle cannot validate the new code. Each commit requested the managed
coalesced production rebuild; no duplicate manual build or fresh launch was
introduced.

This is partial FileAPI/Fetch/WebIDL integration. Blob.stream and Fetch body
stream bindings, FormData, native LibJS File/FileReader, foreign-realm WebIDL
fallback, Blob History serialization and complete native callback/GC ownership
remain open. The existing 32-bit native byte-vector bound is retained. Additional
JS/Web/Intl behavior, async generators, top-level await and full page rendering
also remain open; the prepared cache cases supply no measured reuse evidence.

The original fixture manifest remains
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`;
the unchanged Brave PNG remains
`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
The last executed GitHub observation is still the historical 672 warm native
entries, 51 frontend hits, zero compiler calls, 33 rows, zero commit links and
five module errors, before these slices. Acceptance still requires 33 rows,
56 commit links, current README, active controls, no errors, the unchanged
Brave content audit and zero differing pixels, then matched performance
evidence. Full GitHub execution, faster compiled revisits and pixel-perfect
Brave rendering remain unverified and unachieved.

## Native default readers and Blob Fetch stream continuation

This continuation spans 2026-11-15/16 and retains the user's test hold. No
regression source was compiled or run, no JavaScript was evaluated, and no
browser launch, capture, comparison or performance trial was performed.

| Commit | Implemented behavior |
| --- | --- |
| `0ee818076` | Add traced, detachable WebIDL native Promise settlement observers. Existing callback reactions keep their behavior; native VM mirrors no longer require escaping V observer closures. |
| `2b11fe072` | Bridge native readable streams and default readers with stable wrapper/closed-Promise identity, locked/cancel/tee operations, typed release/lock errors and pending native ReadRequest records. Chunk results use real Uint8Arrays. Capability settlement enters the bounded VM without flushing JS reactions partway through a native enqueue/close task. Close detaches observers and releases pending reader roots. |
| `07da5df1d` | Expose Blob.stream through the actual HTML byte stream and FileReading task. Delivery tasks own their callback captures and can be discarded at VM teardown. Request/Response.body getters expose native streams; readable-stream body inputs preserve late lock/disturbed checks. Teardown errors retained streams and clears wrapper roots. |

The frozen original repository script contains one .getReader() call in one
body: the repository polling path streams an error response through the native
TextDecoder. There are no textual ReadableStream identifiers, .stream() calls or
for-await loops in these frozen bodies. This scan only describes source text;
it does not prove that a path ran or identify the next runtime failure. The
body hash and first match context remain local in
`docs/performance/libjs-stream-bindings-20261116/static-source-scan.json`.

Twenty-four regression functions are prepared: five native Promise observer,
nine native reader and ten Blob/Fetch stream cases. They cover registration/
removal/adoption, real Promise and wrapper identity, delayed JS reaction jobs,
lock/release/reacquisition, cancellation, original abort values, native byte
results, file-reading delivery, empty streams, body-use rules, clone/tee state,
late body locking, arena/task teardown and compiler-disabled second-VM cache
revisits. None is compiled or executed; cache-hit assertions are pending source.

Eight compiler-only attempts and raw logs are preserved byte-identically with
a hashed index. Both initial observer attempts rejected an immutable local
array used for mutable interface dispatch. It was corrected before the
observer commit. The remaining six checks passed:

| Compiler-only check | Child exit | Seconds | Peak sampled RSS bytes |
| --- | ---: | ---: | ---: |
| Native observers initial normal | 1 | 12.043 | 1,521,876,992 |
| Native observers initial production | 1 | 9.050 | 1,798,520,832 |
| Native observers corrected normal | 0 | 16.319 | 5,284,085,760 |
| Native observers corrected production | 0 | 18.657 | 5,567,414,272 |
| Reader bridge normal | 0 | 27.112 | 5,367,545,856 |
| Reader bridge production/prealloc/no-GC | 0 | 23.585 | 5,639,782,400 |
| Blob/Fetch streams normal | 0 | 22.289 | 5,358,272,512 |
| Blob/Fetch streams production/prealloc/no-GC | 0 | 24.385 | 5,636,161,536 |

Each check uses `V3_STR_CAP=1 VJOBS=1`, current V and the normal import
program `tools/libjs_github_revisit.v` with `-w -n -b c -no-parallel
-cc clang -check -memory-limit 10G -enable-globals`. Production adds
`-prod -prealloc -gc none`. Every attempt has its own memory-guard lock/
report, uses the default 12 GiB process-tree RSS budget, and reports
`reason=completed` with the child exit above. These checks exclude `_test.v`,
C compilation/linking and runtime execution. Compiler durations are not JS
timings. Completed per-job Build artifacts were removed after preserving the
evidence in local `docs/performance/libjs-stream-bindings-20261116/`.

At implementation revision `07da5df1dd8b5ba8bab69a2fc3be3bc60f671d46`, the
latest completed production executable inspected statically has SHA-256
`523e30ddb154f3a25f336661a213bc912b3eaddd409226ab886f19f440cff6f7`.
Its actual hash matches the receipt at
`Build/production-build/receipts/20261115-234808-804cb6d9/frozen-compile.json`.
The build uses one C unit and literal V `-prod`. The sealed consumed-source
manifest matches none of thirteen selected changed implementation files.
Executable and latest-receipt identity stayed unchanged throughout the audit.
The available bundle cannot validate this new code. All three commits requested
the managed coalesced rebuild; no extra manual build or fresh process was
introduced.

This completes the default-reader bridge for native Blob/Fetch producers,
not complete Streams/WebIDL parity. Public ReadableStream construction and
source/controller callbacks, BYOB readers, pipe methods, async iteration,
WritableStream/TransformStream, foreign-realm behavior, native ownership/
collection, FormData and other JS/Web/Intl/rendering work remain open. The
bridge rejects unbound BYOB mode explicitly. It adds no JSC execution route;
selected-path execution and absence of fallback still need an allowed runtime
diagnostic.

The original fixture manifest remains
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`
and the unchanged Brave PNG remains
`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
The last executed GitHub observation is still historical: 672 warm native
entries, 51 frontend hits, zero compiler calls, 33 rows, zero commit links and
five module errors, before these implementation slices. Acceptance still
requires 33 rows, 56 commit links, current README, active controls, zero errors,
the unchanged Brave content audit and zero differing pixels, followed by
matched performance evidence. GitHub hydration, faster compiled revisits and
pixel-perfect Brave rendering remain unverified and unachieved.

## Native readable source and controller continuation

The 2026-11-16 continuation preserves the user's hold: no tests were compiled
or executed, no JS was evaluated, and no browser, screenshot, comparison or
performance trial was launched. The compiled-JS GitHub/Brave objective remains
incomplete.

| Commit | Implemented behavior |
| --- | --- |
| `876589c37` | Expose internal PerformPromiseThen observation without a result capability or additional public then/constructor/species lookup. Ordinary public Promise behavior retains its existing lookups. |
| `7b34dedd9` | Add traced native readable-source and size-algorithm records. Start/pull/cancel receive the actual controller/reason; readable, writable and transform strategies retain the size record and clear it with their algorithms. |
| `3eb8bef4a` | Bind public ReadableStream construction, default/byte controller wrappers, source callback this/argument values, native desired size/queue/close/error operations, author Promise results and the owning VM's FIFO Promise queue. Extend native Fetch byte aggregation to actual authored Uint8Array chunks. |

Constructor conversion retains strategy-member ordering before the new-target
prototype getter, followed by native underlying-source dictionary conversion.
Start executes synchronously; its completion enables later pulls. Start's
thrown author value remains synchronous, while pull/cancel failures become
native rejected Promises carrying the same value. An escaped controller is
errored before a failed constructor detaches its source record.

Upstream WebIDL/Promise.cpp creates a fresh intrinsic capability and resolves
it with a callback result. The bridge therefore retains Get(result, "then"),
including a replaced or throwing getter on an intrinsic Promise; it does not
apply PromiseResolve's same-constructor shortcut. Only later internal
observation avoids another public lookup. Pending settlement uses traced
callable records. A JS settlement reaction executes its immediate native
reaction in that turn; subsequent native jobs enter the normal VM/HTML FIFO.
Temporary job captures are retained until safe release, and VM teardown
detaches pending source/adoption records and job roots. This is not a complete
native garbage-collection audit.

Default controllers preserve actual object, symbol, BigInt and other chunk/
error identities. Size callbacks use undefined this and ToNumber once. Byte
enqueue accepts actual fixed, non-shared ArrayBufferViews, copies the selected
window and detaches the original buffer before completing pending reads.
Native auto-allocation beyond the byte-vector bound rejects the affected read
before queuing it, preserving the readable stream; it does not reject the
constructor. Full BYOB request/view bindings, buffer-sharing metadata and
cross-realm semantics remain open.

Thirty-two regression functions are prepared: four LibJS internal-observation,
six native callback/allocation and 22 public-source/controller cases. They cover
FIFO/start gating, pending pull serialization, callback this/arguments, getter
ordering, thrown/rejected value identity, size coercion/errors, controller
brands, History rejection, byte transfer/view windows, read allocation failure,
native Fetch consumption, arena/teardown ownership and compiler-disabled
second-VM cache revisits. These are uncompiled, unexecuted source; the cache
assertions provide no measured reuse or performance evidence.

All ten compiler-only attempts and logs are preserved byte-identically in
local `docs/performance/libjs-stream-source-20261116/`, with a hashed index:

| Compiler-only check | Child exit | Seconds | Peak sampled RSS bytes |
| --- | ---: | ---: | ---: |
| Internal Promise observation normal | 0 | 19.466 | 5,355,241,472 |
| Internal Promise observation production | 0 | 20.463 | 5,646,548,992 |
| Native callback records normal | 0 | 19.677 | 5,356,191,744 |
| Native callback records production | 0 | 15.621 | 5,636,603,904 |
| Public bindings initial normal | 1 | 9.816 | 1,525,858,304 |
| Public bindings corrected normal | 0 | 17.386 | 5,362,384,896 |
| Public bindings callback-result record normal | 0 | 20.913 | 5,374,902,272 |
| Read-allocation bound initial normal | 1 | 13.868 | 1,526,087,680 |
| Public bindings final normal | 0 | 22.985 | 5,374,672,896 |
| Public bindings final production/prealloc/no-GC | 0 | 23.758 | 5,638,733,824 |

The first failure identified numeric Value conversion and an explicit optional
interface cast; the allocation-bound failure identified a missing WebIDL
import. Both were corrected before the bindings commit. Checks use
`V3_STR_CAP=1 VJOBS=1`, a unique default 12 GiB `run_memory_bounded` guard and
`/Users/alex/code/v/v -w -n -b c -no-parallel -cc clang -check
-memory-limit 10G -enable-globals tools/libjs_github_revisit.v`; production adds
`-prod -prealloc -gc none`. Every guard reports reason=completed and the child
exit above. These normal-program import checks exclude `_test.v`, C linking and
execution. Compiler durations do not measure JS performance. Completed own
Build reports and locks were deleted after evidence preservation.

At implementation revision `3eb8bef4a`, the latest completed production
executable inspected statically has SHA-256
`419ad8d777319bd5b8605799a59da05b59e20ae596bc3f50594babb87db2ba56`.
Its actual hash matches
`Build/production-build/receipts/20261116-002422-18914df3/frozen-compile.json`;
the C mode is single with literal V -prod. Its exact consumed-source manifest
matches none of 17 selected current implementation files. Receipt and executable
identities stayed unchanged during the audit. This older bundle cannot validate
the additions. The managed post-commit hook requested coalesced production
rebuilds; no duplicate manual build or fresh launch was introduced.

The original fixture manifest remains
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`,
and the Brave PNG remains
`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
The earlier frozen-source scan contains no textual ReadableStream identifier
or .stream() call. These constructor additions therefore supply no demonstrated
progress on a reachable GitHub path. No new run identifies the next first
failure. The last actual observation remains 672 warm native entries, 51
frontend hits, zero compiler calls, 33 rows, zero commit links and five module
errors, predating these changes. Acceptance remains 33 rows, 56 commit links,
current README, active controls, zero errors, the unchanged Brave content audit
and zero differing pixels, followed by matched performance evidence. BYOB,
pipe/async iteration, other stream classes, FormData and remaining
JS/Web/Intl/rendering behavior remain unfinished.

## Native File FormData and Fetch continuation

This 2026-11-16 continuation retains the user's hold. No tests were compiled
or executed, no JS was evaluated, and no browser, capture, comparison or
performance trial was launched. GitHub/Brave compiled-JS parity remains
incomplete.

| Commit | Implemented behavior |
| --- | --- |
| `9f2d64cfa` | Native File construction, File/Blob prototype and backing identity, name/lastModified, inherited Blob reads and owned wrappers. File parts are copied after later options/new-target conversions. |
| `50fe7541e` | Native FormData methods, Blob/File overload conversion, actual File entry identity, live iterators/forEach and form/submitter construction. FormDataEvent exposes the native mutable entry owner, so formdata handler mutations reach entry-list construction. History rejects FormData and its iterators. |
| `62dc0ffe0` | Native FormData Fetch bodies, late multipart serialization and Request/Response.formData. The native URL-encoded byte parser preserves leading '?'; multipart text fields are decoded separately, preserving uploaded file bytes. Result wrappers do not consult replaced public constructors. |
| `21807ad29` | Preserve mathematical signed WebIDL remainder without an unsigned-double round trip that loses small negative values such as File.lastModified=-1. EnforceRange/Clamp are unchanged; exact unsigned-64 representation is still limited by the f64 boundary. |

The unchanged original fixture has 87 JS URLs / 86 distinct JS bodies. A static
scan finds 63 textual FormData identifiers in 11 bodies, including repository,
core, React, codespaces and code-view scripts. Source hashes, first-match
contexts and counts remain local in `static-source-scan.json`. These are
source references, not execution coverage or evidence of the current first
module failure.

Twenty-nine regression functions are prepared: six File, 13 FormData/event,
six Fetch-body and four signed-integer cases. They cover conversion ordering,
native identity, USVString normalization, duplicates/overloads, mutation during
iteration, form/submitter errors, trusted/native and constructed formdata
events, arena/teardown roots, late body snapshots, binary file bytes, invalid
MIME/multipart data, body-use rules and compiler-disabled second-VM cache
revisits. All remain uncompiled and unexecuted. Cache assertions are pending
source and provide no speed or reuse evidence.

Eleven compiler-only attempts and raw logs are preserved byte-identically with
a hashed index in local `docs/performance/libjs-form-data-20261116/`:

| Compiler-only check | Child exit | Seconds | Peak sampled RSS bytes |
| --- | ---: | ---: | ---: |
| File normal | 0 | 22.013 | 5,360,435,200 |
| File production/prealloc/no-GC | 0 | 20.308 | 5,640,880,128 |
| FormData initial normal | 0 | 26.055 | 5,370,265,600 |
| FormData initial production | 1 | 13.468 | 1,799,028,736 |
| FormData corrected normal | 0 | 19.272 | 5,367,283,712 |
| FormData final normal | 0 | 19.098 | 5,376,737,280 |
| FormData final production | 0 | 21.471 | 5,640,896,512 |
| Fetch form bodies normal | 0 | 24.071 | 5,379,080,192 |
| Fetch form bodies production | 0 | 23.646 | 5,641,093,120 |
| Signed integer final normal | 0 | 22.581 | 5,365,776,384 |
| Signed integer final production | 0 | 25.409 | 5,642,240,000 |

The production failure identified a pointer-map lookup without an optional
branch; it was corrected before the FormData commit. The final normal check
also includes avoiding byte-copy work for an unchanged File append. Commands
use `V3_STR_CAP=1 VJOBS=1`, unique default 12 GiB `run_memory_bounded` guards and
`/Users/alex/code/v/v -w -n -b c -no-parallel -cc clang -check
-memory-limit 10G -enable-globals tools/libjs_github_revisit.v`; production adds
`-prod -prealloc -gc none`. Every guard reports reason=completed and the exit
above. Checks exclude `_test.v`, C linking and runtime execution. Compiler
durations are not JS timings. Completed own Build reports/locks were removed
after preservation.

At implementation revision `21807ad29`, the latest completed production
executable inspected statically remains
`419ad8d777319bd5b8605799a59da05b59e20ae596bc3f50594babb87db2ba56`.
Its actual hash matches
`Build/production-build/receipts/20261116-002422-18914df3/frozen-compile.json`,
using one C unit and literal V -prod. Its exact consumed-source manifest matches
none of 12 selected changed implementation files. Receipt/executable identities
stayed unchanged during the audit; this bundle cannot validate the additions.
Each commit requested a coalesced managed rebuild. No duplicate manual build or
fresh browser launch was introduced.

This remains partial native integration. Full form-control property bindings,
FileReader, native LibJS XMLHttpRequest, foreign-realm rules, physical collection
and remaining JS/Web/Intl/rendering work are unfinished. The existing multipart
lexer constraints remain; body serialization uses the native byte-vector limit
and a conservative bound before allocation. This is not complete FileAPI,
FormData, Fetch or WebIDL conformance.

The original manifest remains
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`,
and the Brave reference remains
`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
The last actual GitHub observation remains 672 warm native entries, 51 frontend
hits, zero compiler calls, 33 rows, zero commit links and five module errors,
predating these changes. Acceptance still requires 33 rows, 56 commit links,
current README, active controls, zero errors, the unchanged Brave content audit
and zero differing pixels, followed by matched performance evidence. New full
GitHub execution, faster compiled revisits and Brave pixel parity are unverified.

## Native control state and form action continuation

The 2026-11-16 continuation retains the user's hold. No tests were compiled or
executed, no JS was evaluated, and no browser, capture, comparison or performance
trial was launched. GitHub/Brave compiled-JS parity remains incomplete.

| Commit | Implemented behavior |
| --- | --- |
| `cefbf0a6c` | Preserve explicit empty checkbox/radio values; "on" applies only when the value attribute is absent. |
| `27563fc78` | Bind input/textarea values/defaults, checkedness/indeterminate state, select values/indices, option state, button values/types, common reflected members and native form owners. Empty checked values reach FormData unchanged; lazy select initialization supplies initial selectedness once. Native mutations notify the host and frame scheduler. |
| `e18c888d8` | Bind form action/method/encoding/autocomplete, length/relList, submitter overrides, reset/validation and submit/requestSubmit. Bind SubmitEvent with original submitter identity and public-constructor trust rules. Install a traced browser submission service that forwards native GET/POST bodies/targets to the existing navigation owner. |

Live text values and default attributes remain separate. Legacy null-to-empty
conversion applies to input/textarea value; other string members use their
IDL conversion. Actual HTML models perform sanitization, radio grouping,
selectedness and reset. Explicit no-selection survives model reuse. Form owners
are resolved from native DOM identity and wrappers retain their identity.

Form requestSubmit without a button now respects noValidate. Public SubmitEvent
construction clears trust while native submission events retain native trust.
Submitter eligibility is checked before creating a control for an unrelated
HTMLElement. The submission service borrows a temporary native hook only when
the model lacks one, releases it after the call and preserves existing hooks.
Its browser record is allocated persistently and carries no VM callback capture.
Target attributes are read at native handoff after author handlers. relList's
PutForwards setter observes ordinary JS getters/setters before string coercion;
reportValidity also notifies the host after native focus changes.

The frozen original scripts contain 92 textual HTMLInputElement references in
11 bodies, 35 HTMLTextAreaElement references in six bodies, four .requestSubmit
references in two bodies and seven .formAction references in two bodies. The
static scan also records 68 .checked references in eight bodies and 38
.defaultValue references in seven bodies. Property names alone do not establish
object brands, runtime reachability or the current first module error. The
same scan finds 12 .setSelectionRange references in six bodies; that binding
remains unfinished. Source hashes/contexts remain local in static-source-scan.json.

Thirty-five focused functions are prepared: six native HTML, 14 control-binding,
14 form/event/service and one main-browser integration case. They cover live
state/defaults, coercion/brands/UTF-16, FormData snapshots, selection, radio
groups, attribute reactions, mutation notification, arena lifetime, action/
encoding overrides, reset cancellation, validation bypass, submitter identity,
POST body/target handoff, late target mutation, existing-hook preservation,
PutForwards, shell navigation and compiler-disabled second-VM cache revisits.
All remain uncompiled and unexecuted; their assertions supply no cache or pixel
evidence.

Fourteen compiler-only attempts and raw logs are preserved byte-identically
with a hashed index in local docs/performance/libjs-form-controls-20261116/:

| Compiler-only check | Child exit | Seconds | Peak sampled RSS bytes |
| --- | ---: | ---: | ---: |
| Empty input value normal | 0 | 18.428 | 5,378,424,832 |
| Empty input value production | 0 | 18.971 | 5,656,608,768 |
| Controls initial normal | 1 | 1.584 | 653,410,304 |
| Controls corrected normal | 0 | 19.846 | 5,386,027,008 |
| Controls production | 0 | 18.063 | 5,661,802,496 |
| Form properties normal | 0 | 19.123 | 5,392,564,224 |
| Form service normal | 0 | 21.895 | 5,398,773,760 |
| Browser embedding normal | 0 | 27.555 | 6,679,150,592 |
| Browser embedding production | 0 | 27.880 | 6,963,249,152 |
| Browser callback lifetime normal | 0 | 26.341 | 6,679,019,520 |
| Browser forwarding/focus final normal | 0 | 28.524 | 6,672,400,384 |
| Browser forwarding/focus final production | 0 | 31.985 | 6,957,711,360 |
| Submitter eligibility final import normal | 0 | 19.977 | 5,383,749,632 |
| Submitter eligibility final import production | 0 | 16.560 | 5,672,878,080 |

The failed attempt used V's reserved select keyword as a variable name; it was
corrected before the controls commit. Import checks use current V with
`V3_STR_CAP=1 VJOBS=1`, a unique default 12 GiB run_memory_bounded guard and
`-w -n -b c -no-parallel -cc clang -check -memory-limit 10G -enable-globals
tools/libjs_github_revisit.v`. Production adds -prod -prealloc -gc none.
Whole-browser checks instead target '.', with vox_production/vox_ui2/
vox_sparse_ttf definitions, the native-zoneinfo exclusion and existing shared
font/HTTP/UI2 module paths. They do not schedule a production build. Exact
commands/exits are retained; each guard reports reason=completed. Checks
exclude _test.v, C linking and execution. Compiler durations are not JS timings.
The last import pair covers the submitter-tag guard added after the browser
pair. Own completed Build reports/locks were removed after preservation.

At implementation revision e18c888d8, the latest completed production
executable inspected statically is
`195b51717bc5195ec40257d10c96e22bcddbbb432a757d232c93c74352d36e0c`.
Its actual hash matches
`Build/production-build/receipts/20261116-014301-d3498b0e/frozen-compile.json`,
using one C unit and literal V -prod. Ten of twelve selected implementation
files match its consumed-source manifest. libjsdom/forms.v and
document/form_submission.v differ, so it cannot validate the final form-service
revision. Receipt/executable identities stayed unchanged during the audit.
Commits requested coalesced managed rebuilds; no duplicate manual build or fresh
process was introduced.

Full control validation/selection/FileList bindings, options/form collections
and named properties, remaining IDL, foreign-realm rules, native collection and
broader JS/Web/Intl/rendering behavior remain open. These source additions do
not establish full HTML or form-navigation conformance. The original manifest
remains `893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`,
and the Brave PNG remains
`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
The last actual GitHub observation is still 672 warm native entries, 51 frontend
hits, zero compiler calls, 33 rows, zero commit links and five module errors,
predating these changes. Acceptance remains 33 rows, 56 commit links, current
README, active controls, zero errors, the unchanged Brave content audit and zero
differing pixels, followed by matched performance evidence. New full GitHub
execution, faster compiled revisits and Brave pixel parity remain unverified.

## Native text selection and constraint validation continuation

The user's hold on tests and execution remains in force. This continuation ran
only compiler checks of non-test programs and static source/hash audits. It did
not compile or execute tests, initialize a JavaScript runtime, launch a browser,
capture pixels or collect performance measurements. GitHub/Brave parity remains
incomplete.

Four focused commits add the following source behavior:

- `a5cc02c99` restores concrete input/textarea owner dispatch for range
  replacement. The live value, dirty flags, user-edit state, validation and
  editing text reach the same owner used by rendering and FormData. Textareas
  retain their raw value separately while selection offsets count the
  newline-normalized API value. `select()` also handles the broader native
  input applicability set, including email.
- `c9a5a05b2` binds selectionStart, selectionEnd, selectionDirection, select,
  setSelectionRange and both setRangeText overloads on the native input and
  textarea prototypes. Receiver and overload checks precede author conversion;
  nullable input attributes, unsigned-long wrapping, enum rejection, conversion
  side effects and native DOM errors follow their IDL paths. Native selection
  tasks remain responsible for select/selectionchange events.
- `023f3c67c` restores live constraint-owner dispatch for inputs, textareas and
  selects, including form-level checks. Select required/placeholder checks no
  longer depend on stale base flags. Radio group comparisons use pointer
  identity. Custom messages normalize CRLF/CR to LF and invalidate the control,
  owning form and ancestor fieldsets; readonly custom controls are barred.
- `86bf060b1` exposes the eleven readonly ValidityState flags and control
  willValidate, validity, validationMessage, checkValidity, reportValidity and
  setCustomValidity on input, textarea, select and button prototypes. Wrappers
  retain the actual native state/control, survive the transient arena, reject
  forged/Proxy receivers and History cloning, and clear ownership maps on close.
  Public ValidityState construction is illegal. Native invalid-event dispatch
  and its cancellation/return semantics are retained.

These additions do not establish complete text-control or validation conformance.
In particular, reportValidity uses the existing native reporting path; platform
validation-message UI remains unfinished. Broader control IDL, FileList bindings,
form/options collections and named properties, foreign-realm behavior, native
ownership and wider JS/Web/rendering work remain open.

Thirty-six additional focused functions are prepared: seven native range-owner,
eleven selection-binding, seven native validation-owner and eleven
validation-binding cases. They cover normalized newline/UTF-16 offsets, dirty
owners, clamping and wrapping, arity/brands/conversion order, replacement modes,
FormData values, live selectedness/defaults/radio groups, constraint flags,
invalid-event behavior, submission prevention, custom messages, descriptors,
clone rejection and persistent lifetime. They remain uncompiled and unexecuted.

All fifteen compiler-only attempts are retained byte-identically, including the
two corrected failures, with a hashed index in local
`docs/performance/libjs-control-editing-20261116/`:

| Compiler-only check | Child exit | Seconds | Peak sampled RSS bytes |
| --- | ---: | ---: | ---: |
| Range owner initial normal | 0 | 16.555 | 5,370,429,440 |
| Range owner final normal | 0 | 19.400 | 5,384,142,848 |
| Range owner production | 0 | 18.348 | 5,663,948,800 |
| Selection bindings normal | 0 | 19.055 | 5,389,565,952 |
| Selection bindings production | 0 | 18.599 | 5,660,573,696 |
| Validation owner initial normal | 1 | 1.382 | 764,198,912 |
| Validation owner corrected syntax normal | 1 | 8.916 | 1,531,396,096 |
| Validation owner corrected mutability normal | 0 | 15.854 | 5,391,826,944 |
| Validation owner production | 0 | 15.802 | 5,666,406,400 |
| Validation owner final normal | 0 | 15.566 | 5,395,939,328 |
| Validation owner final production | 0 | 16.621 | 5,662,539,776 |
| Validation bindings normal | 0 | 15.645 | 5,394,317,312 |
| Validation bindings production | 0 | 15.482 | 5,670,371,328 |
| Whole browser final normal | 0 | 24.584 | 6,688,276,480 |
| Whole browser final production | 0 | 25.142 | 6,965,460,992 |

The failures were an unsupported optional-unwrapping loop syntax and mutation
through an immutable select control field; both were corrected before commit.
Each guard reports reason=completed, with the child exits above. Import checks
use current V, `V3_STR_CAP=1 VJOBS=1`, a unique default 12 GiB memory guard and
`-w -n -b c -no-parallel -cc clang -check -memory-limit 10G -enable-globals
tools/libjs_github_revisit.v`. Production adds `-prod -prealloc -gc none`.
Whole-browser checks target `.` with vox_production/vox_ui2/vox_sparse_ttf,
the native-zoneinfo exclusion and the existing shared font/HTTP/UI2 module
paths. Exact commands, logs and guard reports remain local. Own Build job
reports and locks were removed after hash-verified preservation. Compiler
success establishes source typing, not execution or native-cache behavior.

The static scan verifies all bodies before reading the original 87 JS URLs /
86 distinct bodies. It finds 66 .selectionStart references in five bodies,
62 .selectionEnd in five, four .selectionDirection in two, twelve
.setSelectionRange in six, eleven .checkValidity in one, seventeen
.setCustomValidity in two, and one each .validity/.validationMessage in one.
The .validity context reads customError before saving validationMessage.
Textual property names do not establish receiver brands or runtime reachability.
No .setRangeText, .willValidate or .reportValidity dot references were found;
those APIs complete the exposed selection/validation families. Counts and
bounded contexts remain local in static-source-scan.json.

The inspected completed production executable is SHA-256
`9b721c8a10c11bb7e3e0de505993ce69fe79113e3a14edcd89c2b6e481641262`,
receipt `20261116-021306-0ff8edb4`, single-C-unit / v_prod. Five of fourteen
selected current implementation inputs match its consumed-source manifest;
the nine selection/validation inputs differ or are absent. Receipt and
executable identities stayed stable during the audit. The available bundle
cannot validate this continuation. Commits requested coalesced managed builds;
no duplicate manual build or browser launch was introduced.

The original fixture manifest remains
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`,
and Brave reference PNG remains
`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
The last actual GitHub observation is still the historical 672 warm native
entries, 51 frontend hits, zero compiler calls, 33 rows, zero commit links and
five module errors; it predates these changes. Acceptance remains 33 rows,
56 commit links, current README, active controls, zero errors, the unchanged
Brave content audit and zero differing pixels, followed by matched performance
evidence. No new full execution, compiled-revisit speed or pixel-parity claim
is established.

## Native form and select collection continuation

The user's execution hold remains in force: no tests were compiled or run,
no JavaScript runtime was initialized, and no browser, capture or performance
trial was launched. This continuation closes additional source binding gaps;
full GitHub execution and Brave pixel parity remain incomplete.

- `eba665855` makes native form length count its live elements collection,
  including lazy and external controls, and changes RadioNodeList value writes
  to select the actual target's radio group. Equal IDs in unrelated groups no
  longer cause those groups to be unchecked; group members outside the named
  list are handled by the concrete input owner. Native list/base-collection
  views are exposed for inherited binding operations.
- `d033c168a` binds form.elements/form.length, HTMLFormControlsCollection and
  RadioNodeList to native owners. namedItem returns null, the real Element, or
  a native live radio list. Inherited length/item/iteration methods share the
  same native records. HTMLCollection is published with its illegal public
  constructor and iterator; wrappers are cached by native identity. Collection
  reads enter persistent allocation before native cache updates, and ownership
  maps clear on host close. Required arguments, brands and author conversion
  errors retain their native binding paths.
- `b17e0ee4b` binds select.options/selectedOptions, HTMLOptionsCollection,
  length/selectedIndex, add/remove and select item/namedItem operations. Both
  saved views read the real option owner; selectedOptions recomputes current
  selectedness even when no DOM/attribute generation changes. The before
  HTMLElement/long union is resolved before native insertion. Select remove's
  zero-argument ChildNode overload remains distinct from indexed removal.
  DOM exceptions and author-thrown values are preserved, and successful native
  mutations drain reactions and notify the document host.

Twenty-three focused functions are prepared: three native collection-owner,
ten form/radio binding and ten select/options binding cases. They cover live
membership, external owners, hierarchy/identity, radio groups, explicit empty
values, iteration, conversion side effects, brands/arity, add/remove overloads,
selection without attribute mutation, native exceptions, clone rejection and
arena lifetime. They remain uncompiled and unexecuted and provide no runtime
or compiled-cache coverage evidence.

All nine compiler-only attempts passed. Exact commands, byte-identical logs
and guard reports are retained with a hashed index in local
`docs/performance/libjs-form-collections-20261116/`:

| Compiler-only check | Child exit | Seconds | Peak sampled RSS bytes |
| --- | ---: | ---: | ---: |
| Form collections initial normal | 0 | 15.538 | 5,380,980,736 |
| Form collection owners/ancestry normal | 0 | 15.561 | 5,401,395,200 |
| Form collections production | 0 | 15.435 | 5,669,224,448 |
| Form collections persistent reads final normal | 0 | 15.255 | 5,402,525,696 |
| Form collections persistent reads final production | 0 | 15.420 | 5,669,486,592 |
| Select collections normal | 0 | 15.906 | 5,400,510,464 |
| Select collections production | 0 | 16.926 | 5,674,647,552 |
| Whole browser final normal | 0 | 25.907 | 6,673,252,352 |
| Whole browser final production | 0 | 27.991 | 6,966,870,016 |

Import checks use current V with `V3_STR_CAP=1 VJOBS=1`, unique default 12 GiB
memory guards and `-w -n -b c -no-parallel -cc clang -check -memory-limit 10G
-enable-globals tools/libjs_github_revisit.v`. Production adds
`-prod -prealloc -gc none`. Whole-browser checks target `.` with
vox_production/vox_ui2/vox_sparse_ttf, the native-zoneinfo exclusion and existing
shared font/HTTP/UI2 module paths. Every guard reports reason=completed and
child_exit_code=0. Own Build reports/locks were removed after hash-verified
preservation. These checks establish typing, not execution or C code generation.

Static inspection of the hash-verified original 87 JS URLs / 86 bodies finds
38 .elements references in three bodies, 16 .namedItem in two, 371 .options in
twelve and three .selectedOptions in one. Contexts include
form.elements.namedItem("utf8") and Array.from(select.selectedOptions). Property
text does not establish receiver brands, reachability or the first module error;
the bounded contexts remain local in static-source-scan.json.

The inspected completed executable is SHA-256
`de425d522698020cf02909ac88fb8a6547e597e21e2c61638bfd475012308a5c`,
receipt `20261116-023116-834ed845`, single-C-unit / v_prod. Its identity and
receipt remained stable during the audit. Only three of ten selected current
inputs match the consumed-source manifest; all seven changed collection inputs
differ or are absent. It cannot validate these changes. Commits requested
coalesced managed production rebuilds; no duplicate manual build was scheduled.

Legacy named properties, indexed option assignment and select indexed reads,
collection descriptor/integrity semantics, collection roots across form moves,
broader IDL, FileList, reporting UI, foreign realms and native ownership remain
open. These additions do not establish complete collection or HTML conformance.
The original fixture manifest remains
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`;
the Brave PNG remains
`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
The last actual GitHub observation is still the historical 672 warm native
entries, 51 frontend hits, zero compiler calls, 33 rows, zero commit links and
five module errors, predating these additions. Acceptance remains 33 rows,
56 commit links, current README, active controls, zero errors, the unchanged
Brave content audit and zero differing pixels, followed by matched performance
evidence. Full execution, faster compiled revisits and pixel parity remain
unverified.

## Native indexed property continuation

The user's hold remains in force. This continuation ran compiler-only checks
of non-test targets and static source/hash audits. It did not compile or run
tests, initialize JavaScript, launch a browser, capture pixels or measure
performance. Full GitHub/Brave parity remains incomplete.

- `495bbc224` adds opt-in legacy platform-object metadata and typed native
  index/setter services in LibJS. The indexed portions of upstream
  Bindings/PlatformObject.cpp now govern GetOwnProperty, Set, DefineOwnProperty,
  Delete and PreventExtensions. Supported indices expose configurable/enumerable
  descriptors and the native setter's writability, while deleting supported
  indices and preventing extensions fail. Definitions invoke the native setter;
  alternate assignment receivers retain ordinary assignment semantics. Other
  HostProperties families do not acquire WebIDL behavior merely by providing
  native properties.
- `bc730ee49` marks native NodeList, HTMLCollection and DOMTokenList wrappers
  with their live indexed owners. This includes derived radio/form/option
  views. Readonly numeric definitions are rejected, and supported index
  descriptors are not writable. Nonindex expandos remain ordinary properties.
  Token-list reads retain persistent native allocation scope. Configurable descriptors now feed
  the existing Proxy invariant checks correctly.
- `19ee01341` replaces an indexed option through its actual parent. This fixes
  replacement inside optgroups. It intentionally differs from the inspected
  upstream HTMLOptionsCollection.cpp root.replace_child call: the native DOM
  replacement algorithm requires the old node to be a child of that parent.
- `7438f1f00` binds native option setters to both select[index] and
  select.options[index]. Null/undefined remove an option; other values require
  a real HTMLOptionElement before mutation. Native gap creation, replacement,
  selection updates, DOM errors and custom-element reactions are retained.
  Select indexed getters/keys share the lazy native option owner. Mutation
  notification also runs after a native error that leaves earlier insertions
  in place. The native 100,000-index cap is retained.
- `4bb6db210` prepares a focused native-cache revisit case: the first VM runs
  synthetic indexed operations and flushes their native cache; the second VM
  executes the same source with /usr/bin/false as its compiler. Assertions
  require cache hits, native fast/slow steps and zero compiler calls on revisit.
  This test remains uncompiled and unexecuted.

Twenty-one focused functions are prepared: four engine protocol, five readonly
collection, two native option-owner and ten select/options binding cases.
They cover descriptors, deletion, extensibility, Proxy invariants, direct and
alternate receivers, native throws, nullish removal, gap insertion, optgroup
replacement, argument brands without coercion, ignored definition flags,
prototype interception, partial native failure and arena/closed-host lifetime.
They remain uncompiled and unexecuted and provide no runtime evidence.

A static cache-boundary audit records the native tier source hash and its
fast-opcode allowlist. Generated code carries NV values and an opaque Slow
callback; property operations dispatch through native_slow_step to the current
VM.execute_instruction. The emitter does not declare an Object structure whose
layout would embed these new metadata fields. This is source reasoning about
the cache boundary, not proof that cached GitHub code exercises the hooks.
The audit remains local in native-cache-boundary-audit.json; no native cache
was loaded or compiled during it.

All ten compiler-only attempts passed. Exact commands, byte-identical raw logs
and guard reports are retained with a hashed index in local
`docs/performance/libjs-indexed-properties-20261116/`:

| Compiler-only check | Child exit | Seconds | Peak sampled RSS bytes |
| --- | ---: | ---: | ---: |
| Indexed engine protocol normal | 0 | 15.410 | 5,374,083,072 |
| Indexed engine protocol production | 0 | 15.520 | 5,685,428,224 |
| Readonly bindings initial normal | 0 | 15.738 | 5,411,373,056 |
| Readonly bindings final normal | 0 | 15.530 | 5,404,393,472 |
| Readonly bindings production | 0 | 15.948 | 5,667,028,992 |
| Select indexed bindings initial normal | 0 | 16.289 | 5,405,589,504 |
| Select indexed bindings final normal | 0 | 15.951 | 5,403,459,584 |
| Select indexed bindings production | 0 | 17.315 | 5,675,319,296 |
| Whole browser final normal | 0 | 25.653 | 6,694,748,160 |
| Whole browser final production | 0 | 27.177 | 6,971,359,232 |

Import checks use current V with `V3_STR_CAP=1 VJOBS=1`, unique default 12 GiB
memory guards and `-w -n -b c -no-parallel -cc clang -check -memory-limit 10G
-enable-globals tools/libjs_github_revisit.v`. Production adds
`-prod -prealloc -gc none`. Whole-browser checks target `.` with
vox_production/vox_ui2/vox_sparse_ttf, the native-zoneinfo exclusion and existing
shared font/HTTP/UI2 module paths. Each guard reports reason=completed and
child_exit_code=0. Own Build reports/locks were removed after hash-verified
preservation. These results establish source typing, not execution or C code
generation.

The static scan re-verifies the original 87 JS URLs / 86 bodies. It finds
371 .options references in twelve bodies and three textual .options[index]
expressions in two bodies. No direct .options[index] assignment matches were
found. Aliased/computed accesses, receiver brands and runtime reachability are
not established by this scan, so the new setter path earns no execution or
performance claim. Counts and bounded contexts remain local.

The inspected production executable is SHA-256
`c23c0d0a98ad945b7f6ffb581c1dc91172ed39b99aa5a37eecf23641607c8fa8`,
receipt `20261116-030137-13ee3df8`, single-C-unit / v_prod. Executable and
receipt identities stayed stable during the audit. Two of eight selected
current inputs match its consumed-source manifest; six differ or are absent,
so it cannot validate the full continuation. Commits requested coalesced
managed rebuilds; no duplicate manual build was scheduled. Concurrent engine
work remains outside these commits.

Named-property visibility, form named/indexed bindings, collection roots across
form moves, broader IDL, FileList, reporting UI, foreign realms and native
ownership remain open. These changes do not establish complete WebIDL, HTML,
LibJS or GitHub conformance. The original fixture manifest remains
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`;
the Brave PNG remains
`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
The last actual GitHub observation is still the historical 672 warm native
entries, 51 frontend hits, zero compiler calls, 33 rows, zero commit links and
five module errors, predating these additions. Acceptance remains 33 rows,
56 commit links, current README, active controls, zero errors, the unchanged
Brave content audit and zero differing pixels, followed by matched performance
evidence. Full execution, faster compiled revisits and pixel parity remain
unverified.

## Native named property continuation

The user's execution hold remains in force. This continuation ran compiler-only
checks of non-test targets and static source/hash audits. It did not compile or
run tests, initialize JavaScript, launch a browser, capture pixels or measure
performance. GitHub/Brave parity remains incomplete.

- `ee1a89ff1` implements readonly WebIDL named-property visibility in the
  engine. Native supported names, ordinary own storage, LegacyOverrideBuiltIns,
  prototype own properties and named-properties objects follow the inspected
  Bindings/PlatformObject.cpp algorithms. Prototype queries use checked VM
  operations, retaining author Proxy traps, mutations and thrown values.
  GetOwnProperty/HasProperty, definitions, deletion and key enumeration share
  the protocol; Set continues to ignore virtual names while resolving ordinary
  setters. The engine boundary preserves UTF-16 name identity.
- `d23c23222` clears native past-name aliases when a control leaves its owner
  and preserves them during lazy same-owner queries. Control registration and
  removal compare record identity. Native form collections and their saved
  radio/image lists follow the form's current root and refresh collection caches
  when the root changes. This closes the detached-form cache issue exposed by
  named-property lookup, including discovery of later external controls.
- `e86bede9d` exposes named properties on native HTMLCollection/form/option/
  selected-option views, plus indexed and named form access. Collections obey
  LegacyUnenumerableNamedProperties; forms also obey LegacyOverrideBuiltIns,
  including fields named elements/action/submit. Duplicate fields return real
  live RadioNodeList records, and native past-name lookup is retained. Form
  view identity survives root changes, inherited NodeList operations retain
  their radio owner, and item conversion observes root moves performed by
  author callbacks. All native cache allocations enter persistent scope.

One concurrent class-query routing hunk was inadvertently included in the
binding commit. `05b26204b` restores independent committed routing in a linear
follow-up; that concurrent working-tree change and its implementation remain
preserved outside this feature. No shared history was rewritten.

Twenty-six focused functions are prepared: eight engine protocol, four native
form-owner/root and fourteen binding cases. They cover visibility/override
flags, descriptors, ordinary expandos, UTF-16/symbol/index distinctions,
prototype Proxy behavior, native name mutations, radio results, builtin
collisions, past-name cleanup, external owners, saved root views, conversion
side effects and arena lifetime. A synthetic first/second-VM native-cache case
requires native hits/fast/slow steps and zero compiler invocations with
/usr/bin/false on revisit. All remain uncompiled and unexecuted; their
assertions provide no cache coverage or GitHub execution evidence.

Eleven compiler-only attempts are retained byte-identically, including the
failed production attempt, with a hashed index in local
`docs/performance/libjs-named-properties-20261116/`:

| Compiler-only check | Child exit | Seconds | Peak sampled RSS bytes |
| --- | ---: | ---: | ---: |
| Named engine protocol normal | 0 | 16.619 | 5,383,487,488 |
| Named engine protocol production | 0 | 16.680 | 5,683,724,288 |
| Named bindings initial normal | 0 | 19.074 | 5,409,832,960 |
| Past-name owners normal | 0 | 16.927 | 5,398,167,552 |
| Control identity normal | 0 | 16.914 | 5,404,737,536 |
| Form/radio roots final normal | 0 | 15.403 | 5,375,262,720 |
| Named bindings production | 0 | 16.024 | 5,683,527,680 |
| Whole browser initial normal | 0 | 25.132 | 6,672,302,080 |
| Whole browser initial production | 1 | 1.606 | 1,033,551,872 |
| Whole browser final normal | 0 | 24.559 | 6,678,167,552 |
| Whole browser final production | 0 | 26.001 | 6,977,503,232 |

The failed attempt caught a deprecated usize cast in concurrent, uncommitted
class-query work. That source changed to uint before the final pair passed;
the failed receipt remains preserved. Import checks use current V with
`V3_STR_CAP=1 VJOBS=1`, unique default 12 GiB guards and
`-w -n -b c -no-parallel -cc clang -check -memory-limit 10G -enable-globals
tools/libjs_github_revisit.v`. Production adds `-prod -prealloc -gc none`.
Whole-browser checks target `.` with vox_production/vox_ui2/vox_sparse_ttf,
the native-zoneinfo exclusion and existing shared font/HTTP/UI2 module paths.
All guards report reason=completed, with child exits above. Own Build job
reports and locks were removed after hash-verified preservation. Compiler
success establishes typing, not execution or C code generation.

Static inspection verifies all original 87 JS URLs / 86 bodies before scanning.
It finds 38 .elements references in three bodies, 16 .namedItem in two,
30 .elements.member expressions in three and three .selectedOptions references
in one. No direct .elements[...] regex matches were found. Aliases, receiver
brands, runtime reachability and the current first module error remain unknown;
counts and bounded contexts remain local. No native fast-path or performance
credit follows from these textual matches.

The inspected production executable is SHA-256
`aa91e7cc1c8c2c3ebe083a96582817e16f1de903c8a81ff43a4a3674bc5b1a64`,
receipt `20261116-035309-fefe9f5d`, single-C-unit / v_prod. Its executable and
receipt stayed stable during the audit. All fourteen selected committed feature
inputs at `05b26204bc3c33c5f5d58078e398ce053a1d6fbb` match its consumed-source
manifest. Thirteen current working inputs match; nodes.v differs by the
concurrent class-query routing change. This is selected source-identity
evidence only; the bundle was not launched. Commits requested coalesced managed
rebuilds and no duplicate manual production build was scheduled.

Global/window named objects, named setters/deleters, broader IDL, FileList,
reporting UI, foreign realms, adoption/cross-document ownership and wider
JS/Web/rendering behavior remain open. These source additions do not establish
full WebIDL, HTML or LibJS conformance. The original fixture manifest remains
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`;
the Brave PNG remains
`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
The last actual GitHub observation remains the historical 672 warm native
entries, 51 frontend hits, zero compiler calls, 33 rows, zero commit links and
five module errors, predating these additions. Acceptance remains 33 rows,
56 commit links, current README, active controls, zero errors, the unchanged
Brave content audit and zero differing pixels, followed by matched performance
evidence. Full execution, faster compiled revisits and pixel parity remain
unverified.

## Browser diagnostics resumed, 2026-11-16

Automated suites remain off. Fresh browser processes, original-response replay
and standalone initialization diagnostics resumed with the existing 12 GiB
aggregate memory guard. The fixture, content gates, Brave PNG and pixel
tolerance are unchanged. All failed attempts are retained locally.

| Commit | Change | Verification boundary |
| --- | --- | --- |
| `c47f79420` | `document.domain` reads the native effective origin and delegates setter validation to native Document. | The missing-domain failure disappears in subsequent original-response initialization. Origin relaxation remains the native model's existing limitation. |
| `292ed4206`, `3949d1e80` | Deferred native error/reason string conversion enters its owning callback scope; primitive conversion stays direct, and disabled script conversion fails explicitly. | Source builds succeed. A prior compiler-disabled browser attempt crashed during error description without an execution context; it remains a failed attempt. |
| `a3fb4aff4` | Cached native execution returns to its caller at `await`, generator start and yield, preserving the resume PC. | Static defect correction and subsequent cached GitHub execution; no isolated performance attribution. |
| `2b1f7ca13`, `18e0926c9` | Budget exhaustion retains its first error/trace while unwinding; native callback diagnostics retain error stacks. | Original GitHub traces now identify the first factory/callback failure. No instruction limit was changed by these commits. |
| `ff2806bce` | Native shadow attachment, ShadowRoot identity/ancestry, open/closed visibility, option conversion and shadow-tree HTML. | A fresh production browser no longer reports the polyfill's missing `attachShadow` failure. Broader ShadowRoot/ElementInternals bindings remain incomplete. |
| `ae1c8f9fa` | Native `performance.measure`, mark/measure ordinary-value detail cloning and native timestamps; failed detail cloning publishes no entry. | Production initialization reaches the next actual missing API, `crypto`, instead of failing at `performance.measure`. Other structured-clone families and PerformanceObserver remain incomplete. |
| `f7178d6d2` | Document script/module/callback entries use a bounded ten-million-instruction policy; bare Runtime entries retain one million. The capture audit records the limit. | An interpreter control gets through Primer/React initialization with zero module errors. This is an execution-policy change, not an optimization or matched speed result. |
| `9fd264af7` | Crypto uses the owning native global's secure random UUID/bytes and actual integer-view storage; insecure exposure, brands, fixed-buffer conversion and native quota/type errors are preserved. | An interpreter control advances past the missing-crypto failure to missing CustomEvent. SubtleCrypto is still a separate binding. |
| `5405548d5`, `28d124637` | Native CustomEvent details/dispatch identity and strict block-function lexical initialization. | Non-test compiler checking succeeds; the next interpreter control has no module errors or JavaScript diagnostics. Compiled/windowed follow-up remains pending. Sloppy Annex B block functions remain explicitly unsupported. |

The standalone revisit driver now preserves the actual Window/Navigable pair
created by `parse_navigation_document`. Its obsolete placeholder context caused
a native History identity panic. One attempted replacement created a second
Window and also failed; both attempts remain recorded. `3844b1c48` removes the
replacement and preserves the existing identity.

The browser runner accepts explicit shared native-cache/compiler paths and
retains compiled-cache counters. `3349dd763` corrects a staging mistake in
`7853bc8ab`: another session's runtime-audit file remains in its working tree,
while the committed cache audit uses an independent source file. Shared history
was not rewritten.

### Observed page/cache state

The original production bundle
`aa91e7cc1c8c2c3ebe083a96582817e16f1de903c8a81ff43a4a3674bc5b1a64`
loads a 1024×768 active document viewport, with 33 rows, README, zero latest
commit entries and zero commit links. The errors are missing `document.domain`
and a polyfill call. Browser/controller/guard exit zero, input hashes are stable,
and sampled aggregate RSS peaks at 5,752,356,864 bytes. Its compiler-disabled
reopen fails cache compilation and panics during error string conversion; it
does not establish reuse correctness.

A later production browser
`4488b888297c87a05424c6b5c6fcd32d76a15c901c1b0ee099a9a6bb65b863a7`
contains the shadow and deferred-string fixes, preceding Performance.measure.
It publishes an active 1024×768 document audit and whole-window PNG, still with
33/0 rows/commit links. The shadow-polyfill error is gone. The audit selects
LibJS, records no JSC context, 1,527 compiled native executables, three compiler
calls and no pending entries/cache error. Remaining diagnostics are missing
Performance.measure and the one-million-instruction cutoff in Primer factories.
Browser/controller/guard exit zero, identities stay fixed, and sampled aggregate
RSS peaks at 6,536,101,888 bytes. A whole-window PNG is not the document pixel gate.

The production standalone driver with Performance.measure has SHA-256
`1ae9caf4e22edfaefabfebcd4400c52acbd3acc5dde1e49abadb92763ce40d6b`.
One first/reopened pair compiles 1,620 executables on its first visit; its second
VM gets **1,546 native cache hits, zero cache misses, 51 frontend hits and zero
compiler calls**, with `/usr/bin/false` selected. Both visits have the same one
module failure, missing-crypto diagnostic, 33 rows and zero commit links. The
process/guard exits are zero, pins stay unchanged, and sampled aggregate RSS
peaks at 5,532,205,056 bytes. This driver has no window/layout/paint. The earlier
non-production driver pair (1,524 warm native hits) and incompatible-cache reuse
failure remain separate diagnostics, with no performance credit.

The subsequent cache-disabled interpreter control, SHA-256
`3ea20881616345d76383e2748540e23030cd04b902ca8634104b84af2e482313`,
uses the recorded ten-million instruction limit. It reports zero module errors,
but missing CustomEvent and unsupported block-function bytecode still interrupt
callbacks. Rows/commit links remain 33/0. It has no native cache activity, no
JSC context, unchanged inputs and process/guard exits zero. It is useful for
finding errors without repeatedly compiling incomplete startup, and supplies no
compiled-path or rendering acceptance.

After CustomEvent and block-function integration, the interpreter control
`ce66d3c47fa1d91b049b23d74215571f7687b379e0bf0b94e1dee87134279bd9`
reports **zero module errors and zero JavaScript diagnostics**, with the same
ten-million limit, no native cache activity, no JSC context, unchanged inputs
and process/guard exits zero. Sampled aggregate RSS peaks at 3,936,452,608 bytes.
It still has 33 rows and zero commit links. Its initialization-only driver has
no browser window/frame pump; successful module initialization does not prove
that scheduled React rendering, interactions or completed hydration work.

Raw guards, logs and browser captures are local under
`docs/performance/libjs-github-browser-20261116/`. Initialization binaries,
parsed-buffer proofs, commands and results remain in the local benchmark cache
at `libjs-github-observe-20261116/`. Completed jobs' Build scratch is removed.
The new focused cases remain uncompiled and unexecuted while suites are held;
non-test V checking and diagnostic builds are recorded separately.

Acceptance still requires the original **33 rows, 56 commit links, current
README, active controls, zero errors, unchanged Brave content audit and zero
differing pixels**, followed by matched first/reopened performance evidence.
The document instruction-policy change must be recorded consistently in those
cohorts. Full GitHub execution and pixel parity remain incomplete.
