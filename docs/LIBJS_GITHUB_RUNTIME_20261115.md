# GitHub compiled-JavaScript continuation, 2026-11-15

**Automated test suites remain held at the user's request.** Browser and native
initialization diagnostics resumed on November 16; see the
[runtime continuation](#browser-diagnostics-resumed-2026-11-16). Historical
source-only checkpoints below retain their original verification boundaries.
Initial hydration and one compiler-disabled reopen complete. A later same-binary
cohort exposed mutable development cache identity; that fix is now implemented.
The full 60-second interpreter control sequence passes. An all-module native
first opening compiles 23,669 executables and its fresh reopen reuses 4,245
entries with zero misses. Native controls expose two missing field-initializer
templates and hit the memory guard. The subsequent initializer candidate exposes
a decoder ownership crash. After correction, a fresh first opening compiles
23,778 entries, its compiler-disabled reopen has 4,245 hits and zero misses, and
the complete native mouse/keyboard sequence passes with 4,690 hits, zero misses
and actual native execution. The SVG compositor, PNG capture-scale and shared rectangle/clip corrections
are enabled by default. A border-phase regression is removed; the unchanged
windowed-reference gate currently has 25,224 differing pixels. Exact content is preserved throughout. Speed, live validation
and pixel-perfect acceptance remain open.

**Full GitHub acceptance remains unachieved.** The latest initial native LibJS capture
has 33 rows, 56 commit links, latest commit and README, zero page errors and an
exact unchanged content audit. One fresh compiler-disabled reopen has zero
native misses and matches a fresh headless Brave PNG exactly. The historical
windowed PNG, interactions, live behavior and matched performance remain separate
gates. Earlier failing captures and 3 GiB runs remain historical diagnostics;
the scope correction below explains why the smaller guard cannot block a full
browser capture.
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

### Windowed rendering follow-up

Windowed diagnosis exposed an allocator problem in the standalone binaries:
ordinary `-prealloc -gc none` compilation without the browser's patched
`v_realloc` can crash during PNG decoding. Initialization-only cache observations
from those binaries, including the later 2,733-hit/53-frontend-hit reopen, are
not heap-safety or rendering validation. The retained older prepared runtime
uses compiler `2655544`; its first initialization succeeds, but its
compiler-disabled second VM fails cache compilation before producing its old
result JSON. That failed attempt is retained. The revisit tool now reports
flush failures and counters before returning failure.

New windowed diagnostics use prepared runtime
`b55745acc97cfa239ffabebd699dcd85b496a72d1f41d3e8468adc6fce7d0621`,
matching current V `cbfc1be`. They build canonical sources into standalone
diagnostic executables without copying an app bundle. These initial builds use
unoptimized generated C and are not production/performance acceptance builds.

| Commit | Original-page finding and change |
| --- | --- |
| `133864412` | Native event entry now respects the document's recorded instruction policy. |
| `d0c28bab3` | Real ParentNode children/first/last/count getters remove the clipboard template's missing `children[0]` failure. |
| `3895dd2d2` | Console and queued-callback errors retain native ErrorData stacks; render failures now identify their original source locations. |
| `3ca8d7632`, `4a8193d9a` | Legacy named setters/deleters and native HTMLElement.dataset reflection remove GitHub's missing `documentElement.dataset.colorMode` failure. |
| `2660c91a4` | Native live Document.getElementsByName removes the page-load fragment lookup failure. |
| `9e46ea43b` | The Function intrinsic and translated dynamic constructor remove Primer's `instanceof Function` ReferenceError. Dynamic functions use global scope, separate parameter/body validation and the existing bytecode/native cache. |
| `31f6c9d3f`, `31307be7d` | Intrinsic Date locale formatting removes the commit-date call failure; native Window scrolling removes React Router's missing scrollTo failure. |
| `c51999aca` | Closures in one realm share bytecode/register layouts for identical function syntax, source owner, location and name. Instance-specific field initializers remain separate. The audit records successful compilations and reuse. |

The dataset/name-lookup browser
`5913414cbe1f6df4889718561ce232571be0fd984db9f44d4e726f5fb9413229`
gets past those two failures and renders GitHub's error boundary for the missing
Function intrinsic. Its follow-up
`d3156d23498ddbc40dcdc60b835a66381ebf0af1df502705c0569b45c385e602`
gets past Function and exposes the missing locale-Date/scrollTo calls. Both
publish active 1024×768 document audits, whole-window PNGs, unchanged inputs
and browser/controller/guard exit zero; neither has the required page content.

After locale/scroll bindings, two original-page attempts exceed the unchanged
12 GiB guard: sampled peaks 12,978,388,992 and 12,952,649,728 bytes, guard exit
125/child exit 137. The first interim audit has 33 rows, README and zero
reported JavaScript errors. Both commit-data endpoints are requested from the
unchanged replay archive. Neither attempt completes capture, so neither passes.
The second omits periodic audits and separately samples the native stack. It
finds repeated bytecode generation during React work; disabling audit polling
does not remove the memory failure.

With realm-local bytecode sharing, the subsequent 30-second original-page
observation completes: **3,705 successful function compilations, 3,584 shared
entries and 24,376 reuses**. Sampled aggregate peak is 7,873,150,976 bytes;
browser/controller/guard exits are zero and input pins remain unchanged. It has
33 rows and README, but zero latest-commit entries/commit links and a call-stack
limit error in React's recursive `uN`/`uC` commit traversal. This confirms cache
execution and an improved bounded diagnostic outcome; it is not a matched
performance result. An optimized diagnostic build is the next check before
attributing that stack failure to engine semantics.

Automated tests remain uncompiled and unrun. Focused regression sources accompany
each feature. Non-test browser builds use the memory guard and 10 GiB V limit.
A separate diagnostic-driver check initially hits that compiler limit; repeating
with the browser's `V3_STR_CAP=1`, `VJOBS=1` configuration succeeds at a sampled
5,474,369,536 bytes. The limit was not raised. The latest available shared
production bundle remains separate evidence and cannot validate later changes
until its consumed-source proof contains them. All unsuccessful attempts remain
local. Compiled full-page execution, control behavior and unchanged Brave pixel
parity still require validation.

The optimized diagnostic (`-cflags -O2`, not a literal V `-prod` production
bundle), SHA-256
`1790f0f0a33495833882110c5f757ea5a7683b7b5b39b2e7772ac7ed0266c23b`,
finishes the 30-second interpreter control with **33 rows, 56 commit links,
latest commit and README, zero JavaScript/native errors and no JSC context**.
All reference audit scalar fields, selection counts, element texts and expected
attributes match exactly. The unoptimized build's stack failure does not recur.
Function-bytecode counters are 4,167 compilations / 4,045 shared entries / 44,436
reuses; browser/controller/guard exit zero, input hashes stay fixed, and sampled
aggregate RSS peaks at 9,954,017,280 bytes. This diagnostic build's C optimization
mode differs from the shared production acceptance protocol.

Its first cached opening blocks the event loop in compilation: the capture
contains 33 rows/README but no commit content, despite zero reported script
errors. The audit records 3,887 compiled executables, four compiler calls,
355,483.844707 ms compilation and 22 still pending. Guard/browser/controller exit
zero with 10,790,043,648-byte sampled peak. A compiler-disabled fresh-process
reopen reaches all required content, with **3,995 native hits and 255 misses**,
146.181623 ms recorded loading and a failed `/usr/bin/false` compile attempt.
It reports zero author-script errors, but cache `last_error` is nonempty and 255
entries remain pending. Its guard/browser/controller exits are zero and sampled
peak is 9,182,183,424 bytes. This pair fails compiler-free second-opening
acceptance; zero successful compiler invocations alone does not mean a compiler
was never requested. The first capture did not finish initial hydration.

`9e86dba0f` routes remaining Fetch/stream/string-timer entry limits through the
owning Host policy and preserves fetch error stacks. `ec9ec4353` bounds each
native compiler batch to 128 executables / 32,768 bytecode instructions (one
oversized function may occupy its own batch); explicit flush still drains every
pending entry. `77b9fd1c9` waits for a one-second quiet interval with no pending
module/Fetch work, then yields to the event loop between batches. Closing stops
the timer and completes remaining compilation. The fresh original-page first
opening now reaches all content before compilation begins; its final reopen
result is still pending. A current-V non-test browser check passes with sampled
6,779,994,112-byte peak. Focused cases remain uncompiled/unrun under the hold.

The unchanged Brave PNG carries **Display P3 Gamut with sRGB Transfer**, while the
native PNG carries **sRGB IEC61966-2.1**. A raw-channel diagnostic comparison of
the cropped native document reports 115,201 / 786,432 differing pixels (14.6486%,
MAE 1.6340). Converting only a derived native PNG into the reference's extracted
ICC profile leaves 107,522 differing pixels (13.6721%, MAE 1.5508); the explicit
zero-tolerance comparison exits one. The original PNGs and reference hash remain
unchanged. These are retained diagnostic comparisons, not pixel acceptance. The
whole-window crop uses the audited 1024×768 document, an 88-pixel toolbar/bookmark
area and 24-pixel status area. Direct document capture and capture-density checks
remain necessary. A relative-date label also differs from the November 15
reference; clock/capture conditions must match before attributing that to JS.

The fresh batched candidate, SHA-256
`9dc5acd23b4cc38d87d092cd8639d30a0b771a2ef684911fc583e8f244ed39f8`,
reaches 33/56 rows/commit links, latest commit and README before compilation.
Its first capture records 3,328 compiled entries / 26 compiler calls /
320,029.212459 ms compilation / 929 still pending. Shutdown finishes those
entries; 4,257 native cache records exist after the first process exits.
The complete lifecycle takes 425.022397 seconds, including the requested
360-second observer delay, capture and remaining shutdown compilation.
Browser/controller/guard exit zero, input pins remain unchanged and sampled
aggregate peak is 12,106,203,136 bytes, below the unchanged 12 GiB guard.

The compiler-disabled second process has the same complete content and zero
JavaScript/native errors, **4,246 native hits, four misses, zero successful
compiler calls and 176.720873 ms loading**. Its cache error reports the attempted
`/usr/bin/false` compiler; the four entries remain pending. Browser/controller/
guard exit zero, unchanged pins, sampled peak 9,194,766,336 bytes. Both attempts
use driver SHA-256
`d2cfbdcdac79dfd41f43b03119b94d36bea377d8c87ca522cdfb56417fae30b6`.
This narrows the cache defect but **still fails** the zero-miss/zero-compiler-
request requirement. The unequal fixed observation delays cannot establish a
matched launch-time speedup. Bounded pending-source diagnostics are the next
step. The separate native document-capture mode now supports a readiness
selector and direct viewport PNG; its pixel result is pending.

### Lazy modules, compiler-disabled reopening and capture grids

Bounded pending-source diagnostics identify four uncompiled functions in the
GHCC consent lazy chunk and `Dg` in `chunk-7d`. Two intervening observations
happen to have 4,250 hits and no misses; they do not erase the earlier failed
pair. A later direct document capture reproduces five misses. Native functions
are now prepared from each dynamically imported module's parsed function table
while the VM is idle, without calling those bodies. Preparation preserves
observed hit/miss counters, yields between batches and reports unsupported
bodies explicitly. The engine and browser changes are `6f7f9d106` and
`bd84e0c81`; regression sources accompany both and remain uncompiled/unrun.

The new diagnostic executable's source proof and raw evidence are retained
locally under `libjs-github-observe-20261116/module-templates-window` in the
benchmark cache; finished scratch receipts are in
`docs/performance/libjs-github-browser-20261116/scratch-receipts/`.
The first process starts with an empty native cache, completes all selected
content with zero errors, and exits with **8,363 cache records / 66 native
libraries**. All five previously missing identities are present. Its sampled
aggregate peak is **11,373,150,208 bytes**, lifecycle **717.493885458 seconds**,
and browser/controller/guard exits are zero. The capture-time audit precedes
shutdown draining: 4,299 observed misses, 4,480 compiled entries, 35 compiler
calls, 484,691.362754 ms compilation and 3,010 pending entries. A separate stack
sample catches the main thread waiting for Clang on a 128-function batch;
bounded batch count does not guarantee a short compiler pause.

The second fresh process uses the same executable and `/usr/bin/false`:
**4,250 native hits, zero misses, zero compiler calls, no pending entries, no
cache error, 226.853961 ms loading**. It retains 33 rows, 56 commit links, latest
commit and README, zero JavaScript/native errors, no JSC context, unchanged pins
and zero browser/controller/guard exits. Sampled peak is **8,399,618,048 bytes**,
lifecycle **37.306369417 seconds**, including the requested 30-second observer
delay. Both fresh processes still parse 83 sources; the frontend cache is
process-local. Unequal observer delays and first-visit compilation prevent
claiming a matched page-execution speedup from these lifecycle durations.

A fresh **headless sRGB** Brave capture matches the compiler-disabled reopen
with **zero differing pixels / zero maximum channel error across 786,432
pixels**, using the existing pixel tool's explicit `0 0` gate. This is additional
diagnostic evidence, not replacement of the historical windowed PNG. Brave's
binary is still `019e37a757d8dca6dadf7d8e2407d90bd52a0ac31a4e5a49d1cf0a444ab3d3d0`,
Chrome `157.0.8103.79`, revision `52886f99c599c22139930531da30c7c8be9f38a`.
The new headless PNG is
`cf9a0f2d58d4b08f286d01d650b6b37add96dcb6b7f605876e7267b079edaa77`;
the native reopened PNG is
`448e8cd56ce4281f612055d58dca607f51a9882b9024d02c8f4dbdad94e20380`.
PNG encodings differ; decoded pixels are exact.

The historical windowed reference remains unchanged. A direct native sRGB
capture converted to its extracted P3 profile still differs at 48,550 pixels
(6.1735%). Read-only paint diagnostics (`a24fc5df9`) show display DPR 1, layout
scale 1 and Chromium font policy. Further fresh Brave observations isolate a
capture-condition difference: the same `.github` text range is **17 CSS pixels
high headless and 16.5 windowed**, although both expose script DPR 1. The
windowed screenshot is P3; the headless screenshot is sRGB. A new windowed Brave
PNG differs from the unchanged historical PNG at only **587 pixels**, all within
`583,705`–`662,718`, the relative-date label that has advanced from “last week”
to “2 weeks ago.” Matching rendering-grid and clock conditions is pending; no
reference, source body or tolerance has been changed.

Native entry/fast/slow counters and post-shutdown cache receipts are opt-in
diagnostics (`9723b4788`), outside timing runs. The first instrumented follow-up
uses a newer binary after shared native-tier/value changes, correctly selects a
new ABI partition and has zero native entries with compiler-disabled misses.
It cannot establish native eligibility or invalidate the earlier pinned pair.
A new cache cohort is required for that binary. Original failing attempts,
including two Brave diagnostic-controller/proxy failures, remain retained.

No automated unit or broad suite has resumed. Non-test root builds and guarded
browser diagnostics provide the evidence above; control interactions, live
validation, the unchanged historical pixel gate and matched performance remain
open.


## Development cache identity and control continuation — 2026-11-16

The rendering-grid first/reopen attempt is retained as a **failed cache cohort**.
Its first process compiles 8,356 executables in 66 Clang invocations, with zero
pending entries or compiler errors at shutdown. Native compilation takes
1,402,211.925206 ms; complete browser lifecycle is 1,439.6342395 seconds and
sampled aggregate peak is 11,265,327,104 bytes. All 30 queued module-template
jobs complete, preparing 4,426 functions and queueing 4,106, without unsupported
functions or preparation diagnostics. Content remains 33 rows, 56 commit links,
latest commit and README, with zero page errors and no JSC initialization.
The compiler-disabled second process instead records **zero hits / 4,272
misses**, and requests the disabled compiler. Its lifecycle is 72.794124625
seconds and sampled peak is 10,075,455,488 bytes. Normal process exits and full
content do not make this cache attempt pass.

Both processes use the same executable, but the selected cache partition changes
from `24c8be60810b8706cccf77ead32675a9c327d087604e73e2fdc611258d079998`
to `03b41df63c4ca9386626e664ceb5612111ce40084ddb7eaaccb086af6c0f0f89`.
Local compiler inspection explains why: without literal V `-prod`,
`$embed_file(...).to_string()` reads current source files at runtime. Shared
native-tier edits therefore changed the ABI of an unchanged diagnostic binary.
The executable/library pins did not cover this extra runtime input. The earlier
successful pair remains an observation under its recorded source conditions,
not evidence that this identity was immutable.

`ba7cd6a57` binds development cache ABI to executable bytes and fails closed if
they cannot be read. Production still hashes its embedded compiler/layout
sources, allowing reuse across unrelated browser rebuilds. Cache audits now
include the actual ABI. No old cache records are copied or relabeled. Its
focused identity regression source is included and remains uncompiled/unrun.
An optimized non-test C browser build succeeds in 274.201277416 seconds, peak
12,500,140,032 bytes; executable SHA-256 is
`ae20aafa27c394ca0f0c3e0842cfe2a3cc5d7930116fcf7f1e28a97744b9f7d2`.
This diagnostic is C `-O2`, not the managed literal V `-prod` acceptance build.
A fresh populated-cache pair is still required for this executable.

### Original clock and unchanged pixel gate

The reference under `libjs-revisit-20261115/reference` was copied after capture;
its copied mtime, previously used as epoch `1794695786712`, was incorrect.
Read-only inspection of the original
`libjs-github-20261114/evidence.tar.gz` recovers the actual PNG member timestamp:
**2026-11-14T15:21:59.568014Z**, epoch **1794669719568 ms**. That archived PNG's
SHA-256 is still `649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
Earlier wrong-clock captures are retained; no reference is changed.

A fresh document-only initial capture with that epoch, media DPR 1, rendering
DPR 2 and layout scale 2 completes all content, reports zero script/native errors
and keeps all input pins unchanged. After converting only the actual sRGB PNG
to the reference's extracted P3 profile, the explicit zero-tolerance pixel gate
**fails: 25,962 differing pixels / 786,432 (3.3012%)**, maximum channel error 164,
MAE 0.0763, RMSE 2.5389; 2,704 pixels exceed channel error 3. The Go to file input
has a remaining horizontal geometry difference. Color quantization, antialiasing
and the search-button shadow also differ. This capture is interpreter-only and
cannot establish compiled-path pixel acceptance or performance.

### Native input reaches additional control code

The initial native-input diagnostic sends actual mouse/keyboard events through
the native document view. Focus changes identify the intended Code and master
buttons, but controls never expand. JavaScript diagnostics (separate from the
native-error array) expose missing `Event.composedPath`, `MouseEvent` and
`window.getSelection`. A zero native-error count alone missed these failures.

Native bindings now use the existing DOM records:

| Commit | Binding |
| --- | --- |
| `c907549f6` | Fresh composed-path arrays, native targets and closed-shadow visibility. |
| `89a811c22` | UIEvent constructor/inheritance, owning Window, detail and descendant which. |
| `123a31ce0` | MouseEvent constructor, coordinates, modifier state and platform-event wrappers. |
| `d53983c36` | KeyboardEvent key/code/modifiers and platform-event wrappers. |
| `e9ac78bc9` | Window/Document getSelection, native range identity and selection state/mutations. |

The non-test root compiler check passes (53.653970416 seconds, sampled peak
6,801,702,912 bytes); focused regression sources accompany each slice and remain
uncompiled/unrun. Selection Range wrappers remain unsupported.

The next native-input process no longer reports those earlier errors. Opening
Code instead reaches GitHub's focus traversal and throws **ReferenceError:
NodeFilter is not defined** from `pb-25305857c53068ff.js:347:20103`. React Router
then replaces repository content with its error state: final rows/commits/latest/
README counts are all zero. No expanded controls are observed. Browser exit 0
and unchanged pins do not establish working controls; the diagnostic controller
now marks this attempt failed and retains every JavaScript diagnostic.
Native TreeWalker/NodeFilter bindings (`657eb47ac`) then remove that missing API.
Their optimized C build succeeds (281.460768333 seconds, peak 12,607,537,152
bytes). The next control process instead reports missing `focus()` and
`getComputedStyle()`, and still reaches React Router's error state.

Raw evidence remains local in
`libjs-github-observe-20261116/{render-grid-window,native-events-selection-window}`
and `docs/performance/libjs-github-browser-20261116/scratch-receipts/`. Automated
suites remain held. Full compiled control behavior, historical pixel equality,
live validation and matched unprofiled performance remain open.


### Focus, computed style and native CSS lifetime

`c4cf803f9` adds native mutable DOMRect/DOMRectList snapshots and element client
geometry; `c9ec625dd` adds native focusing/unfocusing steps, synchronous focus
events, tabindex reflection and preventScroll; `793414061` exposes native element
offset/client/scroll dimensions; `fc657b75d` binds live, readonly native computed
styles. Explicit focusVisible currently retains the existing native document
indication policy. Each slice includes focused regression sources, still
uncompiled/unrun. A non-test root check succeeds in 43.540818584 seconds, peak
6,804,815,872 bytes; its first attempt catches and fixes a reference-field
initializer error before building.

The combined diagnostic C build succeeds in 171.531881666 seconds, peak
12,569,493,504 bytes. Its native-input run is **a crash**, not a control pass:
browser exit **139**, controller/guard exit 1, lifecycle 12.440621917 seconds,
peak 9,876,520,960 bytes. Only the first of five planned actions is delivered.
The last audit still has full content and no script diagnostics; this does not
supersede the abnormal exit. The stack enters `Element.scrollIntoView` from the
new native focus binding, then synchronous layout and
`collect_native_equal_text_inputs`.

A debugger launch stalls before executing the browser, produces no input events
and is stopped; it supplies no runtime validation. A separate, pinned native
signal recorder reproduces the click failure and captures the actual fault
context. The faulting instruction reads the DOM style's mutation state at
collector offset 364; the style handle is `0x0101010101010101`. The captured stack
pointer lies well within the main stack bounds, excluding stack exhaustion for
this failure. Signal-handler instrumentation supplies diagnosis only, with no
pixel or performance credit.

Inspection finds that computed-style property reads can recompute native document
styles while using the caller's transient allocation arena. CSSOM property,
method and index reads/writes now use persistent allocation scopes (`7fba25965`),
including length and computed-style index bounds. A regression source explicitly
checks native style/placeholder ownership across caller-arena reset; it remains
uncompiled/unrun. The non-test root check succeeds (25.17818125 seconds, peak
6,780,452,864 bytes), followed by a diagnostic C rebuild (167.267816459 seconds,
peak 12,494,209,024 bytes). The next valid native-input repeat reaches a second lifetime fault in
`computed_properties_to_dom`, called by anchor-position fallback layout. An
earlier repeat used an unsupported audit depth of six, delivered no actions and
provides no control validation; it is retained with the other attempts.

The input controller now requires all five scheduled actions and the explicit
completion marker before accepting controls, as well as normal browser exit and
observed Code/master expansion with no JavaScript diagnostics. No full compiled
reopen, interaction or historical pixel acceptance is claimed by these builds.


### Anchor-position ownership, font strike grid and the memory gate

`f2960ddde` retains anchor-position fallback state, computed styles, DOM mirrors,
anchor maps and stored option strings across temporary geometry workspaces.
Allocation scopes end before geometry scratch work. A broad earlier ownership
candidate and the final narrower implementation both open Code and master
without script errors, but exceed the 12 GiB aggregate memory guard before all
five actions. These are failed runs, not interaction acceptance:

| Candidate | Guard/child exits | Seconds | Sampled peak RSS bytes |
| --- | --- | --- | --- |
| Broad retained position-try scope | 125 / 137 | 23.317173208 | 12,894,896,128 |
| Narrow scope plus font strike correction | 125 / 137 | 24.976510084 | 12,999,704,576 |

A partial Code-popup diagnosis exits normally at 19.281562875 seconds, peak
10,810,228,736 bytes; its one-second main-thread sample is idle. It does not
complete the full schedule. Branch-picker expansion, rather than a steady idle
Code-popup loop, precedes the large RSS increase. These observations do not
justify assuming an anchor-style cache leak.

`e0b349df7` rounds the text-control average advance on the physical font strike
before projecting to CSS pixels. Fresh original-response Brave geometry measures
Go to file at x=390.1484375, width=156, height=30; the wrapper is x=357.1484375,
width=206, height=32. Vox now matches those measurements; its earlier width was
153 with a 203-pixel wrapper. The font fallback heuristic and measurement source
remain shared platform behavior, without page-specific rules. Focused regression
sources remain uncompiled/unrun.

An initial-document capture after this correction has the complete 33/56/1/1
content audit, zero JavaScript/native errors and no JSC initialization. Its guard
exits zero, elapsed 24.871378292 seconds, peak 9,979,002,880 bytes. After converting
only the actual sRGB PNG to the original reference's Display P3 profile, the
unchanged strict historical gate remains **25,399 of 786,432 differing pixels
(3.2296%)**, maximum channel error **64**, MAE **0.0220**, RMSE **0.5678**;
2,001 pixels exceed error three. The explicit zero/zero pixel gate exits one.
The earlier 25,962-pixel/max-164 result remains historical evidence. No reference
or tolerance changed. Color/blend quantization, antialiasing and the remaining
search-control shadow still need diagnosis; this is not pixel parity.

### Independent parser policy and allocation diagnosis

`b0a4488af` adds an explicit `VOX_LIBJS_FRONTEND_CACHE=on|off` override while
preserving the default policy. `d624a672b` exposes it in the browser diagnostic
controller. This permits syntax reuse in an interpreter control without native
lookup or compilation. The non-test root check succeeds (25.782382459 seconds,
peak 6,811,303,936 bytes); optimized diagnostic C compilation succeeds
(322.646945375 seconds, peak 12,558,008,320 bytes). These private C -O2 builds are
not literal V -prod production acceptance. The frontend regression source is
included but remains uncompiled/unrun; the Python controller passes AST parsing.

The full frontend-only native-input run records **34 syntax hits / 83 misses**,
4,506 compiled bytecode functions and 48,892 reused function bodies. Native cache
ABI, hits, misses and compiler requests all remain empty/zero. Both menus expand
without script errors and content remains complete, but the memory guard kills
the run: guard/child 125/137, 26.819848334 seconds, peak 12,938,838,016 bytes.
No completion marker or final summary is available. Parser reuse alone therefore
does not resolve the memory gate. The RSS series is steady around 9.7 GiB while
Code is idle, then rises after branch-picker input.

A subsequent stack-sampling attempt also hits the guard (22.6155835 seconds,
peak 12,909,330,432 bytes), before a usable sample is written. A lower-overhead
anonymous-mapping probe retains stacks through another guarded failure. Its
reported capacities are virtual mappings, not live allocation totals or RSS;
reusable geometry scopes can map repeatedly. Native allocator restart produces
two image identities, so symbolization uses the final executable image at
0x102cec000, not injected image zero or the pre-restart image. Across the final
process, 2,112 MiB of new mapping capacity has `VM.execute_instruction` as the
first nonallocator frame. Inspection of its generated C confirms an unconditional
`memdup` of the Instruction value parameter on every dispatch, caused by passing
it to reference-taking helpers. Interpreter and native fallback dispatch now borrow executable-owned instruction
records (`6c43920fb`). The first non-test
check catches one obsolete address-of at a callee helper; it is corrected before
repeating the check. No automated test source is compiled or executed.

Local raw evidence, including every failure, is retained under
`docs/performance/libjs-github-browser-20261116/scratch-receipts/` and
`/Users/alex/Library/Caches/Vox/benchmarks/libjs-github-observe-20261116/`.
Fresh current-binary compiled first/reopen, completed controls, the original
windowed zero-pixel gate, live behavior and matched performance all remain open.


### Borrowed dispatch, Escape routing and a corrected interaction claim

The borrowing change passes the non-test root compiler check on its corrected
second attempt (27.834560416 seconds, peak 7,187,365,888 bytes), then an optimized
C browser build (297.648176833 seconds, peak 12,517,982,208 bytes). Generated C
has neither the old Instruction `memdup` in `execute_instruction` nor a copied
instruction in `native_slow_step`. An allocation regression source covers both
paths but remains uncompiled/unrun. One concurrent function-environment change
and a native declaration input also differ from the prior browser proof, so the
memory difference is not an isolated performance attribution.

The next full input schedule delivers six actions, including separate m/a keys,
and records the branch input's **value attribute** changing to `m`, then `ma`.
This is not yet the native-model value audit. Both menus expand and no script
errors appear, but the guard kills the process at 38.157388875 seconds, peak
12,959,514,624 bytes (guard/child 125/137). All delivered actions alone cannot
establish successful control behavior. A separate 36-second mapping diagnosis
exits normally with stable pins (37.386566958 seconds, peak 12,873,121,792 bytes),
but its screenshot still shows the branch picker open after Escape. Its earlier
controller's `controls_accepted=true` field used the incomplete opening/delivery
gate and is explicitly **not accepted** here. The full 60-second gate is retained.

Inspection finds that browser editing dispatch consumes unmapped keys when an
input has focus; Escape never reaches page listeners. Escape now reaches the
active document before editing defaults, while browser-owned shortcut/address
handling retains precedence. A new read-only input audit (`50f3dd30c`) observes
only existing native models, without initializing controls or emitting events.
The corresponding source check succeeds after correcting an Element-versus-
HTMLInputElement field access (36.843781542 seconds, peak 7,201,357,824 bytes),
and the optimized browser build succeeds (217.968861917 seconds, peak
12,529,664,000 bytes). No `_test.v` source appears in the parsed-buffer proof.

**Correction to the progress update and `50f3dd30c` commit message:** this build
closes Code, but the new return-focus path scrolls the document by 313 pixels.
The next fixed-coordinate click therefore misses master; there is no native
branch-input value sample and no verified native `ma` input in this run. The
commit message's assertion of that observation is incorrect. All pinned launch
inputs still match after the guard stops the process at 44.14927625 seconds,
peak 12,945,211,392 bytes, guard/child 125/137. No script errors appear, but neither
that fact nor empty expanded-control arrays establishes the full sequence.

A fresh Brave CDP interaction diagnosis on the unchanged replay closes both
menus with Escape and reads actual branch input value `ma`. Its branch input is
x=196.8984375, y=67, width=270, height=30, matching the earlier Vox geometry.
Browser/controller/guard exit zero and all pinned inputs match. CDP input is
separate functional reference evidence, without native-input or performance
acceptance credit. Its screenshots do not replace the original pixel reference.

The native focus bridge had called default scrollIntoView (block start), unlike
upstream Focus.cpp's nearest/nearest reveal policy. It is being corrected to
leave an already visible target still, skip redundant focus and avoid scrolling
a target whose focus handler redirected focus. The corrected run must actually
open the branch picker and read its native model before claiming input success.

A post-dismissal mapping probe attributes 1,145 MiB of new mapping capacity to
SVG/shape tile callbacks, mostly through native frame replay. Deferred pictures
and UI2 chrome can invoke those callbacks after the ordinary document replay
workspace has ended. The callbacks synchronously copy their result into
caller-owned pixels, but their result/tile arrays otherwise enter the surrounding
long-lived arena. Each exported raster callback is being given a temporary
thread workspace, including rejected draws; existing GPU context initialization
already redirects its retained state to persistent storage. This remains a
candidate under non-test checking and original-page diagnosis, without a memory
or pixel pass. Mapping capacity is not RSS or a live-byte count.

The shared-index audit also finds that `50f3dd30c` contains concurrently staged
updates to OPTIMIZED_SITES.md and two rendering reports in addition to the three
input-audit files. Those updates were not authored by this continuation; shared
linear history is preserved. Subsequent commits of wholly owned files use an
explicit path list to avoid consuming another session's staged files.


### Full interpreter control sequence completes

`c8ef90374` applies nearest focus reveal and avoids scrolling a redirected or
already focused target. `fe20abd4f` reclaims synchronous native raster callback
work even outside the frame replay workspace. Both have focused regression
sources, still uncompiled/unrun. The non-test root check succeeds in
36.281749125 seconds, peak 7,188,430,848 bytes; the optimized C browser rebuild
succeeds in 207.297199042 seconds, peak 12,534,349,824 bytes. Its verified parsed
manifest contains 3,728 source files and no `_test.v` files. The latest completed
shared production bundle is still SHA-256 7515422c0006a9451ea33a2d7d2f71f15e98cfb9865ef4aa27f4c50b82b7d4e4
(from request 7fba25965); it cannot exercise these later fixes. Normal commit
hooks coalesce their production rebuild requests.

The **unchanged full 60-second interpreter observation now completes**:

- Browser/controller/guard exit zero; no changed pinned inputs.
- Native mouse/keyboard input opens Code, closes it with Escape, opens master,
  types m and a separately, and closes master with Escape. All six actions and
  the explicit completion marker are recorded.
- The new native input-model audit reads `m`, then **`ma`**, with selection
  offsets one and two. The final expanded-control and visible-overlay lists are
  empty. Master remains at y=261, avoiding the earlier 313-pixel viewport jump.
- All 33 rows, 56 commit links, latest commit and README remain present; the
  complete frozen Brave content audit matches exactly. No JavaScript or native
  errors appear.
- Guard elapsed 61.771742042 seconds, sampled aggregate peak **12,336,431,104
  bytes (11.49 GiB)**. This establishes the full diagnostic interval under its
  12 GiB guard; it is not a long-duration bound or isolated optimization claim.

This run explicitly disables native execution and enables frontend caching.
It therefore establishes control behavior only, not compiled control acceptance.
The fixes share one diagnostic binary, and host/source contention is recorded;
no timing improvement is attributed from these runs.

A fresh native cache is now being populated by that exact immutable executable,
using the original replay, correct historical Date origin, render grid two,
frontend cache on and an active document-only capture. The initial capture has
an exact complete content audit and zero page errors. Its native ABI is
964b367e4da21eb9b4b5ddb24bc5563f85e2ecf97ea034ca660b41a4a9daef9c;
the capture observes compilation in progress, and shutdown must finish the
remaining module templates and compiler batches before reopening. No warm result
or speed claim is available yet.

The new first-opening PNG, converted only on the actual side to the original P3
profile, retains exactly the same strict mismatch statistics: **25,399 pixels,
maximum error 64, MAE 0.0220 and RMSE 0.5678**. The zero/zero gate exits one;
reference SHA-256 remains 649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3.
The memory/interaction changes introduce no change to this diagnostic image,
but the historical pixel goal remains unachieved. Full native reopening and
controls, live behavior, historical zero-pixel equality and matched performance
are still required. Finished job receipts are archived with verified hashes and
symlinks under `scratch-receipts/continued-20261116-r4` and `-r5`; the running
native-cache job remains in Build until completion.


### Fresh native cache reopen and injected-image identity follow-up

The bounded-control executable completes its fresh original-page cache cohort.
Its final first-opening audit contains **8,351 compiled executables, 66 successful
compiler invocations, zero pending entries, zero invalid entries and no cache
error**. All 30 requested lazy module preparations complete, covering 4,426
function templates with 4,106 new entries and zero unsupported functions.
Recorded compiler time is 806,599.218709 milliseconds; the guarded lifecycle is
836.441192667 seconds, peak 9,865,281,536 bytes. Browser/controller/guard exit zero
and every pinned input remains unchanged.

The **same executable's fresh compiler-disabled reopen** has **4,245 native cache
hits, zero misses, zero compiler invocations, zero invalid entries and zero
pending entries**, with no cache error. Native library loading records
789.274276 milliseconds. Browser/controller/guard exit zero; lifecycle
39.510249542 seconds includes the fixed 30-second observation interval and
capture/teardown, and peak RSS is 8,605,974,528 bytes. Complete frozen content
matches exactly and no script/native errors occur. Both captures retain the same
25,399-pixel historical mismatch, max 64, MAE 0.0220 and RMSE 0.5678, with strict
pixel gate exit one and unchanged reference. This one functional pair does not
establish isolated JS speed or matched browser performance.

The following injected native-input eligibility run **fails compiled acceptance**
even though all control checks pass: no native entries execute, 4,746 cache misses
appear, 4,802 entries remain pending and `/usr/bin/false` produces a compiler
error. The successful-compilation counter remains zero; it does not prove that
no failed compiler request occurred. The controller explicitly rejects this
result. JSC remains uninitialized, so executing the controls through the
interpreter does not establish compiled control execution.

The cold/plain reopen ABI is
964b367e4da21eb9b4b5ddb24bc5563f85e2ecf97ea034ca660b41a4a9daef9c,
but the input run selects c6026dacefc02ca8e31de62ade5060bf9062ffd09bc385b964ed73e5c9e35b00.
The exact executable and injected-library bytes independently reproduce those
two ABI hashes. Current V's macOS `os.executable()` returns
`_dyld_get_image_name(0)`, which names the injected input library in that launch.
The development cache identity fix is being completed with `_NSGetExecutablePath`
and a checked, canonicalized process-executable path; lookup fails closed if the
path cannot be obtained. Production's embedded source identity remains separate.
No old cache is relabeled or copied. A focused injected-image regression source
is added but remains uncompiled/unrun.

The other coverage boundary is now explicit: only dynamic-import roots had
queued uncalled templates. Initial and statically imported JavaScript modules
now queue their function tables too, without running those bodies or changing
import evaluation order. A focused static-dependency first/reopen regression
source is included, still uncompiled/unrun. Non-test root checks pass for the
identity fix alone (38.958534875 seconds, peak 7,195,639,808 bytes) and both changes
(39.109591583 seconds, peak 7,192,838,144 bytes). Their optimized browser rebuild
and a new native first/reopen/control diagnosis remain pending.

The SVG edge geometry diagnosis finds identical header search SVG viewports in
both engines: x=773.7578125, y=26, width=height=16, and Brave's screen transform has
identity scale with that translation. Its path bounds differ: Brave reports
x=774.7588500976562, y=27.001007080078125, width=14.018310546875,
height=14.017444610595703; the native audit reports conservative conic-control
bounds. Existing Chromium-mode path conversion already rounds relative operands
in float32; that behavior must not be duplicated or replaced based on the edge
mismatch alone. A first Brave query incorrectly calls SVGMatrix.toJSON and fails;
the corrected read-only query records scalar matrix fields and exits normally
with unchanged pins. Neither query changes the historical reference.


### Full-module compile guard and temporary compiler storage

The executable-identity/all-static-module diagnostic browser builds successfully
in 180.352651459 seconds, sampled aggregate peak 12,568,838,144 bytes. Its parsed
manifest covers 3,729 sources and no `_test.v` files. A separate injected-image
identity observation confirms ABI
480a41bcafb34bf8761e768ff65c1fe43bcc231a8776b18a4a93f6cf3b31061e,
exactly the hash derived from the actual executable despite the input probe
being dyld image zero. That observation deliberately uses an empty cache and no
actions: it proves identity only and fails the compiled-control gate.

The new full-module first opening **fails the 12 GiB memory guard** after
1,280.984547 seconds. Controller exit is 137, guard reason memory_limit, sampled
aggregate peak 12,885,475,328 bytes against 12,884,901,888. It leaves 21,888 cache
records, 171 libraries and an interrupted compiler job. No final cache audit or
controller summary exists. At capture, all 81 module records are requested, but
preparation and compilation are incomplete. The complete content audit and zero
page errors at that early capture do not make the first opening successful. Its
partial cache is retained separately and receives no acceptance credit.

The synchronous native compiler previously put C-source builders, temporary
strings, process diagnostics and library-hash input in the surrounding prealloc
arena across batches. `1690dec4f` gives that operation a temporary workspace and
copies only the loaded entry array, library path and digest into caller-owned
storage after leaving it. Failure messages are copied before releasing their
workspace. The OS owns dlopen mappings independently; selected executable state
is read-only, with validation completed by callers before this boundary. A
non-test root compiler check passes in 30.775948792 seconds, sampled aggregate
peak 7,193,378,816 bytes. Focused success/error lifetime and repeated-batch memory
regression sources are included, still uncompiled/unrun. The new browser build
and a fresh full-module cohort are pending; no old cache is renamed or copied.

The host also exhausts disk space during this continuation. Thirty-six obsolete
generated diagnostic C files in the continuation's external cache are removed
after retaining sizes and SHA-256 hashes; canonical sources, binaries and
measurement receipts remain. This releases 3,789,740,749 bytes. Finished Build
jobs are archived with recursive hashes and symlink verification under
`scratch-receipts/continued-20261116-r6` (46 entries); the interrupted full-module
job remains separate until its failure receipt is archived.


### Compiler workspace build, failure lifetime and rejected MSAA experiment

The workspace browser builds successfully in 172.358018084 seconds, sampled
aggregate peak 12,534,071,296 bytes. Its parsed manifest contains 3,729 sources
and no `_test.v` files. Executable SHA-256 is
c3c8fb58ac32ac53560adeedeb980195a275c0e6ecd70f3251861fe225563f98;
its native ABI is d46bb8de112ee7692e050307638250a2426ee0ddec423d146e8b893d484feaa2.
A fresh all-module first opening is running with an empty ABI partition and the
original 12 GiB guard. Its early capture has exact complete content and no page
errors. The PNG remains byte-identical to the earlier first/reopen captures
(SHA-256 05ede3eae524f64796fe08bfa6406c6703006026387a94d816d3e832807cbb70).
Final completion and warm native-control acceptance remain pending.

A **separate original-page failure diagnostic** uses this executable with an
empty cache and `/usr/bin/false`. It closes normally, preserves the complete
exact Brave content audit and reports no author/native page errors. The retained
cache error is still `Native compiler exited 1: ` after later script/raster work;
zero native executables are compiled. Browser/controller/guard exit zero,
elapsed 40.818625125 seconds, sampled peak 8,462,499,840 bytes. This exercises
error-message ownership and interpreter fallback after temporary compilation
storage is reclaimed; it supplies no compiled or performance acceptance.

The SVG coverage investigation first verifies that a fresh Brave header and the
search/avatar/commit/Code regions match the unchanged original reference exactly.
The browser reports GraphiteDawnMetal and maxMsaaSamples=8. The white search icon
has eighth-coverage gray levels in Brave versus quarter levels in Vox, prompting
a counterfactual eight-sample GG context experiment. Its patch, executable and
sealed source proof are retained locally. Both captures use the same experimental
executable, original response, historical clock, grid two, frontend caching and
native execution disabled. Both preserve the complete exact content audit, have
no page errors and exit normally with unchanged pinned inputs.

| Internal MSAA | Strict differing pixels | Maximum channel error | MAE | RMSE | Sampled aggregate peak |
| --- | ---: | ---: | ---: | ---: | ---: |
| 4 (control) | 25,399 | 64 | 0.0220 | 0.5678 | 8,154,628,096 bytes |
| 8 (counterfactual) | 26,378 | 96 | 0.0527 | 1.0632 | 8,152,334,336 bytes |

Both zero/zero pixel gates fail. The four-sample raw PNG is byte-identical to the
existing diagnostic image. Eight samples introduce 108 differing pixels in the
previously exact GitHub mark and still leave 79 search-icon pixels different,
with maximum search error 64. The global eight-sample candidate is **rejected
and removed from the canonical implementation**; no default, reference or
tolerance changes. Simple adjacent-pixel filtering also fails to explain the
search coverage. These findings do not establish an alternative renderer fix.

The experimental non-test browser check passes in 43.550800875 seconds, peak
7,206,191,104 bytes; its C build passes in 211.206327042 seconds, peak
12,583,649,280 bytes, with 3,730 parsed sources and no tests. An initial build-tool
check omits `-b c` and fails because the repository selects FastC; the explicit
C-backend check passes in 0.680860375 seconds, peak 206,749,696 bytes. The first
color conversion uses a nonexistent sips option and fails before comparing
pixels; the corrected conversion uses `--matchTo` with the original extracted
profile. Both failures are retained. Independent production compilation runs
during these functional observations, so no timing attribution is made.

Finished job data, including the interrupted full-module cohort and both
counterfactual images, move with verified recursive hashes/symlinks to
`scratch-receipts/continued-20261116-r7` (32 entries). The active fresh cohort is
left in Build. Thirty-six more obsolete private executables are removed after
retaining their sizes and SHA-256 hashes, releasing 1,352,163,168 bytes; current
executables and the latest comparison baseline remain. Automated suites remain
held, and newly written regression sources remain uncompiled/unrun.


### All-module first/reopen completes; controls reveal synthetic initializer gaps

The compiler-workspace executable completes its fresh all-module first opening
under the unchanged 12 GiB guard: **23,669 compiled executables, 185 successful
compiler invocations, zero pending/invalid entries and no cache error**. All
81 requested module preparations finish, with 25,412 reported prepared functions,
19,424 newly queued functions and zero reported unsupported functions. Those
counts cover the ordinary function table; the later interaction exposes omitted
synthetic initializer bodies, so this is not a claim that every callable body
was prepared. Compilation records 1,389,924.803132 milliseconds and library
loading 40,285.051243 milliseconds. Browser/controller/guard exit zero, elapsed
1,457.510650291 seconds, sampled aggregate peak **11,099,521,024 bytes (10.34 GiB)**.
No pinned inputs change. The earlier 21,888-record memory failure remains retained.

The same executable's fresh compiler-disabled reopen records **4,245 native hits,
zero misses, zero pending/invalid entries, zero compiler invocations and no cache
error**. Loading records 1,011.903766 milliseconds; browser/controller/guard exit
zero, elapsed 39.684485125 seconds, peak 8,738,488,320 bytes. Both complete content
audits match the original Brave audit exactly with no author/native errors.
The two PNGs are byte-identical to each other and the previous image, SHA-256
05ede3eae524f64796fe08bfa6406c6703006026387a94d816d3e832807cbb70.
All shared pinned inputs match across the pair. The historical pixel gate remains
25,399 differing pixels, maximum 64; no pixel acceptance or isolated timing
credit is earned. The first lifecycle includes compilation after capture.
PNG filesystem write timestamps relative to the controller's host-before wall
clock are 47.022697687 and 38.755912781 seconds, respectively; both include a
fixed 30-second observation. These single-pair diagnostics and contended host
loads do not establish a matched performance result.

The following full native-input sequence **fails**. Its ABI correctly remains
d46bb8de112ee7692e050307638250a2426ee0ddec423d146e8b893d484feaa2
under input injection. Before the guard terminates it, the audit records 4,676
native hits and actual execution of **849,296 native entries, 24,362,017 fast
steps and 14,694,726 slow steps**, with JSC uninitialized. Two bodies miss:
`priority` at function:243947:243947:true:false and `#r` at
function:244900:244917:true:false, both in pb-25305857c53068ff.js.
`/usr/bin/false` reports a compiler failure; the successful-compilation counter
of zero does not mean no failed compiler request occurred. Those entries remain
pending. The 12 GiB guard kills the process before final Escape/completion:
34.106804667 seconds, peak 12,906,774,528 bytes, controller 137/guard 125. No final
controller summary exists, and this is neither complete control nor compiled
acceptance despite the substantial native execution observed.

`698a407e9` now traverses the synthetic field-initializer and static-block records
emitted into module/function bytecode, recursively including nested classes.
It compiles those bodies without evaluating author expressions, class side
effects or computed keys. The anonymous-function name placeholder supplies a
constant slot only; actual invocations read their own property key, including
Symbols. A focused first/reopen source covers side effects, public/private fields,
computed Symbol names, static blocks and nested class fields; it remains
uncompiled/unrun. The first non-test check fails on the retired experimental GG
adapter left in generated modules. Managed staging removes that adapter
(`34a4c0e96`); the corrected root C check succeeds in 31.872546375 seconds, peak
7,469,154,304 bytes. Its separate literal V -prod single-unit C build succeeds
in 317.059106958 seconds, peak 12,764,823,552 bytes; it is not a browser execution
result.

### Warm native lookup ownership and the next fresh production-mode cohort

A separate native branch mapping-stack diagnostic reproduces the guard failure
at 34.459935916 seconds, peak 12,901,269,504 bytes. It records 1,599 anonymous
RW mapping events totaling 3,781,553,984 capacity bytes after branch opening;
2,628,710,208 bytes remain mapped at termination. These capacities are neither
live-byte nor RSS attribution. The probe verifies the actual executable image
across allocator-policy exec and does not use dyld image zero for symbolization.
Observed sites include layout relayout snapshots, glyph-run cloning and raster/
backdrop-filter work; no single cause or isolated memory saving is established.

Source inspection also finds that native cache lookup retains decoded records
and entire library-file inputs to digest checks in its surrounding prealloc
arena. The completed partition contains 185 libraries totaling 87,971,224 bytes.
`3476d907a` makes that synchronous lookup temporary, then retains only owned
library identity strings and the OS mapping owner after leaving the workspace.
A newly opened library with a missing symbol is closed before returning its
owned error, rather than being retained without a usable entry. Focused repeated
lookup, owner/error lifetime and missing-symbol regression sources are included,
still uncompiled/unrun. The non-test root C check passes in 53.403152041 seconds,
peak 7,474,135,040 bytes. No RSS improvement is attributed from inspection alone.

The combined literal V -prod single-C-unit diagnostic browser builds in
309.032466042 seconds, sampled peak 12,027,150,336 bytes, with 3,733 parsed sources
and no tests. Its executable SHA-256 is
e66828fe55aafd90fcffc05bbbb088ef971cd91811176e994bddbd805082d35e,
and its production source ABI is
3a8e5e6a914cd6a22e8427e537e7859c6a12adb397f19edefa365fdcc0432725.
It begins a fresh cache partition with the original response/clock/grid and the
unchanged 12 GiB guard. Early capture is complete and error-free; final first/
reopen/control results remain pending. No old partition is copied or relabeled.
Production's immutable embedded source identity allows unrelated rendering
rebuilds to reuse compatible native code, unlike development's whole-binary
identity. The shared managed worker remains responsible for normal publication;
this private bundle is needed because the latest completed shared bundle still
predates these fixes.

Disabling Brave's small-path-atlas feature in another fresh original-page
counterfactual leaves the header pixel-identical to the original reference. It
does not establish a small-path-atlas explanation for the search edge mismatch.
Neither the original references nor comparison tolerances change. Four completed
older generated C files are removed after retaining hashes/sizes and source
proofs, releasing 540,464,802 bytes as shared host disk space tightens again.


### Production cache decoder failure and bounded invocation records

The completed `cache-load-window` first opening renders exactly the original
Brave content audit, with no author/native errors and unchanged input pins.
It prepares all **81 modules, 25,643 bodies (including synthetic initializers),
19,533 queued templates and zero reported unsupported bodies**. Final draining
records **23,778 compiled executables, 186 compiler invocations, zero pending or
invalid entries and no cache error**. Compilation records 1,379,919.561493 ms;
loading records 40,079.175337 ms. The browser/controller/guard all exit zero;
guard elapsed is 1,446.227871583 seconds and sampled aggregate peak is
11,173,871,616 bytes, below the unchanged 12 GiB cap.

Its fresh compiler-disabled reopen **fails**, browser exit 139, controller one,
guard completion in 2.834923875 seconds, peak 1,261,436,928 bytes. Pins remain
unchanged, but there is no audit or PNG. The stack enters
`json2__Decoder__next_decoded_struct_field` from native cache loading during
module initialization. This is a deterministic decoder ownership failure, not
an AppKit launch retry. JSON2's typed decoder retains a per-type field cache;
initializing it inside the temporary lookup arena and freeing that arena leaves
cached metadata dangling. The earlier compiler-disabled success belongs to a
different binary and does not validate this candidate.

`f6c96dbc0` narrows temporary lookup storage to library-file bytes and SHA-256
work. Record decoding and mapping setup remain in caller storage, with owned
returned digests/errors. Record fields are decoded through Map/Any with explicit
field/type/range checks, avoiding typed reflection-cache initialization. The
missing-symbol handle-close fix remains. The root non-test C check passes in
30.4366205 seconds, sampled peak 7,478,607,872 bytes. Regression sources cover
record/owner/error lifetimes and repeated 1 MiB digest input, but remain
uncompiled and unrun under the user's hold.

`d7b59b4af` replaces per-entry native callback-record allocation with one stable
record per maximum active native depth. Reentrant calls receive distinct records;
release verifies LIFO order and clears source, error and control state. Generated
C confirms that record allocation occurs only when the pool grows, rather than
on every native entry. The non-test root check passes in 36.422551375 seconds,
peak 7,472,349,184 bytes. Standalone non-test CLI C generation and compilation
also succeed (4.033222375 / 12.136096667 seconds, sampled peaks 731,021,312 /
1,015,791,616 bytes); that CLI is never executed. Focused bounded-growth and
nested throw/return sources remain uncompiled/unrun. A transient earlier root
check fails on an immutable argument in a concurrent argument-buffer change;
the corrected canonical source passes. The separate bounded argument-buffer
implementation is `ebf6894b3`.

The first corrected-browser build fails because Clang's temporary object file
runs out of disk space: 123.864221334 seconds, peak 12,019,351,552 bytes, compiler
and guard child exit one. After hashing and removing this session's completed
generated C outputs, a fresh literal V `-prod`, single-C-unit retry succeeds in
206.389120875 seconds, sampled peak 11,993,464,832 bytes. Parsed-source proof lists
3,735 sources and **zero test sources**. Executable SHA-256 is
`046c1341685e61c6ccd5f05a69c50014d4fb62f0a4c8fb630924fd4381ee524d`;
its fresh production ABI partition is
`ecff4d2f520c528fa405f54897a75d69f7659a33bf5d69a1d1357f52b410f264`.
No prior ABI partition is relabeled or copied.

A separate fresh process reads that **incomplete, actively compiling cache**
with `/usr/bin/false`. It completes the exact original content audit without
page/native errors or a decoder crash, with 251 cache hits and 4,014 expected
misses. It retains the failed compiler-request error and 3,994 pending entries;
zero successful compiler invocations is not compiler-free acceptance. Browser,
controller and guard exit zero, unchanged pins, 38.180261792 seconds and
8,385,871,872-byte sampled peak. This diagnoses decoder survival only. The
normal first opening must finish before its acceptance reopen and control
sequence. No timing or memory saving is attributed from these partial-cache
observations.

### SVG origin counterfactuals and the filtered foreground boundary

A same-executable, original-page diagnostic compares existing SVG root snapping
with an unrounded origin. Both complete exact content audits, no page errors,
unchanged pins and normal exits. After converting only derived actual PNGs into
the original reference's extracted P3 profile, the strict `0 0` comparison is:

| SVG origin | Different pixels | Maximum channel error | MAE | RMSE |
| --- | ---: | ---: | ---: | ---: |
| Existing rounded origin | 25,399 | 64 | 0.0220 | 0.5678 |
| Unrounded origin | 25,541 | 128 | 0.0362 | 0.9954 |

The unrounding experiment is removed from canonical source. A separate 2x
raster/capture-density observation, averaged into a derived 1x diagnostic PNG,
also worsens the strict comparison: 51,496 pixels, maximum 133, MAE 0.8115,
RMSE 5.6591. Its full content audit matches; guard/browser/controller exit zero,
elapsed 37.269024792 seconds, sampled peak 7,994,130,432 bytes. Neither resampling
nor a changed density supplies pixel acceptance. The original reference,
fixtures, tolerance and production snapping are unchanged.

Fresh Brave read-only style diagnostics identify `backdrop-filter: blur(20px)`
on the search button, with no SVG/ancestor transform or opacity reduction. In a
separate counterfactual capture, disabling only that button's backdrop filter
makes its 16x16 search icon **pixel-exact with the existing native icon**. The
untouched initial Brave icon remains pixel-exact with the historical reference;
the difference is confined to this independent filtered-foreground diagnostic.
This points to compositing rather than author JS or an unconditional SVG origin
change. The counterfactual is not a replacement reference or a live-site fix.

An initial LayerTree snapshot attempt sees stale pre-navigation layers and
returns “No layer matching given id found”; that failed attempt is retained.
Enabling LayerTree after hydration obtains the actual picture: a backdrop-filter
layer with physical translation **(1521,32)** and dimensions **85x72** on the
2x presenting grid. Its command log translates by one physical pixel, then draws
the SVG with scale two and translation (26,20). Thus the picture origin is
**x=760.5** at 1x capture, while the SVG's resulting global paint origin remains
x=774. The native foreground currently loses the fractional picture phase.
A guarded disjoint-SVG phase experiment is underway; it is not yet a production
fix or pixel acceptance. All automated tests remain held.


### Corrected production first opening, compiler-disabled reopen and native controls

The `decoder-lifetime-window-r2` first opening completes its fresh ABI partition
without borrowing an older cache. Final results are **23,778 compiled entries,
186 compiler invocations, no pending/invalid entries and no cache error**.
All 81 requested modules finish preparation: 25,643 bodies, 19,533 queued
uncalled templates, zero reported unsupported bodies or preparation diagnostics.
Compilation records 1,217,822.200678 ms and loading 38,720.570334 ms. Browser,
controller and guard all exit zero, unchanged pins; guard elapsed is
**1,275.431115542 seconds**, sampled aggregate peak **10,913,251,328 bytes**.
The exact original content audit passes with zero author/native errors.

A **fresh compiler-disabled reopen** with the identical executable and cache
records **4,245 native hits, zero misses, zero pending/invalid entries, zero
compiler invocations and no cache error**. Recorded native loading is
650.474350 ms. Browser/controller/guard exit zero, elapsed 38.78540275 seconds,
sampled peak 8,478,294,016 bytes. The exact original content audit passes with no
errors, and the first/reopen PNGs are byte-identical:
`05ede3eae524f64796fe08bfa6406c6703006026387a94d816d3e832807cbb70`.
The unchanged strict windowed-reference gate still has 25,399 differing pixels
before the separate compositor-phase candidate. The 30-second observer is
included in both launch/capture lifecycles; the first lifecycle also drains
compilation after capture. These durations establish neither an isolated native
execution speedup nor matched performance acceptance.

The same corrected executable then completes the **entire 60-second native
mouse/keyboard observation**, with `/usr/bin/false` as compiler. Code and master
menus are both observed open; the branch input receives native value `ma`; all
six actions and their completion marker arrive. Final menus/visible overlays
are closed. The terminal exact content audit retains all 33 rows, 56 commit
links, latest commit and README, with zero author/native errors. Controller
`controls_accepted` and `compiled_controls_accepted` are both true.

That sequence has **4,690 cache hits, zero misses, zero pending/invalid entries,
zero compiler invocations and no cache error**. Actual native counters record
**868,401 entries, 25,149,987 fast steps and 15,041,224 slow steps**; JSC stays
uninitialized. The two previously missing synthetic field bodies no longer
miss. Native loading records 646.676358 ms. Browser/controller/guard exit zero,
unchanged pins, elapsed 61.41013075 seconds, sampled aggregate peak
**12,646,662,144 bytes (11.78 GiB)** under the unchanged 12 GiB cap. This is a
complete interaction checkpoint, with little memory headroom, rather than a
long-duration memory bound or a native speed claim. The separate mapping probe,
earlier failed controls and decoder crash remain retained.

All 28 shared executable/native-library/archive pins agree across this
first/reopen/control cohort. The first/reopen diagnostic observer hashes also
agree with the current canonical driver:
`019574fce1afd03f0741b2bb0d74d639fe977d7903c08e21c6404be5a873e544`.
The selected runtime is LibJS, module evaluations are fulfilled and the native
context flag remains false. The earlier failed ABI partitions have since been
removed for disk space after preserving all 47,818 file hashes and sizes in the
local `superseded-native-cache-cleanup-20261116.json` manifest. Their browser
executables, parsed source proofs and observation receipts remain; the new
successful partition is retained unchanged.

### Fractional compositor origin and coverage-precision continuation

The first guarded phase build passes non-test root checking and builds from
3,737 sources with zero tests: 217.700182542 seconds, sampled peak
11,993,645,056 bytes. Same-binary phase-off/on captures both reproduce exactly
the existing native PNG and strict 25,399-pixel mismatch. No phase-publication
marker appears, so this is an **ineligible fast path**, not a rendering gain.
A separate retained layer diagnostic identifies the missing state: the layer
plan encloses fractional bounds before replay receives the origin.

`8bb72fd6b` retains each independent effect picture's raw origin before that
enclosure, clearing it on reuse. A focused fractional filtered-picture/plan-reuse
regression source is included but remains uncompiled/unrun. The corrected
non-test check passes in 43.341212709 seconds, peak 7,474,577,408 bytes. Its
literal production-mode diagnostic browser builds in 228.96337525 seconds,
peak 11,996,102,656 bytes. The guarded rendering path now explicitly records
origin **760.7578125**, presenting scale two, capture scale one and raster phase
**(0.5,0)**, matching the independent Brave picture-log geometry.

That original-page observation completes the exact content audit with no errors
or changed pins; browser/controller/guard exit zero, 37.42005125 seconds,
8,068,268,032-byte sampled peak. The strict unchanged-reference comparison
improves to **25,349 differing pixels, maximum channel error 43, MAE 0.0185,
RMSE 0.3819**, with zero pixels over 50. All 83 search-icon pixels previously
over three levels are corrected. Its remaining 33 differing pixels are exactly
**159 versus 160 (18 pixels) and 191 versus 192 (15 pixels)**. The GitHub mark
stays pixel-exact. The complete page still fails pixel acceptance.

These residuals follow from interpolating already rounded four-sample alpha:
5/8 coverage should become 159, while averaging encoded 128 and 191 gives 160.
The next candidate recovers the known four-sample count only for an opaque solid
curved fill whose every stored channel matches that paint/count encoding, then
interpolates before final byte rounding. It declines gradients, clips,
translucency and mixed-path recovery. This is a precision experiment, not a
claim about Brave's internal texture format. Its non-test root check passes in
39.735511125 seconds, peak 7,478,837,248 bytes; production build/observations are
pending. A disk-full patch attempt leaves the source unchanged; finished own
C output is hashed before removal and the patch is reapplied after recovery.
No automated tests have resumed.


### Completed compositor, PNG and border corrections

The clean precision build (`compositor-phase-window-r4`) seals 3,740 parsed
sources, with zero test sources, before building the single C unit with literal
`-prod`. It completes in 276.300314708 seconds, sampled peak 12,014,649,344 bytes.
Its executable is SHA-256
`cbefd013727b734c93baf9b9fd505a9dff6829cd0c3e36fb5838ab2c2c78ffee`.
Matched same-binary off/on observations preserve the exact original content and
all pins, with zero author/native errors and normal browser/controller/guard
exits. The precision correction makes the search icon **pixel-exact** against
the original Brave reference. The full page still differs in 25,316 pixels.

The earlier `r3` build is rejected: a C retry reads four changed V buffers,
including the generated GG image adapter. The final source manifest disagrees
with its sealed proof. Its executable is never launched and is renamed
`Vox.unverified-source-buffers`; the failed build and rejection receipt remain.
The clean `r4` result does not erase that failed attempt.

`8cb27505d` enables the SVG correction by default. A fresh default-path browser
builds from 3,741 non-test sources in 334.708281958 seconds, sampled peak
12,015,845,376 bytes. Its original-page capture reproduces the candidate PNG
byte for byte, with full exact content, unchanged pins, zero errors and normal
exits. This verifies the production selection independently of the diagnostic
switch. Disjoint foreground or uniform opaque backgrounds are eligible;
complex overlaps retain the existing path. Focused regression sources remain
**uncompiled and unrun**.

`12fc9e48b` folds a positive uniform capture transform into the PNG destination
and rounded clip **before choosing decoder dimensions**. Previously the 0.5
capture matrix declined the V sampler and used a different native resize.
Original-page eligibility logs show the 40×40 commit avatar decoding to 20×20
and painting at 9×20, (46,326.5), and the 60×60 repository avatar decoding to
30×30 and painting at 24×24, (32,190). The DOM geometry is unchanged; Brave's
independent picture log confirms the fractional commit-avatar paint position.

The PNG candidate passes a non-test root compiler check (50.448110791 seconds,
7,479,427,072-byte peak), then builds from 3,742 non-test sources in
264.042419209 seconds, peak 12,032,196,608 bytes. Matched same-binary off/on
captures preserve full exact content and all pins, with zero errors and normal
exits. The repository-avatar region changes from 253 differing pixels,
185 over three levels, maximum 40, to 178 differing, 38 over three, maximum 7.
The commit avatar changes from 165 differing, 80 over three, maximum 43, to
148 differing, 41 over three, maximum 23. The full strict comparison becomes
**25,224 differing pixels, maximum 31, MAE 0.0162, RMSE 0.3135**.

A default production-path PNG build completes in 340.845045209 seconds, sampled
peak 12,043,370,496 bytes. Its fresh original-page capture has identical output
to the PNG candidate:
`eef33d71212f5ef8dbb444c6d378295f3ba7926d5505d993fdb642dd8ba9e328`.
Its content/pins/error/exit checks all pass. The correction needs no diagnostic
environment setting in production. Regression sources are included but remain
uncompiled/unrun.

`8641a3868` also preserves the compositor phase for supported solid rounded
fills and strokes. It uses the retained layout/capture basis and the same
atomic foreground publisher; unsupported transforms, underlays and clips keep
the established path. The root compiler check completes in 57.823171833 seconds,
7,482,392,576-byte peak. Its candidate builds in 321.643241584 seconds,
12,015,697,920-byte peak. Original-page markers establish eligibility for the
fractional-origin 46×40 and 76×36 strokes. Matched same-binary off/on captures
preserve exact content, pins and zero errors. The default production build
(269.216982667 seconds, 12,020,121,600-byte peak) reproduces the corrected PNG
byte for byte:
`4fe168e4d3e66119ec762d4ed47c2da9c4ddd72b7ce22b56242ee1b40fcc3bbe`.

The unchanged original-reference comparison now has **25,206 differing pixels,
maximum 31, MAE 0.0138 and RMSE 0.2119**. There are 1,589 pixels over three
levels, 47 over ten, one over 25 and none over 50. Native PNGs are sRGB; only a
**derived actual** is converted to the reference's existing Display P3 profile
for comparison. The original PNG, its profile, content audit and zero/zero
pixel tolerances stay fixed. Small color-quantization differences remain;
these observations do not establish their complete cause or pixel acceptance.

### Retained timeout, cache recovery and compiler-disabled controls

The newer native ABI is
`862d89840fed1aca9365c3c9213968204f3f483865fb6262cb3b8d389999a482`.
Concurrent native compiler changes invalidate the earlier successful ABI;
no partition is renamed, copied or relabeled to force reuse. The PNG candidate
executable is SHA-256
`3cc01b68a39a3b66a27fc4f01d5729af633d5e1010d741a245297bc7027a9bb1`.
Its fresh-cache first opening reaches the memory guard's **default 1,800-second
timeout**, after 21,760 entries, before the shutdown compilation drain finishes.
The guard reports 1,800.120981541 seconds, 11,079,450,624-byte sampled peak and
child exit 137. This is a retained failure, not successful first-opening
acceptance. The earlier capture already preserves exact content and the PNG
correction, but cannot establish a complete cache.

The default production SVG/PNG executable is SHA-256
`48743078b353f9c37771b5f0d230724bde51458eeff511534a26812e21be130e`.
The native-ABI source hashes agree with that candidate, so it can use the
same retained partition without conversion. A recovery opening finishes the
missing templates: 2,018 compiled entries in 16 compiler calls, no pending or
invalid entries and no error; all 81 module preparations complete, zero
unsupported bodies. The guard records 184.657093959 seconds and
11,202,756,608-byte peak, normal browser/controller/guard exits and fixed pins.
This is **recovery from a partial cache**, not a cold first opening.

A fresh recovery-cache reopen sets the compiler to `/usr/bin/false` and records
**4,245 native hits, zero misses, zero compiler calls, zero pending/invalid entries
and no error**. Native counters establish execution: 481,419 entries,
11,478,579 fast steps and 6,749,953 slow steps. JSC remains uninitialized.
Exact original content passes, zero author/native errors, all pins fixed and
all exits zero. Guard elapsed is 43.073832708 seconds, sampled peak
8,605,188,096 bytes. Recorded loading is 963.666642 ms; the observation includes
the fixed 30-second capture delay and supplies no speed ratio.

The entire native input sequence then passes with the compiler still disabled:
Code and master open, branch input receives `ma`, all six actions and completion
arrive, and terminal menus/overlays close. Exact content is retained with no
errors or changed pins. Both control acceptance flags are true. It records
**4,692 hits, zero misses or compiler calls, zero pending/invalid entries**, and
**872,562 native entries, 27,212,564 fast steps and 12,786,281 slow steps**.
All exits are zero; guard elapsed is 62.206785666 seconds, sampled peak
**12,583,337,984 bytes**, under the unchanged 12 GiB cap. This validates compiled
interaction with this recovered partition, without upgrading the failed cold
opening into acceptance.

A separate first opening starts with a genuinely empty partition, using this
same production executable. Only the wall-clock limit is extended to 3,600
seconds; the aggregate memory cap remains 12 GiB. Its normal completion and a
fresh compiler-disabled reopen are still pending. Full live-site, zero-pixel
and matched-performance acceptance also remain open. No automated tests run.

### Rectangle/clip coverage experiment

The largest residual is the orange selected-tab underline at (91,166): original
reference (242,197,186), current derived actual (243,222,217). Brave's root
picture log records an antialiased rectangle ending at x=91.5 inside a clip
ending at that same edge. A prototype removes redundant rectangle coverage
where a device-space edge exactly matches the active clip edge, leaving the
clip to resolve that boundary once.

Its first C build fails because the native declaration uses `const float*`
while V exports `float*`; no executable is used. After correcting the signature,
the build completes in 389.769992083 seconds, 12,024,922,112-byte peak, with a
sealed 3,744-source proof and zero test sources. Matched mode-off/on observations
have full content, fixed pins, zero errors and normal exits, but **identical
PNGs and no eligibility marker**. A separate original-page GG trace confirms
the orange rectangle bypasses that GPU callback and uses the direct solid-rect
boundary. This prototype supplies no rendering credit; its patch and both
captures are retained. The callback changes are removed, and the next guarded
experiment applies the same device-space rule at the actual solid-rect boundary.


### Completed empty-cache first/reopen/control cohort for the SVG/PNG browser

The separate empty-cache opening completes normally under the extended
3,600-second wall-clock limit and unchanged 12 GiB aggregate memory cap.
It compiles **23,778 entries in 186 compiler invocations**, with zero pending or
invalid entries and no cache error. All 81 module preparations complete:
25,643 prepared bodies, 19,533 queued uncalled templates, zero unsupported
bodies and zero preparation diagnostics. Compilation records
1,611,187.718865 ms; native loading 39,278.060091 ms. Browser/controller/guard
exit zero, fixed pins, full exact content and zero author/native errors.
Guard elapsed is **1,676.399337084 seconds**, sampled peak **10,946,527,232
bytes**. The earlier 1,800-second failed attempt remains retained; the successful
run has different host contention and is not a speed comparison or an excluded
retry of that attempt.

Its fresh `/usr/bin/false` reopen has **4,245 hits, zero misses, zero compiler
calls, zero pending/invalid entries and no cache error**. Native loading is
617.106142 ms. It executes **482,882 native entries, 11,505,373 fast steps and
6,777,473 slow steps**; JSC stays uninitialized. Exact content passes, all pins
are fixed, no errors, and all exits are zero. Guard elapsed is 38.369853458
seconds, sampled peak **8,491,728,896 bytes**. First/reopen raw PNGs agree at
`eef33d71212f5ef8dbb444c6d378295f3ba7926d5505d993fdb642dd8ba9e328`.

The complete 60-second native input sequence also passes against this genuinely
fresh partition, with `/usr/bin/false`: Code/master open, native filter value
`ma`, all actions/completion received, terminal menus and overlays closed, full
exact content, no errors, no changed pins. Both control flags are true. It has
**4,690 hits, zero misses or compiler calls, zero pending/invalid entries**, and
**857,556 native entries, 27,095,679 fast steps and 12,639,083 slow steps**.
Native loading is 621.698818 ms. All exits are zero; guard elapsed is
61.645732917 seconds and sampled peak **12,500,566,016 bytes**. All **28 shared
executable/library/archive fingerprints agree** across first/reopen/controls;
the canonical first/reopen observer remains SHA-256
`019574fce1afd03f0741b2bb0d74d639fe977d7903c08e21c6404be5a873e544`.
These are functional and native-execution observations, with little memory
headroom. Fixed observation delays and shutdown compilation are included;
there is no isolated speed ratio, long-duration memory bound or matched
performance acceptance.

### Border-phase regression and direct rectangle/clip correction

A full changed-pixel audit catches a regression in `8641a3868`: **235 pixels
change; 48 mismatches resolve but 30 previously exact pixels become wrong**.
The new mismatches form the search button's straight right edge at x=803,
including 24 pixels with channel error 16. Bilinearly sampling already analytic
stroke coverage creates an extra fringe. The aggregate count improves by 18,
but that does not establish a correct border change. The border-phase path is
removed; the separate SVG path/coverage correction stays. A regression source
exercises a retained analytic border through the exported callback with zero
and half-pixel SVG phases, requiring the exterior straight-edge pixels to stay
black. It remains uncompiled/unrun.

That earlier commit also carried a pre-existing image-MSAA selection hunk.
The rollback preserves it. Intermediate builds made during its temporary
removal are retained and cannot validate the final source. Each later browser
build seals the restored source digest before its C compilation. This avoids
silently dropping the independent image-sampling behavior during the rollback.

The direct-rectangle candidate explicitly logs eligibility for the actual
underline: user-space bounds (16,624,75.5,2), clip (16,624,75.5,40), identity
native device transform, revised width 76. Only the redundant shared edge is
expanded; the active native clip still resolves the half pixel. Its non-test
root check completes in 33.273963084 seconds, 7,484,588,032-byte peak; candidate
C build in 209.229657875 seconds, 12,031,655,936-byte peak, sealed 3,744 sources,
zero tests. Matched same-binary off/on original-page captures preserve exact
content and all pins, with zero errors and normal browser/controller/guard exits.

Exactly **two pixels** change, both improving: at (91,166), reference
(242,197,186), before (243,222,217), after (240,196,184); at (91,167), reference
(224,181,172), before (215,198,197), after (222,180,171). Under the then-current
border candidate, the full mismatch count stays 25,206 but maximum channel
error falls **31→23**, pixels over ten **47→45**, and over 25 **1→0**.
The default-path rectangle build completes in 215.553503208 seconds,
12,033,523,712-byte peak; its fresh capture (37.560894917 seconds,
8,065,531,904-byte peak) reproduces candidate output exactly:
`b728060a060a5e9abbe68a98d2f6bb8233d4ece3b6f8c3de457ce09d45ed5b78`.

The rectangle policy lives in V, with native code only transferring context
bounds and transform. It declines non-axis transforms, empty/invalid or
collapsed geometry, and overflow in both device and inverse mappings. Focused
sources cover shared edges, unchanged independent edges, device scale and
translation, flipped Y and invalid/extreme mappings; they remain uncompiled
and unrun. The final non-test root compiler check passes in 31.998921083
seconds, sampled peak 7,486,210,048 bytes. The final exact-source production
capture combining this correction with the border rollback is complete below.

### Color-conversion precision diagnosis; original pixel gate retained

The native PNG has the standard sRGB chunk. The original Brave PNG embeds its
520-byte Display P3 matrix/TRC profile. At 3,253 opaque text pixels, native
sRGB is correctly (31,35,40), while the existing ColorSync conversion yields
P3 (32,35,39) and Brave stores (32,35,40). A numerical matrix/TRC calculation
using the embedded profile and canonical sRGB XYZD50 matrix gives (32,35,40).
All four ColorSync rendering intents give the same existing result, so changing
intent does not fix the discrepancy.

The numerical transform is a **separate artifact diagnosis**. It produces
22,340 mismatches against the original reference in that retained image, still
maximum 31, rather than the existing comparison's 25,206. Neither number is a
new renderer result; the original ColorSync-derived comparison stays unchanged
and failing. Converting already quantized sRGB pixels also cannot establish
that text and overlapping paints blend in the same destination space as Brave.
No inverse color remap, replacement reference, tolerance change or rendering
credit is taken from this experiment.

Completed scratch jobs move out of Build with idle-lock checks and full
SHA-256/symlink verification: 154 owned roots, 1,880 files, in local
`scratch-receipts/continued-20261116-r9`. Native cache partitions, source proofs
and original references are retained. Newer independent native compiler entry
lookup changes alter the ABI again; later rendering executables cannot borrow
an older partition by renaming it. Full compiled rendering with the final
source, live behavior, exact original-reference pixels and matched speed remain
open. All automated tests remain held.


### Committed rollback and rectangle correction; final-source observation

`a39b66400` removes the unbounded solid-border resampling and adds the exterior
edge regression source. `373e0b083` enables the shared rectangle/clip-edge
correction by default, with its V geometry/invalid-transform regression sources.
The independent image-MSAA selection is preserved. Tests remain uncompiled and
unrun; normal commit hooks request coalesced production rebuilds.

The final private literal `-prod`, single-C executable is SHA-256
`e4805fce68555f8da380e07dce60eea5e6878c3942b82cf8247f88950e5096f8`.
Its sealed proof contains 3,744 V sources and **zero test sources**; the owned
implementation digests match the checkout. Build elapsed is 212.691658375
seconds, sampled peak **12,030,574,592 bytes**, compiler/guard exit zero.
Its fresh original-page capture preserves exact content and all pins, no
errors, browser/controller/guard exits zero, elapsed **38.343840334 seconds**,
sampled peak **8,140,701,696 bytes**. Raw PNG SHA-256 is
`507e18ea74d07b35938a579d6d82361afa5975ad9c8d82e53e487def01ea98e0`.
The prior intermediate builds and their exact consumed buffers remain retained;
they are not used to validate later mapping guards or the restored image hunk.

The two improved underline pixels retain their candidate values. Previously
exact black exterior pixels at x=803 are black again. The strict unchanged
reference comparison is **25,224 differing pixels, maximum 31, MAE 0.0162,
RMSE 0.3122**, with 1,730 pixels over three levels, 158 over ten, 52 over 25 and
none over 50. This deliberately does not retain a lower aggregate count at the
cost of new exterior errors. Remaining maximum errors now occur inside the
unadjusted search-button border, rather than at the corrected underline.

A next guarded experiment retains the effect picture's **unsnapped size** as
well as its origin. Brave's independent picture log has physical width 85 and
origin x=1521: its texture ends at document x=803. The former phase publisher
had no corresponding finite texture footprint. The candidate snaps the origin
and size independently on the presenting grid, encloses that footprint for
capture, and limits supported foreground sampling to it. A non-test compiler
check passes (29.916952875 seconds, 7,478,542,336-byte peak); original-page
eligibility and same-binary off/on captures are pending. This is not another
accepted border correction.

The new native-compiler executable's ABI is
`af0aaf736a2b968092fe845c9270847b777a642fb11b8782276e1d35ec8310d4`.
A separate empty-cache original-page opening is running against the final
rectangle/rollback executable under the same 3,600-second/12 GiB guard. Its
initial capture already has exact content and zero errors, with compilation
still pending; it does not yet establish completed-cache reuse. The earlier
complete 862d first/reopen/control cohort remains valid for its pinned SVG/PNG
browser and is not relabeled as this new ABI's result.

A second verified scratch move removes another 52 completed owned roots/226
files from Build into local `scratch-receipts/continued-20261116-r10`. Active
first-opening and bounded-picture jobs stay in Build. Cache partitions, browser
executables, source proofs, original references and every failed attempt remain
retained. Pixel-perfect, live-site and matched-speed acceptance remain open.

### Finite compositor footprint and completed af0a native reuse

`c6ac1122d` retains a compositor picture's unsnapped size and clips supported
foreground resampling to its separately snapped texture footprint. The actual
search-button path executes in the original-page diagnostic. Same-binary
off/on captures change 205 pixels: 201 improve, 48 mismatches disappear, and
**zero previously exact pixels become wrong**. The final default production
executable is `0219ea33a4d9cbb0d9f072c66a6e940e9b6eb47a0204385e7cddc9d770414cc6`;
its 218.259318083-second build peaks at 12,010,438,656 bytes and seals 3,744 V
sources with zero tests. A fresh capture reproduces the candidate exactly:
`c14f8003edb4e87832ea4d89dd943cdf24a1a707c6aad04ebd88b3992220b4f0`.
The unchanged zero/zero reference gate is **25,176 pixels, maximum 23,
MAE 0.0134, RMSE 0.1959**. Browser/controller/guard exits are zero, inputs stay
pinned, content is exact and errors are absent.

The previously pending af0a empty-cache opening also completes normally:
23,778 compiled executables in 186 compiler calls, 81 completed modules,
25,643 prepared bodies and 19,533 queued bodies, with zero unsupported bodies,
pending/invalid entries or diagnostics. Guard elapsed is 1,306.245397 seconds,
sampled peak 11,068,964,864 bytes. Compilation totals 1,241,446.872909 ms;
native loading totals 45,763.804788 ms. A fresh `/usr/bin/false` reopen records
4,245 native hits, **zero misses and compiler calls**, 472,538 native entries,
11,204,322 fast steps, 6,628,995 slow steps and 442,272 entry-cache hits. Native
loading totals 840.043829 ms; guard elapsed is 38.7776475 seconds and peak
8,452,587,520 bytes. Both captures are identical to the earlier rectangle
PNG `507e18ea…`, with exact content, unchanged inputs, no errors and all exits
zero. These elapsed intervals include fixed observation delays and shutdown;
they do not establish an isolated performance ratio.

The same af0a browser completes the native Code/master/filter/close sequence
with `/usr/bin/false`: 4,690 hits, zero misses/compiler calls/pending/invalid
entries, 857,558 native entries, 27,095,747 fast steps, 12,639,264 slow steps
and 792,726 entry-cache hits. Both acceptance flags are true; native input
reaches `ma`, all six actions finish, menus close, content stays exact and
errors remain absent. Guard elapsed is 61.2177735 seconds, peak 12,489,621,504
bytes, all exits zero. The bounded-footprint default browser independently
reopens this unchanged ABI's completed cache: 4,245 hits and zero misses or
compiler calls, 482,921 native entries, 11,505,915 fast steps and 6,777,947 slow
steps. It reproduces `c14f8003…`, with exact content, fixed inputs and all exits
zero (39.081343584 seconds, 8,600,125,440-byte peak).

### Destination color-space experiment and current live screenshot

The document-color candidate is guarded by `vox_diagnostic_document_p3` and
`VOX_DIAGNOSTIC_DOCUMENT_P3=1`; the default remains sRGB. Its V implementation
constructs a standard Display P3 matrix/TRC profile from canonical Skia gamut
and transfer coefficients, then converts text and solid paints **before
blending** into that document space. It does not read the reference image or
remap its pixels. The native boundary supplies the selected bitmap/IOSurface
profile and preserves that profile in the direct document capture. All seven
numeric matrix/TRC tags match the original Brave profile; the original PNG,
fixture bytes, clock, viewport, capture scale and strict tolerance stay fixed.

The first candidate reduces the strict count to 932 but introduces an avatar
regression (maximum 43) when compatibility image leaves lose their backdrop.
The second preserves that backdrop in the image leaf's sRGB working space:
**808 differing pixels, maximum 23, MAE 0.0009, RMSE 0.0646**. Search-icon
coverage is exact again after `3d01c98fb` quantizes each covered UNORM8 sample
before resolving MSAA coverage. The focused regression source is added but
remains uncompiled/unrun. Same-binary mode-off captures retain the exact
default `c14f8003…` PNG. The r2 candidate executable is
`d62f8734338ce5f94ecd2b0976b2b52adca158150a461b18a9b4398ace3644e7`;
its sealed production proof contains 3,746 V sources and zero tests. Mode-on
and mode-off browser/controller/guard exits are zero, inputs unchanged,
content exact, and script/native errors absent. This is a guarded rendering
experiment, not pixel-perfect acceptance.

At the user's request, a fresh direct-HTTPS opening of the **current live**
`https://github.com/vlang/v` is captured at 1024×768 using that r2 LibJS
executable, actual current responses and clock, and an eight-second ready
settle. The page has 34 rows, 53 commit links, latest commit and README, with
no reported author/native errors. The live bundles differ from the frozen
fixture: its initial capture has 443 native-cache hits and 3,863 misses,
138,770 native entries, and JavaScriptCore uninitialized. The missing live
templates are still compiling normally at this checkpoint. The first PNG is
retained locally as `current-live-libjs-first.png` (SHA-256
`376de5c7413194a4c3ea5b5609d5d44998edb7209605d73f59c903a60d5a9947`).
It must not be labeled a completed-cache capture. A fresh compiler-disabled
live reopen, exact pixels and matched speed remain outstanding; automated
tests remain held by the user's instruction.

The scalar conversion is committed in `3fe85bb00`, after the independent MSAA
fix `3d01c98fb`. It adapts the scalar, non-FMA skcms transfer approximation,
inverse-transfer endpoint adjustment, double-intermediate matrix inversion and
preconcatenated gamut transform from [skcms](https://skia.googlesource.com/skcms/+/refs/heads/main/skcms.cc)
and [SkColorSpaceXformSteps](https://skia.googlesource.com/skia/+/refs/heads/main/src/core/SkColorSpaceXformSteps.cpp).
The BSD notice and license accompany the implementation. The first non-test
root attempt encounters an in-progress independent native-property source
change; the second rejects changed generated-C inventory membership. Both
failures are retained. The third check passes in 41.510880166 seconds, peak
7,493,517,312 bytes. The single-C literal `-prod` build passes in 296.755507917
seconds, peak 12,023,545,856 bytes, sealing 3,747 V sources and zero tests.
Executable SHA-256 is
`eac43c1167aeb57a94043794a7b601d023d7e0272285b23140d6cde75a1e378d`.

Fresh same-binary mode-on/off captures preserve all input fingerprints, exact
original content and zero script/native errors, with browser/controller/guard
exits zero. On-mode elapsed/peak are 39.474668417 seconds/8,168,833,024 bytes;
off-mode 40.671691125 seconds/8,274,821,120 bytes. The off PNG remains exactly
`c14f8003…`. The on PNG is
`7e13e529b6d2cb9771e933cb5f380583d65e554287ff85331cc51f68fd051af6`;
the unchanged strict reference gate falls **808→343 pixels**, maximum 23,
MAE 0.0008, RMSE 0.0634. Of these, 312 are in the two avatar regions and 31
elsewhere. A separate empty-cache opening is preparing native code for the
newer property-plan ABI; it is not yet a completed compiled-rendering result.

The first **live** opening finishes normally after 1,476.374767833 seconds,
10,741,661,696-byte peak: 23,077 new executables, 181 compiler calls, 77/77
modules, 25,930 prepared bodies, 19,214 queued bodies, zero unsupported bodies,
pending/invalid entries or diagnostics. Compilation totals 1,386,857.691880 ms,
native loading 60,223.266809 ms. All browser/controller/guard exits are zero
and executable/library/tool fingerprints stay fixed.

Its immediately following fresh live `/usr/bin/false` screenshot **fails the
cache acceptance check**: GitHub changes 13 module URLs between visits,
including code-view, core, repositories and webpack runtime. The observed
resource graph changes; this could reflect deployment or response variants and
does not permit reusing old code under new keys. The page
still loads with 34 rows, 53 commit links, latest/README, no script/native
errors and unchanged pinned inputs. It executes 371,463 native entries with
3,233 hits, but has 1,095 misses and 7,655 pending templates; the deliberately
disabled compiler reports exit 1. Browser exit is zero; controller/guard exit
is one, elapsed 25.253570834 seconds, peak 9,998,057,472 bytes. The screenshot
therefore establishes live native execution, **not a zero-miss compiled
reopen**. Both attempts are retained, and the newly deployed bundles are now
being compiled before another immediate fresh reopen. No speed claim follows
from these changing-resource live intervals.

The live refresh completes with 7,655 additional executables in 60 compiler
calls, 77 completed modules, 25,968 prepared bodies, zero unsupported bodies,
pending/invalid entries or diagnostics. Native compilation totals
840,450.378252 ms and loading 22,544.864307 ms. Browser/controller/guard exits
are zero; elapsed is 887.275987125 seconds, sampled peak 11,746,328,576 bytes.
It retains exact live document identity, 34 rows/53 commit links/latest/README,
no errors and unchanged pinned inputs.

An immediate fresh direct-HTTPS live opening with `/usr/bin/false` then passes:
**4,300 native hits, zero misses/compiler calls/pending/invalid entries**, no
cache error, 348,912 native entries, 7,091,708 fast steps, 4,910,683 slow steps
and 322,844 entry-cache hits. JavaScriptCore stays uninitialized, all 77 loaded
modules are evaluated, content is complete and there are no author/native
errors. The process, controller and guard exit zero; all inputs stay pinned.
Guard elapsed is 23.76610925 seconds, peak 7,820,935,168 bytes; native loading
totals 3,357.921702 ms. These are a ready-selector plus eight-second screenshot
observation and native execution diagnosis, not matched performance acceptance.
The current-live compiled screenshot is retained locally at
`docs/performance/libjs-github-browser-20261116/current-live-libjs-compiled.png`,
SHA-256 `5835af684c22e95150436f87e3d91c47bddf9c2ad7ac6bc54c5443ead818585f`.
It uses the pinned r2 P3 executable, not later source or the frozen reference.

A further guarded PNG experiment selects decode dimensions at rendering
density instead of capture density. Its original-page log confirms full
60×60/40×40 uploads, matching the independently observed Brave picture data.
The root check passes in 42.775259042 seconds, peak 7,480,623,104 bytes; the
production build passes in 300.675811792 seconds, peak 11,959,009,280 bytes.
Same-binary off mode retains exactly the scalar candidate's decoded pixels
(PNG metadata bytes differ); on mode reaches **284 differing pixels, maximum
15**. Of 302 changed pixels, 231 improve, 80 resolve, 23 worsen and 21 become
new one-level mismatches. Avatar maxima fall to two levels. This is kept
experimental rather than accepted solely on an aggregate count. The image
reference, numeric profile tags and zero tolerance remain unchanged. A GPU
mipmap follow-up passes its root check but its build fails when an independent
native JPEG XL bridge appears during compilation; the retry also verifies
native input fingerprints after C compilation. No automated test is run.

Another 88 completed owned scratch roots/789 entries move out of Build with
idle-lock and SHA-256/symlink verification into local
`scratch-receipts/continued-20261116-r11`. Nineteen older completed generated C
files (6,565,659,623 bytes) are pruned with a retained hash/size manifest;
executables, exact source proofs, references and failed-attempt receipts stay.
Active native preparation and rendering jobs remain under their guards.


The b72b scalar-P3 native cohort has now completed. Its empty-cache opening
compiles 23,778 executables in 186 compiler calls and prepares all 81 modules,
with no pending/invalid entries or diagnostics. Guard elapsed is
2,063.079582959 seconds, peak 11,035,934,720 bytes; compilation totals
2,001,024.809537 ms. A fresh `/usr/bin/false` reopen records 4,245 hits and zero
misses/compiler calls/pending entries, 482,662 native entries and 11,490,671
fast steps. Its decoded PNG is identical to the 343-pixel scalar candidate.
Guard elapsed/peak are 41.016731583 seconds/8,373,698,560 bytes. The subsequent
original-page native mouse/keyboard sequence completes all six actions, opens
and closes the Code/branch menus, observes the master branch and `ma` filter,
and finishes with exact 33-row/56-commit/latest/README content. It records
4,691 hits, zero misses/compiler calls, 777,359 native entries, and both control
acceptance flags true. Guard elapsed/peak are 61.447283459 seconds/
12,044,402,688 bytes. All three browser/controller/guard exits are zero, there
are no author/native errors, and 28 common input fingerprints match across
the cohort. This instrumented observation establishes execution eligibility;
it is not a matched speed comparison.

The guarded rendering experiments continue against the original Brave PNG
`649abff5…` and the unchanged zero-tolerance gate. Rendering-density PNG decode
plus hardware-generated mipmaps reduces the gap to 150 pixels, maximum 15;
its same-binary off mode reproduces the prior 284-pixel result. A guarded
analytic thin-rectangle path then resolves one additional pixel: 149 remain.
The underline geometry diagnostic confirms that the actual page takes this
path. These changes are committed separately as `be9dbf81d` and `19e3b1248`.

The next guarded path converts sampled PNG colors to the document's Display P3
space before blending. Its validated build and fresh on/off captures reach
**130 differing pixels, maximum 15, MAE 0.0001, RMSE 0.0230**. Off mode
reproduces the 149-pixel output. Of 103 changed pixels, 47 improve, 28 retain
the same error, and 28 regress or become new one-level mismatches; the path
therefore remains experimental. Remaining differences comprise 82 logo pixels
(maximum one level), 18 grayscale-avatar pixels (maximum two), and 30 other
pixels. The reference, viewport, date, response bytes and tolerance stay fixed.
This is committed as `204fcfdf6`, with focused regression source held
uncompiled/unrun as requested.

That path's first prototype accidentally updates only the Python shader
stager; production uses the V stager. Its capability check correctly refuses
the old shader and the capture regresses to 434 pixels. Updating both staging
paths fixes that mismatch. A subsequent build produces an executable but fails
its final source-integrity check when another session changes native rendering
code; its exploratory capture is explicitly ineligible for acceptance. The
final r3 build seals its native and shader inputs and independently reproduces
the 130-pixel result. It completes in 276.815531917 seconds, peak
11,870,257,152 bytes; both accepted captures have zero browser/controller/guard
exits, complete content, no script/native errors and unchanged input hashes.
All failed and exploratory attempts are retained. The pruned older prepared
compiler is replaced through the official runtime stager; current V SHA-256 is
`6a620b108a2ab5d64bcfa55cf03aaf80bd3ccffc762aa4b66621af470cfa30c5`.
The accepted image-space binary starts a new empty-cache preparation for its
actual native ABI; it does not relabel or reuse an incompatible partition.

A further GPU precision experiment is pending. Its first build fails the final
source-integrity check because shared shader-staging JSON changes during the
build; the retry retains the same guard. No result from that rejected build is
used. Another 96 completed scratch roots/437 entries are archived with SHA-256,
symlink and idle-lock verification under local
`scratch-receipts/continued-20261116-r12`. Tests remain held, and full Brave
pixel parity and matched compiled-revisit speed remain open.


The GPU precision retry passes in 311.581433125 seconds, peak
12,036,276,224 bytes, sealing 3,755 V sources and zero tests. Executable SHA-256
is `573c6fe1fffa434cd6a2c5e32db76d8fc7f39dc9cf1f0662ec3b89c404f55df0`.
All three fresh original-page captures preserve exact content and input hashes,
have no script/native errors, and exit zero throughout. Each confirms its
requested shader mode is active. Mode 0 reproduces the prior 130-pixel output
exactly. The legacy combined half-uniform model worsens it to 138 pixels
(5 improve, 13 regress/new); staged half intermediates worsen it to 224
(5 improve, 99 regress/new). Maximum error remains 15 in both. Guard
elapsed/peak are 39.638516792 seconds/8,141,029,376 bytes for control,
38.580221625 seconds/8,139,849,728 bytes for legacy and
38.119425667 seconds/8,137,342,976 bytes for staged. Both experiments are
rejected and their owned implementation is removed, preserving independent
YUV changes. Exact source proofs, the observed checkout patch and all failed
and successful attempt receipts remain local. No Brave GPU precision setting
is inferred from these results. Eight completed generated C files totaling
2,766,619,811 bytes are pruned with a retained hash/size manifest.


`9f2952508` adds guarded destination-gamut conversion **before mipmap generation
and filtering**, following Chromium's
[image transfer-cache order](https://chromium.googlesource.com/chromium/src/+/HEAD/cc/paint/image_transfer_cache_entry.cc).
The decoded source converts once into an 8-bit destination-space texture;
its mip levels and final blend retain that encoding. This resolves all 82
remaining repository-logo pixels, with **82 improved/resolved, zero regressed
or new mismatches**. The strict unchanged reference now differs in **48 pixels,
maximum 15, MAE 0.0001, RMSE 0.0223**: 18 around the commit avatar's rounded
edge and 30 elsewhere. Same-binary off mode reproduces all 130 prior pixels.
The single-C literal production build completes in 323.992851 seconds, peak
12,030,541,824 bytes, sealing 3,755 V sources and zero tests. Its executable is
`917d9cde83fafa12786fc49733ec61ca7e90d0807794ec9fe5b9b2d02d603571`.
On/off capture elapsed/peak are 39.808384833 seconds/8,033,124,352 bytes and
38.48223875 seconds/8,030,044,160 bytes. Both retain complete exact content,
unchanged input fingerprints, no author/native errors and zero exits. The
new regression source is included but remains uncompiled/unrun.

The newer native ABI
`0130530796c7d77dd62a7dc3c73b0941cf2cfd99e4d0a026077c70ab789bf404`
finishes its empty-cache preparation on the accepted image-space r3 executable:
23,778 executables, 186 compiler calls, 81/81 modules, 25,643 prepared bodies,
19,533 queued bodies, no unsupported bodies, pending/invalid entries or errors.
Compilation totals 1,998,037.089997 ms and native loading 45,287.154337 ms.
Guard elapsed/peak are 2,062.870794417 seconds/11,020,910,592 bytes. The fresh
compiler-disabled reopen uses the later prefilter renderer and the **same
actual ABI**; it does not rename an incompatible cache partition. It passes
with 4,245 hits, zero misses/compiler calls/pending/invalid entries, 482,600
native entries, 11,583,516 fast steps, 6,674,036 slow steps and 449,529
entry-cache hits. Page JavaScriptCore stays uninitialized. Guard elapsed/peak
are 39.813248833 seconds/8,451,145,728 bytes; native loading totals
1,357.496826 ms. Its full exact content and decoded PNG match the 48-pixel
interpreter candidate exactly. All browser/controller/guard exits are zero and
all measured inputs stay fixed. These are different renderer executables with
compatible native runtime code, not a same-executable timing comparison.

The new ABI's compiler-disabled original-page native control sequence also
passes all six actions, Code/master menu expansion and closure, `ma` filtering,
complete 33-row/56-commit/latest/README content, both acceptance flags, no
script/native errors and unchanged input pins. It records 4,690 hits, zero
misses/compiler calls/pending entries, 771,763 native entries, 23,789,538 fast
steps and 11,154,694 slow steps. Guard elapsed/peak are 61.235857042 seconds/
11,659,198,464 bytes; browser/controller/guard exits are zero. This is native
input diagnosis, not an automated unit suite or matched performance result.

`1d59ddfc6` corrects a density mismatch in the paint diagnostic's visibility
filter and logs each visible command's transform and clipping geometry. Its
production build passes in 332.489109667 seconds, sampled peak
12,780,093,440 bytes under the unchanged 12 GiB guard, sealing 3,756 V sources
and zero tests. The fresh trace preserves complete content and the exact
48-pixel output, with normal exits and fixed inputs. It exposes the URL
underline as a 214.9375-by-3 rectangle under a 0.5 transform, without clip-outs;
the GPU trace confirms its owning tile and 4x multisampling. The one remaining
pale-blue corner pixel is not used to adjust the reference or tolerance.

Two further original-page shader diagnoses are rejected. Explicit Metal
relaxed math (as in Dawn's compiler) changes zero pixels; guard elapsed/peak
are 41.55228475 seconds/8,143,831,040 bytes. Quantizing final edge coverage to
half precision worsens the gap to 72 pixels, resolving one but introducing
25 mismatches; elapsed/peak are 36.831856125 seconds/8,042,315,776 bytes.
Both confirm actual shader interception, full exact content, fixed executable,
probe and resource inputs, no errors and normal exits. No permanent renderer
change is made for either. A layout-basis experiment for the elliptical avatar
clip is pending. Full Brave pixel parity remains open and automated suites
remain held as requested.


The next round retains 64 completed roots/361 entries in local archive r13,
then 58 roots/1,835 entries in r14, with idle-lock, SHA-256 and symlink checks.
The compiled 48-pixel PNG is retained as
`docs/performance/libjs-github-browser-20261116/github-frozen-libjs-compiled-48px.png`
(SHA-256 `47ca454b437b8c8eb4032bdb9649fc7bc5e4b2b27236b31d5eaa05c4d33c5f6d`).
Vertex-position invariance changes no pixels; its actual-page guard exits zero,
elapsed 36.97094575 seconds, peak 8,042,807,296 bytes. The initial ellipse-basis
build cannot exercise the avatar because that branch is single-sampled while
the real image uses 4x MSAA; no capture acceptance is claimed. An eligible
MSAA destination-frame follow-up confirms execution but changes zero pixels;
its control reproduces the same 48-pixel result. Both are rejected and their
owned code is removed. The on/off captures exit zero, elapsed/peak
38.816847917 seconds/8,168,570,880 bytes and 38.650611375 seconds/
8,130,101,248 bytes, with exact content, no errors and unchanged pins.

Repeated native edits during optimization invalidate two direct diagnostic
builds, both retained. The next private diagnostic build uses the existing
production `preprocessed-c-v1` protocol from `freeze_browser_compile.py`:
it verifies parsed V buffers and native/resource inputs, preprocesses them,
then optimizes the sealed translation units while continuing to pin live link
inputs. It does not copy source trees, bypass checks or change the 12 GiB
guard. That build passes in 242.200517416 seconds, peak 8,968,585,216 bytes.
A later native-header edit before sealing is correctly rejected as well.

`ce128d06c` adds guarded precise percentage transform origins for Chromium
geometry. The breadcrumb separator is a rotated border, not a glyph. Its
22.390625-unit height has a 50% center at 11.1953125; the old fixed-point
resolution truncates that to 11.1875. Preserving the fractional center makes
all six float32 matrix components match Brave's independently recorded picture
exactly. Non-percentage origins and other geometry policies retain their
previous resolution; calculated-origin precision is not expanded by this slice.

The accepted origin build seals 3,758 V sources and zero tests, finishes in
270.689518708 seconds with peak 8,899,723,264 bytes, and produces executable
`d17bf2f22fb6cfc42ec0b74ed11fcd2ded9f407fbd0efc00412192a44adbf9f4`.
Both fresh captures use the actual 0130 native cache with `/usr/bin/false`.
On mode has 4,244 hits/473,185 native entries; off has 4,245 hits/482,576 entries.
Both have zero misses/compiler calls/pending/invalid entries, no author/native
errors, complete exact content, fixed input pins and zero exits. On elapsed/peak
are 53.616901542 seconds/8,843,198,464 bytes; off are 38.507044708 seconds/
8,447,754,240 bytes. These contended diagnostic intervals are not a speed claim.
Off reproduces 48 pixels. On reaches **42 differing pixels, maximum 15,
MAE 0.0001, RMSE 0.0222**: nine pixels resolve and three new one-level
mismatches appear. The guarded path is retained because its transform agrees
with the independent paint record; the remaining raster differences are open.
Its regression source is committed but uncompiled/unrun. The compiled on PNG
is retained locally as `github-frozen-libjs-compiled-42px.png`, SHA-256
`4eefb0221d7baffecf8ef7b5b352695ee754aab379b41faaa83a41c74fd50410`.

A shared shadow/PNG multisample replay follow-up is still pending. Its first
root compile catches a positional decoration initializer that must be changed
to named fields; the next build passes but its capture lacks an execution
marker, so no optimization credit is attributed. Caller/eligibility tracing is
being built. A separate Brave shader-log diagnosis fails because its injected
clock attempts to annotate the document before the HTML root exists; that
failure belongs to the diagnostic, not GitHub. It is retained and does not
replace the original reference. Tests remain held and pixel-perfect parity
remains incomplete.

### Shared PNG/shadow samples and 25-pixel compiled capture, 2026-11-17

`e17f869cd` keeps an eligible scaled PNG and its zero-blur outer shadow in
one destination-space sample pass. The guarded path accepts matching positive
uniform transforms, transforms the shadow and image clip consistently, decodes
at the selected rendering density, and converts the source image separately
from the already destination-colored shadow. Each tile keeps its owning sample
count and the existing unsupported-case fallback. Nonidentity replay requires
the P3 scope and zero scroll. The switch remains
`VOX_DIAGNOSTIC_SCALED_PNG_SHADOW_GROUP=1`; the default production pixel gate
is not changed to the diagnostic result.

The r3 production-mode build seals 3,758 sources and zero tests, finishes in
255.32481475 seconds with peak 8,981,626,880 bytes, and produces executable
`9cd41a3e45e786f2518efdfa483d3db88bfa1c8d747c3077620284724f6915d4`.
Actual-page logs confirm both the 60-by-60 logo and 40-by-40 avatar enter the
shared path. Early log excerpts alone had missed the later hydrated avatar;
the earlier r2 attempt remains retained without retrospective acceptance.
The r3 on/off captures both use the actual 0130 ABI cache with the compiler
set to `/usr/bin/false`, full exact content, no author/native errors, unchanged
input pins and zero browser/controller/guard exits. On has 4,244 cache hits,
474,023 native entries and zero misses/compiler calls/pending/invalid entries;
off has 4,245 hits and 472,575 entries with the same zero gates. Elapsed/peak
are 52.745366708 seconds/8,949,743,616 bytes and 38.7811755 seconds/
8,524,152,832 bytes respectively. These intervals do not establish a speedup.

On resolves all 17 changed pixels with no regressions or new mismatches.
The unchanged reference and zero/zero tolerance now give **25 differing pixels,
maximum 15, MAE 0.0001, RMSE 0.0218**. Off reproduces the prior 42-pixel
image exactly. The compiled P3 PNG is retained locally as
`github-frozen-libjs-compiled-25px.png`, SHA-256
`29793c7f747190d05be226f4018cedb553b7637de1c8a91a1c656eb45cfa9b3a`.
This is the frozen-page diagnostic, distinct from the direct-live compiled
screenshot `current-live-libjs-compiled.png` documented above.

The trimmed r4 build removes verbose caller/eligibility tracing and seals
3,758 sources and zero tests in 287.639708458 seconds, peak 8,906,670,080 bytes.
Its executable is
`66d5893cd87bf1916fe9064ec91564491b3c7016fbf0bd649ab0d3f5f1afe1ce`.
Its fresh on/off captures repeat exactly 25/42 pixels, but concurrent LibJS
runtime work changes its ABI to
`ecad02d7b83c947931f24c8ea36a2eee083391a21c0653ba5035a00242eb13a9`.
The old cache cannot load under that ABI: both attempts have zero native
entries, 4,265 misses, 4,245 pending executables, and a disabled-compiler error.
They are rendering evidence only, not compiled-JavaScript acceptance. A real
first opening is now preparing the new ABI before a compiler-disabled reopen;
no ABI partition is renamed or copied to manufacture compatibility.

Three follow-ups are rejected. Allowing rounded shadow/background/border
underlays enters the actual page path but changes no pixels in either mode;
that source experiment is removed. Its captures also have the incompatible
ABI and supply no compiled-execution evidence. Explicit Metal safe arithmetic
on the compatible r3 binary changes zero pixels, with 4,244 hits, 473,291 native
entries and zero misses/compiler calls. Changing interpolation to centroid
worsens the image to 6,936 differing pixels, with no resolved original pixels;
it has 4,244 hits and 473,433 entries with the same native zero gates. The
upstream-current 73-index analytic rectangle strip differs from GG's 69-index
strip, but a buffer-matched original-page counterfactual worsens the result to
41 pixels, introducing 16 mismatches and resolving none. It has 4,245 hits and
472,346 native entries with zero misses/compiler calls. No mesh staging patch
is retained. These shader/mesh probes are instrumented diagnoses, not
performance evidence, and do not assert that current upstream matches the
installed Brave revision. Reference pixels and tolerances remain unchanged.

Safe/centroid/mesh capture elapsed and sampled peak RSS are respectively
51.777625458 seconds/8,827,682,816 bytes, 56.175325417 seconds/9,031,024,640
bytes, and 38.637134667 seconds/8,525,561,856 bytes. All retain complete exact
content, fixed inputs and zero exits. A centroid launcher failure before any
browser starts is retained separately: the guard compiler runs out of disk
space. Hash-journaled pruning of 24 completed owned generated compiler inputs
reclaims 5,631,450,791 bytes; completed receipts, source proofs, executables
and the latest generated inputs remain available. The next launch succeeds.
Completed scratch jobs move to `scratch-receipts/continued-20261117-r15` after
idle-lock checks and before/after hash verification (46 roots/253 entries).
The active native preparation is excluded. Regression sources for the PNG
change are committed but remain uncompiled/unrun at the user's request.
Pixel-perfect parity, a current-ABI compiled reopen, and matched revisit
performance remain open.

### Rectangle clip ownership: 24 differing pixels, 2026-11-17

`60880e94e` transfers an eligible containing rectangular ancestor from Quartz
publication into GG's clip stack. The initial scope is an antialiased plain
fill, a shared local transform, finite containing bounds, no rounded/path/SVG
clip, and a root grid with zero origin. GG receives the actual intersection;
Quartz restores it if GPU replay declines. The opt-in is
`VOX_DIAGNOSTIC_GPU_RECTANGLE_CLIP=1`. Defaults remain unchanged, and the
regression sources are committed but uncompiled/unrun under the test hold.

The blue URL corner at (719,439) was already correct in the GPU readback:
`240,244,252`. Publication used a native clip starting at x=720 and discarded
that pixel. The source trace identifies the authored rectangle
`1440,490,544,1204` under the same 0.5 transform as the fill. Brave's independent
picture records that same antialiased clip. GG can simplify the containing
clip before rasterization and retain the antialias footprint; clipping the
finished bitmap again in Quartz loses that footprint. Saved URL glyph
backdrops show the pixel is already white before text compositing, so the
later glyph blend is not its cause.

Read-only extraction from the retained installed-Brave GraphiteDawnCache finds
54 MSL text segments, with source-file hashes, offsets and output hashes.
Using its ordinary rectangle vertex and fragment shaders, changing only entry
names and buffer slots to the existing GG bindings, reproduces all 25 prior
mismatches exactly. This original-page shader counterfactual uses 4,245 native
hits/482,832 entries and no misses or compiler calls. It is diagnostic evidence
about this cached program, not performance credit. Explicit contraction-off
and precise FP32 function variants also change zero pixels, with 4,245 hits
and 482,957/482,953 native entries respectively. Their compiler controls follow
[Apple's Metal specification](https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf).

The accepted clip build uses sealed production inputs, 3,760 sources and zero
tests, and exits zero in 274.5400425 seconds, peak 8,979,955,712 bytes. Its
executable SHA-256 is
`a9bf45c4dee83d712c4491a8087a2d5c9d93d130568895882c77773394005d2b`.
The matched-registry on/off captures both use the actual 0130 native cache and
`/usr/bin/false`, complete exact content, no author/native errors, unchanged
input pins, successful PID adoption, and zero browser/controller/guard exits.
On records 4,245 hits/482,836 native entries; off 4,245/482,537. Both have zero
misses/compiler invocations/pending/invalid entries and an uninitialized page
JavaScriptCore context. Elapsed/peak are 39.302211625 seconds/8,660,434,944
bytes and 39.837779584 seconds/8,556,150,784 bytes; no speedup is attributed.

On resolves the one changed pixel without regression: **24 differing pixels,
maximum 10, MAE 0.0001, RMSE 0.0191** against the original zero/zero reference.
Off reproduces the prior 25 pixels exactly. The normalized compiled PNG is
`github-frozen-libjs-compiled-24px.png`, SHA-256
`655a9a4886dbabe70ed0e00236693a307ab634ab3e5be46c140e20c43ff07a3f`.
The direct-live screenshot remains separately named
`current-live-libjs-compiled.png`; this frozen result does not replace it.

The ecad ABI preparation also finishes, without renaming any partition. Its
original attempt loses its process without a completion/final-exit receipt;
11,008 manifests are present, but that attempt is not acceptance. The resumed
opening adds 10,112 executables in 79 compiler invocations, then hits compiler
ENOSPC with 2,658 pending entries. The next fresh opening compiles those 2,658
in 21 invocations, prepares all 81 modules, and ends with zero pending,
unsupported or invalid entries and no cache error. Elapsed/peak for that final
drain are 267.530289459 seconds/10,797,137,920 bytes. A fresh compiler-disabled
reopen then records 4,244 hits, 474,379 native entries and zero misses/compiler
calls/pending/invalid entries, complete exact content, no errors, fixed pins
and zero exits. Its decoded output equals the trimmed 25-pixel renderer.
Elapsed/peak are 53.623060625 seconds/8,987,541,504 bytes. Canonical runtime
sources have meanwhile independently reverted to the compatible 0130 ABI;
the clip build verifies all embedded ABI source hashes against that cache.
These interrupted and resumed preparations are not a single empty-cache
first-opening cohort or a matched speed result.

All failed diagnostics remain visible. The first publication hook recurses
and exits 138 before capture; the corrected read-only hook succeeds. A later
source-coordinate probe records its geometry but disk exhaustion leaves an
empty PNG and no content audit, so that capture is rejected despite process
exit zero. The first clip root build also fails writing generated C with
ENOSPC (89.91188525 seconds, peak 8,974,401,536 bytes). The first candidate
capture uses an old output/registry name and has no adopted PID; its 24-pixel
image is retained as diagnosis only, followed by the correctly named pair
above. Completed shader/publication/cache-failure jobs move to
`scratch-receipts/continued-20261117-r16` with idle locks and verified hashes
(50 roots/235 entries); the incomplete original guard stays empty and is
explicitly marked incomplete in the move manifest.

Disk cleanup is hash-journaled. Old completed/rejected private executables and
generated inputs are pruned after retaining their identities and source/
validation receipts; the current live executable, compiled controls/candidates,
native caches and newest accepted generated inputs remain. Historical paths
whose executables were pruned are not launchable validation inputs. No source
checkout or app bundle is copied. The remaining Code-tab fringe and button
corners are still open, as are full pixel parity and matched revisit speed.
Automated tests remain held.


### Fractional fills and nested clip ownership: 21 differing pixels, 2026-11-17

`b2ce3a8e5` preserves the original geometry of fractional thin fills when
transferring their containing rectangle to GG. Previously Quartz's shared-edge
conditioning changed the Code-tab underline before replay. Its compiler-disabled
0130-ABI capture improves 24 to **22 pixels**, maximum 10, MAE 0.0000,
RMSE 0.0180; both changed pixels resolve with no regression. The off control
reproduces 24 pixels exactly. The sealed 3,760-source/zero-test production build
exits zero in 293.158253708 seconds, sampled peak 8,936,095,744 bytes; executable
SHA-256 `fd9499cd84bb5b2232d212f2a831043e71e746dcf3f3d317aabca2bba20a32aa`.
On/off native hits are 4,244/4,245 and entries 474,385/472,379. Guard elapsed/peak
are 51.725183417 seconds/8,941,076,480 bytes and 38.340494584 seconds/
8,484,388,864 bytes. The normalized 22-pixel PNG SHA-256 is
`05154b72deb7d8fe0aac7a57cc379b6727630dfe5b69701ece1a7352caa8c19c`.

`968d162f9` then intersects every eligible containing rectangle in the same
GPU stack. Leaving an outer ancestor in Quartz still removed the bottom tab
fringe after GG resolved it. It improves 22 to **21 pixels**, maximum 10,
MAE 0.0000, RMSE 0.0164: one pixel resolves, none regress or become newly wrong.
This build consumes 3,761 sources and zero tests; guard/compiler exits are zero,
271.412727125 seconds, peak 8,984,707,072 bytes. Executable SHA-256 is
`afee4141853b175aa44c5261b354386e24b883a36e3b7146d09d53eb0e049a30`.
The on capture has 4,245 hits/482,927 native entries, native load 613.123057 ms,
guard 39.261126792 seconds/8,559,788,032 bytes. Its same-binary off control has
4,245 hits/482,345 entries, 39.11032675 seconds/8,449,556,480 bytes and reproduces
the prior 25-pixel image exactly. Off disables the entire GPU rectangle transfer,
so it does not isolate just nested ancestors from the separate 22-pixel build.
No performance improvement is attributed to these timings.

All four captures preserve exact full content, pinned inputs, an uninitialized
page JavaScriptCore context, successful browser PID adoption and zero browser,
controller and guard exits. Each uses `/usr/bin/false` as native compiler and
records zero misses, compiler invocations, pending or invalid entries and no
cache/native/author errors. The original reference and zero/zero tolerance stay
unchanged. The normalized best image is `github-frozen-libjs-compiled-21px.png`,
SHA-256 `7501754cc5720a538b82c40c805e645b40380702ad8a0981471bbf004973bfa2`.
It remains separate from the direct-live `current-live-libjs-compiled.png`.

Read-only publication and actual Metal instance-buffer probes repeat the
22-pixel output. The remaining button corner colors are already different in
GPU readback under a full-viewport publication clip. Actual shadow/background/
stroke instance geometry, radii, transforms and paint colors agree with the
independent Brave picture. Changing both the analytic mesh to 73 indices and
its depth compare/write state increases the 21-pixel baseline to 66: 46 pixels
regress, 45 newly wrong, none improve. That instrumented original-page run has
4,246 hits/472,384 native entries, zero cache misses/compiler calls, exact content,
fixed pins and zero exits (40.131119709 seconds, peak 8,423,620,608 bytes).
The depth/mesh counterfactual is rejected; no production depth change is made.

Completed jobs move with idle-lock checks and verified before/after hashes to
`scratch-receipts/continued-20261117-r17` (60 roots/332 entries). The ongoing
shadow-contribution diagnosis is excluded. Regression sources are committed but
remain uncompiled/unrun at the user's request. Default rendering is unchanged;
these opt-ins have **21 remaining differences**, so full Brave parity and matched
compiled-revisit performance are still open.


Further read-only pipeline mapping repeats 21 pixels exactly twice. The actual
button background/border use `analytic_rrect_solid`, the shadow uses its clipped
variant, all with four samples and alpha-to-coverage disabled. Thus the earlier
plain-shader replacement does exercise the background/border path. The intrinsic
uniforms describe a 2,048×416 surface; this is an observation of Vox, not proof
of Brave's GPU attachment dimensions. These captures have 4,244/4,243 native hits
and 474,166/477,441 native entries, zero misses/compiler calls, exact content,
fixed pins and zero exits; elapsed/peak are 55.752793792 seconds/8,826,060,800
bytes and 59.452539208 seconds/8,905,687,040 bytes. Instrumentation supplies no
performance acceptance.

Omitting positive-radii analytic fills with alpha below 0.1 changes 907 pixels
and is strictly a component diagnosis, not a candidate fix. The four largest
button-corner discrepancies are unchanged, so they are not caused by the omitted
shadow. Two smaller bottom-corner discrepancies improve but do not resolve.
The run records 4,245 hits/472,620 native entries, zero misses/compiler calls,
complete exact content, fixed pins and zero exits (38.703446458 seconds,
8,419,196,928 bytes sampled peak). Hash-journaled removal of the superseded thin-
rectangle generated C/preprocessed C reclaims 710,771,187 bytes; the newer accepted
all-ancestor inputs, both executables, source proofs, receipts and native caches
remain available.


Discarding fully transparent analytic rectangle fragments before depth writes
resolves all six original remaining button-corner pixels, but introduces 17
new discrepancies elsewhere. The strict result is therefore **32 differing
pixels**, maximum 67, and is rejected as a production change. Its shader,
69-index mesh, four samples, depth compare/write policy and positive-color
arithmetic otherwise remain unchanged. This narrows the investigation to
transparent-fragment/depth interaction; it does not prove a general discard
rule is correct. The diagnostic records 4,244 native hits/474,393 entries,
zero misses/compiler calls/pending/invalid entries, exact content, fixed pins,
successful PID adoption and zero browser/controller/guard exits
(61.098319334 seconds, peak 8,795,783,168 bytes). The best committed rendering
remains 21 pixels from the original reference. No production shader change is
retained.

The completed shadow/pipeline/discard probes are archived with hash verification
and idle locks in `scratch-receipts/continued-20261117-r18` (24 roots/116 entries).
Automated tests remain held.


### Runtime raster opt-ins in ordinary production builds, 2026-11-17

`05c41f8bf` removes the four custom compile-time raster switches while retaining
the existing explicit runtime environment opt-ins for document P3, image P3,
analytic thin fills, PNG decode density and GPU mipmaps. The runtime-disabled
path preserves the preceding behavior. The profile bridge now has a regression
source checking absent-profile output, borrowed bytes, repeat-pointer stability
and a null size pointer; it remains uncompiled/unrun under the requested hold.

The latest completed shared bundle, SHA-256
`5d1aeeb92a46bc8e8cd474007c0c8842223461ce548ea8273e0713be91dd7116`,
has 4,246 native hits/476,464 entries and zero misses/compiler calls but lacks
the former raster defines. Its initial P3-path assertion therefore fails:
there is no gamut-before-filter marker. The recorded **25,171 differing pixels**
are a legacy/off-path baseline with the other diagnostic switches enabled,
not reproduction of the 21-pixel experiment or evidence that P3 regressed.
The failed eligibility assertion and observed-image analysis are both retained.

The new sealed single-unit production build uses only the ordinary
`vox_production`, `vox_ui2` and `vox_sparse_ttf` defines, consumes 3,761 V sources
and zero tests, and verifies its parsed buffers and sealed native inputs before
and after compilation. Build/guard exits are zero: 389.48326475 seconds, sampled
peak 8,803,074,048 bytes. Executable SHA-256 is
`df9efc0209e7d675637d88148c11bf42de262319087ed0863ef6663628befc1e`.
The runtime-on capture is decoded-pixel-identical to the accepted **21-pixel**
image (maximum 10); runtime-off is identical to that shared-bundle **25,171-pixel**
baseline. Off disables the newly available options while retaining the same
other diagnostics; this is not a wholly unconfigured launch comparison.
The on PNG is `github-frozen-libjs-compiled-runtime-optin.png`, SHA-256
`5daf06a1b6c4c055ac33e5ca58b32ae4e81d85938455280ada1a92b9c3803ca7`.

Both use the actual 0130 native partition, `/usr/bin/false`, complete exact
33-row/56-commit/latest/README content, fixed pins, no errors, successful PID
adoption and zero browser/controller/guard exits. Page JavaScriptCore stays
uninitialized; cache misses/compiler calls/pending/invalid entries stay zero.
On/off native hits are 4,243/4,246 and entries 481,057/476,463. Elapsed/peak are
56.311067 seconds/8,926,052,352 bytes and 55.836197208 seconds/8,952,725,504 bytes.
These are diagnostic timings, not matched speed acceptance. The commit requests
the managed production rebuild; the private consumed executable validates this
change, not an earlier installed bundle.

Further original-page depth/mesh counterfactuals preserve all content, input
pins, native-cache gates, PID adoption and zero exits:

| Analytic rectangle counterfactual | Differing pixels | Resolved/new vs 21 | Native hits/entries | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- | --- |
| Original mesh, LessEqual with writes | 38 | 6 / 23 | 4,243 / 480,941 | 58.936967792 / 8,851,062,784 |
| 73 indices, LessEqual with writes | 37 | 0 / 16 | 4,244 / 473,528 | 55.612614417 / 8,835,956,736 |
| Exact strip-to-list expansion | 21 | 0 / 0 | 4,243 / 477,250 | 63.474231666 / 9,037,430,784 |
| Unique nondegenerate triangles | 21 | 6 / 6 | 4,246 / 482,258 | 38.707302084 / 8,457,027,584 |

The 73-index/LessEqual pair follows current upstream
[ShaderInfo.cpp](https://skia.googlesource.com/skia/+/refs/heads/main/src/gpu/graphite/ShaderInfo.cpp)
and the no-self-intersections mesh; this does not establish the installed
Brave revision's policy. A requested Chromium DEPS revision is unavailable
(HTTP 404). None of these variants improves the complete reference, so no
production mesh/depth change is retained.

Read-only glyph publication tracing repeats the 21-pixel image. At (138,749),
the source is 237 gray while the published result is 251 and the reference is
246. Two identical paths, rectangle `75,29.5,63.5,21`, are applied successively
on the same destination context from `BrowserApp__draw_command`; the second
already has exactly that clip as its prior bounds. The readback becomes 251
immediately after publication, with alpha 255. This identifies repeated
fractional clipping, rather than final screenshot encoding, as this pixel's
cause. The two read-only captures have 4,245 hits each, 483,022/482,356 native
entries and zero misses/compiler calls, fixed pins, exact content and zero exits
(39.729933625 seconds/8,469,708,800 bytes and 40.209927875 seconds/8,473,526,272
bytes). A guarded V-side exact-rectangle deduplication is being built; no claim
for that candidate is made yet.

Completed jobs move with idle-lock checks and before/after hash verification to
`scratch-receipts/continued-20261117-r19` (46 roots/254 entries). The active
clip-dedup build is excluded. The original Brave reference and zero/zero
tolerance remain unchanged. Full pixel parity and matched revisit speed remain
open; automated suites remain held.


### Identical rectangular clips: 20 differing pixels, 2026-11-17

`26b30df0b` skips an exact repeat of a finite ordinary rectangular clip in
Chromium native replay when `VOX_DIAGNOSTIC_RECTANGLE_CLIP_DEDUP=1`. Geometry
and normalized transform must match an earlier clip in that same list; rounded,
path and SVG mask clips remain on the existing path. This is geometric
intersection before antialiased coverage, not removal of an authored boundary.
The selected native mode remains explicit, and regression sources for repeated,
nonadjacent, transformed and unsupported clips are committed but uncompiled/unrun.

The sealed ordinary production build consumes 3,761 V sources and zero tests;
compiler/guard exits are zero in 410.411355625 seconds, sampled peak
8,905,867,264 bytes. Executable SHA-256 is
`4632da9274d0b17039999a9da26d90a8c9990485d71f3800b4ba262eed80296b`.
The staged main-file change is isolated from an unrelated working-tree hunk;
the isolated staged file exactly matches the consumed source hash.

On improves **21→20 differing pixels**, maximum 10, MAE 0.0000, RMSE 0.0157. Only the
file-name edge (138,749) changes and it becomes exact; no pixels regress or
become newly wrong. Off is decoded-pixel-identical to the preceding 21-pixel
image. The normalized compiled PNG is `github-frozen-libjs-compiled-20px.png`,
SHA-256 `a01cd432fbf64e3b7b67f3ff0472746f754f768e9ce1489a0e1c0d4476ca5f2b`.
The direct-live screenshot remains separately named and is not replaced by
this frozen-page result.

Both use the compatible 0130 native partition and `/usr/bin/false`, complete
exact full content, fixed pins, no author/native/cache errors, successful PID
adoption and zero browser/controller/guard exits. Each records 4,244 native
hits, zero misses/compiler calls/pending/invalid entries and an uninitialized
page JavaScriptCore context. Native entries are 472,809 on/472,792 off.
Guard elapsed/peak are 59.512364042 seconds/8,875,868,160 bytes and 58.239936333
seconds/8,892,727,296 bytes. Timings receive no performance credit.

Completed build/capture jobs move with idle-lock checks and hash verification
to `scratch-receipts/continued-20261117-r20` (10 roots/56 entries). A separate guarded
candidate is being built to apply ordinary rectangular text clips in the
existing cpuraster antialiased clip before glyph blending, with restoration of
the original native clips if rasterization declines. No result for that
candidate is claimed yet. The original reference and zero/zero tolerance remain
unchanged; full parity and matched compiled-revisit speed are still open.
Automated tests remain held.


### Fractional glyph clip edges: 15 differing pixels, 2026-11-17

`86324739d` intersects eligible ordinary axis-aligned text clips in document
space, then applies their fractional boundaries with the existing GG A8-mask
blend. Fully covered pixels retain the established glyph blitter. Other native
clips stay active, and the deferred rectangles are restored before native fallback
if mask generation, sample selection or GG replay declines. Selection is explicit:
`VOX_DIAGNOSTIC_GLYPH_RECTANGLE_CLIP=1`, together with the preceding raster
opt-ins. Opaque A8 ink and a consistent one/four-sample selection are required.
No reference coordinates or colors participate in this selection.

The complete original reference improves **20→15 differing pixels**, maximum
10, MAE 0.0000, RMSE 0.0156. All five changed pixels resolve, with zero regressions
or newly wrong pixels: two repository-title clip-edge pixels and three directory
commit-text clip-edge pixels. The same-binary off capture is decoded-pixel-
identical to the prior 20-pixel image. The normalized result is
`github-frozen-libjs-compiled-15px.png`, SHA-256
`134a10dd9e6ce6621ca48e82f0afb15b5409f8a4b73d7e0db872cd49ede0e483`.
The older direct-live screenshot remains separately named; this is a frozen-page
result, not a new live-site acceptance claim.

The ordinary single-unit `-prod` build consumes 3,765 V sources and zero tests,
verifies parsed buffers and sealed native inputs, and exits zero in 238.311652167
seconds, sampled peak 8,987,213,824 bytes. Executable SHA-256 is
`d466cae2f6fe193662ab63023852090297fceda2ee8b2530548dd2b227fd6376`.
The validated snapshot includes unrelated working-tree lines; only the feature's
changes are staged. Geometry/mapping/coverage-merge regression sources and the
one/four-sample GG mask test source are committed but remain uncompiled/unrun.
The managed post-commit rebuild is requested normally.

Both captures execute the compatible 0130 native cache with `/usr/bin/false`,
4,245 hits each, zero misses/compiler invocations/pending/invalid entries and no
cache, author or native errors. On/off native entries are 470,476/472,394. Exact
33-row/56-commit/latest/README content, input hashes and successful PID adoption
hold; page JavaScriptCore stays uninitialized. Browser/controller/guard exits
are zero. Guard elapsed/peak are 39.16719875 seconds/8,634,957,824 bytes and
38.356668083 seconds/8,547,762,176 bytes. Timings supply no performance credit.

The earlier attempts remain visible and are not production selections:

| Text-clip diagnosis | Strict result | Changes vs 20 | Native hits/entries | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- | --- |
| CPU antialiased clip | 21 | 1 resolved, 2 new, 1 changed with equal error | 4,244 / 473,542 | 52.45179725 / 8,896,266,240 |
| CPU-clip off | 20 | unchanged | 4,245 / 472,405 | 38.288256417 / 8,549,941,248 |
| GG blend over the complete glyph raster | 20 | 5 resolved, 5 new interior pixels | 4,245 / 472,317 | 38.952149125 / 8,447,115,264 |
| Full-GG off | 20 | unchanged | 4,245 / 472,223 | 38.354561375 / 8,552,497,152 |

Their sealed builds also exclude tests and exit zero. CPU/full-GG executable
identities are `612102df7056be9a4059cd66c16708b3bdf26bc448f0cf4bc39a46bb898396df`
and `86ca37bb8c922d0fa69f5b32c1ebc33ced6f23331910ec4fecfddbc4c092158c`;
build elapsed/peak are 246.058507125 seconds/8,925,921,280 bytes and
242.809548791 seconds/8,932,933,632 bytes. Each capture preserves exact content,
fixed inputs, the native-cache gates, PID adoption and zero exits. The accepted
implementation applies GG only where clipping affects coverage, avoiding the
unrelated interior rounding changes of the whole-raster variant.

The newer completed shared bundle is also checked in a fresh process:
SHA-256 `212567863b8f1e818f58b4813073436d54e4e5920f0c13dc5dcd06d75ac0a0c7`.
It contains the committed runtime options and rectangle deduplication, and
reproduces **20 pixels exactly** with 4,244 native hits/473,903 entries and zero
misses/compiler calls. It does not contain the later glyph-edge implementation;
the private consumed executable above validates 15. The read-only shared-bundle
separator probe records the complex-inset AA sentinel `-1` (`bf800000`) and
matrix bits matching the retained float paint transform. It changes no pixels,
has exact content/fixed pins/zero exits and a 52.718228917-second guard with
8,822,308,864-byte sampled peak. No AA-radius or transform adjustment is retained.

Completed/rejected jobs are archived with idle locks and verified hashes in
`scratch-receipts/continued-20261117-r21` (26 roots/141 entries) and accepted
edge jobs in `continued-20261117-r22` (10 roots/56 entries). Owned superseded
compiler inputs are hash-journaled before pruning: 20 files/3,579,384,010 bytes.
The newest accepted generated inputs, private executables, patches, source proofs,
receipts and native-cache partitions remain. Build scratch jobs and guards are
removed after archival.

The fifteen residuals are six rounded-button corner pixels, five rotated
separator pixels, two white-on-green Code-label pixels, one latest-commit avatar/
text-area pixel and one header edge. The original reference and zero/zero
tolerance stay fixed. Defaults remain unchanged, full pixel parity and matched
compiled-revisit performance remain open, and automated tests remain held.

### Captured Brave draw state and fresh shared control, 2026-11-17

`6e0b8c216` adds `tools/decode_metal_capture.py`, a read-only decoder for the
captured MTSP 0x400/GPUTools directory format. It follows the base-vertex/
base-instance indexed draw API and singleton buffer-array bindings actually used
by Dawn, links shader functions to source resources, and reads pipeline/depth
descriptors, viewports, scissors and optional Graphite rectangle buffers. It
checks record/resource boundaries and input hashes, rejects unsupported selected
signatures, and retains counts for undecoded opcodes. This is selected-state
inspection, not a general Metal replay or complete command decoder.

The finalized `brave-metal-2026-11-17T04-18-40-c000.gputrace` has **21,747 records,
296 indexed draws, 46 pipelines, seven depth states and 47 functions**. Optional
rectangle decoding identifies 113 draws/287 instances. The earlier r3 trace lacks
final metadata and remains incomplete evidence. The finalized r4 capture's
browser exit is zero, input hashes are unchanged, author diagnostics are empty,
full content validates, and its screenshot is pixel-exact against the original
Brave reference. Brave executable SHA-256 is
`019e37a757d8dca6dadf7d8e2407d90bd52a0ac31a4e5a49d1cf0a444ab3d3d0`.
The capture stream SHA-256 is
`ab768c38cf9f8e180d0a9986cee3e6d37f822788fdbe53fc2fd0906377b1294d`;
the decoded receipt also pins its index, compressed store and consumed buffers.

The final-scale notification background and border are instances 66 and 73 of
the draw at stream offset 5,172,380. Its viewport/scissor are 1024×256, with four
samples, depth/stencil format 260, full sample mask, sample coverage 1, alpha to
coverage/one disabled, and **Less depth comparison with writes enabled**. This
supports the current 69-index/Less policy, not the previously rejected
73-index/LessEqual experiment. Both the 69 indices and all 36 template vertices
match V's current template exactly; vertex-byte SHA-256 is
`6ae52526e98f52f72020c5521e63db4f1c52f747e00ca30e8c67ee97d6f17b30`.

The attached vertex/fragment sources are exactly the earlier cached-shader
diagnostic's sources after renaming entry points and buffer slots. This establishes
their connection to the actual matching Brave draw. Their captured source hashes,
including the terminating NUL, are
`f553c1418456a7c99a72bbbadf6cb90ccb4616acc1e6a249d6bf5462ddd47889` and
`1304ea9aad83c05f402a002046d2af524f32189dcb92fbca01e0c8875201c76c`.
The separator's nine matrix float bits match the earlier Vox upload trace. A new
read-only Vox probe also matches its uploaded RGBA bits exactly:
`3eb67d80,3ec622c0,3edab280,3f800000`. Neither shader source nor these input bits
justify a correction; the remaining rasterization discrepancy is unresolved.

The latest completed ordinary single-unit production bundle is reused:
`20261117-044846-30b9eb36`, executable SHA-256
`9060d0785fc4127c58709e102eb17bd2c6d271307d0d3242f62ba6806531b651`.
All four fresh processes use the original frozen GitHub archive/clock, existing
raster opt-ins, the compatible 0130 native cache and `/usr/bin/false`:

| Diagnostic | Strict differing pixels | Native hits / entries | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Same-binary off control, PID 20653 | **15**, unchanged | 4,243 / 476,931 | 55.2890875 / 8,985,182,208 |
| Rectangle vertex depth `j - 0.5`, PID 29291 | 517 | 4,245 / 480,935 | 43.216487291 / 8,588,296,192 |
| Rectangle vertex depth `j - 20/65536`, PID 33065 | 517 | 4,245 / 479,349 | 44.715683542 / 8,638,349,312 |
| Read-only color-bit probe, PID 51737 | **15**, unchanged | 4,246 / 482,512 | 42.0811015 / 8,462,991,360 |

Both depth probes produce the same image: zero resolved pixels, 502 newly wrong
pixels and one existing pixel worsened. They are rejected. They change only
rectangle vertex depth, leaving other clip/geometry depths intact; they do not
test a coordinated remapping of the renderer's depth domain and cannot rule out
every depth interaction. No production depth or shader change is retained.

Every capture has exact 33-row/56-commit/latest/README content, unchanged pinned
inputs, no author/native/cache errors, successful PID adoption, zero browser/
controller/guard exits, zero cache misses/compiler calls/pending/invalid entries,
and an uninitialized page JavaScriptCore context. The original Brave PNG
(`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`)
and zero/zero tolerance are unchanged. These diagnostics provide no speed credit.

The final decoder runs against the real trace under a 3 GiB guard, with decoder/
guard exits zero, 0.225130292 seconds and 30,883,840 sampled peak bytes. Initial
decoder attempts rejected variable-length resource names/returns; those failed
receipts remain alongside the successful decode. Automated suites remain held.
The tooling commit requests the normal coalesced production rebuild; no manual
browser build was queued. Local captures, traces, source probes, commands, hashes
and guards are retained in `scratch-receipts/continued-20261117-r28` and
`metal-trace-5204` beneath `docs/performance/libjs-github-browser-20261116`.
Full pixel parity and matched compiled-revisit speed remain open.

### Extended P3 glyph source: 13 differing pixels, 2026-11-17

`2624eace7` preserves extended transformed RGB through opaque A8 glyph coverage
and source-over blending, clamping only at the destination byte store. Selection
is explicit: `VOX_DIAGNOSTIC_EXTENDED_GLYPH_COLOR=1`, with the preceding P3/raster
options. Ordinary Canvas blitters and the bounded conversion keep their existing
behavior. Finite transformed RGB outside [0,1] selects the new CPU blend; author
alpha must be one. Fractional text-clip edges retain GG coverage and native
fallback restoration. No page coordinates or reference colors select the path.

The actual Brave text draw at stream offset 5,514,452 has four Code glyph
instances, 453–456. Its uniform color is
`[1.0000991821289062, 0.9999618530273438, 0.9999465942382812, 1]`.
Vox previously clamped red to one during P3 conversion. With A8 coverage 199
over red 66, keeping that source gives 213.51385 before byte rounding; clamping
first gives 213.49412. That explains both one-level red errors without changing
the glyph mask. The retained extraction script verifies its capture resources
and links the uniforms to the captured text vertex shader.

The complete original reference improves **15→13 differing pixels**, maximum
10. Exactly the two Code-label pixels change and resolve, with no new or
regressed pixels. The same-binary off capture exactly reproduces 15. The result
is `github-frozen-libjs-compiled-13px.png`, SHA-256
`95c69221d0b83f25ef6e6df9bafb3ce556787392205ca755d88f52cadc0cb894`.
It is a frozen-page result; the earlier direct-live screenshot remains separate.

The accepted canonical-source single-unit `-prod` build consumes 3,768 V sources
and zero tests, verifies parsed buffers and sealed native inputs, and exits zero
in 230.880658875 seconds with 8,988,229,632 sampled peak bytes. Executable SHA-256
is `1d828086c9e24ca8161fad859e893535df39ba487c90600d05f5b3c3fd397153`.
Every changed implementation file matches its consumed source hash. Conversion,
eligibility, extended A8 blending/alpha/padding and GG extended-color regression
sources are committed, but remain uncompiled/unrun under the test hold.

| Same-binary mode | Pixels | Native hits / entries | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Extended CPU blend, PID 65867 | **13** | 4,245 / 472,200 | 38.70957475 / 8,434,548,736 |
| Off, PID 66244 | 15 | 4,245 / 472,312 | 38.221539667 / 8,424,505,344 |

Both captures have exact 33-row/56-commit/latest/README content, unchanged pinned
inputs, no author/native/cache errors, successful PID adoption and zero browser/
controller/guard exits. Cache misses/compiler calls/pending/invalid entries are
zero, and page JavaScriptCore stays uninitialized. The compatible 0130 native
partition and `/usr/bin/false` remain selected. The original Brave PNG and
zero/zero tolerance are unchanged; these diagnostic timings give no speed credit.

The earlier full-GG variant also fixes the two target pixels, but introduces
253 Sign in text differences: 266 pixels total, maximum 84. It is rejected.
Its build exits zero in 229.475797292 seconds, peak 8,992,718,848 bytes,
executable `af1e7c2df724fd6fecfb063d17054b1c0d901ab0f1fac11dec124597764dac4b`.
GPU-on/off captures have 4,244/4,246 native hits, 474,179/470,142 entries,
zero cache misses/compiler calls and successful content/input/exit gates;
guard elapsed/peak are 52.026341667 seconds/8,896,233,472 bytes and
38.557416458 seconds/8,427,241,472 bytes. Off matches 15 exactly. The final CPU
blend avoids that GPU text resampling discrepancy. An initial V compilation
rejects an array alias assignment before C generation; that failed attempt is
retained, and the final implementation does not use that assignment.

The shared completed bundle available at the start of this investigation,
`bae97d63343c06b6218311b6eb97624ab8037e9197f31dfb8ca2bc278264f2cf`, predates
this feature; the consumed private executable above validates it. The commit
requests the managed production rebuild normally. Capture/guard receipts move
with idle-lock and SHA-256 checks to `scratch-receipts/continued-20261117-r29`;
private build/extraction records remain in `extended-glyph-p3-5204*` beneath
`docs/performance/libjs-github-browser-20261116`. Thirteen residuals remain:
six button corners, five separator pixels, one header edge and one avatar/text
edge. Full parity, live validation and matched revisit speed remain open.

### Extended P3 shape source: 12 differing pixels, 2026-11-17

`2c77167fb` applies the same late-clamping principle to opaque shape and underlay
colors, selected by `VOX_DIAGNOSTIC_EXTENDED_SHAPE_COLOR=1` with the preceding
raster/P3/glyph options. Finite transformed RGB stays extended until GPU blending
and the destination store. Default and translucent conversions retain their
existing behavior. The focused regression source covers selection, opaque
extended white and the translucent exclusion; it remains uncompiled/unrun under
the test hold.

The matching Brave capture identifies the header border at stream offset
5,067,656, rectangle instance 48, paint index 20 in `MTLBuffer-86-11`. Its RGBA
is `[1.0000991821289062, 0.9999618530273438, 0.9999465942382812, 1]`, the same
extended neutral source as the Code glyphs. The retained extraction script
verifies its capture-resource hashes. A shader-only diagnostic first restores
the clipped red excess for opaque white rectangles: **13→12 pixels**, one
resolved and none new. It preserves complete content/input/cache/exit gates,
records 4,245 native hits/472,290 entries, and exits zero in 38.667009084 guard
seconds, sampled peak 8,530,083,840 bytes. That injected probe is not the
implementation validation below.

The canonical-source implementation build consumes 3,768 V sources and zero
tests, verifies parsed buffers and sealed compiler inputs, and exits zero in
240.500482167 seconds, sampled peak 8,996,405,248 bytes. Executable SHA-256 is
`c496b94d43dbc94ac3dd51f62a2cb06aeb58b080b6d2b47d1a1bb223fa717e0c`.
The changed implementation matches its consumed source hash. An initial attempt
cannot start because its old compiler snapshot was pruned; the failure is
retained. The successful retry uses the current managed build's compiler,
preallocation, font and HTTP module snapshots. No additional shared production
build was queued; the feature commit requests its normal coalesced rebuild.

| Same-binary mode | Pixels | Native hits / entries | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Extended shape color, PID 76971 | **12** | 4,244 / 474,375 | 51.933439542 / 9,017,229,312 |
| Off, PID 78416 | 13, unchanged | 4,245 / 482,955 | 38.494075083 / 8,602,075,136 |

The implementation resolves exactly the header-edge pixel with no new or
regressed pixels. Both modes keep the earlier glyph correction enabled, exact
33-row/56-commit/latest/README content, fixed inputs, successful PID adoption,
no author/native/cache errors and zero browser/controller/guard exits. Native
cache misses/compiler calls/pending/invalid entries are zero; page
JavaScriptCore stays uninitialized. The compatible 0130 partition and
`/usr/bin/false` remain selected. The unchanged Brave reference and zero/zero
tolerance are retained. These diagnostic elapsed times provide no speed credit.

The normalized result is `github-frozen-libjs-compiled-12px.png`, SHA-256
`a4442ccdb1f0431c159cf7e9b1cde95ed749335d0dbc2faebba1d6d98e185e03`.
The live screenshot remains separate. Completed shape jobs move with idle-lock
and SHA-256 checks to `scratch-receipts/continued-20261117-r30`; private build,
probe and extraction records remain in `extended-shape-p3-5204*`. Four superseded
glyph generated/preprocessed compiler files (1,421,896,818 bytes) are hash-journaled
before deletion; binaries, source proofs and receipts remain. The newest accepted
shape build retains its full sealed compiler inputs. Twelve differences remain:
six rounded-button corners, five separator pixels and one commit-avatar edge.
Full parity, live validation and matched compiled-revisit speed remain open.

### Captured rectangle replay and root capture width: 7 pixels, 2026-11-17

`8b3ca8517` extends the Metal trace decoder to retain inline vertex/fragment
bytes, buffer bindings, attachment blending and serialized library options,
and export selected rectangle draws with hash-verified inputs. Dawn's projection
is inline slot 30; slot zero is unused by these shaders. The captured static
buffer starts at base vertex 12: the export explicitly zero-pads only the unused
prefix and verifies every referenced vertex. Export regression sources are
committed but unrun under the continuing test hold. The final real-trace decode
exits zero: 21,747 records, 296 indexed draws, seven depth states,
0.517326541 guard seconds and 32,587,776 sampled peak bytes. Earlier exporter
failures involving the unused prefix/binding and resource key are retained.

The finalized r4 Brave trace still matches the original reference exactly.
Standalone Metal replays use actual button draw 5,172,380 (base instance 66,
nine instances) and separator draw 5,154,768 (base instance 57, four instances),
with reconstructed uniform backdrops. Captured Dawn shaders and current GG
shaders produce byte-identical complete tiles: button BGRA SHA-256
`b552685a16a2889c0ef36d035660b2fe6f3b9ef8266a0ca8092f133c26df3722`,
separator `73c33adadfa6fca7879f6cbcf908fef990fad6e4c2f254fca1e3b8f0599058ba`.
Replacing button depths with Vox's values also leaves the tile unchanged.
These selected-draw replays reproduce four large button corners; the two lower
shadow-dependent corners cannot be accepted from the uniform-backdrop replay.
They are diagnostics, not complete-page replay or performance acceptance.

Keeping the separator buffers, shaders and geometry fixed isolates attachment
width. Both 1,024×256 and 1,024×416 produce the five correct reference pixels;
2,048×256 and 2,048×416 reproduce Vox's five one-level errors. Changing height
alone does not. A full-page MSL 4.0 probe leaves the shared bundle's 13 pixels
unchanged in both modes (4,243/4,244 native hits, zero misses/compiler calls).
An unrestricted half-width shader probe regresses to 2,489 pixels: five resolved,
2,481 new and one previously wrong pixel worse. Restricting that diagnostic to
the root attachment gives 13→8 with five resolved and none new; off repeats 13.
Those probes use the available shared bundle
`2c5e6da342aa8778cfe070fa6dd4f71cf7e17c82110376cca17d6a0d6f23b72e`,
which contains the glyph fix but lacks the later header-color fix. They do not
validate the implementation below. Read-only pipeline and buffer probes repeat
13 exactly and confirm the template vertex hash
`6ae52526e98f52f72020c5521e63db4f1c52f747e00ca30e8c67ee97d6f17b30`,
geometry, four samples, BGRA attachment, source-over blending and full scissor.
The remaining button cause is unresolved.

`77db37b0e` adds `VOX_DIAGNOSTIC_ROOT_CAPTURE_WIDTH=1`. When the root has one
column and layout density exceeds capture density, its raster projection uses
the capture pixel width. Rows, sample ownership and other layer grids remain
intact. Selection uses viewport/density inputs, with no page coordinates or
reference colors. Disabled mode, ordinary density, multiple columns, an already
narrower grid and invalid inputs keep existing behavior. Focused regression
sources cover those boundaries and borrowed cell ownership; they remain
uncompiled/unrun by request.

The final canonical-source single-unit C `-prod` executable is SHA-256
`3f72b920de27b227b1b20c678544feecb6381ea26af517a0d8474750400467a3`.
Verified parsed buffers contain 3,773 V sources and zero tests, and both changed
implementation files match their consumed hashes. Initial build attempts run
out of disk during generated C/object output. The successful retry compiles the
same sealed input and command, exiting zero in 196.092329792 guard seconds,
sampled peak 6,521,683,968 bytes. Generated C and preprocessed inputs use lossless
filesystem compression with unchanged SHA-256; no compiler flags are altered.
The superseded broad coordinate prototype is reverted and its patch retained.
Its first build was deliberately stopped for review; the next encounters an
unrelated syntax error, subsequently fixed by its owner. All attempts remain
in the receipts, including the successful prototype baseline build.

Concurrent LibJS changes require native ABI
`812aba8dedf9cfb6996a8cdf0aab5f04d4a1aa23b1dd32894d1f102632c5f972`;
the old 0130 partition is not relabelled. Preparation uses an isolated cache at
`~/Library/Caches/Vox/benchmarks/libjs-github-capture-grid-20261117/native-cache`
with the ordinary Clang native compiler. The first preparation hits the guard's
1,800-second wall limit after 18,304 valid records: child exit 137, wrapper 125,
sampled peak 11,220,058,112 bytes. Its provisional PNG is ineligible. Resuming
valid records with a 3,600-second timeout succeeds: PID 12909, zero browser/
controller/guard exits, 386.491729334 seconds, peak 10,986,913,792 bytes.
It compiles 5,474 additional executables in 43 invocations; all 81 requested
modules complete, with zero pending/invalid entries or errors. The final cache
contains 23,778 record JSONs and 186 libraries. Cache preparation gives no
compiler-disabled or performance credit.

| Final same-binary mode | Pixels | Native hits / entries | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Root capture width, PID 34352 | **7** | 4,245 / 470,258 | 38.23962725 / 8,537,391,104 |
| Off, PID 41180 | 12, unchanged | 4,245 / 472,272 | 38.198960167 / 8,582,971,392 |

Both fresh processes select `/usr/bin/false` as native compiler, execute the new
ABI cache, and record zero misses/compiler calls/compiled executables/pending/
invalid entries. Page JavaScriptCore stays uninitialized. The complete content
audit remains 33 rows, 56 commit links, latest and README; pinned inputs remain
unchanged, PID adoption succeeds, and author/native/cache errors and browser/
controller/guard exits are zero. Both modes also repeat the same 7/12 images
with native caching disabled, explicitly without claiming native execution for
that diagnostic. The original Brave PNG, frozen clock, 1,024×768 viewport,
layout/render density two, PNG density one, P3 normalization and zero/zero
tolerance remain unchanged.

Exactly five separator pixels resolve with no new or regressed pixels; maximum
channel error remains ten. The accepted frozen screenshot is
`github-frozen-libjs-compiled-7px.png`, SHA-256
`85c80b02bf5208a65a07405a77bea03f14eb5f5e5731a585570703cde085efe8`.
The direct-live screenshot remains separate. Seven pixels remain: six button
corners and one commit-avatar edge. Full parity, current live validation and
matched compiled-revisit performance remain open; these diagnostic timings
give no speed credit.

Completed job outputs, guards, registries and logs move with idle-lock and
SHA-256 checks to `scratch-receipts/continued-20261117-r31`; private builds and
probe/replay scripts remain under `metal-language-5204`, `button-state-5204*`,
`capture-width-probe-5204*`, `capture-grid-5204*` and `root-capture-width-5204*`.
Disk recovery journals identify removed superseded generated compiler files;
their executable/source proofs remain. The incomplete earlier Brave r3 trace
is compressed locally only after verifying all member hashes and symlink
targets; the finalized r4 trace stays unpacked. Failed diagnostic arguments,
compression and disabled-cache audit assumptions are retained with corrected
attempts. The managed commit hook requests the coalesced production rebuild;
no duplicate shared build was queued.

The subsequent draw-grouping replay keeps the same captured rectangle data and
GG shaders. Compacting the static vertex prefix, instance prefix or color slots
leaves the entire baseline tile byte-identical. Splitting the nine-instance draw
into one-instance calls changes exactly six pixels, raw BGRA SHA-256
`51266e02fad22c8b2dcff03c55dfcaf3e4d1b09f52bfd7540aeb76f81dac9a06`.
The four large corner values now exactly reproduce Vox's errors. The two lower
values also change, but still omit the real shadow contribution. Substituting
Vox's depths in the split replay gives the same bytes. Drawing each background/
border pair together, or separating the five fills and four strokes into two
calls, also gives those same six changes. Reordering all nine into adjacent
pairs within one call changes only two pixels. Thus grouping and ordering both
affect this captured legacy strip; this does not establish a safe general fix.
All captured resource hashes, control-tile hashes and before/after input pins
verify. Twelve replay variants finish with zero exits under 3-GiB guards.

A fresh read-only probe of the final implementation confirms that Vox sends
each button background/border as a two-instance pair. Its full image is exactly
the accepted seven-pixel image: PID 47669, 4,245 native hits/470,473 entries,
zero misses/compiler calls/pending/invalid entries, unchanged complete content
and inputs, and zero browser/controller/guard exits. Guard elapsed/peak are
38.405868459 seconds/8,461,156,352 bytes. Page JavaScriptCore stays uninitialized.
The grouping probes add no production renderer change or speed claim. Their
completed jobs move with hash and idle-lock verification to
`scratch-receipts/continued-20261117-r32`; scripts and raw tile outputs remain
under `button-batching-5204` and `metal-language-5204`. Automated tests stay held.

### Shared production confirmation and captured-shader grouping, 2026-11-17

The newest completed shared single-unit C `-prod` browser is now
`fe18a216c3b5195666de9520722abf986e60a3751c9a1bf0762fc77ea0bfa7fa`,
receipt `20261117-122951-3be37d4d`. Although its recorded head precedes the
root-width commit, its sealed consumed hashes include the final root-width
implementation. A fresh process with all preceding opt-ins reproduces the
seven-pixel image exactly: PID 57460, 4,246 native hits/470,279 entries in the
812a ABI partition, zero misses/compiler calls/compiled executables/pending/
invalid entries, and page JavaScriptCore uninitialized. Complete 33-row/
56-commit/latest/README content, unchanged input pins, adopted PID and zero
browser/controller/guard exits are verified. Guard elapsed/peak are
38.172230542 seconds/8,521,236,480 bytes. No separate production build was queued.

The grouping effect also occurs with **Brave's actual captured Dawn shaders**,
not only GG's equivalent shaders. The nine-instance captured draw repeats raw
tile hash `b552685a16a2889c0ef36d035660b2fe6f3b9ef8266a0ca8092f133c26df3722`;
splitting it repeats `51266e02fad22c8b2dcff03c55dfcaf3e4d1b09f52bfd7540aeb76f81dac9a06`.
Both match the corresponding GG replay byte for byte, including the same six
changed pixels. Shader invariance, compiler invariance preservation and disabled
fast math leave the split result unchanged; invariance leaves the unified
control unchanged too. Those compiler variants are rejected as fixes.

A second float attachment records primitive IDs and coverage while preserving
both complete original BGRA control tiles exactly. At (646,190), resolved mean
primitive ID/coverage change from 22.75/0.71923828125 to 1/0.45849609375 when
split. These are averages across four samples, not integer fragment IDs. The
diagnostic confirms different triangles writing the disputed pixels; it does
not establish a production depth rule. Its initial pipeline creation fails
because the vertex output declares point size with explicit triangle topology;
both failed shader runs (exit 5) are retained as ineligible. Removing that unused
output only in the diagnostic allows the corrected probe to run. No production
shader change is retained. The native shared-recording setters are currently
empty compatibility hooks; changing only their V eligibility cannot supply a
shared root draw pass.

`91252e0cf` adds `tools/replay_metal_rectangle.m` to make this experiment reusable directly
from `decode_metal_capture.py --export-rectangle-draw` exports. It accepts a
snapshot and a new raw BGRA output, plus `--split-instances` and an explicit
premultiplied `--background RRGGBBAA`. It checks resource sizes/hashes before
GPU work and again before publication, validates referenced vertex/instance/
paint ranges, rejects unsupported compiler/depth/stencil/sample policies, and
publishes atomically without replacing existing evidence. The supported ABI is
unclipped Dawn vertex-pulled rectangles, four-sample BGRA8, inline slot 30 and
the observed v225 relaxed-math options. Target size comes from the viewport;
this remains a selected-draw replay with a uniform backdrop, omitting other
passes, shadows and page publication.

The canonical tool compiles with `clang -Wall -Wextra` and replays the retained
button batch, split button batch and separator draw to all three known complete
raw-tile hashes, with zero native/driver/guard exits under 3-GiB guards. Rejection
regression sources for corrupt inputs, escaping resource paths and output
replacement are included but remain unrun under the test hold. All completed
jobs move with idle-lock and SHA-256 verification to
`scratch-receipts/continued-20261117-r33`; replay scripts and receipts remain
under `metal-invariance-5204`, `metal-primitive-5204`,
`metal-captured-split-5204` and `shared-root-width-5204`. The original Brave PNG,
zero tolerance and accepted seven-pixel screenshot remain unchanged. Full pixel
parity, current live validation and matched compiled-revisit performance remain
open; these diagnostics provide no speed credit.

### Disjoint rounded decorations: 3 differing pixels, 2026-11-17

`753c3b684` adds `VOX_DIAGNOSTIC_DISJOINT_ROUNDED_BATCH=1` with the preceding
raster/P3 options. Complete opaque rounded decorations with a common root
owner, transform and viewport policy can share one resolve across intervening
leaves whose conservative ink is disjoint. The crossed leaves retain their
original replay positions. Effects, resource boundaries, foreign owners,
unbounded ink, custom corner shapes and unsupported opacity keep ordinary
replay. Selection is bounded to 128 commands/32 descriptors and native capture
density one. Native failure leaves the original commands available for replay.
The existing single-group path keeps its allocation behavior through a shared
descriptor constructor; its original eligibility remains unchanged.

Bold/varied fonts deliberately keep face-wide bounds in ordinary layout. On
the original page these bounds overlap the next button even though the actual
glyph ink does not. The new separation proof refines them through the existing
eligible retained A8 raster path, preserving integer crop phase. Declined,
empty or edge-touching masks keep the original enclosure; ordinary layout and
culling bounds are unchanged. The Notifications enclosure, for example, spans
x=666.14453125 with width 104.5546875; its verified mask ink spans x=674 with
width 73. Crops are capped at 2,048×256. The selected final page batch contains
Notifications, Fork and Star shadows/backgrounds/borders, nine descriptors;
their labels, SVG icons and count badges remain in place.

Focused sources cover disjoint gaps, overlapping ink, effects, foreign owners,
underlays, custom corners, retained inactive SVG strokes, integer mask phase,
truncated masks and empty/invalid coverage. They and the small two-box fixture
are committed but remain uncompiled/unrun under the test hold.

The final canonical-source single-unit C `-prod` executable is SHA-256
`08909c931f26bbb553940b094795e2eb84548311480bdb6a696a01e53de8dc0a`.
Its sealed build consumes 3,774 parsed V sources and zero tests, verifies all
three changed implementation hashes, and exits zero in 249.24923125 guard
seconds with 9,003,352,064 sampled peak bytes. The available shared bundles
were checked first; neither contained this final candidate. No extra shared
production build was queued, and the commit requests its normal managed rebuild.

| Same-binary mode | Pixels | Native hits / entries | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Disjoint batch, PID 50355 | **3** | 4,245 / 472,303 | 38.760738209 / 8,553,529,344 |
| Off, PID 51450 | 7, unchanged | 4,245 / 472,234 | 38.021087084 / 8,575,107,072 |

Exactly four Star-button corner pixels resolve, with zero newly wrong or
regressed pixels. The original Brave reference, zero/zero tolerance, frozen
clock, 1,024×768 viewport, layout/render density two, PNG density one and P3
normalization remain unchanged. Both fresh processes use the 812a native ABI
partition with `/usr/bin/false`, positive native execution and zero misses/
compiler calls/compiled executables/pending/invalid entries. Page JavaScriptCore
stays uninitialized. Full 33-row/56-commit/latest/README content, unchanged
inputs, PID adoption, no author/native/cache errors and zero browser/controller/
guard exits are verified. These diagnostic timings provide no speed credit.

The accepted frozen screenshot is `github-frozen-libjs-compiled-3px.png`, SHA-256
`871e681957c466696191220fbe3720f17102458b4a8aff57b6a06e28d3084ab9`.
Maximum channel error remains ten, RMSE 0.0091. The residuals are Notifications
(648,188), error four; (646,190), error ten; and commit-avatar (54,339), error
one. The direct-live screenshot stays separate. Full parity, current live
validation and matched compiled-revisit speed remain open.

Four earlier page captures never enter a combined batch and repeat seven pixels;
they receive no improvement credit. They have 4,245/4,246/4,245/4,245 native hits,
472,247/472,346/472,318/472,428 entries, unchanged full content/inputs, zero native
misses/compiler calls and zero browser/controller/guard exits. Their builds also
consume 3,774 V sources and zero tests. The first strict candidate comparison
correctly rejects the missing eligibility marker; separately labelled ineligible
comparisons retain its image metrics. Subsequent traces isolate the conservative
glyph-bound overlap instead of relaxing the disjointness check.

Derived captured-draw probes remain separate from page acceptance. Removing
the underline yields eight button instances; captured order, paint order and
adjacent-pair order give the same whole tile, SHA-256
`bd5f7c2dde2265200a8c71a07d96d12ccfa5989cf9112ac4979c5bba64190169`.
The six-instance subset for shadowed buttons is
`891aba9516acc6d8bf7d35fe65ca379111c6ceafdd05941cb36ea8058c436b81`.
Those probes omit real shadows and other passes and cannot establish complete
page correctness or performance. Completed jobs move with idle-lock and hash
verification to `scratch-receipts/continued-20261117-r34`; private source/build
proofs and probe scripts remain under `rounded-cohort-5204` and
`rounded-batch-5204*`. Every attempt remains in the evidence.


### Image draw decoding and shared three-pixel confirmation, 2026-11-17

`2fa964251` extends the retained Metal trace reader with nonindexed image-quad
calls, fragment texture/sampler bindings, texture descriptor dimensions and
mip counts. Each draw snapshots descriptor identity before pointer reuse.
Unknown texture descriptor versions and changed command signatures decline;
GPU-written texture contents are explicitly **not reconstructed**. Focused
regression sources cover these boundaries and remain unrun under the test hold.
Python syntax parsing and actual-trace decoding pass. All 296 earlier indexed
records retain every prior field exactly; the same 21,747-record capture adds
755 nonindexed draws, 113 textures and 55 samplers. Guard elapsed/peak are
0.354418917 seconds/23,314,432 bytes, exit zero. Decoder SHA-256 is
`50e0dde5bad197e52355f82634f647eb3280ec0ec13b7ffd7900039943921e9e`.

The avatar's indexed draw at stream offset 5,532,036 uses a 40×40 texture with
six mip levels. Its source circle has radius 20, transform scales
0.22499999403953552/0.5 and AA radius 4.44444465637207. Read-only Vox vertex
tracing verifies the same values. Its shadow color's four float32 words match
Brave exactly: `3c980abb,3ca6fbc4,3cbd3936,3e189899`, including alpha
0.14901961386203766. Captured zero-filled initialization uploads cannot supply
final image-color evidence; their extraction is retained as ineligible. The
first local inspection script exits one on a string-handle conversion and is
retained beside the corrected reader.

The latest completed shared production executable is SHA-256
`2a6d72159438040cf72553c0eac3d52d03e55b74722a41e2c6944824abb01256`.
Its sealed source manifest matches all three committed batching implementation
files. A fresh PID 85877 reproduces the accepted **three-pixel** image exactly (decoded RGB),
with complete 33-row/56-commit/latest/README content, 4,245 native hits,
472,282 native entries and zero misses/compiler calls/pending/invalid entries.
Page JavaScriptCore stays uninitialized; all input pins remain unchanged, PID
adoption succeeds, and browser/controller/guard exits are zero. Guard
elapsed/peak are 37.968199875 seconds/8,530,690,048 bytes. This is the shared
production confirmation; it supplies no performance credit.

Two canonical-source candidates are rejected and fully reverted:

| Candidate / same-binary control | Strict differing pixels | Native hits / entries | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Natural-size PNG mip frame | 3, unchanged | 4,245 / 472,408 | 39.406334 / 8,546,238,464 |
| Its off control | 3, unchanged | 4,245 / 468,910 | 38.169274917 / 8,508,702,720 |
| Capture-density root tile rows | 13 | 4,245 / 472,334 | 39.051120834 / 8,446,001,152 |
| Its off control | 3, unchanged | 4,245 / 472,340 | 38.656541458 / 8,420,950,016 |

The PNG candidate uploads the full 60×60 logo and 40×40 avatar before color
conversion and mip generation instead of retaining the earlier reduced decode.
It changes zero page pixels. Its single-unit C `-prod` build consumes 3,774 V
sources/zero tests, exits zero in 238.352015542 seconds, peak 9,000,042,496
bytes; executable SHA-256 is
`76e538d286a77cd8c825c3d8c76827f7335e98e383f3df3135e6740b0ea0bbdd`.

The row candidate follows the observed 256-row Brave tiles instead of Vox's
416-row capture grid, regenerating MSAA ownership from the retained native ink
triggers. It leaves all three old errors unchanged and introduces ten one-level
border errors at the viewport bottom. Its build also consumes 3,774 V sources
and zero tests, exits zero in 237.913781041 seconds, peak 8,999,731,200 bytes;
executable SHA-256 is
`28ca1f1e3fade6436dd4d68d73adb6ffa3daaf850689617d9cf8e934fa0fc828`.
The off control exactly preserves the accepted image. Its proposed ownership
regression source remains only in the rejected local patch and is not compiled.
All four captures preserve complete content and unchanged inputs, use the actual
812a native ABI partition with `/usr/bin/false`, execute native code with zero
cache/compiler/error gates, adopt their PIDs and exit zero throughout.

A separate read-only Vox avatar-input capture preserves the same three pixels,
with 4,245 hits/470,080 native entries and no compiler calls or misses; guard
elapsed/peak are 38.306938458 seconds/8,545,779,712 bytes. Four derived button
draw groupings retain the original captured geometry and shaders. Adding the
underline to pair-ordered buttons does not fix Notifications; the original
captured nine-instance order still reproduces its two corners. These selected
draws over white are diagnostics, not page acceptance or performance evidence.


Publication tracing retains every attempt. The first two symbol-resolution
startup checks abort before document capture (browser -6, controller/guard one);
they are diagnostic failures and supply no rendering evidence. The next three
captures run normally but do not select the intended pixel because the filter
assumes the wrong native chrome geometry; they are explicitly ineligible for
publication attribution and retain their unchanged three-pixel metrics. A
selected-readback follow-up and the final calibrated trace both preserve the
accepted image, fixed inputs, complete content and zero exits. The final run
has 4,245 native hits/472,265 native entries, no compiler calls or misses;
guard elapsed/peak are 38.179727042 seconds/8,523,055,104 bytes.

The native bitmap is 1,024×852: a 60-pixel top chrome inset, 768 document rows
and 24 status rows. The calibrated hook follows document pixel (54,339) at
native memory row 399. The avatar's 15×27 readback publishes source
`(97,98,98,255)` unchanged. A later 156×60 text raster spanning that point
already contains `(94,96,96,255)`, which publication also copies unchanged.
The text begins at layout x=108 (capture x=54), so it can overlap the avatar's
right edge. This localizes Vox's observed change to the text raster, but does
**not** establish whether its coverage/blend or Brave's underlying avatar
sample is responsible: the independent pre-text Brave pixel is not yet known.
No glyph or image correction is inferred from this observation.

The accepted screenshot and original Brave reference remain unchanged at three
pixels, maximum error ten. The direct-live capture remains separate. All
rejected implementation edits are reverted. Raw attempts, source pins, guards,
images and commands are retained locally under `metal-image-5204`,
`rounded-cohort-5204-r2`, `png-native-mips-5204`, `root-capture-rows-5204` and
`scratch-receipts/continued-20261117-r35`. The archive verifies idle locks,
SHA-256s and symlinks before removing its completed Build entries. Automated
tests remain paused; full pixel parity, current live validation and matched
compiled-revisit performance remain open.

The initial post-capture file-hash assertion rejects differently encoded PNG
files; the retained follow-up compares decoded RGB SHA-256s and confirms exact
image identity for the shared bundle, row-grid off control and calibrated
publication trace. Neither the captures nor reference are replaced. The archive
moves 106 completed roots/298 files, verifies all member identities and exits
zero in 0.165635541 seconds, sampled peak 851,968 bytes. Renderer source files
are clean after both candidate reverts.


### Shared image and overlapping text samples: 2 differing pixels, 2026-11-17

`289da9c02` adds `VOX_DIAGNOSTIC_SHADOWED_PNG_TEXT=1` alongside the preceding
P3/raster options. An eligible unblurred shadow, PNG and adjacent horizontal
A8 text run share one GPU pass when the text's retained ink intersects the
image. Resolving the image before blending the glyph loses its individual
multisample background values. Keeping both until the final resolve corrects
the avatar/text pixel at (54,339), from `(94,96,96)` to the reference's
`(95,95,96)`, without changing any other pixel.

Selection requires the same root owner, transform and viewport policy, opaque
ordinary text, no separate text clips/effects, native capture density one,
zoom one and zero scroll. The existing A8 path preserves face selection,
smoothing, snapping and mask-cache behavior. Unsupported masks and native
preflight failures retain original replay. The union crop is capped at
2,048×256. The native backdrop preflight requires the active bitmap context,
no transparency depth, valid RGBA storage and a compatible transform. Each
owning tile receives the rebased glyph mask; the image clip is restored before
drawing text outside the image. Source-image gamut conversion stays separate
from destination-space shadow and glyph colors. Native failure consumes none
of the commands.

The focused sources cover selection exclusions, foreign owners, image-clip
isolation for later text, and failure without destination mutation. They are
formatted and committed but remain uncompiled/unrun under the test hold.
The canonical-source single-C `-prod` build consumes 3,776 parsed V sources,
zero tests, verifies all five implementation hashes, and exits zero in
252.203100916 guard seconds with 9,001,254,912 sampled peak bytes. Executable
SHA-256 is `e4b517d588c1443e579fa57d184a1d29437123197d7999cb041249cc7b512f8a`.
The shared completed bundle was inspected first and cannot exercise this new
path; the feature commit requests its normal coalesced production rebuild.

The checkout's newer native-tier inputs produce ABI
`94180d7aef29ad2a8c9bc758e1ad87846f4794a7d41896b8c65d242e7a4609ce`.
The initial compiler-disabled on/off attempts cannot use the historical 812a
partition: they have zero native hits/entries, 4,265 misses and a failed
`/usr/bin/false` compiler attempt. The strict native comparison rejects them.
Separately labelled interpreter-only image comparisons show 2/3 pixels,
respectively, and receive no compiled-cache or performance credit.

Ordinary `/usr/bin/clang` preparation of this executable's actual 9418 partition
passes: 23,778 compiled executables, 186 compiler invocations, 81/81 modules,
25,643 prepared functions, 19,533 queued functions, zero unsupported functions,
zero pending/invalid entries and an empty error. Compilation totals
1,853,759.456411 ms and loading 40,688.159622 ms. The guard exits zero in
1,913.443418583 seconds, sampled peak 11,270,619,136 bytes; browser/controller
also exit zero, full content is present and input identities stay fixed.

Fresh compiler-disabled reopens then establish the retained result:

| Same-binary mode | Pixels | Native hits / entries | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Shared image/text, PID 8964 | **2** | 4,245 / 473,486 | 38.446940375 / 8,455,307,264 |
| Off, PID 10065 | 3, unchanged | 4,245 / 472,741 | 38.402479458 / 8,446,345,216 |

Both runs use `/usr/bin/false` with the same reported 9418 ABI, positive native
execution, zero misses/compiler invocations/compiled executables/pending/invalid
entries and an empty error. Page JavaScriptCore stays uninitialized. Complete
33-row/56-commit/latest/README content, native path markers, fixed input hashes,
PID adoption and zero browser/controller/guard exits pass. The original Brave
reference, frozen clock, 1,024×768 viewport, density-two layout/rendering,
density-one capture, P3 normalization and zero/zero tolerance remain fixed.
The candidate resolves exactly one pixel, with zero new or regressed mismatches.
These instrumented functional captures and preparation timings provide no
performance acceptance.

The accepted frozen compiled screenshot is `github-frozen-libjs-compiled-2px.png`,
SHA-256 `eabcdbc15a70621ea17d33745e5f039ff1ae4a4075b218308a3f050691a0476d`.
Two Notifications corners remain: (648,188), error four, and (646,190), error
ten. Maximum error is ten and RMSE 0.0091. The earlier three-pixel and direct-live
screenshots remain separate. Full parity, current live validation and matched
compiled-revisit speed remain open.

A separate unshadowed-background batch experiment is rejected and reverted.
Its build consumes zero tests and exits zero in 336.999326417 seconds, peak
8,988,917,760 bytes. On/off captures both retain two pixels with no changes;
the partially prepared cache yields 1,971/2,304 hits and 254,871/313,582 native
entries, plus misses and failed disabled-compiler attempts, so they are
ineligible for compiled-cache acceptance. Their guards exit zero in
39.718093833/39.547725958 seconds, peak 8,405,893,120/8,447,311,872 bytes.
One comparison correctly fails its nonunique index-14 marker assertion: after
hydration Sponsor can gain a shadow, selecting the original shadow batch at
that index. The corrected pixel-only comparison retains this limitation rather
than attributing the result to the new path. The original failed assertion,
source patch and every capture remain local.

Raw commands, source proofs and rejected variants remain under
`shadowed-png-text-5204` and `plain-rounded-batch-5204`; completed jobs move to
`scratch-receipts/continued-20261117-r36` with idle-lock, SHA-256 and symlink
verification. The archive moves 50 roots/158 files, exits zero in 0.166135208
seconds and peaks at 393,216 sampled bytes. All automated suites remain held.


### Per-sample rectangle replay; two pixels remain, 2026-11-17

`796583540` adds `--samples-output OUTPUT.rgba32f` to the canonical
`tools/replay_metal_rectangle.m`. For the retained Dawn solid-rectangle fragment
ABI, a separate unblended RGBA32F attachment records each sample's primitive ID,
source alpha/coverage, fragment-position Z and W. Pixel-major records contain
four samples of four native float32 components; untouched samples contain -1.
The option caps captures at 1,048,576 pixels, rejects unsupported fragment ABIs,
preflights both output names and publishes without replacing evidence. Its
receipt hashes the sample output and states its interpretation limits. Normal
replay stays unchanged. Existing-sample preservation, output-alias rejection
and duplicate-option regression sources are included but remain unrun under
the continuing automated-test hold.

The canonical tool compiles with `clang -Wall -Wextra` under a 3-GiB guard:
exit zero, 0.408541625 seconds, sampled peak 93,143,040 bytes. Four retained-draw
diagnostics also exit zero, 0.63794225 seconds, peak 64,438,272 bytes. Ordinary
unified replay and instrumented unified replay both reproduce the complete
`b552685a16a2889c0ef36d035660b2fe6f3b9ef8266a0ca8092f133c26df3722` BGRA tile.
Instrumented split and eight-instance replays reproduce their earlier complete
`51266e02fad22c8b2dcff03c55dfcaf3e4d1b09f52bfd7540aeb76f81dac9a06` and
`bd5f7c2dde2265200a8c71a07d96d12ccfa5989cf9112ac4979c5bba64190169` tiles.
Every captured resource, tool source, executable and output hash verifies.
These are selected draws over white, omitting shadows, other passes and page
publication; they provide no page-correctness or performance acceptance.

At (646,190), the captured nine-instance draw records primitive IDs `[1,30,30,30]`
with respective coverage `0.45864123 / 0.80638552 / 0.80638552 / 0.80638552`.
Splitting the draw, or removing the independent underline instance, records
`[1,1,1,1]` with coverage 0.45864123 throughout. Fragment-reported Z is exactly
0.9996795654296875 and W is one in every record. At (648,188), the nine-instance
case gives one low-coverage sample and three higher-coverage samples; the split
case gives two of each. This isolates a sample-ownership difference while
preserving the original complete BGRA controls. Reported fragment Z is not a
readback of the depth attachment or the hardware depth-test result; the probe
does not establish a safe replacement depth rule.

A canonical-source candidate tries commuting a later compatible fractional thin
fill into the disjoint rounded-decoration resolve. Every containing clip stays
with the fill; every crossed leaf remains in place and must have bounded,
disjoint ink. The 1,024-command/32-descriptor scan selects the actual late Code
underline. The source-sealed single-C `-prod` build consumes 3,781 V sources and
zero tests, exits zero in 279.14085175 seconds, sampled peak 8,946,008,064 bytes.
Executable SHA-256 is
`d6599ab0dddf4fcd81e4058cee9a21f323a96f11ef4b30a1605af5919bee919e`.
The latest completed shared bundles were inspected first; they cannot exercise
this new path, so no duplicate shared build was requested.

| Candidate mode | PID | Strict pixels | Guard seconds / sampled peak bytes |
| --- | ---: | ---: | --- |
| Future fill enabled | 25141 | 2, unchanged | 39.236031292 / 8,141,864,960 |
| Off control | 26894 | 2, unchanged | 38.208654667 / 8,095,662,080 |
| Generalized read-only draw trace | 29829 | 2, unchanged | 38.485656958 / 8,012,365,824 |

Native-tier inputs differ from the accepted executable, so these three runs
explicitly disable the native cache. They receive no compiled-execution credit.
Each preserves complete 33-row/56-commit/latest/README content, unchanged input
hashes, PID adoption, no author/native errors and zero browser/controller/guard
exits. The original Brave reference, frozen clock, viewport, density and zero
tolerance remain unchanged. The first comparison incorrectly expects a final
native-cache receipt while caching is disabled and exits one; a separate
corrected image-only comparison retains that failure and passes the actual
cache-disabled policy. The first read-only GPU filter records zero viewport
dimensions and selects no draws; its images remain valid, but it supplies no
draw-order attribution. A follow-up removes that filter and records the
actual nine-instance draw: underline, Sponsor/Notifications/Fork/Star fills,
then those four borders. This differs from Brave's captured whole-list order.
Appending the underline alone therefore supplies no fix. The candidate is
fully reverted; its source patch, sealed executable and all attempts remain.

Raw commands, source proofs and per-sample records remain locally under
`metal-samples-5204`, `metal-sample-tool-5204` and `rounded-future-5204`.
Idle-lock, SHA-256 and symlink verification moves 35 completed roots/80 files to
`scratch-receipts/continued-20261117-r37`, exit zero in 0.162606292 seconds,
peak 540,672 sampled bytes. The retained compiled screenshot remains exactly
`github-frozen-libjs-compiled-2px.png`; both Notifications corners, full parity,
current live validation and matched compiled-revisit performance remain open.
No renderer change is retained, and automated suites remain paused.


### Stored depth and coverage masks: rejected whole-page identity, 2026-11-17

`2dc3bb649` extends the canonical rectangle replay with
`--sample-mode fragment|depth|coverage|post-depth-coverage`, used alongside
`--samples-output`. Default fragment output retains its prior four components.
Depth mode replaces the fourth component with the stored Depth32 sample;
coverage modes replace the third with the raster coverage mask. The post-depth
mode requests early fragment tests and `post_depth_coverage`, as defined by the
[Metal language specification](https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf).
Receipts label every component and the mode. Untouched depth samples report the
clear value one; other untouched components retain -1. Unsupported or duplicate
modes, or a mode without an output, decline before GPU work. Focused rejection
sources are included but remain unrun under the automated-test hold.

The canonical helper compiles with `clang -Wall -Wextra`, exit zero, guarded
elapsed 0.845087833 seconds and sampled peak 118,423,552 bytes. Thirteen manual
retained-draw replays cover ordinary control plus all four modes on the captured
nine-instance, split and eight-instance cases. Every complete BGRA tile matches
its known control hash, every source/resource/output identity remains fixed,
and all twelve sample outputs agree with their labelled untouched values.
The guard exits zero in 1.662629833 seconds, peak 78,004,224 sampled bytes.
These selected draws over white omit real shadows, other passes and publication;
they supply no whole-page correctness or performance credit.

At (646,190), the final stored depth is exactly 0.9996795654296875 for every
sample in both unified and split draws, matching the fragment-reported value.
Both coverage modes record mask 1 for primitive 1 and mask 14 for primitive 30
in the unified draw; the split draw records mask 15 for primitive 1 throughout.
Thus the depth readback finds no differing final sample value. It does not
reconstruct earlier rejected fragments or establish their ordering. Explicit
early fragment tests and sample-frequency shading separately preserve all
three known complete controls in each mode.

Six isolated-triangle replays retain their captured inputs and record only one
covered sample for the extracted triangle 1 at that point, versus three for
triangle 30. These do not by themselves validate a mapping to full-strip IDs.
An attempt to add a flat provoking-vertex varying changes the unified, split
and eight-instance controls by 3/9/5 pixels. Its image-invariance audit correctly
fails, guard exit one, so those records are rejected for original-draw
attribution. No rasterizer bug or safe production depth rule is inferred.

A separate explicit coverage-mask return experiment makes the selected split
and unified rectangle results identical, correcting the target corners but
changing other pixels. Its full-page diagnostic is rejected: **2→18 differing
pixels**, two resolved and eighteen newly wrong; maximum error rises to 67.
It introduces Sponsor/button, header and other edge differences. Its off control
exactly reproduces the accepted two-pixel image.

| Pinned diagnostic mode | PID | Native hits / entries | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Explicit mask return | 47696 | 4,245 / 474,674 | 54.889289792 / 9,009,676,288 |
| Off control | 55143 | 4,245 / 483,499 | 40.798582459 / 8,508,784,640 |

Both fresh processes use the earlier accepted executable
`e4b517d588c1443e579fa57d184a1d29437123197d7999cb041249cc7b512f8a`,
its actual 9418 native ABI partition and `/usr/bin/false`. Native execution is
positive; misses, compiler calls, pending/invalid entries and errors are zero.
Page JavaScriptCore remains uninitialized. Complete 33-row/56-commit/latest/
README content, fixed inputs, PID adoption and zero browser/controller/guard
exits pass. The original Brave reference, frozen clock, viewport, densities,
P3 normalization and zero tolerance remain unchanged. The injected library
changes only analytic-rectangle shader source in this instrumented diagnosis;
these runs are not a new shared-production or performance acceptance. The
latest completed shared bundle was inspected, and no manual browser build
was queued. No renderer implementation is retained.

Raw commands, source derivations, failures, controls and sample buffers remain
locally in the eight new `metal-*-5204` diagnostic directories identified by
`scratch-receipts/continued-20261117-r38`. Idle-lock, SHA-256 and symlink checks
move 40 completed roots/72 files there, exit zero in 0.200885333 seconds,
sampled peak 409,600 bytes. The accepted compiled screenshot remains unchanged
at two Notifications pixels. Full parity, current live validation and matched
compiled-revisit performance remain open; automated tests remain paused.


### Direct live navigation and partial native-cache reopen, 2026-11-17

`6d9819767` adds mutually exclusive `--url HTTP(S)-URL` and `--archive` sources
to `tools/libjs_browser_diagnostic.py`. Direct navigation uses current network
responses and the normal clock, without constructing a replay server or
inheriting its proxy/private CA. Source metadata explicitly labels mutable
responses. Fresh profiles, bundle leases, PID adoption, executable/library
fingerprints and existing document/cache audits remain in place. Invalid URLs,
credentials and conflicting sources decline before launch. Focused regression
sources accompany the feature but remain unrun under the automated-test hold.
Two pre-existing summary-field additions in the tool are excluded from this
commit and left in the working tree.

The latest completed shared production executable at the start is
`8aadccc4dce3f76dc5d4bee10ad87a604d58ac10fcc73c7f847a1a52dc0de7aa`,
with single-C literal `-prod` receipt
`Build/production-build/receipts/20261117-153839-f494e60b/frozen-compile.json`.
No additional browser build is requested. Both initial captures explicitly
disable the native cache and use a 1024×768 document viewport, layout/render
scale two, capture scale one and the retained raster/profile options.

| Shared production check | PID | Content | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Direct live GitHub, interpreter | 17632 | 34 rows / 53 commit links / latest / README | 39.655758 / 8,775,483,392 |
| Original frozen archive, interpreter | 18725 | 33 rows / 56 commit links / latest / README | 38.060907667 / 8,103,837,696 |

Both have zero browser/controller/guard exits, unchanged inputs, no reported
author/native errors and uninitialized page JavaScriptCore. The live check
evaluates all 76 modules, with 4,310 function bytecodes compiled, 4,142 entered
and 60,634 reused. Its image is
`current-live-libjs-interpreted-20261117.png`, SHA-256
`cb75768c3f4652df46d9ea10847029717c26f35c12f4babbedca200924d8e86b`.
This supplies interpreter execution evidence, without compiled-native credit.
The archive control exactly reproduces the retained two-pixel image with zero
changed pixels. The original Brave reference, frozen clock, P3 normalization
and zero tolerance remain unchanged. Its comparison guard exits zero in
2.323052417 seconds, sampled peak 259,129,344 bytes.

A fresh direct-live process, PID 32709, then prepares the ordinary Clang native
cache in its actual ABI partition
`06a04ee8d6666206073e57b0cce172d4a57af55012c8e59801cb0483229b2b19`.
It compiles **24,099 executables in 189 compiler invocations**, with 4,398 cold
misses, zero hits, zero pending/invalid executables and no final compiler error.
All 76 modules finish preparation: 26,042 prepared functions, 19,721 queued
functions and zero unsupported functions or preparation diagnostics. All 76
modules evaluate, content remains complete, input hashes remain fixed, PID
adoption succeeds and browser/controller/guard exits are zero. The 12-GiB
guard records 2,439.827712208 seconds and a sampled peak of 12,134,825,984 bytes.
Reported compile/load times are 2,371,566.309037001 / 42,943.372002 milliseconds.
The PNG is written about 47.988 seconds after launch; subsequent shutdown drains
the native compilation queue. The 40.7-minute guard interval therefore includes
preparation after capture and cannot be compared with ordinary page-load time.
This cold process records zero native entries: it interprets before preparing
the cache. Earlier ABI partitions are neither renamed nor copied.

The first reopen controller incorrectly requires positive native entries in
that cold preparation audit, exits one and launches no reopen browser. Its
41.432815542-second guard and failed audit are retained. The corrected audit
requires positive entries only for the reopened process and verifies all other
preparation gates before launching it with the same executable and cache.

The actual compiler-disabled reopen, PID 37951, executes **495,412 native
entries**, with **2,898 cache hits, 1,490 misses and 1,490 pending executables**.
All 76 modules evaluate and the full live content audit passes, without reported
author/native DOM errors or page JavaScriptCore initialization. Fixed inputs,
PID adoption and zero browser/controller/guard exits pass; the guard records
43.288264542 seconds and 9,576,316,928 sampled peak bytes. However, the final
native error is `Native compiler exited 1:` from `/usr/bin/false`. The zero
successful compiler-invocation counter does not mean no compiler was attempted.
The strict zero-miss/no-error audit correctly exits one. Eleven module URLs
change between preparation and reopen, including `code-view`, `code-menu`,
`core` and `repositories`; both graphs contain 76 URLs. These are mutable live
responses, so a deployment or response variant cannot be distinguished here.
This is partial native execution evidence, with no zero-miss or speed claim.

The new explicitly partial image is
`current-live-libjs-native-partial-20261117.png`, SHA-256
`98a130a6fa212dbdce393c5e120f10c319888e5ab83a6e3c096f78b721b44796`.
It does not replace the earlier fully cached live screenshot or the accepted
frozen compiled two-pixel screenshot.

A planned refresh stops at its executable-identity guard before launching any
browser: the shared worker has published
`d166b53e27274390a698704536cd3984a15b1094579e0c0f9fb126616565b56c`,
whose receipt changes 22 consumed LibJS source hashes. No old ABI is forced
onto that runtime. Validation of the newer executable requires a fresh pinned
cohort; these completed checks cannot establish its behavior.

Separately, 15 selected-draw replays change constant color/radius/stroke varyings
to flat interpolation individually and together, alongside ordinary controls.
Every ordinary control matches its prior hash; each flat variant exactly
reproduces the earlier rejected explicit-mask image, with 3/9/5 changed pixels
for unified/split/eight-instance draws. No renderer change is retained and no
GPU bug is inferred. Helper compile/replay guards exit zero in 0.917481917 /
2.814899167 seconds, sampled peaks 122,552,320 / 46,071,808 bytes.

Raw commands, failures, identities, module graphs and captures remain local in
`live-url-5204`, `metal-constant-varying-5204` and `metal-spec-5204`. Idle-lock,
SHA-256 and symlink checks move 30 completed roots/62 files to
`scratch-receipts/continued-20261117-r39`, exit zero in 0.188624458 seconds,
sampled peak 393,216 bytes; this job's Build outputs and locks are removed.
Full frozen parity, a current zero-miss live reopen and matched compiled-revisit
performance remain open. Automated tests remain paused.


### Strict native-reuse diagnostics and newer runtime checks, 2026-11-17

`87d29a296` adds `--require-native-reuse` to the browser diagnostic. It requires
LibJS, an explicit persistent cache and native execution diagnostics. Both the
capture-time and shutdown receipts must show positive native hits and execution
entries, a consistent ABI, no initialized page JavaScriptCore, zero misses,
invalid/pending/compiled executables or compiler invocations, and an empty cache
error. Missing counters fail the check. A screenshot with a failed compiler
now exits one when this option is selected, even though the current counter
reports only successful compiler invocations. The receipt explicitly limits
the check to cache/execution; page content, pixels and performance remain
separate checks. CLI, absent-proof, compiler-error and ABI-change regression
sources are committed but remain unrun under the automated-test hold. The two
pre-existing summary-field additions remain excluded from the commit.

Fresh processes exercise the previously unvalidated shared executable
`d166b53e27274390a698704536cd3984a15b1094579e0c0f9fb126616565b56c`
with its actual native ABI
`b32c6cda1d21c6618167f155e29fa1f51192c6c09c86208025bcc3c250b24e45`.
The existing single-C literal `-prod` receipt is
`Build/production-build/receipts/20261117-173658-4f20c82c/frozen-compile.json`.
No manual browser build is requested. A controller holds the bundle read lease
across each preparation/reopen sequence, with separate fresh private profiles,
guard PID adoption and unchanged executable/library/tool inputs throughout.

| Hacker News homepage check | PID | Native result | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Archived cold preparation | 69177 | 6 compiled / 1 compiler invocation | 3.014604750 / 444,317,696 |
| Archived compiler-disabled reopen | 69231 | 6 hits / 6 native entries / zero misses | 2.870169375 / 410,599,424 |
| Archived empty-cache control, compiler disabled | 69280 | 6 misses / zero entries / expected strict failure | 2.894460916 / 409,960,448 |
| Direct live cold preparation | 70046 | 6 compiled / 1 compiler invocation | 3.925974750 / 445,251,584 |
| Direct live compiler-disabled reopen | 70241 | 6 hits / 6 native entries / zero misses | 3.780473833 / 399,720,448 |

Both reopens pass the strict capture/shutdown check with `/usr/bin/false`:
zero misses, compiler invocations, newly compiled executables, pending/invalid
entries and errors. The empty-cache control has zero successful compiler
invocations but retains `Native compiler exited 1:` and six pending entries;
its diagnostic/guard correctly exit one while its browser exits zero. Its PNG
is byte-identical to the successful archived captures, showing why image and
cache acceptance need independent checks. Other browser/controller/guard exits
are zero, author/native errors are absent and page JavaScriptCore remains
uninitialized. These homepage initialization checks do not exercise comment
collapse callbacks or supply a matched performance cohort. Their short guard
intervals include the fixed two-second capture delay and are not speed credit.
The direct-live compiled screenshot is
`current-live-hacker-news-native-20261117.png`; the earlier GitHub images remain
unchanged. Native partitions are used as generated, without copying old ABI data.

The same shared executable also completes separate GitHub interpreter controls
with the native cache explicitly disabled, retaining the previous viewport,
layout/render/capture densities and raster/profile options:

| GitHub check | PID | Evaluated modules / content | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Original frozen archive | 72446 | 81 / 33 rows / 56 commit links / latest / README | 37.490210500 / 7,930,462,208 |
| Direct live responses | 74100 | 76 / 34 rows / 53 commit links / latest / README | 38.721670083 / 8,474,279,936 |

All module promises fulfill. Inputs remain fixed, PID adoption succeeds, no
author/native errors are reported and browser/controller/guard exits are zero.
The frozen image exactly reproduces the accepted two-pixel image: zero changed
pixels, maximum reference error ten, unchanged original Brave reference and
zero tolerance. Its comparison guard exits zero in 2.077626084 seconds, sampled
peak 261,193,728 bytes. The first controller uses incorrect module-audit field
names and exits one after the successful archive capture. That failure is
retained; a corrected controller checks `status` and `promise_state`, verifies
the original capture without relaunching it, then completes the live capture.
The new live interpreter image is
`current-live-libjs-interpreted-d166-20261117.png`, SHA-256
`8bf5a85b323f19da7a9db7300dfd6b0c1d72fa7dd106b79da217770c69865b2c`.
These interpreter controls provide no compiled GitHub execution credit.

Raw commands, guards, source pins, rejected control and captures remain locally
in `strict-native-reuse-5204` and `latest-runtime-5204`. Idle-lock, SHA-256 and
symlink verification moves 30 completed roots/98 files to
`scratch-receipts/continued-20261117-r40`, exit zero in 0.182736916 seconds,
sampled peak 245,760 bytes; this job's Build outputs and locks are removed.
Full frozen parity, a current zero-miss GitHub live reopen and matched
compiled-revisit performance remain open. Automated suites remain paused.


### Fixed-bundle live cohort: changing module graphs, 2026-11-17

A complete bundle read lease now spans cold preparation, compiler-disabled
reopen, one incremental refresh and a final compiler-disabled reopen. The
existing shared `d166b53e27274390a698704536cd3984a15b1094579e0c0f9fb126616565b56c`
single-C literal `-prod` executable and its native libraries remain unchanged
throughout. It uses its actual
`b32c6cda1d21c6618167f155e29fa1f51192c6c09c86208025bcc3c250b24e45`
ABI partition, without renaming/copying old cache entries. No manual browser
build is requested. Each phase launches a fresh private profile and process,
with direct current responses, the normal clock, the same 1024×768 document
viewport, layout/render scale two, capture scale one and retained raster options.

| Phase | PID | Native result | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Cold preparation | 92227 | 24,100 compiled / 189 compiler invocations | 1,842.779015459 / 12,185,501,696 |
| First disabled-compiler reopen | 32412 | 3,381 hits / 1,009 misses / 760,843 native entries | 41.861808000 / 9,498,542,080 |
| Incremental refresh | 32821 | 3,367 hits / 7,106 compiled / 56 compiler invocations | 775.061122541 / 12,046,204,928 |
| Final disabled-compiler reopen | 51356 | 468 hits / 3,930 misses / 212,497 native entries | 44.887883958 / 8,929,607,680 |

Both preparation phases finish with zero pending/invalid entries, an empty
cache error, all 76 requested modules prepared, 26,043 prepared functions and
zero unsupported functions or preparation diagnostics. The cold phase queues
19,721 functions; the refresh queues 6,100. Cold compile/load times total
1,775,014.0688700012 / 44,332.55141399998 ms; refresh totals
737,738.653878 / 15,112.07980099999 ms. The refresh itself executes 725,099
native entries. The partition ends with 31,206 records across the source graphs.
These guard intervals include cache compilation after the page PNG; they are
preparation costs, without page-load or native-throughput acceptance.

The first reopen changes seven module URLs relative to preparation, including
`code-view`, `core`, `code-menu` and `repositories`. The final reopen changes
70 URLs relative to the refresh and evaluates 78 modules instead of 76. Those
graphs and all source filenames are retained. Current responses may reflect
deployments or variants; the observations do not distinguish their cause.
The compiler-disabled reopens retain 1,009 / 3,930 pending executables and
`Native compiler exited 1:` from `/usr/bin/false`. Both strict native-reuse
checks correctly fail, with diagnostic/guard exits one. Their zero successful
compiler-invocation counters do not mean no compiler was attempted. The bounded
refresh protocol stops after this final failure; its encompassing controller
also exits one. No zero-miss result is claimed.

Every browser exits zero, PID adoption succeeds, input hashes remain fixed,
and author/native DOM errors remain absent. Every evaluated module promise
fulfills, page JavaScriptCore stays uninitialized, and all four content audits
retain 34 directory rows, 53 commit links, latest commit and README. Preparation
controllers/guards exit zero. Source churn affects cache eligibility without
turning these successful content captures into zero-miss acceptance.

The final image is explicitly partial-native evidence:
`current-live-libjs-native-partial-r41-20261117.png`. The earlier accepted live
and frozen compiled images are preserved, and no renderer change is retained.
The original Brave reference and the accepted two-pixel frozen image stay
unchanged.

Seventeen separate selected-draw diagnostics vary only instance chunk sizes,
preserving captured instance/index order and all resources. Full nine/eight
controls and the one-instance nine control reproduce their known complete
BGRA hashes. For nine instances, chunk sizes one through seven produce the
same six differences from the unified control; size eight produces four; size
nine produces zero. For eight instances, sizes one through seven each produce
four differences from its unified control. This supports draw-boundary
sensitivity in these captures without establishing a safe whole-page rule.
No renderer change or GPU bug is inferred. The combined helper compilation and
replay guard exits zero in 1.942412625 seconds, peak 120,684,544 sampled bytes.

The separate seven-pair [Hacker News browser comparison](LIBJS_HN_NATIVE_BROWSER_20261117.md)
executes cached native code and preserves exact pixels, but its median startup
instruction count rises by 0.3653%. It supplies no optimization credit. Its
measured pairs start after this GitHub compilation finishes.

Raw commands, guards, source pins, progress and failed reopens remain locally
in `live-cohort-5204-r41` and `metal-chunk-boundaries-5204`, alongside the
Hacker News report's local receipts. Idle-lock, SHA-256 and symlink verification
moves 33 completed roots/241 files to
`scratch-receipts/continued-20261117-r41`, exit zero in 0.28828025 seconds,
sampled peak 20,348,928 bytes. Disposable profiles, Build outputs and idle locks
are removed. Automated suites remain paused. Full frozen parity and a current
zero-miss GitHub live reopen remain open.


### Opt-in generated-code identity, 2026-11-17

`4d06a27db` adds exact generated-C identity as an experimental alternative to
the default source/file/URL cache key. It uses a separate ABI partition and the
existing verified library loader; current constants, realms and environments
remain in the invoking VM. The real 101-comment HN diagnostic retains 26 hits,
zero misses/compiler invocations and 747 native entries after a changed URL
and appended comment. Source-bound controls miss all 27 entries. Adding an
operation correctly misses one body and retains 25 hits. All controls preserve
real collapse/expand behavior and have no initialized JavaScriptCore context.

The older shared bundle correctly fails explicit new-mode verification. A
newer completed production bundle contains the exact implementation and passes
18 windowed HN captures with unchanged Brave pixels. Both modes reopen with
six native hits and no misses/compiler calls. Seven matched pairs show
3,536,702,893 source-identity versus 3,538,744,294 generated-identity median
instructions (+0.0577%); no speed gain is established. Automated suites remain
held, and full live GitHub/cache and frozen pixel parity remain open. See the
[generated-code cache report](LIBJS_NATIVE_GENERATED_CACHE.md) for source pins,
controls, activation, scope and retained evidence.


### Vertex-probe rejection and independent-instance placement, 2026-11-17

Two read-only selected-draw probes add atomic vertex-output logging, first for
position plus varyings and then for position alone. Both change the unified,
split and eight-instance controls by 3/9/5 pixels, maximum error ten. Their
ordinary replays reproduce the complete known BGRA hashes. The logged variants
therefore fail image invariance and are rejected for original-draw attribution.
Both helper compilations and all twelve replays succeed; the guards exit zero in
0.804136958 / 1.103519125 seconds, sampled peaks 99,516,416 / 121,389,056 bytes.
Probe and regression-source changes are fully reverted, with their source
patches, executable identities and failed invariance receipts retained locally.
No automated test source is compiled or run.

Thirteen further selected-draw diagnostics preserve the captured shaders and
vary only independent instance placement or base instance. The eight/nine
controls exactly reproduce the known complete
`bd5f7c2dde2265200a8c71a07d96d12ccfa5989cf9112ac4979c5bba64190169` /
`b552685a16a2889c0ef36d035660b2fe6f3b9ef8266a0ca8092f133c26df3722`
tiles. Moving the real underline first preserves the entire nine-instance
image; moving it last changes only the two Notifications corner pixels. A
fully clipped copy inserted before the borders or prepended also preserves
the nine-instance corner values, while appending it preserves the complete
eight-instance image. The clipped-copy cases intentionally omit the visible
underline and supply only counterfactual corner evidence.

Shifting the buffer's absolute instance IDs by one through four, using leading
records plus `base_instance`, exactly reproduces the complete eight-instance
image in every case. Those leading records are not submitted. This distinguishes
the effect of a submitted preceding instance from buffer position/absolute ID
alone. It does not establish a rasterizer defect or a safe whole-page grouping
rule. The seven/six replay guards exit zero in 0.556053584 / 0.563807 seconds,
sampled peaks 35,520,512 / 24,608,768 bytes. Input hashes remain fixed.

Eight more replays include both controls and six spatial-order variants. Sorting
the four disjoint button groups by ascending X changes four pixels with the
underline first/middle and six with it last; descending X changes two pixels in
all three positions. None reproduces the unified control. The guard exits zero
in 0.757909542 seconds, sampled peak 46,399,488 bytes. These spatial sorts supply
no matching result; raw cases remain in `metal-spatial-order-5204-r44`.

These diagnostics render selected rectangles over white, omitting shadows,
other passes and publication. They provide no whole-page correctness or speed
acceptance. Evidence remains local in `metal-vertices-5204-r44`,
`metal-positions-5204-r44`, `metal-independent-instance-5204-r44` and
`metal-instance-base-5204-r44`. The accepted frozen compiled PNG and original
Brave reference remain unchanged, with two differing pixels; no renderer
implementation is retained.


### Generated-code identity: successful current live reopen, 2026-11-17

The opt-in generated-code cache passes the strict native-reuse check on a
fresh, direct live `https://github.com/vlang/v` reopen: **2,987 cache hits,
zero misses/compiler invocations, and 711,946 native entries**. Capture and
shutdown both verify `generated-code` identity, positive native execution,
no pending/invalid entries, no new compilation and an empty cache error.
The page JavaScriptCore context remains uninitialized. This closes the
current-live functional reuse check for this pinned cohort, without a speed
or rendering-parity claim.

The latest completed shared bundle at launch is reused, with executable
SHA-256 `61a7b90fc08b0bdc1ee9e4de0747f7c0d2c37502b058cfbb9f1a5f48ac92ecc4`.
Its single-C-unit, literal V `-prod` receipt is
`Build/production-build/receipts/20261117-195151-c16c5606/frozen-compile.json`.
Before launching, the consumed-source manifest verifies the three generated-cache
implementation files. A bundle publication lease fixes this executable across
both phases. Later shared checkout edits are outside these sealed inputs;
the recorded executable and loaded runtime-input hashes stay unchanged.
No additional browser build is requested.

The native ABI is
`feb6c79b232473738a30fb26a06b8443dae8ee6e794be55fdb5bc927c4afabd3`.
A new private cache partition is populated normally, without copying or
renaming older entries. Each phase launches a fresh private profile/process,
using direct top-level navigation and the normal clock. This historical harness
retained the default shared HTTP subresource cache; the correction below adds
explicit per-process HTTP caches and disables imported cookies. The document viewport
is 1024×768, layout/render scale two and capture scale one; readiness waits
for commit links followed by a 30-second observation delay. Retained raster
options match the preceding live diagnostic. OS filesystem/shader caches are
retained; ambient measurement/proxy settings and private replay TLS trust are
removed. The frontend cache starts cold per process.

| Phase | PID | Native result | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Cold preparation | 86797 | 13,921 compiled / 109 compiler invocations | 2,088.782239667 / 10,611,851,264 |
| Disabled-compiler reopen | 80651 | 2,987 hits / 0 misses / 711,946 entries | 37.908831000 / 8,710,012,928 |

Preparation completes all 78 modules and 26,072 function templates, with
10,946 queued functions, zero unsupported functions and no preparation
diagnostics. Compile/load time totals 2,045,404.6514600008 / 23,500.330543 ms.
The first phase has zero native entries: preparation is paid after author
execution. Its roughly 35-minute guard interval includes cache compilation
after PNG capture and supplies no page-load or native-throughput acceptance.

The reopen uses `/usr/bin/false`; it records 20,206,072 fast steps and 8,074,554
slow steps, with 723.786460999998 ms library loading. Module URLs are identical
between the two phases: 78 evaluated modules, every promise fulfilled. This
cohort establishes reuse on that current graph. Deployment/source-graph churn
on live GitHub remains unverified for this mode; the changed-URL/comment
evidence remains the separate HN diagnostic. The controller stops after the
first strict success, so its conditional refresh/final-reopen phases are unused.

Both phases retain 34 directory rows, 53 commit links, latest commit and README,
a complete/visible/fully-active document, and no author/native page errors.
Both browsers, diagnostics, guards and the encompassing controller exit zero.
PID adoption succeeds under the unchanged 12-GiB guards. Native metadata and
all 109 referenced library hashes verify after the cohort. Browser process
identities, actual commands, host contention and the full sealed receipt remain
in the local evidence; no timing optimization is inferred from these
instrumented functional captures.

The successful native screenshot is local at
`live-generated-cohort-5204-r44/live-github-generated-code-verified.png`, SHA-256
`5449dfb07a6353b18b8452c15b9cdbd43a8033f655eba210a05680bea5fac8b7`.
The earlier accepted live PNG, two-pixel frozen PNG and original Brave reference
remain unchanged. The strict live-native reuse check passes for this build and
graph; full frozen parity and a measured speed gain remain open. Automated
suites remain paused.

Cold/reopen receipts and the spatial-order guard move with idle-lock, SHA-256
and symlink verification to `scratch-receipts/continued-20261117-r44`:
ten roots/22 files, exit zero in 0.175552291 seconds, sampled peak 229,376 bytes.
The vertex probes and instance-placement guards move to the adjacent
`continued-20261117-r44-gpu` and `continued-20261117-r44-draw-order`:
four roots/four files each, exits zero in 0.1994305 / 0.174742167 seconds,
sampled peaks 393,216 / 1,949,696 bytes. Disposable profiles, completed Build
outputs and idle locks are removed. The native cache and full library manifest
remain private local benchmark evidence.


### Network isolation and controlled module-URL revision, 2026-11-17

`f9b3aee9d` fixes the functional diagnostic's HTTP cache isolation. A private
`VOX_PROFILE_DIR` did not change `browser_cache_root()`: without
`LADYBIRD_CACHE_DIR`, subresources could come from the default shared cache.
The diagnostic now creates an empty `OUTPUT/http-cache`, selects it explicitly,
records its initial state and declines a preseeded cache before launching.
`a2405c7f8` also selects `VOX_COOKIE_FILE=''`; imported Netscape jars otherwise
have a default path independent of the private profile. The two process-boundary
regression sources remain uncompiled/unrun under the automated-test hold.

Earlier GitHub native counters remain valid, with the retained HTTP cache
qualified above. They do not establish empty-cache network conditions. The HN
instruction driver already explicitly selected a private HTTP cache and disabled
imported cookies, so its seven-pair results are unaffected. The native executable
cache remains separate and intentionally persists across these processes.

Two fresh direct live captures reuse executable `61a7b90fc08b0bdc1ee9e4de0747f7c0d2c37502b058cfbb9f1a5f48ac92ecc4`
and its actual `feb6c79b232473738a30fb26a06b8443dae8ee6e794be55fdb5bc927c4afabd3`
native ABI. Both have empty private HTTP caches and `/usr/bin/false` as compiler.
The second also disables imported cookies explicitly.

| Isolation check | PID | Native hits / entries | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Private HTTP cache | 93045 | 2,988 / 674,227 | 41.808042291 / 8,512,913,408 |
| Private HTTP cache and imported cookies disabled | 48464 | 2,987 / 702,260 | 38.418787125 / 8,666,267,648 |

Both strict reuse checks pass at capture/shutdown, with zero misses, new
compilation, compiler calls, pending/invalid entries and cache errors. Each
retains 34 directory rows, 53 commit links, latest commit and README; all 78
module promises fulfill, with no author/native errors or page JavaScriptCore
context. Module URL sets are unchanged from the preceding live cohort.
Browser/diagnostic/guard exits and PID adoption pass. The first private HTTP
cache retains 64 response records, whose bodies/headers are preserved locally.

The older frozen graph initially misses 130 lookups, leaving 126 new C
identities pending while retaining 2,779 hits and 474,673 native entries.
Its compiler-disabled gate correctly exits one; the browser exits zero with
complete 33-row/56-commit/latest/README content and the same two-pixel image.
One ordinary-Clang refresh compiles 362 entries in four invocations, completing
all 81 modules and 25,643 templates with no unsupported functions or diagnostics.
Its guard exits zero in 302.253257208 seconds, sampled peak 9,770,106,880 bytes.
A fresh disabled-compiler reopen then passes: 2,905 hits, zero misses/compiler
calls and 474,658 native entries, again with the unchanged two-pixel image.
Guard exit zero, 39.3032885 seconds, sampled peak 7,923,253,248 bytes. A separate
one-second stack sample during refresh is retained; these captures supply no
performance acceptance.

A first renamed-URL fixture preserves all 87 archived JavaScript bodies, but
URL-specific compatibility redirects cease matching. It retains 2,912 hits
and misses ten app-runtime identities, despite matching the base pixels and
complete content. That attempt is rejected for URL-only cache attribution:
the executed script policy differs. Browser zero, diagnostic/guard one,
39.8634465 seconds and 7,944,667,136 sampled peak bytes remain in the receipts.

The shared production bundle then advances. The first matched-policy controller
detects the identity change before launching any browser and exits one. The
next cohort uses the newly completed single-C-unit, literal V `-prod` executable
`c8718d8055f24d4d86ca34944c9ba7cbbc454e4d73b73ecececc3291e209ff55`, receipt
`Build/production-build/receipts/20261117-213143-e9e1ab81/frozen-compile.json`.
Its native ABI is
`86c4dd90dce7559306565c15490dd2530117b9ee2a9b4113db0535bf5aebffc5`.
No older cache records are renamed or copied into this ABI.

For this functional experiment, a pinned compiler wrapper substitutes `-O0`
for the tier's requested `-O2`, recording every actual argv and C-input hash.
The separate private functional cache contains 13,911 entries from 109 actual
Clang invocations. Compilation totals 102,791.474413 ms; the preparation guard
exits zero in 155.725341292 seconds, sampled peak 8,987,394,048 bytes. This is
not an ordinary `-O2` cache or a matched compilation-speed comparison. It
supplies no browser performance or optimization credit.

An incomplete compatibility import retargeting leaves three canonical script
URLs unarchived. That candidate times out waiting for readiness, has no PNG or
final cache audit, and is rejected: browser -15, diagnostic/guard one,
180.851946291 seconds, sampled peak 3,871,719,424 bytes. Its successful base
capture and every failed request remain. The completed policy retargets all six
known module-URL strings across the core/CSS compatibility programs, while
preserving their operations and the standard-URL replacement resources.

The final controlled fixture relocates **all 81 evaluated module URLs** into
`/assets/__vox_native_revision_5204__/`. Raw archived JavaScript bodies remain
unchanged. HTML module references/import-map URLs change, with the matching CSP
hash updated; stylesheet/image references and the original fixture stay intact.
Both cases use the same private compatibility bundle, including aliases for the
three replacements. The actual served replacement bytes verify against the
intended original/retargeted sources. Every normalized module URL matches its
base counterpart, every module fulfills, and there are no unarchived JavaScript
requests. Only the previously missing off-viewport Vinix image/favicon requests
are blocked by the offline replay. Nothing is forwarded live.

| Matched-policy phase | PID | Native hits / entries | Guard seconds / sampled peak bytes |
| --- | ---: | --- | --- |
| Warm verification (`prepare` label; no new compilation) | 96222 | 2,944 / 474,444 | 39.025079833 / 7,655,030,784 |
| Original module URLs; compiler disabled | 96975 | 2,944 / 474,350 | 37.500443667 / 7,444,660,224 |
| Relocated module URLs; compiler disabled | 97716 | 2,944 / 474,972 | 38.244985709 / 7,660,929,024 |

Both disabled-compiler captures pass strict reuse with zero misses, compiler
calls, new compilation, pending/invalid entries and errors. Native inputs,
private policy assets and cached libraries stay fixed under the publication
lease. Content remains complete, HTTP caches start empty, imported cookies stay
disabled and page JavaScriptCore stays uninitialized. All browser, diagnostic,
guard and controller exits are zero; adoption passes under unchanged 12-GiB
guards. The original and relocated captures differ by **zero pixels**. Each
still differs from the original Brave reference by exactly the same two pixels,
maximum error ten, with zero tolerance. This validates controlled URL-only reuse
on this page/program, not independently changed vendor code or live deployments.

Thirty-four further selected-draw diagnostics append zero through sixteen
repeated final strip indices, preserving every existing triangle and shader.
One trailing degenerate index fixes the eight-instance counterfactual tile but
changes four pixels in the nine-instance control. No tested padding matches
both controls. Guard exit zero, 2.233861208 seconds, sampled peak 44,941,312
bytes. No renderer change follows from these selected draws over white.

Full commands, flags, source/binary/library pins, proxy and replacement receipts,
failed controls, PNGs and exact exits remain local in `live-private-http-5204-r45`,
`frozen-private-http-5204-r46`, `rebased-modules-5204-r47`,
`metal-strip-padding-5204-r48`, `matched-policy-5204-r49`,
`url-reuse-o0-5204-r50` and `url-reuse-complete-policy-5204-r51`.
The successful relocated PNG is `github-renamed-modules-native.png`, SHA-256
`7d837ff4a96bf87f703e97faac0c1ac4f3d3ae5a4a028d133fd15ebb67209ac4`.
Earlier accepted live/frozen PNGs and the Brave reference remain unchanged.
Automated suites remain paused; full parity and a measured speed gain stay open.

Completed per-job Build outputs move with idle-lock, SHA-256 and symlink
verification to `scratch-receipts/continued-20261117-r45-r51`: 64 roots and
3,811 files. The archive guard exits zero in 1.229806541 seconds, sampled peak
24,641,536 bytes. Disposable profiles and the archive's idle lock are removed;
no matching completed job roots remain in Build. All three earlier accepted
live/frozen/reference PNG hashes verify unchanged.

For the repository page specifically, initial load, hydration and native-cache
reopening are demonstrated. Earlier native mouse/keyboard sequences also open
the Code and master menus, type `ma` into the branch input and dismiss overlays
with zero native misses/compiler calls. Those interaction checkpoints belong to
their recorded builds; the latest isolated captures do not rerun them. Selecting
a different branch, following files/directories, Go to file and history/back
navigation still need an end-to-end acceptance matrix before claiming complete
repository-page behavior. The two remaining frozen screenshot pixels measure
rendering conformance, independently of that functional coverage.

### Compiled LibJS and shared-script browser controls, 2026-11-17

`1d31e348e` adds the frozen-page driver in `tools/benchmark_github_page.py`.
It prepares a private generated-code cache, checks capture and shutdown on a
fresh compiler-disabled reopen, and compares complete repository content and
document PNGs. The replay receipt must contain the declared compatibility
script URLs and body hashes. A private Vox filter bundle cancels the three
bundled redirects so all engines fetch the same archived replacements. The
archived CSS runtime also carries the shared advancing Date prefix. The
original HTTPS origins, fixture bodies and Brave reference are retained.

The shared single-C-unit V `-prod` executable is
`d2f42448a39c16687c5889c3513dd539c6d18b8edc25d239b14ce749b970abe6`.
Its generated-code ABI is
`835bbc6baf5c17ddc3771b08c7cef1b86623a7ed1465aa00429cb18aa085840f`.
The earlier cache eligibility attempt had zero hits under that ABI. Fresh
preparation produces 13,915 entries in 109 Clang invocations. The private
compiler substitutes `-O0` for `-O2` for this functional run. The preparation
guard exits zero in 136.057630917 seconds at 9,623,126,016 sampled peak bytes.
The cache files remain unchanged through the following reopens.

One matched functional pass launches each browser with a fresh profile and
HTTP cache, a 1024×768 document viewport, and a one-second settle. Vox's
document render scale is two with a 1× PNG. The OS caches are retained and
imported cookies are disabled. All captures retain the same 33 directory rows,
56 commit links, latest commit and README, with no recorded script or native
page errors. Both LibJS modes fulfill the same 81 modules. JavaScriptCore
initializes for its own control and remains uninitialized for both LibJS modes.

| Mode | PID | Pixels differing from the retained Brave image |
| --- | ---: | ---: |
| Compiled LibJS | 58138 | 2 |
| Interpreted LibJS | 58247 | 2 |
| JavaScriptCore | 58348 | 2 |
| Brave | 58420 | 0 |

The three Vox captures have identical RGBA pixels. Their two differing pixels
against Brave have a maximum channel error of ten. The compiled capture and
shutdown report 2,948 hits and 475,046 native entries, with zero misses,
compiler calls, pending entries or invalid entries. The compiled PNG SHA-256 is
`452b7ac13e03e6666d0f49fcd1abbfba16786123d7320e727e3c9bd7384a9bb0`.
Every browser, controller and guard exits zero, all four PIDs are adopted, and
the 12-GiB guard records 27.878634125 seconds and 8,192,458,752 sampled peak bytes.

The default-filter control loads complete content and exits zero, while the
driver and guard exit one because all three script URLs bypass the common
replay. The previous missing-Pillow pilot, interrupted comparison and
empty-ABI attempt are retained. The sampled instruction counters include
startup, capture and shutdown, and the Brave run includes CDP setup and
auditing. The native run uses instrumented counters and unoptimized libraries.
The one-pass results supply functional evidence. Optimized performance, live
behavior for this executable, and deeper repository navigation remain open.

The commands, compiler arguments, process receipts, script hashes, pixel
comparisons and PNGs are local in
`docs/performance/libjs-github-browser-20261116/libjs-github-continue-20261117/`.
Cleanup moves 34 completed Build entries and verifies 243 file identities.
Disposable profiles, HTTP caches, and job locks are removed from Build.

### Live compiled reopen on the same production bundle, 2026-11-17

The same `d2f42448…abe6` executable and `835bbc6b…840f` generated-code ABI
load the public `https://github.com/vlang/v` directly in two fresh processes.
Both start with an empty private HTTP cache and imported cookies disabled.
The browser uses its bundled site policy for direct navigation. The separate
live cache starts empty and a pinned wrapper selects `-O0` for functional
preparation. The first visit compiles 14,220 entries in 112 Clang calls with no
pending/invalid entries at shutdown.

With `/usr/bin/false` as compiler, the live reopen records **3,017 native hits
and 505,906 native entries** at capture and shutdown. Misses, compiler calls,
new entries and pending/invalid entries are all zero. Both visits fulfill the
same 78 modules without initializing page JavaScriptCore. The complete content
audits agree across all 34 directory rows, 53 commit links, latest commit and
README. There are no recorded page-script or native errors. Both 1024×768
document PNGs are byte-identical, with SHA-256
`f70639d82a0b709c7dc1d09fb3ef49c67044a41e0cb1969c801c6e5d38691ba3`.

| Live phase | PID | Guard seconds | Sampled aggregate peak bytes |
| --- | ---: | ---: | ---: |
| Empty cache preparation | 82424 | 160.639825209 | 10,414,063,616 |
| Compiler-disabled reopen | 87363 | 15.938324 | 8,555,954,176 |

Browser, diagnostic and guard exit zero in both phases. PID adoption and input
hashes verify. The captures measure one unchanged live module graph and include
a four-second readiness settle. The separate optimized frozen comparison uses a
different cache. The live PNG, input pins, compiler arguments, exact commands,
and guard reports are local in
`docs/performance/libjs-github-browser-20261116/libjs-github-o2-20261117/live-and-pilot-receipts/`
and its parent directory.

### Live Go to file interaction, 2026-11-17

On the same build, native mouse and keyboard events open Code and master,
enter `ma` in the branch filter, dismiss the menus, then enter `v` in
Go to file. The compiled LibJS run keeps all audited repository content and
completes the nine input events. It records 3,422 cache hits and 1,173,973
native entries, with no cache misses or compiler calls. GitHub reports that
Web Workers are unavailable. Its synchronous file-search fallback then throws
`InternalError: LibJS instruction budget exceeded`, and the final overlays
still say “Loading”. The input value alone does not establish working search.

The JavaScriptCore control delivers the same nine events and preserves
repository content. It reports an earlier `showPopover` TypeError and fails
the error-free interaction gate. Both Vox browsers exit zero and their
controllers/guards exit one. The guards record 60.140548917 and 57.491421292
seconds, with sampled peaks of 11,242,864,640 and 6,231,769,088 bytes,
respectively. Executable and cache pins stay fixed.

A fresh Brave CDP control on the live page enters `v`, observes the visible
`v.mod` result, and dismisses the search with Escape. It has no recorded page
exceptions. Browser/controller/guard exit zero, with 15.267308709 seconds
and sampled aggregate peak 951,058,432 bytes. These are functional observations
with different input instrumentation. Commands, input events, audit timelines,
and error stacks are in the local `libjs-github-o2-20261117/interaction-receipts/`.

### Frozen file search with compiled LibJS, 2026-11-17

Fresh windowed runs use the same `d2f42448…` bundle and functional `-O0`
generated-code cache as the earlier frozen four-engine comparison. Native
mouse and key events pass through the browser's platform view. The root page
uses the same HTML and compatibility scripts, with imported cookies disabled
and an empty private HTTP cache per process.

The initial fixture lacks the commit-pinned `tree-list` response. Both inputs
work (`ma` in the branch filter and `read` in Go to file), but the missing GET
returns 404 and Go to file shows “Failed to search”. The extended fixture adds
the original GitHub response for commit `c4863bafb29a66c27044fdc2007ec2321ae228ee`.
It contains 18,376 paths, with body SHA-256
`a57d594c88d91a5c45896d4b0d046c87ecad2a9dae1844305633daf7017b6566`.
Existing response bodies are byte-identical. With the archived GET returning
200, GitHub's synchronous fallback reaches fuzzy scoring and exhausts the
10-million-instruction document entry limit while handling the short query.
The dialog stays at “Loading”. Both runs have zero cache misses and compiler
calls, and the branch-filter audit observes text entry only.

Entering `readme.md` in one burst against the extended fixture completes
under the same budget. The initial loading state resolves to visible results,
including the root `README.md` link at `/vlang/v/blob/master/README.md`.
The search dialog dismisses normally. Final content remains complete with
3,155 cache hits, 859,353 native entries, and zero misses or compiler calls.
The browser, controller and guard exit zero. The 12-GiB guard records
29.792548666 seconds and 10,288,398,336 sampled peak bytes. GitHub still reports
the unavailable Worker constructor and uses its synchronous fallback.

JavaScriptCore requests both the same-origin module-worker entry and its CDN
module. A second fixture extension replays both unchanged responses with status
200. The `read` query still stays at “Loading” throughout the observed input
period, with no reported page exception. This supplies no successful
JavaScriptCore search result. The prior `jsc` launch is retained with browser
exit two because the CLI requires `javascriptcore`.

Clicking the visible README result closes the overlay but leaves the root URL
active. Selecting by Arrow Down and Enter reaches the GitHub navigation
handler but raises a `TypeError` when the handler calls
`performance.clearResourceTimings()`. Neither run requests the archived
README destination. The keyboard run records 3,169 hits with zero misses or
compiler calls, and exits zero after the controller records the navigation
failure. Its guard exits one in 41.247368458 seconds at 11,498,012,672 sampled
peak bytes. `481a848d8` binds the operation to the owning native Performance
timeline's resource buffer, with focused coverage for receiver validation,
ignored arguments, surviving mark entries and previously returned resource
entries. The guarded production type check exits zero in 67.850972542 seconds
at 6,509,002,752 sampled peak bytes. The new regression source remains unrun
under the test hold. End-to-end navigation remains pending a bundle containing
the binding.

The fixture extensions preserve the original Brave reference and controlled
root capture. The original response bodies, audit timelines, input plans,
cache receipts and process exits remain local in `repository-controls-5204-r54`
through `repository-controls-5204-r60` and the two interaction replay archives.
These observations provide functional evidence. They do not establish a
performance gain or complete repository-page parity. Automated suites remain
paused.

### Triangle-list rendering control, 2026-11-17

The canonical Metal replay expands the captured 69-index triangle strip into
67 triangles, preserving winding, primitive order and zero-area triangles.
The expanded draw is byte-identical to each of the eight-instance, unified
nine-instance and split nine-instance controls. Omitting the 15 repeated-index
triangles instead changes two pixels in the eight-instance control at
`(991, 212)` and `(990, 213)`. It leaves the two nine-instance controls exactly
unchanged. Both eight-instance changes are outside the remaining Notifications
corners at `(648, 188)` and `(646, 190)`.

All nine selected draws and the guarded compiler invocation succeed with fixed
input identities, elapsed 1.694646042 seconds and sampled peak 100,466,688
bytes. The replays use a white backdrop. They rule out strip topology alone as
the cause and leave the frozen whole-page comparison at two differing pixels.
The raw tiles and draw hashes remain local in `metal-triangle-list-5204-r53`.

### Optimized generated-code cache at the PNG endpoint, 2026-11-17

Seven alternating pairs compare cached `-O2` native LibJS with interpreted
LibJS on the same `d2f42448…abe6` production executable. Both use the frozen
shared-script fixture, a fresh process/profile/HTTP cache, disabled imported
cookies, a 1024×768 active document, a one-second readiness settle, and standard
Vox raster settings. OS filesystem and shader caches are retained. Each launch
validates the complete 33-row, 56-commit, latest-commit and README audit, all
81 fulfilled modules, the three compatibility response hashes, and exact
pixels against the pre-measurement standard-raster Vox reference
`c14f8003edb4e87832ea4d89dd943cdf24a1a707c6aad04ebd88b3992220b4f0`.
That reference differs from the retained Brave image at 59,867 pixels. The
earlier two-pixel comparison used raster diagnostic options.

The preparation retains 109 browser-emitted C units from a private staging
visit. The optimized cache contains 28 completed units from ordinary Clang
preparation and 81 units compiled separately with the same `-O2 -std=c11
-fno-strict-aliasing -dynamiclib` flags. The separate linker output paths can
shift Mach-O layout. Source hashes, cache keys, exported symbol indices and
optimized library hashes verify for all 13,915 entries. The staging and
parallel guards exit zero in 179.066663292 and 783.389549291 seconds, with
sampled peaks of 9,788,620,800 and 3,841,015,808 bytes. After the optimized
cache passes eligibility, the redundant serial seed is stopped. Its browser
exit is -15 and its controller/guard exit is one, with 1,777.8847875 seconds
and sampled peak 9,350,873,088 bytes retained in the receipt.

The separate instrumented optimized reopen records 2,924 hits and 411,817
native entries, with zero misses or compiler calls. It uses `/usr/bin/false`
and matches the frozen reference. Its guard exits zero in 42.221999958 seconds
at a sampled peak of 7,993,327,616 bytes. Native entry diagnostics are disabled
for the measured pairs. Their capture and shutdown receipts record 2,948–2,949
hits, with zero misses, compiler calls, new entries or pending/invalid entries.

| Pair | Interpreted instructions | Cached native instructions |
| --- | ---: | ---: |
| 1 | 75,876,183,196 | 81,870,047,391 |
| 2 | 76,143,070,911 | 81,863,921,836 |
| 3 | 76,128,471,110 | 75,987,323,229 |
| 4 | 68,446,894,133 | 83,511,866,222 |
| 5 | 75,965,375,496 | 81,841,276,537 |
| 6 | 70,145,197,213 | 74,325,290,481 |
| 7 | 68,185,597,125 | 81,868,686,894 |

The medians are **75,876,183,196** and **81,863,921,836** instructions,
respectively. Cached native uses **7.89% more** by the ratio of medians.
The median paired ratio is **1.07735**, the highest-native/lowest-interpreter
ratio is **1.22477**, and native uses fewer instructions in one of seven pairs.
These results establish the startup cost of the two modes on this fixture.
They do not isolate the native cache lookup, script execution, or rendering.

The measured endpoint is the cumulative exclusive Vox resource coalition
through native PNG encoding. It includes startup and owned helper work,
including aggregate exited tasks. PNG file writing, subsequent auditing,
shutdown, GPU work and outside services are excluded. The stable live
ownership audits pass and individual exited task identities remain unavailable.
All 14 browsers, the controller and guard exit zero with fixed inputs and
successful PID adoption. The 12-GiB guard records 134.354363083 seconds and
8,169,291,776 sampled peak bytes. The 18-CPU host's before-trial one-minute
loads range from 8.79 to 12.12, so no wall-time comparison is inferred.

Raw counts, commands, fixture/browser/library identities, rejected pilots,
PNG files and the optimized cache manifest are local in
`docs/performance/libjs-github-browser-20261116/libjs-github-o2-20261117/`.
The completed optimized cache remains private and reusable for this ABI.
Cleanup archives 18 completed Build entries with 251 verified file identities.

### README navigation after the LibJS timing binding, 2026-11-18

The published `d2f42448…` bundle reproduces the `clearResourceTimings()`
failure after keyboard selection, with 3,169 native-cache hits and zero
misses or compiler calls. The guarded run exits with browser zero and
controller/guard one in 49.521418375 seconds at 11,275,534,336 sampled peak
bytes. The newer production build was queued. The private C `-O0` executable
`f8e37a149c12292672137b3040a76e0e1b82a4f0d145370110d830add6fe91ed`
contains the exact `481a848d8` binding source. Its sealed build passes in
250.94093425 seconds at 8,609,136,640 sampled peak bytes.

The private executable reaches the native stack limit while hydrating with
the host's 8,176 KiB soft limit. Running the same executable with the host's
65,520 KiB hard limit as its process-local soft limit restores the complete
33-row, 56-commit, latest-commit and README audit. The full 18,376-path file
list remains difficult for the main-thread fallback. One cache-disabled
attempt stays at “Loading” and a longer one reports a React instruction-budget
error. Their browser processes exit zero but their acceptance controllers and
guards exit one. The longer attempt peaks at 9,757,114,368 sampled bytes.

Partial native preparation renders the exact `readme.md` results and shows
`file-result-0` already selected. Arrow Down therefore selects `ci/README.md`.
The subsequent Enter changes the URL and sends the file request past the old
timing exception. That destination is unarchived and returns 404. Preparation
records 385 compiled entries, 45,936 native entries and 2,936 pending entries
before the 12-GiB guard stops it at 152.277659125 seconds and 12,888,457,216
sampled peak bytes, child exit 137 and guard exit 125. There is no clean
compiler-disabled reopen of this diagnostic ABI.

For a narrower navigation check, the frozen search response is reduced to its
existing root `README.md` entry. The root document and script bodies stay
fixed. GitHub's reader requests JSON at the HTML document URL. The real JSON
body, SHA-256 `9aa3d3b95f8bf65bef4e74fdb9ec28cf2c66bc095b3b8c6e6b953781cffa35bf`,
is byte-identical with just `Accept: application/json` and with the additional
router headers. Matching the actual request instead of requiring those extra
headers advances the diagnostic build to the root README URL and title without
the original timing exception. The initial file view says “Unable to load
page”. The replay returns 404 for the tree list of the destination commit
`eeee53a268261d8cd15a831b55704628ba710def`. The Command–Left action is delivered
from that error page, and the terminal URL remains the file URL. A correct
title and URL alone cannot verify file content or history return.

The follow-up adds the destination's original 18,551-path response. All
observed README-layout and file-tree requests then replay with status 200.
React still renders “Unable to load page”. Its stack points to the
`e.scrollTo(...)` call in `360-fd75fa985cb61e08.js` at line 2, column 473.
The same run reports instruction-budget exhaustion in a separate callback.
Browser PID 79719 exits zero and the controller/guard exit one, with
60.748026917 seconds and 11,857,231,872 sampled peak bytes. The Back input now
waits for the visible README heading anchor and therefore stays pending.

`7bccf9906` exposes the existing native Element scroll offsets and scrolling
methods. The Window and Element bindings share argument conversion and the
native Promise bridge. The production type check exits zero in 38.215097666
seconds at 6,506,283,008 sampled peak bytes. Focused regression sources cover
native viewport offsets, conversion order, and rejected Promises. End-to-end
file rendering and Back still require a bundle containing the Element
binding. The diagnostic builds and replays provide no performance comparison
or new pixel result. The automated-test hold remains in effect.

Commands, source and binary hashes, exact process exits, original responses
and snapshots are retained locally under `repository-navigation-5204-r61`
and the three navigation replay archives. An isolated literal HTML capture
also fails before script execution due to an `about:srcdoc` origin panic. It
supplies no timing-binding evidence.

## README rendering and browser history

The private single-C `-O1` executable with Element scrolling, SHA-256
`0b13f6f21c9519c9821f83ca5c4062ec077053cb76a67fe61ead9b525d84881c`,
opens the frozen README from the file picker. The file-specific breadcrumb
and “The V Programming Language” heading are visible, and layout reports a
605 × 50.59375 CSS-pixel heading. The replay retains all 18,551 destination
paths. The 12-GiB guard ends the controller at 29.047305208 seconds and
12,911,886,336 sampled bytes with controller exit 137 and guard exit 125.
The browser exit is unavailable. A second control with only the destination
README path and the original directory list also reaches the memory guard.

On the earlier installed production executable (`d2f42448…`), a controlled
LibJS `pushState()` page stays on the file URL after native Command–Left and
records no `popstate`. `1c41c3a2f` routes same-document browser traversal to
the active navigable's history and exposes the native `PopStateEvent` in
LibJS. The production type check passes in 36.581525209 seconds at
7,084,883,968 sampled bytes. The independently built private diagnostic
executable, SHA-256
`9cde2a523f6ce806d4d085fadfffadfcfd9441bbed882c2899f02078b9fc11da`,
is built from the canonical checkout with concurrent local changes. Its
parsed source manifest pins the history and Element scrolling sources.

On the controlled fixture, native Command–Left restores the repository URL
and the UI2 Forward button restores the file URL. Both trusted events have
the same state object as `history.state`. Browser, controller and guard exit
zero with unchanged input hashes. PID 41376 peaks at 247,660,544 sampled
bytes over 11.374360125 seconds. The diagnostic first tried Command–Right,
then a page-view click, before using the enabled toolbar control itself.

The narrower GitHub replay keeps the original root HTML, scripts and README
router response and selects the original README path in each tree list.
GitHub leaves a text input focused, where Command–Left is an editing
shortcut in Vox. Two 24-second toolbar runs finish before the required
file-content gate. A 29-second run presses the enabled Back button after
README renders. Audits then show the root URL with the README title and
content still present. The root route requests `/_sidebar/about`, which
returns 404 in this replay, and a GitHub mutation observer exhausts the
LibJS instruction budget. Browser PID 44890 exits zero, controller and
guard exit one, and input hashes remain fixed. The sample peaks at
11,695,144,960 bytes over 32.90050475 seconds.

An anonymous live root JSON response identifies a different commit from the
frozen root page. The follow-up therefore uses the original page's embedded
repository and sidebar data in the observed JSON response shapes. Capture
records `Accept: application/json` for the post-Back root request. The root
JSON, sidebar and other return-route requests return 200. A 29-second run
ends before file readiness. With a longer observation window, PID 47475
renders the README and accepts toolbar Back after 24.329640625 seconds of
input observation. Three subsequent audits show the repository URL with
the README title, zero repository rows and three commit elements. The
12-GiB guard stops the controller at 42.203362417 seconds and 12,973,506,560
sampled bytes. Controller exit is 137, guard exit is 125, and the browser
exit is unavailable. This run establishes history traversal and correct
replay routing. Restoration of repository content remains unverified.

Raw commands, source and browser hashes, responses, audit snapshots, actual
exit records and screenshots are retained locally under
`repository-navigation-5204-r64`. These are interpreter diagnostics with the
native cache disabled. Compiled execution, live-site rendering, and pixel
parity with Brave remain open. The automated-test hold remains in effect.

### Mutation record allocation and a garbage-collected replay

`62944cca9` moves `MutationRecord.addedNodes` and `removedNodes` creation to
their first read. Records retain the original node snapshots and cache each
list separately to preserve the WebIDL `SameObject` guarantee. The production
type check exits zero in 57.290283709 seconds at 7,085,441,024 sampled bytes.
The focused regression source covers untouched lists and repeated getters.
It remains unrun under the automated-test hold.

A private single-C `-O1` browser with Boehm GC and 16-KiB collector blocks
tests whether the return can settle under the unchanged 12-GiB guard. Its
sealed executable SHA-256 is
`90d71f3778e685629a134daa06d85dfa0441b06642def8455898b3ae60faaf2e`.
The 294.477473542-second build exits zero at 8,599,552,000 sampled bytes. The
parsed source manifest includes the Back and Element scrolling changes and
predates the mutation-record allocation change. The controlled history round
trip again sees both trusted events, equal `history.state` identities and
unchanged pins. Browser PID 73046, controller and 3-GiB guard exit zero in
11.853522792 seconds at 254,787,584 sampled bytes.

The same binary completes README search, file navigation and toolbar Back in
the supplemented frozen replay. After Back, the repository title, 33 rows,
56 commit elements, latest commit and README return. The terminal content
audit exactly matches the original root content audit. The same-origin file
and root JSON responses are selected by their request headers. The browser
reports its Worker fallback and no other script diagnostics. Browser PID
73695, controller and guard exit zero, with successful PID adoption and
unchanged pins. The replay takes 86.872056 guard seconds and peaks at
5,276,237,824 sampled bytes. The root and destination file lists still contain
only the archived README path and their original directories. Native code is
disabled for this observation.

A two-second diagnostic sample after Back captures activity in rendering,
the LibJS interpreter and Boehm collection. Of 170 main-thread samples with
the complete window run loop stack, 70 include the idle cleanup's two forced
collection calls. That sample is diagnostic and supplies no relative timing
or instruction-count result.

Preparing generated code from an empty partition restores the repository in
the sampled content, but React's commit callbacks report exhaustion of the
document instruction budget. The controller times out while flushing the
cache at shutdown. Browser PID 82676 is terminated with exit -15 and the
controller and guard exit one. The run retains 9,344 entries across 73
completed native libraries at 6,018,318,336 sampled peak bytes. The functional
compiler wrapper uses `-O0` and records the requested flags and C source hash
for every invocation.

Reopening that partition with `/usr/bin/false` restores the full repository
content and records 2,456 hits and 1,085,575 native entries at shutdown. It
has 1,498 misses and 4,571 pending entries, and a compilation attempt fails
at shutdown. Browser PID 3512 exits zero, and the controller and guard exit
one at 129.58978775 seconds and 5,863,079,936 sampled bytes. Input hashes are
fixed. The result demonstrates native code reuse during the interaction
alongside interpreted fallback.

Resuming preparation on the same partition completes another 4,571 entries
across 36 Clang calls. Shutdown records zero pending and invalid entries and
an empty compiler error. The partition now contains 13,915 entries across
109 libraries. Browser PID 6848 exits zero. The controller and guard exit one
because the observed return does not pass the content and script gates. The
run uses 166.526396875 guard seconds and 5,268,996,096 sampled peak bytes.

The fresh compiler-disabled reopen with the completed partition captures the
README and returns to the exact initial repository content. The browser has
2,876 hits and 340,638 native entries at root capture, then 3,580 hits and
1,445,292 native entries at shutdown. Both receipts show zero misses,
compilations, compiler calls, pending or invalid entries, and page
JavaScriptCore stays uninitialized. Only the Worker fallback warning is
reported. Browser PID 9310, controller and guard exit zero with no changed
inputs. The run records 107.624852417 seconds and 6,044,745,728 sampled peak
bytes. This is a functional result for the private collector build and
reduced file lists.

The full-list follow-up restores the original 18,376 root paths and 18,551
destination paths while preserving the supplemented router responses and
the prepared native partition. Search opens the README and toolbar Back
returns the repository title, 33 rows and 56 commit links. The exact content
gate fails because the restored README text has different whitespace.
GitHub's mutation observer and React commit callbacks also report
instruction-budget exhaustion. Shutdown records 3,585 hits and 1,661,177
native entries with zero cache misses, compiler calls, pending entries or
invalid entries. Browser PID 11232 exits zero, and the controller and guard
exit one. Pins remain unchanged over 103.11109025 guard seconds and
5,912,248,320 sampled peak bytes.

The history diagnostics use whole-window screenshots. Their measured
document crops differ from the retained Brave PNG at 116,413 pixels for the
interpreter and 117,091 for the partial-cache reopen. Window compositor
overlays can enter those captures. The canonical document-only parity
reference and tolerances stay fixed.

Two attempts to build a separate browser containing `62944cca9` fail source
verification while other sessions edit the checkout. The first detects a
package membership change and the second detects a change in `main.v`. The
production type check remains the verification for the allocation change.

Raw receipts and the cache manifest stay local under
`repository-navigation-5204-r66`. The private executable and prepared
partition are retained in the benchmark cache as
`libjs-github-navigation-20261118-5204-r66`. The shared production build,
live GitHub, exact full-list restoration and document-only pixel parity
remain unverified by this run. The automated-test hold remains in effect.

### Brave return control and LibJS MessageChannel

A fresh Brave window uses the same full-list fixture, including the 18,376
root paths, 18,551 destination paths and recorded router variants. CDP mouse
and keyboard input opens the first `readme.md` result, and CDP traverses the
previous history entry after the file renders. The full repository audit
matches before and after Back. The 20,773-character README and its serialized
article HTML are byte-identical, and Brave records no script exceptions.
Browser PID 30585, controller and guard exit zero with fixed input hashes.
The guard records 3.780595666 seconds and 995,213,312 sampled peak bytes.
Different input and observation boundaries limit this to a functional control.
Both captured 1024×768 Brave states remain local. A strict before/after
comparison differs at 1,315 pixels. The established Brave reference and
tolerances stay fixed.

The archived React scheduler selects a MessageChannel when one exists and
otherwise schedules work on a timer. The new LibJS binding uses the existing
HTML posted-message queue and MessageEvent record. It supports opening and
closing ports, deferred FIFO delivery, ordinary structured content and
transferred ports referenced by the payload and the event's frozen port list.
The production type check for the final sources exits zero in 41.024679667
seconds at 7,102,709,760 sampled bytes. Focused regression sources remain
unrun under the automated-test hold.

The private single-C `-O0` Boehm build, SHA-256
`21a6e6495dbb5cc8800f346169bf05a52540205f9442012baca3062788e64417`,
seals the messaging source inputs and exits zero in 109.470711917 seconds at
8,478,425,088 sampled bytes. A controlled window observes FIFO delivery after
start, cyclic clone identity, transfer and reply, trusted events, and the
existing Back and Forward behavior. Browser PID 59344, controller and guard
exit zero in 11.311671583 seconds at 255,836,160 sampled bytes. This binary
predates the final preflight ordering for rejected transfers.

An instrumented copy of the archived scheduler records its selected branch
in a document attribute. The earlier private browser reads `timer`, and the
binding browser reads `message-channel`. The latter 34-second observation
ends before the full root content audit has hydrated. These branch markers
establish selection without a load-time or performance comparison.

The first unmodified full-list run finds the root README and delivers Enter.
The observation ends before the file content gate. Browser PID 61429 exits
zero, controller and guard exit one, and the 121.479385875-second run peaks at
4,179,247,104 sampled bytes with unchanged inputs. A longer run retains the
same binary and replay.

The longer run renders the README, delivers toolbar Back, and restores the
repository title, all 33 rows, latest commit and 56 commit links. The README
has 20,110 characters after Back versus 20,773 initially, with identical
non-whitespace words. React's scheduler callback still hits the document
instruction budget. Browser PID 64662 exits zero, controller and guard exit
one, and pins stay fixed. The run records 259.808822167 guard seconds and
4,657,577,984 sampled peak bytes. A separate two-second sample late in the
return finds idle garbage collection on 130 of 168 main-thread stacks.

The browser runs use the interpreter and private Boehm builds. The new
binding is committed as `8e73206e2`. Live GitHub, the shared production build,
generated-cache reuse with the binding, and exact Brave parity remain open.
The guarded runs, source hashes, modified scheduler fixture and window
artifacts are retained locally under `repository-navigation-5204-r67`.

### LibJS document budget and exact GitHub return

A private single-C `-O1` Boehm browser used one sealed executable,
SHA-256 `6bcd9aeb49764ce5251732869e40bc8a42f531745682c93c985b728eee87044c`,
for three fresh launches with empty profiles and HTTP caches. The build
passed its guard in 204.868994917 seconds at 8,633,221,120 sampled peak
bytes. A compile-time diagnostic switch selected the audited instruction
ceiling per launch. The archived full file lists, router variants, unmodified
author scripts, and native input were common across all three replays. Each
launch used a 120-second observation window and reported unchanged pins.

| Document ceiling | PID | Browser / controller / guard exit | Guard seconds | Sampled peak bytes | Observed result |
| ---: | ---: | --- | ---: | ---: | --- |
| 10,000,000 | 95931 | 0 / 1 / 1 | 121.439517167 | 3,487,154,176 | React exhausted the budget during initial hydration. The input gate stayed closed with zero commit links. |
| 20,000,000 | 6766 | 0 / 0 / 0 | 122.278184083 | 5,736,267,776 | File search opened README.md, and toolbar Back restored the complete audited repository content. |
| 30,000,000 | 93068 | 0 / 0 / 0 | 122.018696 | 5,633,376,256 | The same file search and Back sequence passed. |

At both higher ceilings, the initial and returned snapshots match the Brave
control on all 33 row identities and texts, 56 commit links, the latest
commit, and the exact 20,773-character README text. The file destination
reaches readiness before Back. JavaScriptCore remains uninitialized and the
only author diagnostic is GitHub's Worker fallback warning. The 10-million
trial failed earlier than the previous attempt that exhausted the budget
during Back.

A separate native-click fixture runs a synchronous listener that increments
a counter one million times. The 10-million ceiling leaves the marker at
`ready` and reports budget exhaustion. At 20 million the marker reaches
`1000000` with no script errors. Both browsers exit zero. The failing and
passing controller and 3 GiB guard exits are one and zero respectively, at
264,175,616 and 264,503,296 sampled peak bytes.

Commit `ceec95fd5` uses 20 million, the lowest passing ceiling of the three.
It applies to document execution entries and their nested callbacks. Standalone
LibJS entries retain a one-million ceiling. The production type check exits
zero in 69.6198835 seconds at 7,103,905,792 sampled peak bytes. The updated
regression sources remain unrun under the automated-test hold.

The frozen navigation result covers the private interpreter build. Shared
production validation, generated-cache reuse at the new ceiling, live
navigation, Worker support, and pixel parity remain open. The diagnostic
patch, commands, input fingerprints, audits, and guard receipts remain
local under `repository-navigation-5204-r68`.

### Published native round trip and allocation fixes

The shared single-C `-prod` browser SHA-256
`09e4dcb3fe88617ba5afe0a6af7a20c957f203f5bc2a000d21917bfbde539e76`
still reports a 10-million document instruction ceiling. A fresh launch
with the full-list archive, a private profile and a prewarmed generated
cache uses `/usr/bin/false` as the compiler. The audit observes 3,544 hits
and 1,149,437 native entries at the ready README destination, zero misses
or compiler calls, and an uninitialized JavaScriptCore context. Native
input reaches the toolbar Back action. The 12 GiB guard stops the run
before the returned content can be validated. The guard exits 125, its
controller records exit 137, and the browser has no shutdown receipt.
Browser PID 19441, guard elapsed 32.230879792 seconds, sampled peak
12,911,017,984 bytes. All 139 recorded input pins match after termination.

A separate mapping-trace launch uses the same executable, archive and
cache. PID 22993 opens the README and Back restores the repository URL.
The final content audit still shows the file view, with zero directory
rows and three commit links. React and a native callback report instruction
budget exhaustion. The compiler-disabled cache gate itself passes.
Shutdown records 3,572 hits and 1,537,387 native entries, zero misses or
compiler activity, and no pending or invalid entries. Browser, controller
and guard exit 0, 1 and 1 respectively, with unchanged input hashes. The
guard records 124.762187375 seconds and 12,404,441,088 sampled peak bytes.

The trace matches the pinned executable's text segment and loaded image
bases across the browser's self-exec. Among anonymous writable mappings
still tracked at their exact addresses, 736 MiB has
`resolve_module_export` under the namespace getter. Two resource fetch
stacks account for 720 MiB and 576 MiB through URL trimming. These are
virtual mapping capacities. They do not measure retained objects or
resident-byte savings.

- `09ad5542a` keeps the resolved module binding in each namespace getter
  and reads its current value on access. A manual prealloc probe observes
  `ReferenceError` before initialization, values one and two before and
  after mutation, and stable namespace re-export identity.
- `2c5b20868` puts resource URL trimming into the existing scratch scope.
  With the old and new resolution paths in one manual prealloc executable,
  the caller arena grows by 1,031,839 and 518,687 bytes respectively for
  128 long relative URLs. The same result survives scratch poisoning.
  Both paths preserve the resolved strings and the whitespace-only base
  case.

Both changed sources pass the guarded production type check in 72.369718
seconds at 5,561,647,104 sampled peak bytes. Focused regression sources
remain unrun under the automated-test hold. A preceding shared build
stopped on a duplicate local in `paint/background_raster.v`. The current
type check passes that code and the hooks have queued a newer build.
Browser-level memory and generated-cache navigation with the new sources
remain unverified. Commands, source pins and raw receipts are local under
`repository-navigation-5204-r69`.

### LibJS property enumeration allocations

The published GitHub mapping trace attributes 192 MiB of tracked virtual
mapping capacity to formatting property-name identities inside
`PropertyNameIterator::next` on a native execution stack. Commit
`15108e295` compares canonical keys using the existing property-name hash
and exact key equality. It uses the existing string identity to distinguish
hash collisions. The point at which a key becomes visited stays after the
successful own-property descriptor lookup.

Three alternating fresh-process pairs use single-C prealloc builds and
verify 492 source and fixture pins. Only `libjs/property_name_iterator.v`
differs between the pinned inputs. Each process completes 25,000 property
visits. All three control runs grow the caller arena by 112,085,189 bytes.
All three candidate runs grow it by 30,405,168 bytes, **72.9% less**.
The manual checks preserve distinct lone surrogates, an embedded zero
unit, numeric key ordering, prototype shadowing, and lazy Proxy traversal
when the loop breaks. All six paired trials and their guard exit zero.
The first control attempt exposed a reversed expected order for the two
inherited names in the probe. All measured runs use the corrected fixture.
These byte counts measure the standalone caller arena.

A separate fresh-process native cache reopen performs the same 25,000
visits with `/usr/bin/false` as the compiler. Its audit records two cache
hits, two native entries, 35,031 helper steps, and zero misses, compiler
calls, pending or invalid entries. The earlier seeding process compiles
two executables in one compiler call. The guarded production type check
exits zero in 37.790387375 seconds at 7,091,470,336 sampled peak bytes.
The collision regression source remains unrun under the automated-test
hold.

The running production build seals the earlier document budget, namespace
and resource URL changes. The managed hook queues the enumeration change
for a subsequent build. A browser-level allocation comparison and strict
GitHub navigation replay remain open. Raw commands, source identities,
allocation observations and guard receipts remain local under
`repository-navigation-5204-r70`.

### LibJS iterator protocol keys

The published GitHub mapping trace tags 80 MiB of anonymous mapping capacity
under `create_iterator_result_object`. Commit `d839c68f6` shares immutable
`value`, `done`, `next`, and `return` keys across the synchronous iterator
protocol. Iterator results still own independent mutable properties and use
the existing descriptor, prototype and user callback operations.

Three alternating fresh-process pairs use matching single-C prealloc
builds. The 492 recorded source and fixture pins differ only in
`libjs/iterator.v`. Every process yields 24,000 array elements and sums
108,000. The control caller arena grows by 65,236,983 bytes in all three
pairs. The candidate grows it by 41,956,992 bytes in all three pairs,
**35.7% less**. The checks cover independent writable iterator results,
own-property order, descriptor flags, prototype identity, and the custom
`next`, `done`, `value`, and `return` access order. All six paired
processes and their guard exit zero. The measured bytes describe standalone
caller-arena growth.

The separate native-cache seed compiles two executables in one compiler
call. A fresh reopen with `/usr/bin/false` returns the same sum with two hits,
two native entries and 30,013 helper steps. It records zero misses,
compiler calls, pending or invalid entries. Seed, reopen and guards exit
zero. The production type check passes in 56.768562875 seconds at
7,101,890,560 sampled peak bytes. The updated regression source remains
unrun under the automated-test hold.

Browser validation awaits the shared production build. Commands, executable
identities, source pins and guard receipts remain local under
`repository-navigation-5204-r71`.

### LibJS closure source spans

The published GitHub trace tags 304 MiB of virtual mapping capacity to
UTF-16 copies made during closure creation. Commit `bc35d273e` stores an
exact view of each closure's source. The callable retains the immutable
source through its executable, and `Function.prototype.toString` creates
an owned primitive from the view.

Three alternating fresh-process pairs use single-C prealloc builds.
The 492 recorded source and fixture pins differ only in
`libjs/ecmascript_function.v`. Every launch creates 2,000 closures with
a body containing 6,000 ASCII characters and non-ASCII text. All control
launches grow the caller arena by 29,980,505 bytes. All candidate launches
grow it by 5,660,521 bytes, **81.1% less**. The manual checks verify exact
source text across astral UTF-16 offsets, subsequent script evaluation,
and source modules. A Boehm launch also verifies the text after explicitly
collecting. All runs and guards exit zero. The byte counts describe the
standalone closure-creation workload.

A fresh native-cache reopen uses `/usr/bin/false` and verifies the same
closure behavior and exact source text. Its audit records three cache
hits, 2,002 native entries, 18,017 helper steps, and zero misses, compiler
calls, pending or invalid entries. The seed compiles three executables
in one compiler call. The production type check passes in 38.812599375
seconds at 7,098,286,080 sampled peak bytes. The source-sharing regression
remains unrun under the automated-test hold. Commands, pins and receipts
remain local under `repository-navigation-5204-r72`.

### Published replay and NodeList reads

The shared single-C `-prod` browser
`23ba3183f6c6446597823e434ba9016fc6949940758a6bcbcba91991b782b3bb`
contains the 20-million document budget, resolved namespace bindings, and
resource URL scratch changes. Two fresh interpreter launches use the archived
full file lists and native input. Both match Brave's initial audited directory
rows, commit links, latest commit and README text. Each opens the ready README
destination and delivers toolbar Back. JavaScriptCore stays uninitialized.
The final observed URL matches the repository, with the file view still
present and three commit links. The memory guard ends both runs before
React restores the directory. Both keep their input pins and show only
GitHub's Worker fallback warning before termination.

| Replay | Browser PID | Guard seconds | Sampled peak bytes | Controller / guard exit |
| --- | ---: | ---: | ---: | --- |
| Native input and content audit | 16377 | 27.85490875 | 12,997,951,488 | 137 / 125 |
| Separate mapping trace | 18543 | 28.81390225 | 12,904,677,376 | 137 / 125 |

A separate launch uses the finalized generated-code cache with
`/usr/bin/false` as the compiler and the same published browser. The
last audit shows 3,542 hits, 1,160,855 native entries, zero misses and
compiler calls, and an uninitialized JavaScriptCore context. All 139
input pins match after termination. The README is ready when the input
driver delivers Back, and the last audit still shows the file URL.
The guard stops browser PID 41787 before a restored-page or shutdown
audit. Controller and guard exit 137 and 125 respectively. The guard
records 51.453372917 seconds and a 12,951,355,392-byte sampled peak.

The mapping trace attributes 96 MiB of tracked virtual mapping capacity
to the native `NodeList.length` getter. Both `length()` and `item()`
materialized the entire native list per read.
Commit `6005c7d15` reads static lists and unfiltered child lists directly.
The full `collection()` operation keeps returning an independent snapshot.
Filtered lists retain the existing traversal and ordering.

Three alternating fresh-process pairs use matching single-C prealloc
builds, with only `dom/collections_ranges.v` changing across the 1,176
recorded source and fixture pins. Every pair reports the same arena counts.

| Standalone workload on 800-node lists | Prior caller-arena growth | Direct-read caller-arena growth |
| --- | ---: | ---: |
| 8,000 native list reads | 99,711,994 bytes | 0 bytes |
| 4,000 JavaScript list reads through LibJS DOM | 50,054,597 bytes | 198,600 bytes |

The probes cover static and live identity, out-of-range reads, independent
snapshots, and live list updates after removing and adding a child. All six
paired processes and their guard exit zero. The production type check passes
in 101.962594875 seconds at 7,104,118,784 sampled peak bytes. The regression
source remains unrun under the automated-test hold. The published browser
predates the NodeList fix. Local commands, input pins, guard receipts and
raw mappings remain under `repository-navigation-5204-r73`.

### LibJS RegExp literal programs

The same published replay attributes 192 MiB of tracked virtual mapping
capacity to the runtime RegExp literal compilation stack. Commit `13dcaf2cb`
retains the program produced during bytecode syntax validation with its
executable. Each evaluation creates a fresh RegExp object and match scratch
with an independent `lastIndex`. The executable's opcodes and operands
retain their existing bytecode cache identity.

Three alternating fresh-process pairs use matching single-C prealloc
builds. The 492 control source and fixture pins and 493 candidate pins
differ only in the five implementation inputs. Every launch evaluates
3,000 RegExp literals. All controls grow the caller arena by 38,272,280
bytes. All candidates grow it by 7,840,280 bytes, **79.5% less**. The
manual checks cover distinct objects, captures, flags, independent
`lastIndex`, and syntax errors.

A fresh native-cache reopen with `/usr/bin/false` matches all 3,000
literals and verifies independent state. It records two cache hits,
3,003 native entries, 48,025 helper steps, and zero misses, compiler
calls, pending executables or invalid entries. The seed compiles two
executables with one compiler call. All runtime processes and guards
exit zero. The production type check passes in 48.795497375 seconds at
7,107,100,672 sampled peak bytes. The regression source remains unrun
under the automated-test hold.

These byte counts cover standalone literal evaluation. Full GitHub
Back restoration under the 12 GiB guard remains unverified. Managed
build `20261118-022652-880e7db2` captured the earlier realm-cache
prototype. The commit hook requested a build containing the final
executable-owned implementation. Exact pins, commands and receipts
remain local under `repository-navigation-5204-r74`.

### Resource transport body buffers

The published GitHub trace shows retained resource-worker arenas. Those
workers hand completed responses to the browser thread. Commit `62921ad98`
grows libcurl's temporary body buffer on the native heap and releases it
after each attempt. The worker arena holds the completed binary string.
Cancellation, retry and transport errors also release the temporary buffer.

Three alternating fresh-process pairs use single-C prealloc binaries, with
only the two transport source files changing across 3,746 recorded source
and fixture pins. The local origin serves exact 8 MiB bodies over HTTP/1.1.
Each pair reports the same caller-arena growth.

| Response | Control | Native temporary buffer |
| --- | ---: | ---: |
| Fixed length, 8 MiB | 25,162,671 bytes | 8,401,505 bytes |
| Redirect to fixed length, 8 MiB | 25,176,718 bytes | 8,415,504 bytes |
| Gzip, 8 MiB decoded | 25,163,585 bytes | 8,402,419 bytes |
| Chunked, 8 MiB | 25,162,702 bytes | 8,401,536 bytes |
| Truncated after 4 MiB | 8,381,487 bytes | 8,960 bytes |

The manual probes verify the exact binary body, duplicate headers, redirect
destination, incremental image prefix, empty response and rejection of a
truncated body. The generated C shows the native buffer released on success,
cancellation, retry and transport failure. All six paired processes and
their guard exit zero. The production type check passes in 38.680505541
seconds at 7,095,255,040 sampled peak bytes. The binary-response regression
source remains unrun under the automated-test hold.

The table measures retained caller-arena growth for the local transport
fixture. The archived GitHub replay from the previous section served
11,515,032 bytes across 168 responses through several transport paths. The
managed build hook requested a production build. End-to-end Back restoration
under 12 GiB remains unverified. Local commands, pins and receipts are
under `repository-navigation-5204-r75`.

### LibJS Map and Set key indexes

Commit `25d48cb0c` stores numeric hashes and collision links in the
existing ordered entry list. Map and Set compare keys with SameValueZero
inside each bucket. Tombstones keep live iterator positions stable when
entries are deleted, reinserted or cleared.

Three alternating fresh-process pairs use single-C prealloc builds, with
only `libjs/keyed_collection.v` changing across 493 recorded source and
fixture pins. Each process inserts 9,600 prebuilt keys into each collection
and verifies 28,800 operation groups. The caller arena grows by 33,727,477
bytes in each control and 20,038,679 bytes in each candidate, **40.6% less**.
The manual checks verify number normalization, raw UTF-16 identity,
BigInt equality, object and symbol identity, and live insertion order.

The native-cache seed compiles two executables in one compiler call. A
fresh reopen with `/usr/bin/false` verifies 1,500 cycles of collisions,
head and tail deletion, and iterator order in Map and Set. It records
two hits, 1,501 native entries, 102,006 helper steps, and zero misses,
compiler calls, pending executables or invalid entries. All runtime
processes and guards exit zero. The production type check passes in
56.713607958 seconds at 7,106,461,696 sampled peak bytes. The collision
regression source remains unrun under the automated-test hold.

The earlier production attempt `20261118-022652-880e7db2` exited 1 after
the resource transport header changed during input sealing. The worker
started `20261118-024638-c98004e8` and the published executable is still
`23ba3183…3bb`. The full cached-native Back replay under 12 GiB remains
pending. Local commands, pins and receipts are under
`repository-navigation-5204-r76`.

### LibJS call frame capacity reuse

The published Back replay tags 512 MiB of tracked virtual mapping capacity
to the reusable interpreter stack allocation path. Commit `ef8e54739`
can reuse the smallest available private frame with capacity up to 125%
of the requested value count. The frame's logical length determines its
stack charge, register layout and argument offsets. The pool charges the
full backing capacity against its existing 1 MiB limit. Exposed frames
and saved continuations retain their independent lifetimes.

Three alternating fresh-process pairs use matching single-C prealloc
builds. The 493 recorded source and fixture pins differ only in the two
implementation files. Each launch uses the normal VM call entry point
for 19,200 synchronous calls across 160 argument widths. The control
caller arena grows by 29,399,039 bytes in each pair. The candidate grows
it by 1,685,760 bytes, **94.3% less**. The manual probe checks return
values, exposed frame identities, and retained argument views. The
separate Boehm probe checks those views after forcing a collection.

The native-cache seed compiles four executables in one compiler call.
An independent process reopens with `/usr/bin/false` and verifies the
same calls and views with four hits, 19,365 native entries, 12 helper
steps, and zero misses, compiler calls, pending or invalid entries.
All runtime processes and guards exit zero. The production type check
passes in 43.242286667 seconds at 7,100,071,936 sampled peak bytes.
The frame reuse regression source remains unrun under the automated-test hold.

The in-flight managed attempt `20261118-024638-c98004e8` records the
NodeList, RegExp, resource transport and keyed collection source files.
Its frame pool predates this change. The commit hook queued the updated
sources. A production cached-native Back replay under 12 GiB remains
pending. Local commands, pins and receipts are under
`repository-navigation-5204-r77`.

### LibJS function metadata keys

The published Back replay tags 272 MiB of tracked virtual mapping capacity
to ECMAScript function creation. Commit `6279dd112` shares the immutable
`name`, `length`, `constructor` and `prototype` keys. Each function owns
its property descriptors and ordinary function prototype. Function creation
also uses the already computed name and compares the default-export marker
in UTF-16.

Three alternating fresh-process pairs use matching single-C prealloc
builds. The 493 recorded source and fixture pins differ only in the two
implementation files. Each launch creates and retains 6,000 arrow, 6,000
ordinary and 6,000 bound function objects. In each pair the caller arena
grows by 72,598,741 bytes in the control and 52,049,573 bytes in the
candidate, **28.3% less**. The probes verify descriptors, property order,
independent mutations, prototype identity, and numeric and symbol names.

The native-cache seed compiles 12 executables in one compiler call. A
fresh reopen with `/usr/bin/false` verifies the function properties,
unpaired UTF-16 names, and anonymous default-export names. It records
12 hits, 18,011 native entries, 144,202 helper steps and zero misses,
compiler calls, pending or invalid entries. The processes and guards exit
zero. The production type check passes in 48.842441458 seconds at
7,100,841,984 sampled peak bytes. The regression source remains unrun
under the automated-test hold.

Managed attempt `20261118-024638-c98004e8` exited 1 during sealing with
`Production source membership changed`. Comparing its recorded
inventory with the checkout finds the newly added
`native/include/native_frame_clear_darwin.h`. The shared worker picked
up the next request and the installed executable is still
`23ba3183…3bb`. The full cached-native Back replay under 12 GiB remains
pending. Exact local commands, pins and receipts are under
`repository-navigation-5204-r78`.

### LibJS built-in array iterator steps

Commit `3d052fec4` lets internal iterator steps consume the yielded value
and completion flag from the captured built-in Array iterator method.
The step uses the same native call-frame setup as an ordinary native call.
Array-like getters, TypedArray bounds checks and entry pairs stay on the
shared iterator implementation. Direct `next()` calls still return fresh
ordinary objects. Custom methods follow the generic iterator protocol.

Three alternating fresh-process pairs use matching single-C prealloc
builds. The 493 source and fixture pins differ only in the three
implementation files. Every process yields 24,000 array elements and
sums 108,000. The control caller arena grows by 41,956,992 bytes in
each pair. The candidate grows by 8,693,008 bytes, **79.3% less**.
The earlier trial that allocated the two properties together used
41,957,006 bytes. That trial was reverted and its receipt is retained.

A fresh native-cache process reopens with `/usr/bin/false`, verifies
the same results, and exercises reentrant length reads, thrown value
identity, captured and overridden `next` methods, and TypedArrays.
It records 16 hits, 24 native entries, 138,431 helper steps, and zero
misses, compiler calls, pending or invalid entries. The seed compiles
16 executables in one compiler call. All runtime processes and guards
exit zero. The production type check passes in 44.282047083 seconds at
7,109,165,056 sampled peak bytes. The native-frame regression source
remains unrun under the automated-test hold.

Managed production attempt `20261118-030853-ecf3924d` is underway. The
installed browser is still `23ba3183…3bb`. Full cached-native Back
restoration under 12 GiB remains pending. Local commands, pins and
receipts are under `repository-navigation-5204-r79`.

### LibJS built-in Map and Set iterator steps

The published replay tags 112 MiB of tracked virtual mapping capacity
to iterator result creation under the keyed collection callback. Commit
`24d437163` gives the captured built-in Map and Set methods the same
typed native step dispatch as Array iterators. Each step retains the
original frame, receiver checks, live insertion order, deleted-entry
budget charges and ordinary entry-pair arrays. A public `next()` call
returns a fresh result object.

Three alternating fresh-process pairs use matching single-C prealloc
builds, with 493 source and fixture pins. Only the six implementation
files differ. Every process yields 24,000 Map and Set values and entry
pairs and sums 402,000. The control caller arena grows by 76,555,943 bytes
in every pair. The candidate grows by 37,131,974 bytes, **51.5% less**.
The manual checks cover live deletion, insertion and clear, captured
and replaced methods, wrong receiver brands, public result mutation,
and Array and TypedArray iteration.

The native seed compiles nine executables in one compiler call. A fresh
reopen with `/usr/bin/false` verifies the same semantics, budget
exhaustion while scanning tombstones, and subsequent collection access.
It records nine hits, ten native entries, 172,579 helper steps, and zero
misses, compiler calls, pending or invalid entries. All runtime
processes and guards exit zero. The production type check passes in
37.633454667 seconds at 7,101,612,032 sampled peak bytes. The regression
source remains unrun under the automated-test hold.

In-flight production attempt `20261118-030853-ecf3924d` records the
earlier Array iterator sources. The managed hook queued this Map and
Set change. The installed executable is still `23ba3183…3bb`. Full
cached-native Back restoration under 12 GiB remains pending. Local
commands, pins and receipts are under
`repository-navigation-5204-r80`.

### LibJS built-in String iterator steps

Commit `961d82107` registers String iterator `next` with the same native
step dispatch used by Array, Map and Set. A public `next()` call returns
a fresh result object. The step reuses the VM's ASCII primitives and reads
non-ASCII code units from the iterator's owned text. The returned primitive
owns its code units.

Three alternating fresh-process pairs use matching single-C prealloc
builds. The 493 source and fixture pins differ only in the two
implementation files. Each process yields 24,000 strings and verifies
28,000 code units. The control caller arena grows by 51,794,105 bytes in
each pair. The candidate grows by 16,146,114 bytes, **68.8% less**.
The checks cover paired and lone surrogates, separate public result
objects, captured and overridden methods, wrong receivers, spread and
`Array.from`. The Boehm run forces collection and verifies retained
values, including NUL and lone UTF-16 units.

The native seed compiles three executables in one compiler call. A
fresh reopen with `/usr/bin/false` verifies the same yields and
observable behavior. It records three hits, three native entries and
188,208 helper steps, with zero misses, compiler calls, pending or
invalid entries. All runtime processes and guards exit zero. The
production type check passes in 42.333822041 seconds at 7,107,379,200
sampled peak bytes. The updated regression source remains unrun under
the automated-test hold.

The managed production build is still sealing its inputs. Full
cached-native Back restoration under 12 GiB awaits a new published
bundle. Local commands, pins and receipts are under
`repository-navigation-5204-r81`.

### LibJS built-in RegExp iterator steps

Commit `87ff4f0d1` uses native step dispatch for the captured built-in
`matchAll` iterator method. The normal native frame continues to own
observable `exec` calls, Unicode advancement and budget checks. A
public `next()` returns a fresh ordinary result object and exposes
the matcher-provided value.

Three alternating fresh-process pairs use matching single-C prealloc
builds. Of the 493 source and fixture pins, only
`libjs/regexp_match_all.v` differs. Every process yields 8,000 matches
and verifies their captures and indices. The control caller arena grows
by 77,462,209 bytes and the candidate grows by 65,142,227 bytes in
every pair, **15.9% less**. The probes also verify Unicode empty-match
advancement, custom result identity, retry after an abrupt step, and
captured and overridden methods.

A fresh native-cache process reopens with `/usr/bin/false` and
verifies the same semantics. It records five hits, eight native
entries and 104,273 helper steps, with zero misses, compiler calls,
pending or invalid entries. The seed compiles five executables in
one compiler call. The production type check passes in 41.849718292
seconds at 6,733,873,152 sampled peak bytes. The updated regression
source remains unrun under the automated-test hold.

### Archived Hacker News on the published browser

The installed single-C executable `23ba3183…3bb` completes a fresh
seed and compiler-disabled reopen on the original 30-story archive.
Both match the unchanged document PNG reference at 1024×768 CSS pixels
and 2× capture scale. Both pass the exact content audit with a private
profile and empty HTTP cache. JavaScriptCore stays uninitialized and
the audits record zero JavaScript errors.

The seed compiles six executables in one compiler call. The reopen
records six hits, six native entries and zero misses, compiler calls,
new compilations, pending or invalid entries at capture and shutdown.
The native cache uses ABI
`e2d10230287cafcdb03bce6df0a228f1f9d1fa04cdae2d2648cbe15c81c2835b`.
PIDs 72800 and 72926, the controller and the memory guard exit zero.
The guard adopts both browsers and their helpers and records
7.276059958 seconds and 465,616,896 sampled peak bytes.

The retained cache passes a third strict compiler-disabled reopen after
relocation. PID 75095 and its controller and guard exit zero, with every
input hash stable. That guard records 3.149268541 seconds and
412,729,344 sampled peak bytes.

Managed build `20261118-030853-ecf3924d` completes C compilation and
enters publication checks. Commands, input hashes, content and pixel
receipts, and the verified Hacker News cache are local under
`repository-navigation-5204-r82`.

### GitHub Back replay on the newly published browser

Managed build `20261118-030853-ecf3924d` publishes single-C `-prod`
executable `9c165f7ab3dc15fd6fcc7a0d89336aefde735c3a9f983c15248727de89918301`.
Its source receipt includes the NodeList, RegExp literal, frame capacity
and Array iterator changes. The Map and Set, String and RegExp iterator
steps were committed after its source capture.

Both fresh launches use the frozen full file lists, native file-search
and Back input, and the existing generated-code cache with
`/usr/bin/false`. Both match Brave's initial content, open the ready
README and deliver Back. Every recorded audit shows LibJS without an
initialized JavaScriptCore context. The only page diagnostic is GitHub's
Worker fallback warning. Each run verifies unchanged executable,
libraries, scripts, cache and fixture pins.

| Replay | PID | Brave content after Back | Native hits / entries at last audit | Guard seconds | Sampled peak bytes |
| --- | ---: | --- | ---: | ---: | ---: |
| Native input | 94429 | File view remains at the repository URL | 3,564 / 1,339,617 | 34.133926708 | 12,927,877,120 |
| Separate mapping trace | 98570 | Exact 33 rows, 56 commit links, latest commit and README | 3,585 / 1,780,212 | 57.882372875 | 12,888,014,848 |

Both last audits show zero misses, compiler calls, compilations,
pending or invalid entries. The 12 GiB guard adopts each browser and
ends both runs before normal shutdown or image capture. Both controller
children exit 137 and both guards exit 125. The first run verifies 139
input pins and the traced run verifies 141. The traced run establishes
exact terminal content in that observation. The memory and pixel gates
remain open.

The trace ranks current virtual mapping capacity under resource worker
URL and scratch paths at 624 and 576 MiB, ECMAScript function creation
at 448 MiB, interpreter frames at 432 MiB, and computed style at 377 MiB.
Those values describe attributed mapping capacity. The paired guard
reports above supply the sampled RSS peaks. Raw audits, stack mappings,
comparison inputs and guard receipts are local under
`repository-navigation-5204-r83`.

### CSS substitution input ownership

The GitHub mapping trace attributes 364,904,448 bytes of virtual mapping
capacity to component copies in the CSS substitution workspace during
cascade. Commit `3266e8378` keeps the substituted tokens live until the
typed parser returns. Supported values export their final graph, and only
the fallback path copies tokens that the result can retain.

A guarded standalone probe recomputed the same inline style 2,000 times.
The compiler's generated C differs only at the substitution changes.
Three matched pairs produced identical values for calculated width,
invalid height fallback, margin, padding, border radius, escaped font
family, image-set URLs and attribute-backed content.

| Conditions | Control caller-arena bytes | Candidate caller-arena bytes |
| --- | ---: | ---: |
| Each of three normal pairs | 195,199,955 | 169,279,969 |
| Substitution and typed-parser scratch poisoning | 195,199,955 | 169,279,965 |
| Scratch poisoning with calculated and text exports disabled | 213,695,944 | 198,847,950 |

The normal pairs use 25,919,986 fewer caller-arena bytes, a 13.3% reduction.
All ten runs exit zero with identical computed values. The 3 GiB guard
reports 250,101,760 sampled peak RSS bytes for the paired probe. The
guarded production type check exits zero. The focused regression sources
are included in the commit and the automated suites remain on hold.
GitHub's browser memory and pixel gates still need a bundle containing
this change.

### Hacker News on the GitHub replay build

A fresh compiler-disabled Hacker News launch on published executable
`9c165f7ab3dc15fd6fcc7a0d89336aefde735c3a9f983c15248727de89918301`
matches all 30 archived Brave story rows and the unchanged 2× document
PNG. At capture and clean shutdown, LibJS records six generated-code
cache hits and six native entries. Misses, compiler calls, compilations,
pending and invalid entries are all zero. JavaScriptCore stays
uninitialized. The browser (PID 21784), controller and guard exit zero,
with all 50 input pins unchanged. The guard adopts the browser and its
helper and samples 415,563,776 peak RSS bytes. The first setup was
rejected before launch because inherited proxy exclusions were set.
The verified run cleared those settings.

Generated-C differences, commands, exact CSS observations and browser
receipts are local under `repository-navigation-5204-r84`.

### Resource response filtering storage

Commit `3afba1ed2` retires the temporary header list, serialized filter
request, and decoded decision after each transport response check. The
existing filter memo owns its retained entries and the returned error
message is allocated in the caller before the workspace is released.

Three guarded pairs used 174 archived GitHub response header sets from
the full-list fixture, repeated 12 times with filtering enabled. Each
control retained 37,718,444 caller-arena bytes. Each candidate retained
601,176, a 98.4% reduction for the filter step. The focused probe
preserves the separate values and first spelling of repeated headers
and retains the Pikabu blocked-response error through a later filter
call. Both paths allow the same response with filtering disabled.

With scratch poisoning and filter logging enabled, the control retains
51,065,296 bytes and the candidate 601,176 bytes. Both produce exactly
the same 2,091 log records, including one Pikabu rejection. The generated
C differs functionally only at the response filtering workspace. All
eight processes and the 3 GiB guard exit zero. The paired guard samples
134,529,024 peak RSS bytes. A separate poisoned run verifies 75 blocked
response errors after their worker threads exit and reuses the first
worker's memo entries on a third thread. Its guard exits zero and samples
66,027,520 peak RSS bytes. The guarded production type check exits zero
and automated suites remain on hold.

Managed build `20261118-034626-1932f9c0` rejects a concurrent change in
consumed V package membership during parsing. The previous executable
stays published and the worker starts managed retry
`20261118-035602-2025fd74`. GitHub's full Back replay and exact Brave
pixels still require a completed production bundle with the CSS fix.
The isolated response observations, rejected build receipts and replay
driver are local under `repository-navigation-5204-r85`.

### Published compiler-disabled full GitHub round trip

Managed single-C `-prod` build `20261118-035602-2025fd74` publishes
`296096c89d6b92677139a110f2004bfe8df20d6ebc70db759960be3046c4e829`.
The sealed inputs contain the CSS substitution and response filtering
changes. Compiler and managed smoke guard exit zero. Operand slot
decoding changes the native ABI to
`857d37bf4f2f69da0f581b6094ba9c3456b3b7a09045cfdca817c386c8034ab6`.

The launch with the previous cache opens the README and restores the
exact Brave content. It records 5,163 misses and zero native hits or
entries. The memory guard stops PID 12742 before capture and shutdown
at 29.484697458 seconds and 12,976,996,352 sampled bytes. The guard and
its child exit 125 and 137. That run supplies cold-cache evidence.

New preparation on PID 15601 emits 13,915 executables in 109 Clang calls
using the established `-O0` preparation wrapper. It completes the frozen
root-page audit and shutdown with zero pending or invalid entries. The
controller and guard exit zero in 186.878644791 seconds at 8,467,431,424
sampled peak bytes. The ABI-specific cache is retained under
`libjs-github-production-296096-5204-r86/generated-c-staging` in the
local Vox benchmark cache.

A fresh launch of PID 22090 uses that partition with `/usr/bin/false`,
the original full file lists and private HTTP cache. Native input
searches for README, opens the ready file, and invokes toolbar Back.
Both repository audits match Brave exactly, including 33 rows, 56 commit
links, the latest commit and the 20,773-character README. The terminal
audit has 3,584 native hits and 1,779,548 native entries. Clean shutdown
records the same hits and 1,779,556 entries. Both show zero misses,
compiler calls, compilations, pending or invalid entries. JavaScriptCore
stays uninitialized and the sole page diagnostic is the Worker
fallback warning. All recorded executable, library, fixture and cache
inputs stay fixed. The browser, navigation controller and 12 GiB guard
exit zero. The guard adopts the browser and samples 11,972,313,088 peak
bytes over 123.22602575 seconds.

The standard 1024×768 window crop differs from the unchanged Brave
Back image at 118,210 pixels and from the historical Brave document
reference at 118,438 pixels. The pixel verdict exits one and the
overall parity gate remains open. The warmed capture shows a blue
Turbo progress strip at the top. A separate progress-selector replay
matches the same restored content and finds the element still present,
with opacity one and its width increasing after Back. The published
author script ends this progress path on a qualifying frame-render
event. The trace establishes the lingering element and leaves the
missing completion signal unverified. That separate diagnostic has
zero cache misses when its guard stops it in 35.043459208 seconds at
12,967,067,648 sampled peak bytes.

Hacker News passes an independent seed and compiler-disabled reopen
on the same published browser. PIDs 15139 and 15325 match the archived
30-story content and 2× document PNG. The reopen records six hits,
six native entries, zero cache misses and zero compiler calls, with
JavaScriptCore uninitialized. Both browsers and their guard exit
zero. The guard samples 472,367,104 peak bytes over 7.98300775 seconds.

### Native backdrop bitmap ownership

Commit `ee140dcae` snapshots premultiplied RGB backdrop bytes directly
for Core Image. Unsupported bitmap formats use the existing Quartz
snapshot. An off-canvas backdrop can skip the snapshot. A preview
that only reordered Quartz release and culling had no consistent
sampled RSS benefit.

Three matched standalone pairs of the committed code render 250 Retina
frames each. The exact combined raster digest across 60 direct outputs
and the first 18 frames is
`3239d71551ca253e25107f3b2896383b819e3410e576814251eaf005b8eac3f4`.
The direct outputs cover padded RGBA/BGRA, an opaque fallback format,
sRGB and Display P3, transformed and clipped regions and drawing after
capture. Peak process RSS is 225,820,672 / 222,101,504,
226,099,200 / 222,576,640 and 225,411,072 / 222,134,272 bytes for
control/candidate. All six processes and the 3 GiB guard exit zero.
The focused Objective-C and Objective-C++ regression fixtures compile.
Automated suites remain on hold.

A separate 150-frame mapping diagnostic on the one-copy preview
reports 750,206,976 bytes of requested anonymous writable mappings
versus 4,525,228,032 for the ordinary path. It validates the executable
addresses and uses the same raster digest. These are cumulative
virtual mapping capacities. The matched RSS numbers above describe
the isolated harness, and the published GitHub replay predates the
backdrop commit.

The checkout's local Git exclusions cover old generated C, frozen
compiler inputs and compiled browser artifacts stored with this
GitHub evidence. The file scan now omits 9,806,434,346 bytes, with
all 5,977 production input names preserved. The archived files remain
on disk.

Raw audits, content and pixel verdicts, compiler commands, mapping
diagnostics and guard receipts remain local under
`repository-navigation-5204-r86`.

### Back and Forward event target

A private observation fixture adds a small script to the archived HTML.
The original author scripts, full file lists and both router response
variants keep their hashes. Both browsers receive the JSON
representations of README and the returned repository. The Brave run
preserves the exact returned content and records a trusted traversal
callback whose event target is Window. The Vox trace records Document
as the target of the same Window callback. These instrumented launches
are separate from the compiler-disabled acceptance observation.

Commit `fe078fec5` fires the trusted history traversal event on Window
without the legacy target override. Guarded standalone control and
candidate probes exercise actual same-document Back and Forward through
the HTML navigable and the LibJS DOM binding. Both restore the URL and
the same object returned by `history.state`. The candidate reports Window
as both target and current target, preserves the trusted non-bubbling
`PopStateEvent`, and leaves the Document capture listener untouched.
The production type check exits zero in 51.452773667 seconds at
7,106,166,784 sampled peak bytes. The focused regression source covers
the target and current target. Automated suites remain on hold.
[HTML history traversal](https://html.spec.whatwg.org/multipage/browsing-the-web.html#update-document-for-history-step-application)
[DOM event dispatch](https://dom.spec.whatwg.org/#concept-event-dispatch)

The progress insertion stack identifies GitHub's delayed Turbo
progress callback. The document-level observer records the registration
of the frame-render listener and observes no frame-render delivery
during the warmed replay. The interpreted observation also leaves
the progress strip visible. Three Vox diagnostic attempts cross the
guard after native Back. The insertion-only attempt completes in
53.812231292 seconds at 12,547,260,416 sampled bytes. The browser
captures the restored document and the trace controller exits one
because the added script introduces diagnostic messages and cold code.
The actual cause of the incomplete progress lifecycle remains open,
and production has yet to exercise the popstate correction.

The unchanged Brave Back PNG carries Display P3 primaries with an
sRGB transfer function. The standard Vox document crop carries sRGB.
An offline ColorSync conversion of a copy of the Vox crop into the
Brave profile leaves 110,482 differing pixels, compared with 118,210
in the original raw comparison. Both input hashes verify before and
after. Color profile alignment alone leaves substantial pixel
differences. The original pixel verdict and capture policy stay in
force.

The event traces, browser and guard receipts, focused checks and
color profile diagnosis remain local under
`repository-navigation-5204-r87`.

### Published backdrop bundle checks

Managed build `20261118-043956-76e1c1ba` publishes executable
`66f97ef08d4c9ff9ae1195cd80c9817add78ab82c27960580f1444a44101e77d`.
The preprocessed source fingerprint and backdrop helper verify
against the compiler receipt. The source capture precedes
`fe078fec5`.

Hacker News reopens the existing cache on PID 15613 with the compiler
disabled, six native hits and exact archived content and pixels.
The guard adopts the browser and completes in 3.798951584 seconds
at 417,579,008 sampled peak bytes.

GitHub PID 15909 completes the full search, README and toolbar Back
replay using the archived responses and the existing compiler-disabled
cache. Both repository audits match Brave and shutdown records
3,584 hits and 1,788,838 native entries. It has zero misses, compiler
calls, compilations, invalid or pending entries and no initialized
page JavaScriptCore. The browser, controller and guard exit zero.
The 12 GiB guard samples 10,407,526,400 peak bytes over
122.293082 seconds. The two production builds contain additional
source changes, so these observations describe their separate runs.

The standard crop differs from the unchanged Brave Back PNG at
118,327 pixels and still shows the blue progress strip. The pixel
verdict exits one. The PNGs, audits and guard receipts are retained
with the event trace.

### GitHub soft-navigation bindings

The progress trace on the published `66f97ef0` bundle recorded two
99 ms timers in Vox. Both fired and the first inserted the progress
element. Brave scheduled one timer and canceled it when README rendered.
The private observer used the archived scripts, a separate observer asset
and instrumented HTML. The sampled 12 GiB guard ended the Vox trace with
exit 137 at 12,924,190,720 bytes after the toolbar Back input. Brave exited
zero at 996,704,256 sampled peak bytes.

GitHub's soft-navigation code reads and writes its marker through
`sessionStorage`. A private storage shim produced the progress-end event
and exposed a missing `HTMLMetaElement.content` property when React Router
read the visitor payload. The underlying archived attribute decoded as
valid base64 JSON. The storage-only replay exited cleanly in the browser
and failed the controller's README content check. It used 10,060,824,576
sampled peak bytes.

Adding the reflected metadata properties to the private fixture let
README render and allowed the native toolbar Back input. The progress
element disappeared and the returned repository title was observed. The
guard ended that run with exit 137 at 12,887,097,344 sampled bytes before
capture or the shutdown audit. The trace also identified the missing
`Element.attributes` used by GitHub to snapshot the root attributes and
restore them on Back.

Commit `c7a1a2e36` exposes the native session storage owner.
Commit `a187bc80c` reflects HTML metadata through the DOM attribute
mutator. Commit `21dfd0604` exposes native attribute records as live
`Attr` nodes in `NamedNodeMap`. Standalone LibJS probes exercised storage
identity, Unicode, origin and tab isolation, metadata decoding, live
attributes and restoration through native Back. Each runtime probe
completed under the focused 3 GiB guard. The production type-check of
the combined changes completed in 41.083 seconds at 7,119,486,976
sampled peak bytes. See the
[HTML storage getter](https://html.spec.whatwg.org/multipage/webstorage.html#dom-sessionstorage),
[metadata interface](https://html.spec.whatwg.org/multipage/semantics.html#the-meta-element)
and [DOM attribute map](https://dom.spec.whatwg.org/#interface-namednodemap).

The strict archived replay and exact pixel verdict require a published
bundle containing these changes. The newest completed bundle at the time
of these diagnostics was still `66f97ef0`. The local
`repository-navigation-5204-r88/receipts` directory retains the observer
manifests, audit states and guard exits.

### Active window document captures

The production bundle remains `66f97ef0`. Build
`20261118-053957-1b5fc431` verified the parsed session storage, meta and
attribute map sources and stopped before sealing when
`native_capture_darwin.m` changed. The following attempt
`20261118-054622-79e4258e` stopped on a change to
`native_layer_presentation_darwin.h`.

A standalone production LibJS probe projected the same generated-code
ABI as the existing caches, `857d37bf…4ab6`, with all 19 recorded input
hashes stable. The actual candidate ABI remains a publication check.
Hacker News on the current bundle passes exact 30-story content and
2× pixels, with six native hits and zero cache misses, compiler calls or
JavaScriptCore initialization. Browser PID 2251 and its guard exit zero
at 419,364,864 sampled bytes.

A separate GitHub diagnostic enables the historical raster options on
the original full Back workflow. PID 19106 restores exact Brave content
and records 3,586 native hits before the memory guard stops it after Back
at 12,917,112,832 sampled bytes. A 38-second capture of PID 28931 reaches
exact README and Back content plus a clean shutdown, with 3,583 native
hits and 1,621,141 entries. It has zero misses, compiler calls,
compilations, invalid or pending entries and no page JavaScriptCore.
The guard exits zero in 42.589682083 seconds at 10,138,746,880 sampled
bytes. The whole-window crop remains tagged sRGB and differs from the
unchanged Brave Back PNG at 117,190 pixels. This earlier, instrumented
capture supplies diagnostic evidence.

Commit `712e4197d` lets the active observer honor
`VOX_CAPTURE_DOCUMENT_ONLY` through the existing document PNG scheduler.
An isolated probe verifies opt-in routing, viewport geometry and audit
ownership with a native stub. The production type-check passes in
40.674927167 seconds at 7,113,670,656 sampled bytes. A published
bundle with the changes is required for the direct document capture and
the strict post-fix Back replay. Local scripts and receipts are under
`repository-navigation-5204-r89`.

### Published active document replay

Managed build `20261118-055438-888e0b4d` publishes single-C `-prod`
executable `9568a08eccc0567b56fa837e6d487bd57a63ec69d31c10b9760c9b5a6b5df757`.
The sealed inputs match the storage, meta, attribute map and active
document capture changes. C compilation and the managed headless smoke
check exit zero. The existing generated-code ABI remains in use.

Hacker News PID 86680 matches the original 30-story content and 2×
document PNG. Capture and shutdown record six native hits, with zero
misses, compiler calls and page JavaScriptCore initialization. Its
guard exits zero in 3.826958584 seconds at 418,480,128 sampled bytes.

GitHub PID 87013 opens the full archived README and returns to the
exact Brave repository content through toolbar Back. The last audit
records 3,613 native hits, zero misses or compiler calls, and no
initialized JavaScriptCore. The standard 120-second window capture is
interrupted before its PNG and shutdown audit. The memory guard ends
it at 33.473139333 seconds and 12,889,309,184 sampled peak bytes. The
guard and its child exit 125 and 137.

The 27-second direct document observation on PID 91166 captures the
usual live raster policy after native Back. Both repository content
audits match Brave and the archived README renders before Back. The
returned audit finds zero progress elements. The browser, controller
and memory guard exit zero in 29.811995833 guard seconds at
12,874,825,728 sampled peak bytes. Capture and shutdown report 3,615
native hits, with zero misses, compiler calls, new compilations,
invalid or pending entries. Shutdown records 1,682,385 native entries
and JavaScriptCore stays uninitialized.

The direct 1024×768 PNG differs from the unchanged Brave Back reference
at 77,950 pixels. The first differing row is y=16. Converting a copy
of the sRGB PNG to the Brave profile leaves 52,207 differing pixels.
Both original image hashes remain fixed. An earlier diagnostic with
the historical raster options reached the Display P3 document frame
path. It captured during the README transition before Back, so its
PNG supplies capture-path evidence. The original strict pixel and
long-window memory gates remain open.

A 36-second whole-window memory observation completes the same native
round trip on PID 12988. It records exact repository and README content,
clean shutdown, 3,614 cache hits and zero compiler calls. The guard
exits zero after 48.092839334 seconds at 12,060,753,920 sampled bytes.
The browser RSS samples reach 8,703,377,408 bytes on the repository
before Back, 10,357,620,736 bytes while the README URL is active, and
11,660,165,120 bytes in the returned repository. The timed memory-map
probes expire, so these samples establish the growth across phases.
The window crop differs from Brave at 77,951 pixels and differs from
the earlier direct document image at 63 pixels. Commands, complete
guard exits and original PNGs remain local with the other r89 receipts.

### Resource fetch worker storage and full-window diagnostics

The original 120-second search, README and toolbar Back input on
`9568a08e` completed on PID 18013 with the anonymous-region probe
attached. The initial and returned repository content match Brave,
the README document reached completion, and the browser, controller
and guard exited zero. Capture and shutdown record 3,615 native cache
hits and 1,786,846 native entries, with zero misses, compilations or
compiler calls. Page JavaScriptCore stayed uninitialized. The 12 GiB
guard sampled 9,891,332,096 peak bytes over 121.985285542 seconds.
The whole-window crop differs from the unchanged Brave Back PNG at
115,255 pixels. Converting a copy to the embedded Brave display
profile leaves 107,527 differing pixels. The instrumented run reports
its own memory peak. A reduction claim requires matched ordinary runs.

The anonymous-mapping trace attributes 654,311,424 bytes of tracked
remaining capacity to individual background fetches, 603,979,776 to
batch workers, and 100,663,296 to script fetch workers. Each stack
reaches the temporary URL parser through the worker request. These
are virtual region capacities attributed to the stack that mapped
them. The memory guard supplies the separate resident-byte measurement.

Commit `48bb0b6b1` runs the shared batch and individual request path
in a scratch arena. It copies the response or error into the
existing retained worker arena before releasing request workspaces.
A standalone production-preallocation probe passed with ordinary
allocation and with the request namespace poisoned on release. The
HTTP check receives an embedded-NUL body and repeated headers after
the worker returns. The local file batch checks successful bodies and
an error after repeated jobs. Both guards exit zero. The first full
production type-check reported pointer arithmetic errors in existing
edits to `paint/portable_svg_mask.v`. After those edits were fixed,
the type-check exited zero in 44.145147125 seconds with
7,125,319,680 sampled peak bytes.

The subsequent published single-unit V `-prod` build `5d72f614`
predates `48bb0b6b1`. Hacker News PID 53829 reopens the existing cache
with exact 30-story content and 2× pixels. Capture and shutdown
each have six native hits and zero misses or compiler calls. The
guard exits zero in 3.850159625 seconds at 416,530,432 sampled bytes.
The ordinary 120-second GitHub direct-document replay on PID 54257
matches the initial Brave content, opens the README, and sends
toolbar Back. At the last audit it has 3,594 cache hits, zero misses
or compiler calls, and no page JavaScriptCore. The guard stops it
before the final content and PNG capture and the shutdown audit, at
31.715088334 seconds and 12,912,934,912 sampled peak bytes. The guard
and its child exit 125 and 137. Both replays use the original frozen
inputs and references.

A separate 120-second replay on PID 56162 uses the anonymous-region
probe and the historical raster diagnostics. It restores the exact
Brave repository content after opening the README and using toolbar
Back. Capture and shutdown record 3,615 cache hits and 1,781,009
native entries, with zero misses or compiler calls and no page
JavaScriptCore. The browser, controller and guard exit zero at
12,511,461,376 sampled peak bytes in 121.503931583 seconds.
The presented-frame path produces a 1024×768 Display P3 document
PNG that differs from Brave at 106,106 pixels. The largest RGB channel
difference is 170 at (120, 31) in the masthead. Testing one- and
two-pixel translations in either direction leaves zero translation
as the best fit in six regions. The PNG and memory results describe
this diagnostic configuration.

The managed production build for the resource worker change is
pending. The strict memory and pixel checks remain open. Commands,
audits, capture hashes and measurements are local under
`repository-navigation-5204-r90/receipts`.

### Live capture raster density

On published `5d72f614`, the fresh repository-root screenshot on
PID 79786 matches the full Brave content and reproduces the historic
two Notifications-button pixels exactly. The browser, controller and
guard exit zero. The guard samples 6,896,631,808 peak bytes over
10.37854625 seconds. Shutdown records 2,949 native hits and 483,973
entries, with zero misses, compilations or compiler calls.

The previous Back capture redrew a 1× output bitmap while the
Chromium raster plan and paint helpers still used the display's
2× density. The root screenshot entered the 1× raster path from
launch. Its trace narrows the root tile from 2,048 to 1,024 pixels.
The previous live Back trace lacked that projection.

A separate 120-second diagnostic on the same bundle supplies
`LADYBIRD_SCREENSHOT_DELAY_SECONDS=0.1`, so the live replay presents
at 1× throughout. The layout and rendering DPR stay at 2. The
unchanged search, README and toolbar Back sequence completes on PID
82753. Initial and returned repository content match Brave.
Capture and shutdown record 3,616 cache hits and 1,780,848 native
entries, no page JavaScriptCore, and zero misses or compiler calls.
The browser, controller and guard exit zero in 121.512677333 seconds
at 12,536,053,760 sampled peak bytes.

The Display P3 capture differs from the original Back reference at
exactly two pixels, (648, 188) and (646, 190). Both expected and
actual RGB triples at those points match the historic root residual.
The unchanged historical and Back Brave references themselves differ
at 1,116 pixels, all within the file search control. The returned
Vox image retains the same search control state as Brave. The
instrumentation and the 1× display setting make this a raster
diagnostic. The live memory and exact pixel checks remain open.

Commit `ac5b815eb` scopes the target density to actual capture
painting. Chromium raster plans, tiles, scale-sensitive draw paths
and native masks and filters use that density during the capture.
The live document's display queries and layout retain their own
density. The native capture fixture passes under ARC and MRC. It
checks ordinary 2× drawing, a 1× document capture from that live
window, and restoration of the 2× raster density. The first fixture
run reached both crop checks but stopped in the subsequent
invalid-bounds checks because its mock window received an AppKit
display call. The retry restored the fixture's screenshot mode
for those cases. The native guard exits zero in 2.493498416 seconds
at 190,595,072 sampled bytes. The production type-check exits zero
in 47.716407916 seconds at 7,128,743,936 sampled bytes.

The intervening managed build `20261118-064618-79a6e376` verified
the resource worker source and stopped when
`native/include/native_bitmap_snapshot_darwin.h` changed during
sealing. The new managed build is required to exercise the two
committed fixes together. The original PNG references and both
diagnostic results are retained locally with
`repository-navigation-5204-r91/receipts`.

### Background image batching and rectangle draw order

Commit `3ec988f6d` groups the image URLs discovered during paint
preparation, initial preload and the eager unsized-image scan.
The discovery pass reserves each URL once. The existing fetch pool
then runs the batch with at most 16 workers and the document's
request scope. Each published result follows the existing handling
for decoding, cache insertion and repaint.

The focused production-preallocation probe exercises 19 unique
file responses interleaved with duplicate discoveries and an
already-cached URL. It also checks local file errors, a loopback HTTP
body with embedded NUL and repeated headers, and publication after
worker exit. Both ordinary and poisoned request arenas pass. The
whole production type-check exits zero in 41.080754625 seconds at
7,114,424,320 sampled peak bytes. The next managed build verifies
parsed V inputs for the resource workspace, capture raster scale
and batch changes. Its native sealing and final browser checks
remain pending.

The three retained GitHub round trips also pass exact content
comparison at each visited document. Each standalone README audit
matches the Brave title, viewport, latest commit, three commit links
and all 22,128 article characters. The initial and returned
repository audits each match 33 rows, 56 commit links and the
20,773-character embedded README.

A standalone Metal experiment replays the two captured rectangle
controls and 290 derived instance orders over the same white
backdrop. Both controls reproduce their complete BGRA hashes. The
derived document-order control with the underline first changes
exactly (648, 188) and (646, 190), the same coordinates as the
published-page residual. Both 120-case nine-instance series give
20 complete tile matches each. The Notifications corners match
when its border is third or fourth within the four-border part of
the nine-instance order. Each 24-case eight-instance series has
six orders that match the two corners, with other button pixels
still different. The replay guard exits zero in 13.874308291 seconds
at 51,085,312 sampled bytes. These experiments isolate draw order
and batching on the retained tile. The page renderer and references
stay fixed while the production pixel and memory gates remain open.

The full-content comparison, source proof and draw-order receipts
are local under `repository-navigation-5204-r92/receipts`.

### Retained responses and rectangle viewport controls

Commit `023687635` preserves the payload and headers of a
process-owned cache response when filtering returns that same
response. Fresh, rewritten or shorter-lived responses still copy
into retained storage before the request arena retires.
Stylesheet copies allocated in a document clear the process
ownership flag. The focused preallocation probe verifies binary
body and header equality, independent copies for unmarked input,
and preserved pointer identity for a marked cache hit. It passes
with ordinary allocation and with the request arena poisoned on
release. The production type-check exits zero in 44.589377542
seconds at 7,126,171,648 sampled peak bytes.

Three alternating fresh-process pairs run the 96-response
background discovery probe on the same executable and unchanged
128 KiB local files. All responses arrive once and pass checks
of their source, length, prefix and boundary bytes. Singleton
dispatch creates 96 fetch workers per process. Batched dispatch
creates 16. The median resident-size increase is 18,890,752 bytes for
singletons and 16,973,824 bytes for the batch. The corresponding
physical-footprint increases are 19,465,320 and 16,924,888 bytes.
All six executions and their 3 GiB guards exit zero. These
instrumented local-file measurements cover the dispatch change.
The production GitHub memory check uses the real browser and
archived network replay.

The 36 retained Metal cases compare three instance orders at
widths 1,024 and 2,048 and heights 256, 416 and 768, with both a
full scissor and a scissor around the buttons. The adjusted
projection holds geometry fixed in pixels. Every case preserves
its order's button pixels across these settings. The captured
order and the alternate order with the two narrower borders first
match the reference buttons. Document order with the underline
first retains the same two Notifications corner differences.
The replay guard exits zero in 1.910968541 seconds at 97,665,024
sampled bytes. This is a selected-draw result over white.

Build `20261118-070300-5a022eb6` stopped during sealing after
`native/include/native_scroll_raster_darwin.h` changed. The next
managed attempt is running, and `5d72f614` remains the latest
published executable. The normal 120-second Back replay and exact
pixel comparison await publication of the resource and capture
changes. Local inputs, guards and results are under
`repository-navigation-5204-r93/receipts`.

### Published Retina replay and PNG decode density

Managed build `20261118-071534-1dc4ac8a` published executable
`4ac49eb9690c121587fd4efd8f859f2cf0e2762013861238f07bb91a05547540`
with a single C unit and literal V `-prod`. Its consumed source
receipt includes the capture density, request arena, response
ownership and image batching changes. The build and headless smoke
guards exit zero. The fresh Hacker News reopen (PID 14317) matches
the archived 30-story content and every pixel of the 2× reference.
It records six native cache hits and entries, zero misses and compiler
calls, and an uninitialized JavaScriptCore runtime. The guard exits
zero in 4.330 seconds at 420,102,144 sampled bytes.

Both GitHub attempts use the original archive, a fresh Retina window,
the same generated native cache, `/usr/bin/false` as the compiler,
and the same native input sequence. The ordered content proof checks
the initial repository, the 22,128-character standalone README, and
the repository after native toolbar Back against their Brave content
controls. It checks the initial and returned snapshots on opposite
sides of the standalone README. The original verdict picked the first
matching repository snapshot for both stages because their content
matches. The ordered proof records the actual return separately.

The ordinary attempt (PID 14855) executes all inputs and restores
the exact repository content. The guard stops it at 35.391 seconds
and 12,896,780,288 sampled bytes, above the 12,884,901,888-byte cap.
The guard exits 125 and reports child exit 137. The last native
snapshot records 3,614 hits, 1,643,879 entries and zero misses or
compiler calls. The process reaches neither final PNG encoding nor
the shutdown cache audit.

The separate historical-raster diagnostic (PID 15669) completes the
120-second run with zero browser, controller and guard exits. It peaks
at 12,582,420,480 sampled bytes over 121.699 seconds and records 3,614
hits and 1,774,689 native entries, zero misses or compiler calls, and
an uninitialized JavaScriptCore runtime. The document stays at a live
2× display and layout scale. Native capture rerenders at 1× and encodes
a 1,024×768 Display P3 PNG. The pixel gate against the unchanged Brave
Back reference exits 1 with 310 differing pixels and a maximum channel
error of 23. The repository logo accounts for 176 pixels and the commit
avatar accounts for 132. The two remaining points in this capture are
the Notifications button corners seen in the earlier 1× control.

The upload logs show the 30×30 repository logo and 20×20 commit avatar
decodes in that 1× capture. The earlier whole-window 1× control used
60×60 and 40×40 decodes and matched both image regions. Commit
`2c21578e1` uses the actual raster density for decode sizing in both
sampled PNG paths, including the shadow group. A focused fixture
exercises the 2× live raster, the 1× capture raster in the same window,
and the disabled flag. It verifies the 60×60 and 40×40 capture decode
targets and exits zero. The production type-check exits zero in
42.452 seconds at 7,119,241,216 sampled bytes. Build
`20261118-073809-246321e6` stopped after a native SVG header changed
during input sealing. The commit has requested a managed rebuild.
The published capture has yet to exercise the PNG change. The normal
120-second memory and exact Brave pixel checks remain open.

In the standalone Metal control, a single submitted rectangle clipped
outside the target leaves no pixels on its own. Placing it before the
button borders reproduces the exact reference tile, including both
Notifications corner RGB values. Unused leading instance rows and fully
clipped rectangles submitted after the borders preserve both differences.
These 35 controls run under a guard for 2.520 seconds at 51,118,080
sampled bytes and isolate a draw-submission dependency in the tile.

The build-sealing sample also led to commit `5ddab3b29`. It uses
incremental CommonCrypto SHA-256 in the macOS build tools and preserves
the portable implementation. Three alternating fresh-process pairs on
an unchanged synthetic checkout with a 96 MiB file produce identical
repository and build-input digests. Median time inside the repository
hashing routine is 4.653 seconds for the reference and 0.103 seconds
for CommonCrypto. The binary, symlink and missing-file checks pass, as
do the portable path and its Linux C-backend type check.

The source receipts, input hashes, ordered content proof, guards, raw
browser logs, and pixel comparisons are retained locally under
`repository-navigation-5204-r94/receipts`.

### Resource worker mapping follow-up

The anonymous-mapping probe on the same `4ac49eb9` executable exercises
the whole-window diagnostic used for the earlier fetch-worker trace.
The fresh process (PID 44440) completes the full 120-second replay and
matches the exact initial repository, standalone README and returned
repository content. The browser, controller and guard exit zero at
12,022,005,760 sampled bytes over 122.235 seconds. Shutdown records
3,614 native hits and 1,779,610 native entries, zero misses or compiler
calls, and an uninitialized JavaScriptCore runtime. The driver checks
141 input identities and reports zero changes. The guard verifies
adoption of the browser PID.

The symbolized trace shows 81 surviving mappings of 16 MiB each from
the resource and script workers' first request scratch entry. That
size matches the V runtime's base arena for a fresh thread. Twelve
256 KiB mappings appear at those scratch and nested URL parser sites.
The aggregate surviving virtual capacity at those worker sites is
1,362,100,224 bytes. The largest worker stacks in the older trace
totaled 1,358,954,496 bytes and first reached the allocator from URL
resolution. The traced capacities reflect anonymous mappings, including
pages that might never become resident. This run preserves the original
ordinary memory verdict and supplies a separate view of worker allocation
lifetime. The symbol and input checks, window PNG, and guards are local
under `repository-navigation-5204-r95-memory/receipts`.

### Published PNG density validation

Managed build `20261118-074136-fde66f4a` publishes executable
`870e280a166afa2249e1f90dcd8fb7cee701e0614f25414dd12004c9f4472077`
with a single C unit and literal V `-prod`. The two consumed PNG
source files match `2c21578e1` exactly. The build and headless smoke
checks exit zero. Hacker News PID 64175 reopens the existing cache
with exact 30-story content and 2× pixels, six native cache hits and
zero misses or compiler calls. The guard exits zero in 3.839 seconds
at 419,299,328 sampled bytes.

The ordinary GitHub attempt (PID 64426) again matches the three
Brave content controls in order. The guard stops it at 32.346 seconds
and 12,904,841,216 sampled bytes, above the same 12 GiB cap. The
guard and its child exit 125 and 137. The last audit has 3,615 native
hits and 1,681,884 native entries, zero misses or compiler calls, and
an uninitialized JavaScriptCore runtime. The ordinary attempt ends
before encoding the PNG or writing the shutdown cache audit.

The historical-raster run (PID 65341) again matches the exact repository
and README audits. It completes the 120-second replay in 121.845 guard
seconds at 12,680,183,808 sampled bytes. The browser, controller and
guard exit zero. Shutdown records 3,615 native hits, 1,776,073 native
entries, zero misses or compiler calls, and an uninitialized
JavaScriptCore runtime.

The 1,024×768, 1× capture from the live Retina window now decodes the
repository logo at 60×60 and the commit avatar at 40×40. Both image
regions match Brave pixel for pixel, removing all 308 differences from
those regions. The unchanged Brave Back reference still differs at
the two Notifications corners, (648, 188) and (646, 190), with the
same RGB values as the earlier Metal control and maximum channel
error of 10. The exact-pixel verdict exits 1. The ordered audits,
input identities, image comparison and guard reports are local under
`repository-navigation-5204-r96-png/receipts`.

### Resident memory during the Back replay

Three fresh `870e280a` processes replay the original GitHub inputs with a
120-second endpoint. A read-only observer samples the browser's RSS and
physical footprint with `proc_pid_rusage`, and scans memory regions at RSS
thresholds. The existing 12 GiB guard adopts the browser and reports its
separate aggregate RSS. Both input drivers keep the usual live raster policy.
The third process also runs the anonymous-mapping interposer. The fixed
snapshots show exact repository, complete README, and restored repository
content in that order.

| Capture endpoint | Browser PID | Guard / guarded child | Guard seconds | Sampled peak RSS bytes |
| --- | ---: | --- | ---: | ---: |
| Active document | 83965 | 0 / 0 | 121.689 | 10,353,098,752 |
| Whole window | 91584 | 125 / 137 | 33.573 | 13,045,137,408 |
| Whole window with mapping probe | 94384 | 125 / 137 | 32.298 | 12,924,502,016 |

The active-document attempt records 3,614 native cache hits, zero misses
or compiler calls, and a clean shutdown. The unchanged Brave Back PNG
differs from its standard-raster capture at 60,079 pixels. The earlier
active-document attempt on this executable crossed the cap without the
observer. These outcomes show that an ordinary-raster completion is
possible on the archived workload and that it varies across launches.
The separate physical-footprint sample at the active-document RSS peak
is 13,126,200,720 bytes. The post-Back active-document scan at 37.951
seconds reports 2,476,457,984 bytes in the kernel's swapped-out field
for untagged private regions. That field is zero in the last complete
whole-window scan. The guard uses sampled RSS.

The last complete scan in the ordinary whole-window attempt attributes
11,674,664,960 resident bytes to untagged private regions. The scan that
overlaps termination is retained with its incomplete status. In the
instrumented attempt the last complete scan matches 4,500 exact private
region extents across both ends of the scan, covering 11,519,066,112
resident bytes. The largest individual reservation origins are LibJS
instruction dispatch (452,067,328 bytes), ECMAScript function creation
(402,227,200), and reusable execution-frame allocation (217,497,600).
The worker base mappings account for 7,241,728 matched resident bytes.
Those mappings originally reserve 16 MiB per fresh thread, and recycled
regions can be reused without remapping. The attribution describes the
original reservation sites and current residency of exact matches.

Twelve selected Metal draw controls preserve the shaders and vary the
depth state. Reversing the viewport depth range, clear value and compare
function together reproduces each original full tile exactly, including
both corner differences in document order. Inclusive comparison and
disabled depth writes each produce four differences from the reference
in every tested order. These selected draws leave the exact whole-page
pixel gate open.

The sampled regions, mapping joins, exact audit stages, controller
inputs and guards are local under `repository-navigation-5204-r97/receipts`.

### LibJS merge-sort workspace

Array sorting was among the reservation origins in the final private
region sample. Commit `ad44847c8` replaces the per-merge left and right
clones with a working copy and one reusable merge buffer. The recursion
still visits the left half before the right and takes equal values from
the left. A comparator error from a child sort leaves the caller buffer
intact. An error during the final merge keeps the already written prefix.
The new regression covers both error locations.

The actual sort unit file passes with current V under the aggregate
memory guard. The compiler retries with C after its implicit TCC check
cannot resolve CoreFoundation. The guard exits zero in 140.983 seconds
at 9,298,542,592 sampled bytes. The same unit file passes with `-gc none`
in 95.809 guard seconds at 8,935,849,984 sampled bytes. The production
type check exercises the full browser with `-prod -prealloc -gc none`
and exits zero in 46.927 seconds at 7,119,716,352 sampled bytes.

A focused production-allocator fixture compiles both versions of the
sorter and runs each in its own fresh process. The 2, 3, 16, 57, 512
and 4,096 item cases preserve stable ordering and identical comparison
counts. For 100 sorts of 4,096 items, arena growth falls from
275,203,183 to 9,836,800 bytes with 4,427,500 comparisons in each
process. The guard exits zero in 3.849 seconds at 629,932,032 sampled
bytes. This measures allocations in the focused sort workload. The
managed commit rebuild is required for a GitHub run with the new sorter.

### Capture color and the next published control

The standard-raster active-document PNG from PID 83965 is tagged sRGB.
Converting a copy with ColorSync to the Brave reference profile reduces
the difference from 60,079 to 25,265 pixels. The three sampled link
pixels change from RGB `(9, 105, 218)` to the exact Brave value
`(46, 103, 211)`. The first verification required the complete ICC
profile bytes to match and rejected the rewritten profile. The retry
verifies the identical matrix, white point and channel transfer tags.
Only the copyright tag payload differs. Both original PNG hashes remain
fixed. The converted copy supplies color attribution and the original
capture remains the ordinary-raster result. Among the 25,265 differing
pixels after conversion, 23,107 have a maximum channel difference of one.

Build `20261118-075540-37c2a48b` publishes executable
`896b2d35d455afdbb5ec57c6dd5d5759a42e1a15d5f71961ae39fc0d146365cb`.
Its frozen source manifest contains the call-argument workspace store
change and the previous sorter. Hacker News PID 21382 matches the exact
30-story content and 2× pixels with six native hits and zero misses or
compiler calls. The guard exits zero in 4.416 seconds at 420,790,272
sampled bytes.

On that build, ordinary GitHub PID 21940 matches the three content
controls and reaches 3,614 native hits with zero misses or compiler
calls. Its guard stops the process at 34.293 seconds and 12,947,324,928
sampled bytes, before PNG capture or shutdown audit. Separate raster
diagnostic PID 23784 completes the 120-second replay and matches the
same ordered content. It records 3,615 native hits and 1,767,696 native
entries, zero misses or compiler calls, and no initialized JavaScriptCore.
The browser, controller and guard exit zero in 121.731 guard seconds at
12,586,565,632 sampled bytes. The unchanged Brave Back PNG still differs
at the same two corner pixels and the exact-pixel verdict exits 1.

The ordinary and diagnostic attempts use unchanged archives, comparison
inputs and caches. Both remaining goals require the normal renderer and
memory behavior to be verified on their respective capture paths. The
converted images, ordinary and diagnostic results, and build receipts
are local under `repository-navigation-5204-r97/receipts`.

### Published merge-sort workspace replay

Managed build `20261118-081004-bf6df4bf` publishes executable
`604f51df0b16e909d556320a196324d6fb5af2f4b425127326d6c9899a6c46b4`
as one C unit with literal V `-prod`. The consumed sort source matches
`ad44847c8`. The build and headless smoke guards exit zero. Hacker News
PID 55949 again matches all 30 stories and the 2× PNG with six native
hits and zero misses or compiler calls. Its guard exits zero in 3.825
seconds at 415,760,384 sampled bytes.

The ordinary GitHub replay (PID 56148) matches the three ordered content
controls and records 3,615 native hits and 1,648,713 entries in the last
audit. It has zero misses and compiler calls. The guard stops it at
28.955 seconds and 12,919,668,736 sampled bytes. Guard and guarded child
exits are 125 and 137. The final PNG and cache shutdown audit are absent.

The separate raster diagnostic (PID 56636) completes 120 seconds and
matches the three exact content controls. Shutdown records 3,615 native
hits and 1,773,921 native entries, zero misses or compiler calls, and an
uninitialized JavaScriptCore runtime. The browser, controller and guard
exit zero in 121.491 guard seconds at 12,367,855,616 sampled bytes.
The unchanged Brave Back PNG differs at the same two Notifications
corners, so the exact-pixel verdict exits 1. The two production builds
consume additional source changes, and the standalone sorter allocation
result supplies the isolated comparison. The browser checks, fixed input
hashes and guard records are local under
`repository-navigation-5204-r97/receipts/sort-published`.

### Optional-chain AST storage and Metal sample controls

The resident-page trace identified expression-parser call sites among the
largest LibJS reservation origins. Commit `07d6fa895` stores the optional
chain's base and reference list together in the payload for that node. The
base is embedded in the payload. The AST dump, nested function collection,
and optional-chain compiler walk those same children in the original order.

Clang measures the declarations extracted from the published and candidate
V C output on arm64. `Expression` falls from 784 to 736 bytes and
`ExpressionKind` falls from 760 to 712. The optional payload is 784 bytes,
the size of the former separately allocated base. The layout check compares
individual records and exits zero in 7.968 guard seconds at 1,080,639,488
sampled bytes. The browser runtime guard measures peak RSS separately.

The optional-chain unit file passes with current V in both GC modes. The
regression retains a closure across further parsing and then exercises
functions in the chain's base, computed member and call argument. The
focused upstream fixture and all 100 upstream AST fixtures match. The
production type check exits zero in 43.840 seconds at 7,026,360,320 sampled
bytes. Managed attempt `20261118-082424-a9710d2b` stops when a shared CPU
blitter input changes during sealing. The next attempt's parsed source
receipt matches all four optional-chain implementation files in the commit.

The 15 attachment controls replay the captured instance order, document
order and the document order with a fully clipped prefix. Memoryless color
or depth, memoryless color and depth together, and stored MSAA color samples
all preserve the original full tile for each order. Their guard exits zero
in 1.262 seconds at 126,484,480 sampled bytes.

The sample-position controls use the GPU's four default locations. Explicit
default order reproduces implicit default order. Across all 24 permutations
of those same positions, document order always differs at both Notifications
corners. Eighteen permutations also introduce two or three other corner
differences across all three instance orders. In document order, the
Notifications corner colors take three distinct pairs of RGB values across
the permutations. The reference order and clipped-prefix order preserve
the reference corner colors throughout. The successful retry uses
the Metal SDK's programmable-sample-position property and records 75
successful renders in 6.254 guard seconds at 138,248,192 sampled bytes.
These controls exercise selected draws over white. The exact page result
still depends on the two remaining corners.

The AST inputs and outputs, generated layout proof, raw Metal controls,
and guard results are local under `repository-navigation-5204-r98/receipts`.

### Published optional-chain storage replay

Managed build `20261118-082925-1a2a7a3f` publishes executable
`19554c666e7ef07de44937357e3a2f37df63bc26d8347bd4830a133c38be1766` as
one C unit with literal V `-prod`. The sealed manifest verifies the four
implementation files in `07d6fa895`. The build and headless smoke guards
exit zero. Hacker News PID 17660 again matches all 30 stories and the
2× PNG with six native hits, zero misses or compiler calls, and an
uninitialized JavaScriptCore. Its guard exits zero in 4.278 seconds
at 420,429,824 sampled bytes.

The first ordinary GitHub replay (PID 17921) completes 120 seconds
and matches the initial repository, standalone README and restored
repository content. The browser, replay and guard exit zero. The
guard samples 12,874,465,280 peak bytes over 122.022 seconds, 10,436,608
bytes below its cap. Shutdown records 3,614 native hits, 1,772,683 entries,
zero misses or compiler calls, and an uninitialized JavaScriptCore. The
standard-raster PNG differs from the unchanged Brave Back reference at
60,079 pixels, and the outer pixel verdict exits 1.

The separate raster diagnostic (PID 20941) completes 120 seconds with
the same ordered content. It records 3,615 native hits and 1,765,607
native entries, zero misses and compiler calls, and an uninitialized
JavaScriptCore runtime. Its browser, replay and guard exit zero, with
12,380,717,056 sampled peak bytes over 122.269 seconds. The two
Notifications differences remain against the original Brave Back PNG.
The standard-raster and raster-diagnostic captures each match the prior
Vox image for their respective mode pixel for pixel.

The repeated ordinary replay (PID 35565) uses the same executable, input
hashes, cache policy, and 120-second endpoint. It restores the exact
content again and reaches 3,614 native hits and 1,678,243 entries with
zero misses or compiler calls. The guard stops it at 39.368 seconds and
12,906,889,216 sampled bytes. Guard and guarded child exit 125 and 137.
The ordinary memory result varies across the two launches. Both attempts
and the separate raster result are retained with their input hashes and
host load readings under `repository-navigation-5204-r98/receipts/published`.

### Conditional expression storage and triangle winding controls

Commit `53adf12e9` stores a conditional's test, consequent and alternate
in one owned payload. The parser's temporary tail contains the operator
position and a reference to this payload. It fills the alternate branches
backward, preserving right associativity and the original source ranges.
The code generator borrows the stored branches while preserving their branch
order and shared result register. Other expressions retain their usual
recursion limit.

The arm64 C declarations put `Expression` at 704 bytes, down from 736,
and a `ConditionalTail` entry at 24 bytes, down from 1,488. The single
2,112-byte payload stores three children that formerly occupied three
736-byte allocations. These are record sizes. The layout check's guard
exits zero in 5.158 seconds and samples 987,316,224 peak bytes.
The generated parser body confirms three child allocation sites in the
control and one payload allocation site in the candidate.

The first compile rejects the local borrowed traversal without an
explicit lifetime annotation. The retry confines the borrow to the
function and passes the conditional unit file, including its 1,000-arm
chain and the new delayed-closure regression. The same unit file passes
with `-gc none`. All 100 upstream AST fixtures match, and the production
type check exits zero in 38.612 seconds at 7,124,402,176 sampled bytes.

The Metal replay converts the 69-index strip to 67 triangles, preserving
primitive order and all 15 triangles with repeated vertices. For each of
the captured, document and clipped-prefix instance orders, the original
strip and all six triangle vertex permutations produce identical full
tiles for that instance order. This covers cyclic vertex rotations and
reversed winding. The 21 replays and compiler run exit zero under the
guard in 2.266 seconds at 136,413,184 sampled bytes. The document-order
control still differs at the two Notifications pixels.

Fifteen further draws vary the primitive stream while keeping its vertices
and winding. Reversing the stream repairs both document-order Notifications
pixels and introduces five differences elsewhere. Moving all zero-area
triangles to the front also repairs those pixels and introduces four
differences elsewhere. Putting them at the end reproduces each original
tile. These controls isolate primitive scheduling effects and leave the
page's original renderer and pixel verdict in place. The guard exits zero
in 1.487 seconds at 164,298,752 sampled bytes.

The coverage and post-depth-coverage probes reproduce their uninstrumented
tiles byte for byte in six draws. Their guard exits zero in 0.992 seconds
at 72,564,736 sampled bytes. In the document-order control at
`(646, 190)`, all four samples record primitive 1 with mask 15. Moving the
zero-area triangles to the front gives primitive 1 mask 1 and primitive 30
mask 14, the same sample split recorded in the earlier unified draw.
Reversing the whole stream yields that split at this point as well. At the
other Notifications corner, the two reordered streams reach the reference
color with different sample assignments. Both Notifications differences
remain in all 45 variants that remove one zero-area triangle or move it
to the front or back. Dropping all 15 also leaves both differences.
The 141 draws across the three instance orders exit zero in
7.951 guard seconds at 49,070,080 sampled bytes. The final sample records
describe the submitted draw and cannot reconstruct earlier rejected fragments.

The layout proof, AST outputs, Metal inputs and tiles, and guard receipts
are local under `repository-navigation-5204-r99/receipts`.

### Published control before conditional storage

Managed build `20261118-084641-0a9f1f58` publishes executable
`ea5cc7a3d626c8fdef30c81044f1e9a78976d20c1c5726245d8a335b1950bb74`.
Its sealed manifest contains the previous optional-chain implementation.
Hacker News PID 61415 matches the 30 stories and 2× PNG exactly, with six
native hits and zero misses or compiler calls. The guard exits zero in
4.423 seconds at 454,688,768 sampled bytes.

All three fresh GitHub processes match the initial repository, standalone
README and restored repository content in order, using the same original
archive, Brave reference and native cache. All run for 120 seconds with
successful PID adoption and zero browser, replay and guard exits. Shutdown
reports zero native misses or compiler calls, and JavaScriptCore stays
uninitialized. The outer pixel verdict exits 1 for all three.

| Raster policy | PID | Guard seconds | Peak sampled RSS bytes | Native hits / entries | Brave Back pixels different |
| --- | ---: | ---: | ---: | ---: | ---: |
| Ordinary | 65012 | 121.732 | 12,866,600,960 | 3,614 / 1,776,131 | 60,079 |
| Historical raster diagnostic | 73291 | 121.483 | 12,531,957,760 | 3,615 / 1,771,648 | 2 |
| Ordinary repeat | 77292 | 121.590 | 12,428,476,416 | 3,615 / 1,775,190 | 60,079 |

Both ordinary attempts stay under the 12 GiB cap. Their PNGs have the same
SHA-256. The lower peak of the repeat occurs on the same executable.

### Published conditional expression replay

Managed build `20261118-090120-0e59c085` publishes executable
`eb9c83cc14fe48f533dcf68e7dbc3e4c871426aa6aa110d3e65a570d961f22a1`
as one C unit with literal V `-prod`. The frozen manifest verifies all
three conditional-storage implementation files in `53adf12e9`. The
build and headless smoke guards exit zero. The published compiler's C
output reproduces the 704-byte expression, 24-byte tail and one payload
allocation measured in the focused check. Two CPU raster files and
the SVG mask surface also differ from the published control, so the
browser results describe the complete published build.

Hacker News PID 92610 matches all 30 stories and the 2× PNG exactly.
Capture and shutdown record six native hits, zero misses or compiler
calls, and an uninitialized JavaScriptCore runtime. The guard exits
zero in 4.321 seconds at 419,250,176 sampled bytes.

The first ordinary GitHub replay completes the original 120-second input
and matches the repository, standalone README and restored repository
against the ordered Brave controls. PID 98432 is adopted by the guard.
The browser, replay and guard exit zero in 121.947 guard seconds at
11,758,895,104 sampled bytes. The shutdown audit records 3,614 native hits
and 1,773,873 native entries, zero misses or compiler calls, and an
uninitialized JavaScriptCore runtime. The ordinary PNG matches the prior
ordinary Vox capture byte for byte. The comparison with the unchanged
Brave Back PNG differs at 60,079 pixels and exits 1.

The separate raster diagnostic on PID 11350 also completes all three
content checks and the full 120 seconds. The browser, replay and guard
exit zero in 121.484 guard seconds at 10,759,241,728 sampled bytes.
Shutdown records 3,615 native hits and 1,770,586 entries, zero misses
or compiler calls, and an uninitialized JavaScriptCore runtime. Its
PNG has the same decoded RGBA pixels as the published control's
raster diagnostic. The unchanged Brave reference differs at the same
two Notifications corners, `(648, 188)` and `(646, 190)`, with a
maximum channel error of ten. The exact-pixel verdict exits 1.

The ordinary repeat on PID 14955 uses the same executable, archive,
cache and capture settings. It completes the 120-second input with
the same exact content and ordinary PNG. The browser, replay and
guard exit zero in 121.968 guard seconds at 12,672,598,016 sampled
bytes. Shutdown records 3,615 native hits and 1,791,187 entries,
zero misses or compiler calls, and an uninitialized JavaScriptCore
runtime. Both ordinary attempts stay below 12 GiB, with the second
peak 212,303,872 bytes below the cap. Exact Brave Back pixels remain
open in both raster modes.

The build source comparison, audit order, input hashes, guard and exit
receipts, and PNGs for both published builds are local under
`repository-navigation-5204-r99/receipts`.

### Document capture color and raster option controls

The ordinary GitHub Back PNG is sRGB. The unchanged Brave Back PNG
uses Display P3 primaries. On published executable `eb9c83cc…61f22a1`,
each of the following launches reuses the same archive and generated-code
cache, completes all three ordered content checks and runs for 120 seconds
under the same 12 GiB guard. The color-space controls expose no cache
misses, compiler calls or page JavaScriptCore. The browser, replay and
guard exit zero. The outer exact-pixel comparisons exit 1.

| Diagnostic | PID | Capture policy | Pixels different from Brave | Guard seconds | Sampled peak RSS bytes |
| --- | ---: | --- | ---: | ---: | ---: |
| Display P3 only | 21724 | Direct frame | 343 | 121.860 | 12,498,599,936 |
| Display P3 with image and extended paint color | 23580 | Direct frame | 338 | 122.012 | 12,051,185,664 |
| Historical diagnostics with disjoint rectangle batching disabled | 27020 | Direct frame | 6 | 121.836 | 12,519,129,088 |
| Display P3 with direct frame disabled | 40527 | AppKit fallback | 58,570 | 121.864 | 8,395,390,976 |
| Display P3 with render-density PNG decodes and GPU mipmaps | 55720 | Direct frame | 150 | 121.886 | 7,412,432,896 |

The Display P3 only run resolves 59,737 of the 60,079 ordinary
differences and introduces one. The extra image and extended paint color
options resolve seven of the 343 differences and introduce two. The
repository logo and commit avatar account for the two largest remaining
regions. Disabling rectangle batching keeps both Notifications differences
and adds four other button pixels. Enabling render-density decoding and
GPU mipmaps with Display P3 resolves 195 of the 343 differences and adds
two. These are separate diagnostics on the same executable. The ordinary
renderer captures in sRGB.

The old AppKit fallback composites the wide-gamut frame into a generic
RGB bitmap and encodes sRGB, while the direct frame path preserves P3.
Commit `267914943` gives a document-only AppKit fallback the document's
already-selected Display P3 profile before it composites. The PNG encoder
then carries the same profile. The change preserves the ordinary sRGB
document and whole-window fallback contracts.

The focused async capture fixture reproduces the old profile failure under
ARC and MRC. With the fix, both modes pass on sRGB and Display P3, including
the decoded saturated pixel, clipped document dimensions and current raster
density. The guard exits zero in 3.150 seconds at 192,741,376 sampled bytes.
The production type check exits zero in 48.582 seconds at 7,124,762,624
sampled bytes.

Managed build `20261118-092611-8a1f5a34` publishes executable
`abc313c877690171f669481414f33c967376bd88d45f1128596e79e76f749f4a`
as one C unit with literal V `-prod`. The sealed header matches the
commit, and the sealed native input matches the source containing the
committed screenshot entry point and concurrent SVG work. The build
and headless smoke guards exit zero. Hacker News PID 65110 matches
all 30 stories and the 2× PNG with six native hits, zero misses or
compiler calls, and an uninitialized JavaScriptCore. Its guard exits
zero in 3.845 seconds at 413,302,784 sampled bytes.

The ordinary GitHub replay on PID 65267 completes the three exact
content checks and the full 120 seconds. The browser, replay and guard
exit zero in 121.638 guard seconds at 12,721,143,808 sampled bytes.
The final audit records 3,616 native hits and 1,787,501 entries, zero
misses or compiler calls, and an uninitialized JavaScriptCore.
The page emits the same Web Worker fallback advisory as the previous
build. The ordinary sRGB PNG is byte-identical to the prior ordinary
capture and differs from Brave Back at 60,079 pixels.

On the same published build, both Display P3 capture paths complete the
120-second replay, match all three ordered content controls, and exit zero
through the browser, driver and memory guard. Shutdown records 3,615
native hits in each mode with zero misses or compiler calls and an
uninitialized JavaScriptCore. Both PNGs carry the same seven numeric ICC
tags as the unchanged Brave Back reference. The direct and fallback
images match all 786,432 decoded pixels, including the two Notifications
corners. Both differ from Brave at 343 pixels in this P3-only mode. The
old forced fallback differs at 58,570 pixels and exports sRGB.

| Display P3 capture path | PID | Guard seconds | Sampled peak RSS bytes | Native entries |
| --- | ---: | ---: | ---: | ---: |
| AppKit fallback | 66785 | 121.565 | 12,248,432,640 | 1,783,055 |
| Direct frame | 68633 | 121.483 | 10,065,362,944 | 1,778,194 |

The extended native fixture first reproduces a density metadata mismatch
at 2× in both ARC and MRC. Commit `5bfecb2a8` retains the logical size
through AppKit compositing and encodes the 40×16 fallback with the same
pixel-sized metadata as direct capture. The retry verifies the PNG size,
profile, saturated pixel and capture scale in both compiler modes. Its
guard exits zero in 3.117 seconds at 191,299,584 sampled bytes. The
published GitHub runs above exercise the 1× profile fix. The 2× metadata
change is verified by the native fixture.

The pinned commands, source checks, exact audits, PNGs, ICC comparisons
and guards are local under `repository-navigation-5204-r100/receipts`.
Exact GitHub Back parity remains open.

### Sampled PNG decode density in ordinary captures

The diagnostics on published executable `abc313c8…6f749f4a` vary
the existing PNG options independently. Each runs the original 120-second
search, README and toolbar Back input under the 12 GiB guard. The same
archive, native cache and Brave controls are pinned throughout. All three
ordered content checks pass in each run. The browser, replay and guard exit
zero. The cache records zero misses or compiler calls, with JavaScriptCore
uninitialized. All outer pixel verdicts exit 1.

| Display P3 diagnostic | PID | Logo / avatar decode | Differing pixels | Guard seconds | Sampled peak RSS bytes |
| --- | ---: | --- | ---: | ---: | ---: |
| Render-density decodes | 90579 | 60×60 / 40×40 | 284 | 122.167 | 9,163,767,808 |
| GPU mipmaps | 96740 | 30×30 / 20×20 | 343 | 121.789 | 11,926,765,568 |
| Render-density decodes and GPU mipmaps | 1779 | 60×60 / 40×40 | 150 | 121.537 | 11,918,950,400 |
| Larger decodes, GPU mipmaps and document image gamut | 15010 | 60×60 / 40×40 | 131 | 122.307 | 8,822,243,328 |
| Larger decodes, GPU mipmaps and image gamut conversion before filtering | 35431 | 60×60 / 40×40 | 49 | 121.624 | 12,233,768,960 |

GPU mipmaps alone reproduce all decoded pixels of the previous
Display P3 control. Render-density decoding resolves 80 of its
343 differing pixels and introduces 21. Enabling GPU mipmaps on the
larger decodes resolves a further 144 and introduces ten. The paired
image traces show the changed upload dimensions and mipmap mode at
the repository logo and commit avatar draws. Applying the image gamut
first resolves the remaining 82 logo pixels without introducing a
new difference relative to the preceding diagnostic. Eighteen avatar
pixels remain. These controls retain the ordinary color and mipmap
selection policy in production.

Commit `17eff88ad` uses the document's rendering density as a floor
for both sampled PNG draws and their grouped shadow path. A 1× capture
from a 2× document retains the detail available to the live frame.
Equal-density and higher-density captures use their existing raster
extent. The change preserves the current mipmap selection policy.

The guarded fixture exercises the actual sizing entry point with a
native density stub and the real image decode-size selector. The old
ordinary call requests 30×30 for the logo and fails the expected 60×60
assertion. The new call requests 60×60 and gives the 20×20 avatar a
40×40 decode. It also checks equal and higher targets, fractional
density and invalid inputs. The initial probe used production assertion
stripping and is excluded from the result. The successful guard exits
zero in 2.834 seconds at 393,658,368 sampled bytes. The production type
check exits zero in 45.875 seconds at 6,919,143,424 sampled bytes.

Commit `470423ced` retains the full source texture when the live density
requires it and the capture target still minifies it. Both draw paths
select their uploads from the actual target and the rendering-density
floor. The same eligibility checks reject unsupported image dimensions
and targets that would use the existing non-minifying path. The focused
probe reproduces the earlier selector's decline for a 40×30 image in a
16×12 capture of a 3× document. It verifies the 40×30 upload and the
equal-density, invalid and exact-natural-size cases. The fixture guard
exits zero in 2.328 seconds at 371,752,960 sampled bytes. The production
type check exits zero in 40.396 seconds at 7,121,141,760 sampled bytes.

Managed build `20261118-095612-f974a35a` publishes executable
`c758ea483aa8943ec31cdbdbb282e5271c1335c9a5df3c29b37a32cbedfce3a8`
as one C unit with literal V `-prod`. The build and headless smoke guards
exit zero. Its frozen manifest verifies the default density change and
the wide-gamut Retina capture changes. Its browser replays exercise
`17eff88ad`. The full-source follow-up is covered by the fixture and
production type check above. Hacker News PID 43649 matches all 30 stories
and the 2× PNG exactly with six native hits, zero misses or compiler
calls, and an uninitialized JavaScriptCore. Its guard exits zero in
3.881 seconds at 438,304,768 sampled bytes.

Ordinary GitHub PID 43923 completes all three exact content checks and
the 120-second input. The browser, replay and guard exit zero in 121.748
guard seconds at 8,931,196,928 sampled bytes. Shutdown records 3,615 native
hits and 1,787,662 entries, zero misses or compiler calls, and an
uninitialized JavaScriptCore. The ordinary Back PNG differs from Brave
at 60,057 pixels. Compared with the previous published ordinary Vox PNG,
the 304 changed pixels all belong to the repository logo and commit
avatar. They resolve 43 differences and introduce 21.

Display P3 PID 46338 omits the former PNG density override and keeps
GPU mipmaps disabled. Its actual logo and avatar uploads are 60×60
and 40×40. The PNG reproduces the earlier render-density diagnostic
pixel for pixel, with 284 differences against Brave. It completes the
three ordered content checks and exits zero through the browser, replay
and guard in 122.028 seconds at 12,042,600,448 sampled bytes. Shutdown
records 3,615 native hits and 1,775,903 entries, zero misses or compiler
calls, and an uninitialized JavaScriptCore.

With the GPU mipmap switch enabled alongside the default density rule,
PID 56676 reproduces the earlier combined diagnostic pixel for pixel.
The unchanged Brave PNG differs at 150 pixels. The three ordered content
checks pass, and the browser, replay and guard exit zero in 121.915 seconds
at 12,175,769,600 sampled bytes. Shutdown records 3,616 native hits and
1,778,089 entries, zero misses or compiler calls, and an uninitialized
JavaScriptCore.

The same published build also contains the earlier Retina metadata fix.
Two fresh local-file captures on PIDs 68096 and 68114 produce 768×520
Display P3 PNGs at 2×, with identical ICC numeric tags, no explicit
resolution override, and all 399,360 pixels equal. The direct capture
logs the frame-copy path and the fallback disables it. Both browser exits
and the guard exit are zero in 1.225 seconds at 216,383,488 sampled bytes.
The first readiness wait expired before a matching bundle published.
A subsequent literal-HTML launch hit the existing missing-origin check
for `about:srcdoc` before capture. The successful retry uses identical
local-file input in both paths.

The exact audits, source pins, guard and exit receipts, upload traces,
and PNG comparisons are local under `repository-navigation-5204-r101/receipts`.
The ordinary capture and the isolated PNG diagnostics still differ from
the unchanged Brave Back reference.

### Destination-gamut PNG filtering and shared avatar samples

Commit `6532894f0` selects the sampled PNG color path from the actual
Display P3 raster and renderer support. The PNG source converts to the
destination encoding before mip generation and filtering. Conversion,
blending and the shadow or glyph backdrop keep their existing ownership.
The selected color path follows the raster automatically when it is
Display P3. The ordinary sRGB PNG replay remains the distinct sRGB path.

A focused image test uses two saturated source colors that become the
same red after the gamut transform. Filtering the source first produced
a red channel of 175 where destination-space mip levels produce 255.
The control fails that assertion. The replacement passes the image,
shadow and glyph tests in both GC modes. The guards exit zero in 18.994
and 23.227 seconds, at 798,621,696 and 788,250,624 sampled bytes. The
production type check exits zero in 48.642 seconds at 7,128,121,344
sampled bytes.

The three controls below use published executable `c758ea48…dfce3a8`
with the same 120-second original GitHub replay, generated-code cache,
and Brave reference. Their three content snapshots match in order.
The browser, replay and guard exit zero. Cache shutdown has zero misses
or compiler calls, and JavaScriptCore remains uninitialized.

| Display P3 diagnostic | PID | Brave pixels different | Guard seconds | Sampled peak RSS bytes |
| --- | ---: | ---: | ---: | ---: |
| Destination gamut before filtering and GPU mipmaps | 72452 | 49 | 121.697 | 12,380,225,536 |
| Also retain scaled PNG shadows in the same draw | 74136 | 32 | 121.760 | 10,211,115,008 |
| Also retain overlapping text in that draw | 78888 | 31 | 122.230 | 11,918,278,656 |

The first control is pixel-identical to the prior 49-pixel diagnostic.
The shadow grouping changes exactly 17 commit avatar pixels and resolves
all 17. Sharing the text resolve fixes the final avatar pixel. The
repository logo remains exact across all three captures. The original
Brave screenshot still differs at 31 pixels outside those image regions.

Commit `ae6f0ece9` enables the same scaled grouping on an active 1×
Display P3 raster with image-gamut support. A following text leaf shares
the resolve only when the existing ownership, effect, clip and overlap
checks accept it. The focused fixture runs both real paint classifiers
against the avatar page and stubs the native target as sRGB, 1× P3 and
2× P3. Only 1× P3 accepts the scaled group. Rotated, separately clipped
or differently owned leaves retain their existing handling.

The first fixture assembly interpolated its temporary source path
incorrectly. The combined compile-and-run retry reaches the 3 GiB guard
during compilation. Compiling separately under the 12 GiB guard exits
zero in 39.926 seconds at 4,749,180,928 sampled bytes. The actual test
exits zero under 3 GiB in 0.390 seconds at 34,750,464 sampled bytes.
The production type check exits zero in 46.558 seconds at
7,125,843,968 sampled bytes.

Managed attempt `20261118-102332-8d08d02c` seals the gamut change
and the full-source PNG sizing follow-up, and passes build and smoke.
Its publication is superseded while the canonical bundle has a reader.
Attempts `20261118-103624-9cddba7e` and `20261118-103933-893fb333`
stop during sealing when the shared native SVG mask image header
changes. The managed worker retries the combined source before
windowed verification.

Managed build `20261118-104445-4bbc3f6d` publishes executable
`8449e53002c6c57ed747712cf39421572993bd0986565d5cb6b0224131ba17b1`
as one C unit with literal V `-prod`. Its sealed sources include both
Display P3 changes and commit `470423ced` for full-source PNG sizing.
The build and headless smoke guards exit zero in 381.170 and 0.931 seconds
at 8,939,290,624 and 139,001,856 sampled bytes.

Hacker News PID 67420 matches all 30 stories and the 2× PNG exactly with six
native hits, zero misses or compiler calls, and an uninitialized JavaScriptCore.
Its guard exits zero in 4.511 seconds at 421,052,416 sampled bytes. Ordinary
GitHub PID 72689 completes the 120-second input and all three ordered content
checks. The browser, replay and guard exit zero in 122.010 guard seconds at
9,085,714,432 sampled bytes. Shutdown records 3,613 native hits and 1,771,262
entries, zero misses or compiler calls, and an uninitialized JavaScriptCore.
The comparison exits 1 because the ordinary Back PNG still differs from the
unchanged Brave Back reference at 60,057 pixels. It is pixel-identical to
the preceding ordinary Vox capture.

Two Display P3 runs on that executable were interrupted before the guard
and PNG receipts completed. The next publication, `20261118-105928-fdc9266b`,
contains all seven pinned color, image and grouping sources in another
single-C `-prod` executable. Its SHA-256 is
`91ba43479fe10028a5e83fd9e951193f84d28934cd3ee97cb572dc5a58b8e301`.
The following replays complete the three ordered content checks and the
120-second input. Both Vox processes and both replay guards exit zero. The
comparisons exit 1 for the remaining pixels.

| Capture | PID | Brave pixels different | Guard seconds | Sampled peak RSS bytes | Native cache hits | Native entries |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Display P3 with GPU mipmaps | 33439 | 31 | 121.752 | 12,254,691,328 | 3,614 | 1,770,923 |
| Full raster diagnostic | 37910 | 2 | 121.566 | 12,427,591,680 | 3,616 | 1,775,146 |

Both replays record zero misses or compiler calls and an uninitialized
JavaScriptCore. The first capture uses the gamut and grouping behavior by
default on its P3 target, and matches the prior shadow-and-text diagnostic
pixel for pixel. The repository logo and avatar both match Brave. The full
raster diagnostic still differs at viewport coordinates `(648, 188)` and
`(646, 190)`.

A separate local-page capture on PID 42452 exercises the full-source PNG
selection in the published browser. It traces a 40×30 source decoded at
40×30 and drawn at 16×12 from a 3× layout into a 1× Display P3 PNG. The
browser and 3 GiB guard exit zero in 0.857 seconds at 220,971,008 sampled bytes.

### GitHub repository launch timing against Brave and V8

`tools/benchmark_github_page.py` runs the archived `github.com/vlang/v`
repository in fresh browser processes with 1024×768 document viewports,
fresh HTTP caches and profiles, original-origin replay, and OS caches retained.
The comparison covers process launch, window setup, author-script hydration,
a one-second settle, document PNG and audit collection, and process exit. It uses
the published Vox executable above, the [verified Clang `-O2` native cache](LIBJS_NATIVE_CODE.md),
and Brave with V8 `15.7.112.43`. `--raster-parity-options` is explicit for Vox.
The timing includes each browser's DOM, rendering and capture pipeline. The
separate [Hacker News 500-cycle benchmark](HACKER_NEWS_LIBJS_RAM.md#measurement-boundaries)
times repeated synchronous comment collapse and expand through Vox's script
and DOM integrations. The Hacker News total sums initialization, the first
audited cycle, the next 500 cycles and the compile/cache-finish checkpoint.

The first LibJS process exceeds the 35-second deadline and is terminated
with exit `-15`. Its paired Brave run exits zero in 2.510 seconds. The other
six alternating pairs pass their content and unchanged input checks. All
completed LibJS launches record 2,948–2,949 native cache hits, zero misses
and zero compiler calls. Their PNGs each differ from the Brave
reference at two pixels. All completed Brave PNGs match the reference exactly.
Both engines reproduce their own screenshots across their completed runs.

| Browser and JavaScript engine | Median launch through exit | Completed-pair range | Median observed instructions |
| --- | ---: | ---: | ---: |
| Vox with cached native LibJS | 7.430 s | 6.991–9.708 s | 66,629,943,185 |
| Brave with V8 | 2.202 s | 2.175–2.364 s | 20,629,279,943 |

The median LibJS browser run takes 3.375× as long on the six completed pairs.
The sampled process-tree instruction counts are lower bounds and exclude GPU
and external-service work. The seven-pair cohort is incomplete, and the
comparison makes no isolated engine-speed or optimization acceptance claim.
The guard adopts all 14 browser roots and records 127.366 seconds and
6,750,683,136 sampled peak RSS bytes. The controller and guard exit 1 for the
incomplete cohort. The paired statistics, all attempts, input identities and
raw command, audit and exit receipts are local under
`repository-navigation-5204-r102/receipts`.

### Whole-pixel placement of the Notifications rectangle draw

Commit `a4fe3c594` lets `tools/replay_metal_rectangle.m` replay a viewport
inside a larger target specified by `draw.target_size`. Viewport coordinates
and scissor bounds remain in target space and are recorded in the receipt.
Legacy snapshots still use the viewport dimensions as the target extent.
Both original 1,024×256 selected-draw tiles reproduce their full BGRA hashes.
Seven malformed or out-of-bounds viewport and target combinations decline
without publishing. A 1,056×288 sample capture reproduces the uninstrumented
color output and reports four records per target pixel. Its guard exits zero
in 0.578 seconds at 65,257,472 sampled bytes. The automated regression suite
remains held.

The first experiment compares the captured and document instance orders at
61 integer translations on the original 1,024×256 target. It keeps the
captured shaders, depth state and indices. The zero-offset controls reproduce
the full original tiles and differ at the two Notifications corners. The
button crops differ by two pixels at 39 placements, three at 11, and one at
10. At `(3, -3)`, the two normalized crops agree, but six other pixels differ
from the untranslated captured control. The guard exits zero in 6.235 seconds
at 111,771,648 sampled bytes.

The second experiment compares Metal viewport offsets with equivalent
whole-pixel instance translations at 61 placements on a 1,056×288 target.
For both instance orders the two translation methods produce identical
normalized crops at every position. The two draw orders agree at 13 positions,
and each of those crops differs from the original captured control at one
or more pixels. The unchanged shaders can therefore reproduce the placement
sensitivity without changing their instance transforms. All 244 offset draws,
both legacy controls and the seven rejection checks complete. The final guard
exits zero in 14.449 seconds at 93,831,168 sampled bytes. A strict compiler
attempt fails on the existing `fastMathEnabled` deprecation. The successful
retry keeps the deprecation as a warning and treats other warnings as errors.

These selected draws use a white backdrop and omit the rest of the page.
Raster translation alone supplies no parity fix.

A fresh 120-second full raster replay uses the latest completed single-C
`-prod` browser from `20261118-111945-4ed1a3a8`, executable SHA-256
`d712e8563c55161e84b9994da2ce30bff71c80811739537959f6f708276bbaa2`.
PID 92369 matches the original repository, the standalone README, and the
repository after native toolbar Back. Shutdown records 3,613 native hits,
1,770,686 native entries, zero misses or compiler calls, and an uninitialized
JavaScriptCore. The browser, replay and guard exit zero in 121.950 guard
seconds at 12,661,260,288 sampled peak bytes. Its decoded RGBA matches the
previous published full raster capture. The unchanged Brave reference still
differs at the same two Notifications corners, with maximum channel error
ten. The exact comparison exits 1.

The Metal inputs and raw guards, source and executable identities, and
ordered browser receipts are local under `repository-navigation-5204-r103/receipts`.

### Grouped LibJS startup and the PNG availability endpoint

The [matched grouped-cache comparison](LIBJS_NATIVE_CODE.md#full-archived-vlangv-cache-build-and-reopen)
uses seven alternating pairs on publication `7a17002a…15e5`. Grouping the
same optimized LibJS cache reduces median startup-through-encoding instructions
from 72,930,654,754 to 64,325,501,618, an 11.80% reduction. Median cache load
time falls from 218.36 to 135.01 ms. Both measures improve in all seven pairs.

A separate seven-pair launch-through-exit comparison uses that same Vox
publication, the grouped Clang `-O2` cache and Brave's V8 `15.7.112.43`.
It retains all attempts. All seven Vox launches pass the content and cache
checks. Brave has two teardown watchdog exits and one timeout. The remaining
Brave captures vary between zero and 11 pixel differences from the pinned
reference. The first failed Brave launch had no PNG fingerprint, so the
then-current harness skipped fallback stability checks for later Brave runs.
The controller and guard exit 1 after 276.134 guard seconds at 6,646,661,120
sampled peak RSS bytes. This incomplete cohort supplies no speed ratio.

Commit `9381fb19a` records observed PNG availability for both browsers
separately from launch through exit. Brave's endpoint includes CDP transfer
and its output file write. Vox's endpoint is the first completed PNG observed
during exit polling. The driver now compares each valid capture against its
engine's first valid capture even after an earlier failure. Eleven focused
Python tests pass.

One matched validation pair on `7a17002a…15e5` uses fresh private profiles,
original-origin replay, the one-second settle and the raster diagnostic
settings from the previous Brave comparison. Both browser exits and the
guard exit are zero. The guard adopts PIDs 77007 and 77997 and records
35.463 seconds at 6,627,409,920 sampled peak RSS bytes.

| Browser | Launch to observed PNG | PNG to exit | Launch through exit |
| --- | ---: | ---: | ---: |
| Vox with grouped compiled LibJS | 10.163 s | 164.140 ms | 10.327 s |
| Brave with V8 | 2.737 s | 112.324 ms | 2.849 s |

The LibJS visit records 2,948 native hits and zero misses or compiler calls.
The timing gap is already present at PNG availability. This pair validates
the endpoints and includes browser startup, script hydration and rendering.
It supplies neither a seven-pair timing result nor isolated JavaScript time.

Two instrumented archived-page visits record 477,109–479,732 native entries,
13.09–13.19 million native fast steps and 4.99–5.02 million slow steps. Both
reopen the grouped cache with zero misses or compiler calls. Both stack
samplers exit zero but produce empty call graphs. The counters establish
native and helper execution, with no per-function time attribution.

A candidate removes generic array access from the native entry cache's
positive lookup using the existing fixed slot mask. Two focused binaries
execute the same 480,000-call script with the same warmed native library.
Both diagnostic visits return 7,920,000 and record 479,999 entry-cache hits.
The seven uninstrumented process pairs return the same value with three
native cache hits and zero misses or compiler calls. Their median retired
instructions are 5,183,694,633 before and 5,180,039,512 with the candidate.
The 0.07% median difference and three regressed pairs supply no reliable
gain. The candidate is reverted. The paired guard exits zero in 17.354
seconds at 292,749,312 sampled peak RSS bytes.

The raw timings, rejected attempts, guard exits, profiles, source diff and
pinned inputs are local under `github-performance-5204-r104/receipts`.

### Main-thread instruction attribution on archived GitHub

One instrumented pair on production executable
`68ca9b1d3eb7d53f34a3ff919e92148795e21bff42150bcc5e993efd7f2ba629`
uses the standard 1024×768 Vox capture, frozen original-origin replay and a
one-second settle. It enables the existing nested process and main-thread
instruction scopes and uses the exclusive Vox coalition through native PNG
encoding. Both visits fulfill all 81 modules, pass the complete repository
audit, and reproduce the pinned Vox PNG. The compiler-disabled grouped
LibJS visit records 2,948 cache hits, 480,343 native entries and zero misses
or compiler calls. Both browser exits and the guard exit are zero. The
guard adopts both browser processes and their helpers, and reports 40.084
seconds at 6,622,232,576 sampled peak RSS bytes.

| Exclusive main-thread scope | Interpreted LibJS | Grouped compiled LibJS |
| --- | ---: | ---: |
| Existing JavaScript execution and bindings | 8,327,291,850 | 9,267,347,154 |
| Posted-message task self work | 10,642,133,994 | 9,832,317,544 |
| Flow layout | 9,699,563,636 | 10,968,674,753 |
| SVG paint leaves | 8,993,423,757 | 5,982,397,892 |
| All main-thread instructions through encoding | 72,800,057,702 | 69,771,420,218 |
| Exclusive resource coalition through encoding | 78,840,066,887 | 74,697,744,887 |

The JavaScript scope on this executable covers explicit source entry, while
LibJS event listeners can enter the VM from a posted-message task and modules
can be parsed, linked and evaluated from a fetch callback. The posted-message
row includes all of its remaining self work and cannot be assigned entirely
to JavaScript. Frame and SVG paint counts differ across the pair, and tracing
adds overhead. This pair supplies attribution evidence only.

Two earlier receipts preserve preflight failures. The first specifies a
reference path that was no longer present. The second still inherits ambient
proxy variables and starts no browsers. The successful diagnostic uses the
retained grouped-cache PNG and a clean environment with its explicit replay
route.

Commit `a797cd0ce` attributes LibJS event listener calls and async module
evaluation to the existing JavaScript execution and bindings scope. The
calling-thread stream also reports separate `libjs_module_frontend` and
`libjs_module_link` scopes. These counters use the existing main-thread
nesting rules, so parent self work excludes the new children. The hooks
are inactive in ordinary runs. This addresses the attribution gap without
changing the interpreter, generated code, or archived workload.

The single-C production type check exits zero in 226.841 guard seconds at
7,148,257,280 sampled bytes. Both focused `processmetrics` tests pass with
the process and thread counters enabled, covering nested JavaScript scopes,
counter state restoration, and worker exclusion. Their guard exits zero
in 3.010 seconds at 748,830,720 sampled bytes. The full standalone module
and message callback binaries do not complete. The first tool launch
omits Objective-C mode, the FastC attempt reports C emission errors, and
two explicit C-backend attempts reach their 12 GiB sampled guard, at
12,889,178,112 and 12,988,989,440 bytes. Those attempts supply no runtime
verification of the new browser entry scopes.

The current publication predates both modified sources. The managed
post-commit worker has the rebuild request, and the new archived-page
breakdown is pending a publication that seals both source hashes. Raw stage
streams, input pins, preflight failures and guarded checks are local under
`github-stage-attribution-5204-r105/receipts`.

### Published LibJS callback and module attribution

Managed build `20261118-120526-3448b376` publishes single-C V `-prod`
executable `4e0651cd258ad071ef21997e56960622c0fda2e75b26b0efa3870f08be6ec452`.
The frozen manifest matches both files in `a797cd0ce` and all 17 native
cache ABI sources in the predecessor. Compilation and headless smoke exit
zero. A fresh instrumented interpreter/compiled pair uses the same archive,
viewport, capture reference and one-second settle as the earlier trace.
Both content audits and PNG checks pass. The compiler-disabled grouped
visit records 2,949 hits, 476,289 native entries, zero misses or compiler
calls, and all 81 modules complete. Both browser and guard exits are zero.
The guard adopts both browser processes and their helpers, and samples a
peak of 6,523,813,888 bytes. The guard's 238.942 seconds include waiting
for publication and the two launches.

| Main-thread instruction scope | Interpreted LibJS | Grouped compiled LibJS |
| --- | ---: | ---: |
| JavaScript and bindings self work | 14,516,612,393 | 14,549,470,750 |
| JavaScript self work inside posted-message tasks | 10,632,357,097 | 9,762,068,776 |
| Posted-message task self work | 9,392,292 | 10,480,592 |
| LibJS module frontend self work | 7,374,477,032 | 7,329,509,667 |
| LibJS module linking self work | 221,219,132 | 253,184,471 |

The posted-message JavaScript row is a subset of the JavaScript and
bindings row. The earlier trace exposed zero such scopes under those
tasks. The published hooks expose 44 in the interpreter visit and 49 in the
compiled visit, accounting for almost all of the previously unattributed
posted-message work. The frontend scope runs 81 times in each browser and
includes source-cache lookup, parsing and native template bookkeeping.
These instrumented main-thread counts locate work on this page. There is
one pair, and its tracing adds overhead.

Commit `eb8628f3a` defers building the module fetch `TypeError` and its
stack until there is no module to deliver. A focused regression covers
both the fulfilled namespace and the exact rejection type and message.
The production type check exits zero in 113.009 guard seconds at
5,247,975,424 sampled RSS bytes. Two standalone test build attempts reach
the 12 GiB guard during compilation, so the new test has yet to execute.
A fresh loopback control on `68ca9b1d…a629` verifies the HTTP 200 namespace
and the HTTP 404 rejection in 1.148 guard seconds at 343,048,192 sampled
bytes. The first control's browser exits zero and its document audit
passes, but the controller reads the wrong audit field and exits 1. The
corrected control exits zero. Browser verification and timings for the
allocation change await the managed publication.

Raw stages, launch and input pins, build and guard receipts, and both
loopback attempts are local under `github-libjs-module-5204-r106/receipts`.

### Frontend cache cost on fresh GitHub launches

Four fresh launches on `4e0651cd…c452` use the same archived `vlang/v`
page, warmed grouped native cache, 1024×768 capture and one-second settle
as the preceding diagnostic. The order is frontend cache on, off, off, on.
All 81 modules complete on each visit. The full content and pinned Vox PNG
checks pass. Each visit reuses 2,948–2,950 native entries with zero cache
misses or compiler calls. The guarded controller and all browser exits are
zero. The guard adopts all four browser processes and their helpers and
records 60.124 seconds at 6,636,945,408 sampled RSS bytes.

| Launch | Frontend hits / misses | Function bytecode compilations | Module frontend main-thread instructions | Coalition instructions through PNG encoding |
| --- | ---: | ---: | ---: | ---: |
| On | 20 / 83 | 4,170 | 7,276,764,461 | 79,440,182,356 |
| Off | 0 / 103 | 4,171 | 7,039,107,205 | 77,666,669,865 |
| Off | 0 / 103 | 4,170 | 7,039,841,588 | 72,139,120,905 |
| On | 22 / 83 | 4,170 | 7,278,971,889 | 74,004,640,036 |

The enabled cache has 83 misses in both fresh processes and the browser
still generates function bytecode even with a warm machine-code cache. The
81 module frontend calls retire 3.38–3.40% more instructions with the old
cache enabled in these pairs. This scope includes cache lookup, parsing and
module template bookkeeping. Tracing is enabled and the 18-CPU host's
one-minute load ranges from 10.52 to 15.41 during these observations. The
result locates cache overhead during launch and leaves reload behavior open.

The retained preflight attempts rejected inherited `NO_PROXY` and `no_proxy`
before launching browsers. The next cohort's first browser exited zero, but
its last coalition log record was truncated while the filesystem filled.
The controller and guard exit one for that incomplete cohort. Its other
three visits pass. The complete four-launch cohort above started again
with the same pinned inputs and protocol after free space recovered.

Commit `9c42c5c64` replaces two SHA-256 operations with a noncryptographic
index for this process-local cache. Both reuse paths verify the full source
bytes. The partition, script kind and parser depth remain part of the key.
A focused regression injects a collision and verifies that the caller
receives syntax for its own source. The production type check exits zero in
30.591 seconds at 5,242,552,320 sampled bytes. The regression awaits execution.

A guarded V `-prod` key-construction benchmark uses 87 hash-verified archived
JavaScript responses totaling 5,249,778 bytes. Three alternating process
pairs each sweep the files 64 times. Median key construction is 2,325.58 ms
for the previous pair of SHA-256 operations and 83.11 ms for the new index,
about 36.34 and 1.30 ms per sweep. Compilation, I/O, source comparison on
cache hits, parsing and browser launch are outside this timed region.

The last published executable used for this diagnostic predates `eb8628f3a`
and `9c42c5c64`. Three managed attempts (`123127-a3e610d1`, `124306-3814ee84`,
and `125113-925c0bbf`) fail while writing generated C or sealed compiler
inputs because the filesystem is full. A later request is pending. Runtime
validation and an end-to-end timing for both changes await a publication
with their exact source hashes. Commands, input pins, guard reports, raw
attempts and build errors are local under
`docs/benchmark-results/github-frontend-5204-r107/receipts`.

### Standalone preparation of the 81 GitHub modules

The published browser's audit identifies 81 evaluated and fulfilled modules.
Their 81 distinct archived responses match the manifest and total 5,088,368
bytes. That exceeds the process-local frontend cache's 4 MiB source-byte
limit by 894,064 bytes, before inline scripts. Full retention of the module
set is impossible at that limit. The audit does not establish the hit rate
on reload.

A standalone V `-prod -prealloc -gc none` executable parses those exact
responses as modules at the browser's depth limit of 256. File reads and
diagnostic inspection stay outside the timed intervals. All 81 modules
parse without diagnostics or recursion-limit failures in each fresh process.
The 18-CPU host's one-minute load is 10.00 during the three attempts. The
executable SHA-256 is
`7b2a58eca163a54bee79b7baa746bb15aa6bcfb466bee186adafee3180d81f6f`.

| Attempt | Main-thread frontend instructions | Summed frontend time |
| --- | ---: | ---: |
| 1 | 7,111,911,488 | 640.370 ms |
| 2 | 7,101,116,915 | 648.349 ms |
| 3 | 7,099,606,451 | 651.707 ms |

The interval covers UTF-16 conversion, parsing and lexical-scope analysis.
It has the same order of magnitude as the 7.28-billion-instruction frontend
scopes in the published browser, with a separate executable and fixed source
order. `code-view-5d65cb0f8c6bfda9.js` accounts for 1,812,989,787 median
instructions, or 25.5% of the standalone median total. The five largest
instruction counts account for 59.1%. Browser launch, linking, bytecode
generation and JavaScript execution are outside the standalone intervals.
The [separate seven-pair GitHub comparison](LIBJS_NATIVE_CODE.md#recovered-group-against-brave)
on `4e0651cd…c452` records median PNG availability of 9.186 seconds in Vox
and 2.434 seconds in Brave. Those browser measurements retain startup,
author-script hydration and rendering.

The 3 GiB guard exits zero at 32.310 seconds and 2,970,959,872 sampled RSS
bytes for the compile and three runs. Two earlier attempts fail due to full
disk during C staging and during Clang's object output, respectively. The
retained attempts identify both failures.

The standalone cache probe for `9c42c5c64` compiled and exited zero with LibJS
and a minimal host. It used `-prod`, which removes V assertions. The zero
exit established execution, while the assertions needed the separate
assertions-enabled retest below. The full `browserjs` regression build fails
while writing generated C on the full filesystem.

Managed attempt `20261118-125756-22ae8668` also fails with no space while
sealing `Vox.c.i`. The successful production publication still predates both
`eb8628f3a` and `9c42c5c64`, so browser runtime validation and matched timing
of those changes remain pending. Receipts and probe sources are local under
`docs/benchmark-results/github-frontend-5204-r108/receipts`.

### Keyword lookup in the GitHub lexer workload

Commit `3f45845b7` compares the lexer’s UTF-16 input directly with ASCII
keyword spellings. The unescaped path passes its source slice straight to
the lookup. A focused regression exercises ordinary, escaped, non-ASCII
and longer identifiers alongside keyword and literal tokens. It runs with
assertions enabled and exits zero under the 3 GiB guard.

Seven alternating fresh-process pairs use the standalone C-backend V
`-prod -gc none` lexer on the same 81 GitHub module files. The baseline
and candidate use the repository's lexer, Unicode tables and UTF-16
utilities. `libjs/lexer.v` is the only changed compiled source. All 14
exits are zero. Each visit emits 1,938,155 tokens and reproduces the
per-file checksums of token types, offsets, trivia, decoded identifiers
and messages. The timing includes lexer work and the checksum calculation.
It starts after reading the files and decoding each one to UTF-16. The
standalone lexer uses its default slash disambiguation.

| Median | Baseline | Candidate | Reduction |
| --- | ---: | ---: | ---: |
| Lexer instructions across 81 files | 1,954,238,411 | 1,078,240,652 | 44.83% |
| Summed lexer intervals across 81 files | 93.773 ms | 55.866 ms | 40.42% |
| Lexer instructions for `code-view-5d65cb0f8c6bfda9.js` | 406,543,184 | 235,295,176 | 42.12% |

Every pair improves. The 18-CPU host's one-minute load is 8.30, and the
cohort guard exits zero in 1.718 seconds at 168,984,576 sampled RSS bytes.
An earlier candidate's local slice assignment triggered a compiler notice
about an implicit copy. Its checks and timings are retained separately.
The final candidate's direct slice argument clears that notice. Full-parser
control builds failed on disk writes. The reported gains cover the lexer
alone, and production browser timing remains pending.

The assertions-enabled cache retest uses the exact code from `9c42c5c64`
with a minimal parsed-source record and platform stub. It verifies exact
source reuse, a forced hash collision and independent cache partitions.
The test binary and 3 GiB guard exit zero in 1.354 seconds at 242,188,288
sampled RSS bytes. The full browser regression still awaits a production
build. Receipts, source pins and harnesses are local under
`docs/benchmark-results/github-lexer-5204-r109/receipts`.

### Prepared LibJS script source ownership

Commit `76c3de3ff` lets a prepared LibJS script keep the parser's persistent
source buffer. This removes one copy of the script body. The prepared
script owns the URL used in diagnostics and execution metadata.

A focused executable uses the browser's cache and preparation functions,
the LibJS parser and the real preallocation arena with a minimal host. It
passes the forced cache-collision check, verifies buffer sharing with the
frontend cache enabled and disabled, and reads the original Unicode source
after releasing its input arena. Both its compile and runtime guards exit
zero. The complete `browserjs` regression file passes the production type
check in 25.454 guard seconds at 5,219,123,200 sampled peak bytes.

The full regression binary build stops while writing generated C on the
full filesystem. Runtime verification on the archived page awaits a
production publication containing the change. The focused fixture,
commands and guard receipts are local under
`docs/benchmark-results/github-frontend-5204-r107/receipts`.

### ASCII identifier runs in LibJS

Commit `ba4522f10` advances consecutive ASCII identifier characters in one
scan and leaves the following character for the existing Unicode and escape
handling. The focused regression checks a supplementary code point, an escape,
CRLF, a private identifier, the next token's column and end of input. It runs
with assertions enabled and exits zero under the 3 GiB guard.

Seven alternating pairs use the 81 pinned GitHub modules. The minimal lexer
runs match all per-file token checksums. The full-parser runs use identical
V `-prod -prealloc -gc none` settings and succeed on all 81 modules in each
fresh process, with no diagnostics or recursion-limit failures. Both controls
already include the keyword optimization in `3f45845b7`. The matched build
inputs differ in `libjs/lexer.v`.

| Median | Baseline | ASCII runs | Reduction |
| --- | ---: | ---: | ---: |
| Standalone lexer instructions | 1,078,476,835 | 949,488,475 | 11.96% |
| Standalone lexer intervals | 64.263 ms | 58.616 ms | 8.79% |
| Full frontend instructions | 6,830,150,220 | 6,675,589,585 | 2.26% |
| Full frontend intervals | 587.254 ms | 576.603 ms | 1.81% |

All 14 launches in each cohort exit zero. Every pair retires fewer
instructions. Two full-frontend elapsed-time pairs regress. The full
frontend includes UTF-16 decoding, parsing and lexical scope analysis.
The full-frontend guard exits zero in 9.827 seconds at a sampled peak
of 2,624,225,280 bytes. One-minute host load is 6.48–6.52 on 18 CPUs.
An earlier compile found the lexer-only module through the benchmark
directory. The matched parser build uses the canonical LibJS package.

The separate attempt to measure the earlier keyword-only change through
the full parser uses the historical lexer source and the current canonical
LibJS dependencies. A separate-file control fails module resolution. The
module overlay type-checks, and its later compile attempts stop on the full
filesystem while assembling embedded resources. The 44.83% keyword result
above remains a lexer measurement.

The latest published browser still predates both lexer changes. Managed
rebuilds continue to fail on disk writes, so the standalone cohorts leave
the page-render timing open. Build identities, all attempts and guard
receipts are local under
`docs/benchmark-results/github-identifier-5204-r110/receipts`.

### Full-frontend keyword comparison and ASCII source conversion

The earlier keyword change in `3f45845b7` now has a full-frontend
comparison on the same 81 pinned modules. The control builds share the
canonical LibJS dependencies and use the two exact lexer versions from
Git. Compiler source manifests differ only in the lexer. With limited disk
space, both builds use Clang `-O2` with V's development mode and
`-prealloc -gc none`. Development mode reads resource files at runtime
and avoids embedding their payloads into the executable.

Seven alternating fresh-process pairs complete all 81 modules without a
diagnostic or recursion-limit failure. Median instructions fall from
8,024,481,796 to 7,342,744,816, an 8.50% reduction. Median elapsed
frontend time falls from 693.109 to 663.379 ms, with five pairs faster.
Host one-minute load is 11.75–12.16 on 18 CPUs. The guard exits zero in
11.094 seconds at 2,630,434,816 sampled RSS bytes. This interval includes
UTF-16 decoding, parsing and lexical scope analysis.

Commit `14c08fd53` widens ASCII script bytes directly into the parser's
UTF-16 input. It retains the existing decoder for sources containing
non-ASCII bytes. The regression passes with assertions enabled for empty
input, ASCII control characters and NUL, Unicode supplementary characters,
and malformed bytes. The guard exits zero.

Eighty archived modules are entirely ASCII and total 4,632,522 bytes.
The remaining module brings the workload to 5,088,368 bytes. In seven
alternating fresh-process conversion pairs, every file produces the same
code-unit count and checksum in both modes. The timed intervals cover
conversion and exclude file reads and checksum computation.

| Benchmark and median | Control | ASCII widening | Change |
| --- | ---: | ---: | ---: |
| Standalone conversion instructions | 263,694,090 | 53,121,169 | −79.86% |
| Standalone conversion intervals | 14.255 ms | 4.049 ms | −71.60% |
| Full frontend instructions | 7,377,007,076 | 7,173,729,973 | −2.76% |
| Full frontend intervals | 613.705 ms | 623.934 ms | +1.67% |

The full-frontend pair uses the same Clang `-O2` development build
and lexer from the keyword comparison. Compiler input digests show only
the frontend integration and its new conversion source differing.
All 14 processes parse the 81 modules successfully. Every pair uses fewer
instructions, and three pairs have shorter elapsed intervals. One-minute
load is 9.36–9.51. The guard exits zero in 9.831 seconds at 2,578,825,216
sampled RSS bytes. Two independent attempts to compile a canonical control
stop on full-disk errors. The matched results above use the completed
keyword control.

The production publication still predates the lexer and source-decoding
changes. Recent managed rebuilds continue to encounter disk exhaustion.
Page-render timing with these changes is pending. Compiler input digests,
all timed attempts and regression receipts are local under
`docs/benchmark-results/github-keyword-parser-5204-r111/receipts`.

### Scope rollback and label lookahead

Commit `c2bbfe8a0` trims discarded child scopes in place. Scope records
are appended in index order, so rollback can remove the discarded suffix
and keep the live prefix and its storage. The regression starts with a
retained child, adds two speculative children on each iteration, and
checks the restored tree, flags, diagnostics and storage. The same test
executable evaluates the repeated parenthesized-expression fixture.

Commit `e9694a165` uses lexer lookahead to establish the colon before
parsing a label. Ordinary identifier-led expressions avoid saving parser
and scope state and constructing a label string. Reserved-word and
contextual-label checks pass, along with a fixture that has expressions
before and after a label with comment and newline trivia. Both test
executables run with assertions enabled and exit zero.

Each comparison uses seven alternating fresh-process pairs over the 81
pinned GitHub modules. The binaries use Clang `-O2`, V development mode
and `-prealloc -gc none`. The consumed-source manifests differ only in
`scope_collector.v` for rollback and `statements.v` for label lookahead.
All 28 processes parse every module without diagnostics or recursion-limit
failures. The label comparison uses the completed scope-rollback binary
as its control.

| Comparison | Control instructions | Candidate instructions | Median elapsed |
| --- | ---: | ---: | ---: |
| Scope rollback | 7,199,395,759 | 7,185,142,707 | 737.278 → 768.584 ms |
| Label lookahead | 7,034,554,233 | 7,017,361,502 | 647.501 → 640.255 ms |

Scope rollback uses 0.20% fewer median instructions, with all seven pairs
improving in instructions and four improving in elapsed time. Label
lookahead uses 0.24% fewer median instructions, with six pairs improving
in instructions and five improving in elapsed time. One-minute host load
ranges from 10.67–10.81 for scope rollback and 8.79–8.86 for label
lookahead. Their 3 GiB guards exit zero at 2,519,760,896 and 2,588,704,768
sampled peak bytes, respectively. The timings cover source conversion,
parsing and scope analysis.

The current production publication predates both changes. Managed build
receipts still show disk-space failures. Browser rendering validation is
pending. Pinned build inputs, initial build and regression attempts,
and timed trials are local under
`docs/benchmark-results/github-scope-5204-r112/receipts`.

### Expression identifier storage

A separate two-second stack sample of the baseline parser records 1,571
main-thread snapshots, including 1,324 in the intentional sleep intervals
used to attach the sampler. It records 83 snapshots with
`_platform_memmove` at the top of the stack. Expression construction,
array growth and scope analysis all appear on copying paths. The sampler
and parser exit zero. The sample is diagnostic and stays outside the
timed comparisons.

Commit `10ca314da` constructs the AST's owned UTF-16 identifier name
directly from the token in primary expressions, member access and
optional chains. Scope registration reads the owned name. The Unicode
regression overwrites the parser's UTF-16 input after parsing and verifies
escaped names, a supplementary character and scope resolution. The
focused tests run with assertions enabled and exit zero.

Seven alternating fresh-process pairs parse all 81 pinned GitHub modules
without diagnostics or recursion-limit failures. The binaries use Clang
`-O2`, V development mode and `-prealloc -gc none`. Compiler manifests
differ only in `expressions.v`. Median full-frontend instructions fall
from 6,942,542,494 to 6,815,509,578, a 1.83% reduction. All seven pairs
improve in instructions. Median elapsed time falls from 583.146 to
577.724 ms, with six pairs faster. The largest module's instructions
fall from 1,811,311,662 to 1,774,428,070. One-minute host load ranges
from 6.69 to 6.87 on 18 CPUs. The 3 GiB cohort guard exits zero in
9.010 seconds at 2,598,928,384 sampled peak bytes.

The published browser predates this change. A disk-space failure blocked
the initial benchmark launcher. The standard Build pruner could not
remove its stale protected app bundle, and the later guarded standalone
trial completed. Managed production receipts continue to show disk-space
failures. Browser page timing remains pending. The sample, source pins,
test and benchmark receipts are local under
`docs/benchmark-results/github-profile-5204-r113/receipts`.

### Scope identifier map copies

Commit `6a0b5819b` resolves identifiers directly from each scope's
insertion-ordered map. The loop annotates identifier nodes and propagates
references to the parent. The current scope's map remains live until
propagation finishes. The scope-order and rollback regression suites
pass with assertions enabled, covering local index order, captures and
repeated speculative parsing.

The earlier stack sample includes copying below
`ScopeCollector.resolve_identifiers`. Disassembly of the matched parser
binaries confirms one map-clone call in that function before the change
and zero afterwards. The source manifests differ only in
`libjs/scope_collector.v`.

Seven alternating fresh-process pairs parse the 81 pinned GitHub modules
without diagnostics or recursion-limit failures. Both builds use Clang
`-O2`, V development mode and `-prealloc -gc none`. Median full-frontend
instructions fall from 6,979,238,622 to 6,919,320,506, a 0.86% reduction.
Median elapsed time falls from 656.087 to 650.450 ms. Every pair improves
in instructions, and six improve in elapsed time. Host one-minute load
ranges from 11.05 to 11.31 on 18 CPUs. The 3 GiB guard exits zero in
10.278 seconds at 2,559,754,240 sampled peak bytes.

The published browser predates this change. Recent managed builds still
fail on disk writes. The page-render timing remains pending. The parser
trials, source manifests, test results and disassembly witness are local
under `docs/benchmark-results/github-scope-map-5204-r114/receipts`.

### Statement list assembly

Commit `55347cf55` appends parsed statements directly to the AST list
that owns them. Scripts and function bodies continue their directive
lists, and modules use one list through imports, exports and ordinary
statements. The new regressions check source order across those
boundaries. The frontend, directive prologue and class context suites
pass with assertions enabled.

The earlier parser sample includes bulk array appends during function
body parsing. Disassembly confirms that the script, module and function
body parsers each retain their statement-list call and drop one call to
the bulk append routine. The consumed-source manifests differ only in
`libjs/parser.v` and `libjs/declarations.v`.

Seven alternating fresh-process pairs parse all 81 pinned GitHub modules
without diagnostics or recursion-limit failures. Both builds use Clang
`-O2`, V development mode and `-prealloc -gc none`. Median frontend
instructions fall from 6,940,746,054 to 6,897,837,720, a 0.62% reduction.
Median frontend time falls from 589.378 to 581.243 ms, a 1.38% reduction.
Instructions improve in all seven pairs and elapsed time in five.
One-minute host load ranges from 8.16 to 8.37 on 18 CPUs. The 3 GiB guard
exits zero in 9.451 seconds at 2,476,654,592 sampled peak bytes.

All 100 upstream AST fixtures pass with the current parser. The consumed
source hashes for `parser.v` and `declarations.v` match the commit and
the paired benchmark. Four earlier attempts failed on disk writes during
compiler staging, object compilation or linking. The successful check
uses temporary RAM-backed storage and compares the same upstream
fixtures with the repository's unchanged corpus driver.

The published browser still predates this change. Page timing remains
pending after further managed production build disk failures. The paired
trials and AST check are local under
`docs/benchmark-results/github-statement-list-5204-r115/receipts`.

### Packaged adblock resources

Commit `58239a687` makes the macOS browser and its adblock worker read the
snapshot, metadata and codec from the bundle's Resources directory.
Standalone builds keep their embedded fallback. Staging requests
copy-on-write clones when the volume supports them and verifies the files
through the existing sealed bundle input checks.

The adblock helper's matched Clang C backend configurations use V
`-prod` and differ by the packaged-assets define. Generated C drops from
160,496,655 to 7,562,158 bytes. The packaged helper executes with the
three hash-verified resources and fails with a missing snapshot or
corrupt codec. The asset assertions pass in standalone and packaged
modes, including a separate packaged run with `-prealloc -gc none`.
The standalone self-worker check also passes with assertions enabled.

The initial optimized standalone link crosses the 3 GiB guard. A
separate guarded C-only generation confirms the exact control size, and
the follow-up checks complete in 7.254 seconds at 858,030,080 sampled
peak bytes. Receipts are local under
`docs/benchmark-results/github-adblock-packaging-5204-r116/receipts`.

The published production bundle predates the packaging change. Disk
exhaustion still blocks a fresh browser publication and GitHub timing.

### String and template literal decoding

Commit `1ae9f580f` reads raw string and template tokens from the UTF-16
source view. The decoder copies plain text into owned storage in one
operation and starts escape decoding at the first backslash or carriage
return. Disassembly confirms that both parser entry points drop their
raw-token clone. The focused Unicode and directive suites pass with
assertions enabled, and all 100 upstream AST fixtures match. The Unicode
regression overwrites the parser input and checks plain and escaped
strings, CRLF normalization, and both forms of tagged template data.

Seven alternating fresh-process pairs parse the 81 archived GitHub
modules without diagnostics or depth-limit failures. Both binaries use
Clang `-O2`, V development mode and `-prealloc -gc none`. The consumed
source manifests differ only in `libjs/expressions.v`.

| Median frontend measure | Control | Literal decoding |
| --- | ---: | ---: |
| Retired instructions | 6,872,739,460 | 6,845,399,349 |
| Elapsed time | 495.976 ms | 496.179 ms |

Six pairs use fewer instructions and five finish sooner. The 0.40%
median instruction reduction accompanies essentially unchanged median
elapsed time. Host one-minute load ranges from 8.29 to 8.31 on 18 CPUs.
The 3 GiB guard exits zero in 8.578 seconds at 2,431,205,376 sampled
peak bytes. Builds and checks use private RAM-backed scratch. The raw
timings, source manifests and verification receipts are local in
`docs/benchmark-results/github-literal-decoding-5204-r118.tar.gz`.
The published bundle at the time of those trials predated the change.

### Published parser changes versus Brave

Managed build `20261118-155315-2b212dc4` publishes single-unit V `-prod`
executable `18438d546aa3ff0433adebbf05979010b3de983e4eb20900ce9948853fa1777e`.
Its sealed sources include the statement lists, scope-map reuse, literal
decoding and packaged adblock changes. The build guard exits zero in
1,117.143 seconds at 8,037,236,736 sampled peak bytes. Headless smoke also
exits zero. The generated main C file is 194,134,832 bytes and the new
executable is 50,057,472 bytes. The previous production receipt records
347,061,543 and 80,422,864 bytes respectively.

The archived `vlang/v` visit retains the earlier replay, audit, reference
and one-second settle. Each run uses a fresh process, profile and HTTP
cache, with OS caches retained. Among the pinned inputs, the Vox
executable and adblock worker digests change. The 17 native cache ABI
source hashes match. A separate traced visit maps the recovered grouped
cache library, completes all 81 modules, executes 480,419 native entries
and records 2,948 hits with zero misses or compiler calls.

| Browser | Observed median launch to PNG | Observed PNG time range | Observed median launch through exit |
| --- | ---: | ---: | ---: |
| Vox with grouped compiled LibJS | 9.420 s | 9.331–11.079 s | 9.619 s |
| Brave with V8 15.7.112.43 | 2.644 s | 2.586–2.752 s | 2.976 s |

All seven alternating pairs produce PNGs, pass the repository content
audits and exit zero. Every Vox visit reuses compiled code with
2,948–2,949 hits and zero misses or compiler calls. The seven Vox PNGs
are pixel-identical and each differs from the shared reference by two
pixels. The first Brave PNG differs from the reference by 11 pixels.
The following six match that reference exactly and differ from the
first Brave PNG by the same 11 pixels. The unchanged repeatability
check therefore rejects the cohort. All seven timings per browser are
retained as observations.

The measurements include startup, hydration and rendering. The
timed launches report one-minute host loads of 87.58–105.66 on 18 CPUs.
The guard adopts all 15 browser roots, records 301.835 seconds at
6,149,603,328 sampled peak bytes and exits one. The prior complete
[comparison against Brave](LIBJS_NATIVE_CODE.md#recovered-group-against-brave)
records 9.186 seconds for Vox and 2.434 seconds for Brave under lower
host load. Raw attempts, exact counters, images, executable identities
and guard reports are local under
`docs/benchmark-results/github-compiled-v8-5204-r119/receipts`.

### Compiled runtime profile and array length handling

A traced visit on published executable
`fb9f84d9dfb1322763bab7abb2026df81df55becbfb2c7f87237142caa329818`
reuses the grouped cache and passes the archived `vlang/v` audit. It
records 484,139 native entries, 13,410,611 fast steps and 5,090,065 slow
steps. In 2,353 main-thread snapshots, 619 include the LibJS executable
runner and 475 include the document layout callback. The sampled paths
locate runtime and layout work. The instrumented pass is excluded from
comparative timings. The sampler, browser and guard exit zero. Raw
samples and replay receipts are local in
`docs/benchmark-results/github-runtime-profile-5204-r120.tar.gz`.

Commit `2a82a1ea8` initializes the virtual length of a fresh array from
its validated constructor argument. For a numeric length descriptor,
one bounds check, cast and fraction check replace the generic numeric
conversions. Values that can invoke author code retain both coercions.
The array suite passes with assertions enabled, including coercion
order, sparse length limits and negative zero. The first combined
compile-and-test attempt reaches its 3 GiB guard during compilation. The
separate compile exits zero at 9,161,932,800 sampled peak bytes, and the
focused runtime exits zero under its 3 GiB guard.

Seven alternating trials run the same 16,384 array constructions and
length writes and verify checksum 139,264. The two LibJS executables use
Clang `-O2` and `-prealloc -gc none`. Their consumed source manifests
differ only in `libjs/array_object.v`. Separate diagnostics confirm
16,386 native entries in each binary. Each timed process loads three
prebuilt entries with zero misses or compiler calls. Node embeds V8
`14.6.202.34-node.40` and runs the same source. The elapsed intervals
start at execution of the prepared script, including any native lookup
or VM tiering within that execution.

| Median array workload measure | LibJS control | LibJS numeric length | Node V8 |
| --- | ---: | ---: | ---: |
| Main-thread instructions | 360,759,202 | 352,255,934 | — |
| Elapsed time | 30.775 ms | 30.270 ms | 6.424 ms |

Instruction counts fall 2.36% with all seven pairs improving. Five
pairs finish sooner. The paired guard exits zero in 3.255 seconds at
82,706,432 sampled peak bytes. The 18-CPU host reports a one-minute load
of 47.91 during the cohort. The scope is array execution. The archived
GitHub launch-to-PNG target remains open. Local receipts are under
`docs/benchmark-results/libjs-array-length-5204-r120/receipts`.

### Warm same-process compiled execution

The archived GitHub comparison reuses native code on disk while launching
a fresh browser for each measurement. This array benchmark instead loads
one script, retains the same VM and function for eight untimed calls
and measures the next nine calls in that process. Each call constructs
16,384 arrays, assigns their lengths and checks checksum 139,264. The
timer covers the function call. Startup, disk-cache lookup and the
warm-up calls complete before timing begins.

The LibJS processes use Clang `-O2` and `-prealloc -gc none`, with the
compiler set to `/usr/bin/false` when measuring. They load three native
entries and record zero misses or compiler calls. A separate diagnostic
per build confirms 147,465 native executions during the nine measured
calls. The V8 control runs the same script and verifies the same checksum
under Node's V8 `14.6.202.34-node.40`.

Each cohort has seven alternating trials and reports the median of the
seven per-process medians. The consumed source manifests differ by
`libjs/construct.v` in the first cohort and by
`libjs/constructor_prototype.v` in the second and by `libjs/reference.v` in the third.

| Cohort | LibJS control | Compiled LibJS change | Node V8 | Main-thread instructions before → after |
| --- | ---: | ---: | ---: | ---: |
| Native constructor frame reuse | 21.279 ms | 20.378 ms | 3.334 ms | 348,637,109 → 344,536,537 |
| Cached constructor prototype key | 17.436 ms | 16.648 ms | 2.887 ms | 342,867,848 → 327,819,861 |
| Writable array length assignment | 16.709 ms | 16.298 ms | 2.820 ms | 328,009,811 → 320,477,075 |

Reusing native constructor frames lowers the median by 4.23% and
instructions by 1.18%. An exposed frame remains available to its owner,
as the retention regression checks. The prototype lookup uses the
existing immutable key and still calls the same observable Get.
This lowers the median by a further 4.52% and instructions by 4.39%
in the second cohort. The controls shifted between cohorts. The
18-CPU host reports one-minute loads of 6.33–6.95 in the first cohort
and 7.71–8.05 in the second. Both guards exit zero, with sampled
peaks of 920,420,352 and 763,789,312 bytes respectively.

A direct numeric assignment grows an array's writable length slot without
constructing property descriptors. Shrinking, coercion, explicit receivers
and exotic objects take the checked path. The third cohort lowers the
median by 2.46% and instructions by 2.30%. Six of seven pairs finish sooner
and all seven retire fewer instructions. The guard exits zero at
660,652,032 sampled peak bytes on one-minute loads of 9.08–9.52.
The final LibJS median is 5.78 times the Node V8 median.

The focused constructor, prototype and array suites compile with
assertions enabled and each exits zero under its own 3 GiB runtime
guard. Their separate compiler guards peak at 10,097,819,648,
9,118,482,432 and 9,358,229,504 sampled bytes. The compiled benchmarks
use the canonical checkout, with other local work held fixed across
each comparison. The managed production rebuild is queued for these
changes. The latest valid archived GitHub launch-to-PNG comparison
remains 9.186 seconds for Vox with compiled LibJS and 2.434 seconds
for Brave with V8. Local commands, consumed-source digests, paired
samples and guard reports are under
`docs/benchmark-results/libjs-warm-construct-5204-r121/receipts`.

### Published runtime changes versus Brave

Managed build `20261119-002649-7f5ec8aa` publishes single-unit V
`-prod` executable
`164061bab30f9ca5eca82316de0e03451fefbf0874c96a8c3cab734e19ae1b06`.
The frozen source manifest verifies `1ba724c13`, `f1a24504b` and all
17 ABI inputs of the original grouped native cache. The same archived
`vlang/v` page uses 1024×768 document captures, original-origin replay,
a one-second settle and fresh browser processes, profiles and HTTP
caches. OS caches are retained.

The traced eligibility visit maps the pinned grouped library, evaluates
all 81 modules and records 480,209 native entries. Across seven alternating
untraced pairs, all repository audits pass and all browser exits are
zero. Each LibJS visit records 2,948–2,949 native cache hits and zero
misses or compiler calls. Each browser reproduces its own pixels. Brave
matches its reference exactly and the Vox PNGs differ by two pixels.

| Browser | Median launch to PNG | PNG range | Median through exit | Median observed instructions |
| --- | ---: | ---: | ---: | ---: |
| Vox with compiled LibJS | 8.903 s | 8.413–9.719 s | 8.997 s | 55,428,408,630 |
| Brave with V8 15.7.112.43 | 2.623 s | 2.320–3.762 s | 2.733 s | 20,732,610,187 |

The median launch-to-PNG ratio is 3.39×. The endpoints include browser
startup, hydration and rendering. Brave's endpoint includes CDP delivery
and the harness's PNG write. The sampled process-tree instruction totals
are lower bounds. One Vox visit misses a final process sample and six
Brave visits miss one to three samples. The 18-CPU host reports
one-minute launch loads of 14.62–16.96. The guard adopts all 15 browser
roots and exits zero in 164.664 seconds at 6,227,017,728 sampled peak
bytes. The new cohort validates the published build as a whole, with
other source changes also present. Raw attempts and input digests are
local under `docs/benchmark-results/github-compiled-v8-5204-r122/receipts`.

### Warm compiled array callbacks

Commit `f83322328` uses one live load for a present own array data
element in `forEach`, `map`, `reduce` and `reduceRight`. A live numeric
key guards the dense storage position. Holes, accessors and exotic
objects use checked HasProperty and Get, and the execution budget keeps
the original charge. `map` appends own data properties directly when
intrinsic construction guarantees a fresh result. User-provided species
continue to define properties as each callback returns.

The same-process benchmark prepares one 128-element array and runs 64
iterations of `forEach`, `map` and `reduce` per call. It verifies
checksum 1,560,576. It warms each process with eight calls and measures
the next nine. LibJS uses Clang `-O2` and `-prealloc -gc none`. Separate
diagnostics verify 221,193 native entries across those nine calls for
each build. Every timed LibJS process loads six prebuilt native entries
and records zero misses or compiler calls. Node uses V8
`14.6.202.34-node.40` with the same source and checksum.

| Seven alternating trials | LibJS control | LibJS change | Node V8 | Main-thread instructions before → after |
| --- | ---: | ---: | ---: | ---: |
| Single live element lookup | 10.838 ms | 7.012 ms | 3.061 ms | 215,686,612 → 143,455,272 |
| Direct append into a fresh map result | 7.085 ms | 5.053 ms | 3.050 ms | 143,459,617 → 107,337,455 |

The first cohort reduces median elapsed time by 35.3% and instructions
by 33.5%. The second reduces those metrics by 28.7% and 25.2%. All
seven pairs in each cohort finish sooner. The final LibJS median is
1.66× the V8 median. The consumed manifests isolate the tested changes
and both cohorts complete with guard exit zero. The one-minute host
load is 13.67–14.16 and 17.43–18.16 respectively. The focused element
lookup, map and reduce suites pass in guarded runs with Boehm and with
preallocation and no GC.

A separate candidate borrows stack argument storage for synchronous
callbacks that copy it into their own frames. The candidate saves 0.14%
of instructions and 0.36% of elapsed time under that cohort's load. It
was reverted. The benchmark includes that cohort and its paired control.
Local commands, test exits, and raw samples are under
`docs/benchmark-results/libjs-warm-callback-5204-r123/receipts`.

### Published array callback changes versus Brave

Managed build `20261119-004759-f7511b4f` publishes single-unit V
`-prod` executable
`5ca3ed99fb8d790009d0623097fa643b56847b381f02534d0583f7c319d716c3`.
The frozen manifest verifies all five LibJS implementation files from
`f83322328` and the same 17 native cache ABI files. The publication
also contains four renderer source changes relative to the previous
comparison. It passes the headless startup check.

A separate traced visit completes all 81 modules and records
433,862 native entries and 24,131 direct element reads. The previous
publication's eligibility visit records 2,528 direct element reads.
The profile collects 1,855 main-thread snapshots during a portion of
the traced launch. The native executable runner appears in 777
snapshots and the layout callback in 487. Lexical binding lookup
accounts for 59 samples at the top of the main-thread stack.

| Browser | Median launch to PNG | PNG range | Median through exit | Median observed instructions |
| --- | ---: | ---: | ---: | ---: |
| Vox with compiled LibJS | 8.000 s | 6.553–8.616 s | 8.105 s | 56,353,531,372 |
| Brave with V8 15.7.112.43 | 2.371 s | 2.122–2.598 s | 2.465 s | 20,446,906,860 |

All seven alternating pairs use the prior frozen archive, a one-second
settle and fresh browser, profile and HTTP cache state. Every visit
passes the repository audit and exits zero. Each browser reproduces its
own PNG. Brave is pixel-exact to the reference and Vox differs by two
pixels. Every Vox visit has 2,949 native hits, zero misses and zero
compiler calls. The warm compiled launch-to-PNG median takes 3.37×
as long as Brave's. Both browser medians fall by about 10% across the
two publications, and Vox's observed median instruction count rises.
The matched standalone cohorts isolate the runtime changes. The browser
comparison reflects the host conditions and all sources in each publication.

The 18-CPU host reports one-minute launch loads of 13.11–28.87. The
process-tree instruction totals are lower bounds. Four Vox visits miss
one final process sample, and six Brave visits miss one to four
samples. The guard adopts 15 browser roots, samples 6,245,826,560 peak
bytes and exits zero. Its 504.084 seconds include waiting for publication.
Commands, build hashes, complete pairs and the separate trace are
local under `docs/benchmark-results/github-compiled-v8-5204-r124/receipts`.

### Lookup of single-unit lexical names

Commit `fd7322cf4` compares single-unit UTF-16 binding names directly in
the small-scope scan. It checks the live slot and its length, preserves
lone surrogate units, and retains the existing comparison for longer
names. The focused binding lookup suite passes in guarded Boehm and
preallocation runs, including deleted names and retained closure bindings.

A warm loop reads four single-unit global lexical names over 16,384
iterations and checks checksum 327,680. The same process warms eight
times and measures nine calls. Both LibJS builds use the same
compiler and generated cache protocol. They load two prebuilt native
entries before timing, with zero misses or compiler calls. Separate
diagnostics confirm nine native executions during measurement.
The consumed manifests differ only in `libjs/declarative_environment.v`.

| Median of seven paired process medians | LibJS control | LibJS direct comparison | Node V8 14.6.202.34-node.40 |
| --- | ---: | ---: | ---: |
| Elapsed time | 12.728 ms | 9.857 ms | 0.044 ms |
| Main-thread instructions | 200,261,796 | 171,426,856 | — |

Every pair retires fewer LibJS instructions, with a median reduction of
14.4%. Six pairs complete sooner. The seventh candidate takes 40.074 ms
against its 26.573 ms control. The guard exits zero at 196,050,944 sampled
peak bytes with host loads of 8.37–10.99. The published GitHub
comparison above covers the earlier array changes. The lexical change
is queued for production. Local measurements and focused checks are
under `docs/benchmark-results/libjs-warm-bindings-5204-r125/receipts`.

### Script time against V8 after the lookup index and smaller AST, 2026-11-19

**Compiled LibJS is not yet faster than V8 on this page.** On the final
publication below, LibJS's main-thread JavaScript takes a median 1.17 s of
thread CPU per load; Brave's V8 reports a median 187 ms `ScriptDuration`.
The first stage-logged loads took 1.95–2.26 s with the new lookup index warm
and 2.69 s while it learned; the earlier record path is not separately timed.
The whole archived `vlang/v` load now reaches its PNG in 4.12 s against
Brave's 2.03 s (the previous published comparison was 8.0 s against 2.37 s).

**Measures.** V8 time is Brave's `Performance.getMetrics` `ScriptDuration`
(main-thread script execution, including forced style/layout), read just
before the capture of each Brave visit in the cohorts below. One separately
traced Brave load attributes 389 ms of main-thread and 228 ms of background
worker time to V8 trace events; tracing inflates both, and its own
`ScriptDuration` was 293 ms. LibJS time comes from separate stage-logged
diagnostic loads: commit `a1ea69eee` adds thread-CPU and wall nanoseconds at
each calling-thread stage boundary, and the reported figure is the inclusive
CPU time of the outermost `javascript_execution_and_bindings`,
`libjs_module_frontend` and `libjs_module_link` scopes (nested forced
style/layout included, as in `ScriptDuration`). Logging adds instructions to
those loads; they are not timing cohorts. All loads use the frozen archive,
fresh processes, profiles and HTTP caches, the 1024×768 document capture, a
one-second settle and the grouped `-O2` native cache (2,943–2,949 hits, zero
misses or compiler calls), cloned into a private directory.

| LibJS publication (thread CPU, ms) | Loads | Outermost JavaScript | Execution self | Module frontend | Link |
| --- | ---: | ---: | ---: | ---: | ---: |
| `52cb359d…`, index learning (seed) | 1 | 2,693 | — | — | — |
| `52cb359d…`, index warm | 2 | 1,946–2,260 | 1,210 (one load) | 661 (one load) | 18 |
| `2626c507…`, index, binding hints | 3 | 1,809–1,912 | 1,135–1,204 | 603–635 | 17–18 |
| `48cf9b0d…`, property hints | 3 | 1,867–1,879 | 1,152–1,167 | 641–646 | 17–18 |
| `b03b9f5a…`, expression lists, import/export | 3 | 1,302–1,414 | 882–959 | 367–397 | 13–14 |
| `ed3db3d1…`, rare expression fields | 5 | 1,082–1,238 (median 1,170) | 731–857 | 306–333 | 11–12 |

Host load fell during the day (one-minute loads from about 25 to 6), which
also affects CPU time. The instruction totals of the stage-logged loads fell
from about 58.2 billion (`2626c507…`) to 51.0–52.6 billion (`ed3db3d1…`).

**Native lookup index.** Commits `30536b32f`, `a51308690`, `bd6f256ab`,
`74dfa7666` and `b48902257` persist, per cache ABI directory, a map from a
cheap source-bound key (browser executable file identity, source digest,
filename, function role, frame layout and bytecode encoding) to the record a
previous visit of the same build verified. Without it each of about 4,270
executables regenerated its complete C source to derive its generated-code
key and read one JSON record, and every launch rehashed the 135 MB grouped
library. Libraries verified by digest record their device, inode, size and
nanosecond mtime/ctime; an unchanged identity naming the same digest maps
without rehashing. The index lives outside the 17 native-cache ABI sources,
so existing caches stay valid. `VOX_LIBJS_NATIVE_LOOKUP_INDEX=0` is the
same-binary control and `=readonly` uses a frozen index for timed visits.
Each executed function set differs slightly between visits, so a learning
visit can add a few entries; the timed candidates therefore run read-only.

| Seven alternating rounds, `ed3db3d1…` | Median launch to PNG | PNG range | Median observed instructions | Instruction range |
| --- | ---: | ---: | ---: | ---: |
| Vox, index disabled | 4,325 ms | 4,240–4,565 ms | 44.41 billion | 43.36–45.15 billion |
| Vox, read-only index | 4,116 ms | 4,084–4,171 ms | 42.90 billion | 42.50–43.70 billion |
| Brave with V8 | 2,032 ms | 1,983–2,151 ms | 20.47 billion | 20.28–20.66 billion |

Every index visit is faster and retires fewer instructions than its paired
control; record loading falls from 122–136 ms to about 5 ms, with zero index
misses. The earlier cohort on `2626c507…` (loads 10–14) also improved in all
seven pairs: 46.07 to 43.97 billion instructions and 5,574 to 5,379 ms. Brave's
`ScriptDuration` medians are 187 ms (range 185–201) and 243 ms (217–268) in
the two cohorts. All 42 visits pass the repository audit and exit zero; every
Vox PNG differs from the unchanged Brave reference by the same two pixels, and
Brave matches it. Instruction totals are process-tree lower bounds.

**Smaller AST nodes.** `6f2f71db8`, `c0a39c6a5` and `43ce364c9` move payloads
present only on uncommon node kinds (sequence/array/object lists, assignment
targets, BigInt/RegExp/private-name/dynamic-import/template/optional-chain/
super-call/class records, import and export statement data) into out-of-line
heap records. `Expression` shrinks from 704 to 312 bytes, `Statement` from
1,024 to 704, object-literal properties from 1,456 to 672 and call arguments
from 712 to 320. Parsing all 87 archived scripts (5.25 MB) in one process
falls from 6.66 to 5.23 billion instructions and from 2.55 to 1.66 GB peak
RSS. On the page the module frontend falls from about 640 to 330 ms, and the
execution self time also falls, since lazily compiled functions copy less AST.
Between the `2626c507…` and `ed3db3d1…` cohorts Vox's median peak footprint
falls from 5.43 to 4.69 GiB. The exact upstream
AST corpus passes 100/100 after each change. During the last change a tagged
template's child pointed at a parser loop local and the corpus failed 3/100;
the committed version copies those expressions into the heap explicitly.

**Bounded hint tables.** `f690750de` rejects mismatched binding names by
length and first/last unit before comparing them (139.2 to 125.1 ms on a
closure-heavy script). `76abee941` and `3af86f808` raise the binding and
property successful-position bounds from 64 to 4,096: tables that reached 64
entries were cleared on nearly every insertion. A factory scope read through
120 of its 400 names runs in 39.2 ms instead of 102.7 ms; reading 120 of 400
object properties takes 52 ms instead of 295 ms. The binding results are
medians of eight alternating same-binary pairs; the property result compares
seven alternating process pairs of two otherwise identical binaries. Neither
bound moved the page measurably, so no page credit is claimed for them. A parallel
frame-pool capacity index showed no gain and was not committed.

**Remaining gap.** Execution (about 0.8 s) is spread over interpretive call
setup and frame pooling, linear property scans, binding walks, array growth
and map lookups; native code handles only simple operations and calls back
into the interpreter for calls, property writes and most runtime operations.
The 0.33 s frontend parses every function body eagerly, where V8 preparses
lazily and compiles on background threads. Next levers, in order: lazy
function parsing, environment-coordinate binding reads and module-scope
reads in native code (both native-cache ABI changes requiring a grouped cache
rebuild), and inline caches for property reads.

**Verification.** Focused native-cache, lookup-index, binding, environment,
property, object, module and parser test files pass with Boehm, without GC
and with preallocation where relevant. A whole-directory `v test libjs` run
cannot complete under the 12 GiB guard: 70 of the 232 related test files each
need more than 6 GiB to compile, independently of these changes, and four
fail for unrelated reasons (`class_execution_test.v` still expects static
blocks to be rejected, `native_binding_read_test.v` uses unsupported `with`,
`native_function_test.v` exceeds the compiler memory limit and
`regexp_literal_program_test.v` no longer compiles). The interpreter, array
object, function prototype, bound function, BigInt execution and private
object files pass at 10 GiB. The browser type-checks. The volume was full
(199 MB free) during part of this work. Commands, rows, stage summaries,
profiles and the Brave trace summary are local under
`docs/benchmark-results/libjs-github-v8-e1-20261119/receipts`.

### Worker-thread module parsing and the remaining gap, 2026-11-19

**Not yet as fast as Brave.** On the same archived page, five alternating
rounds give Vox with compiled LibJS a median 4,465 ms to the PNG
(43.38 billion observed instructions), Vox with JavaScriptCore 3,547 ms
(29.02 billion) and Brave 2,197 ms (20.50 billion). All 15 visits pass the
repository audit and exit zero. Both Vox engines still trail Brave, and
LibJS still costs about 0.9 s and 14 billion instructions more than JSC.

**Worker-thread parsing.** `8c6d7c4e7` parses fetched LibJS module scripts on
four worker threads, as V8 compiles streamed scripts off the main thread.
The fetch completion queues the decoded source and returns to the event loop;
the worker's result returns to the origin run loop, which resumes the
ordinary module fetch from a networking task. Workers retain their
allocations for the process. Only a clean result is reused; anything with a
diagnostic or recursion stop is parsed again on the main thread (8 MB worker
stacks versus the 64 MB main thread). `VOX_LIBJS_BACKGROUND_PARSE=0` keeps
main-thread parsing and the audit's `frontend.background_parses` counts worker
parses (80 per load). Parsing all 87 archived scripts on four concurrent
threads matches a main-thread parse (82 full AST dumps, the five largest by
diagnostics and length; two runs).

| Seven alternating rounds, `654a0f77…`, read-only index | Median launch to PNG | Range | Median observed instructions |
| --- | ---: | ---: | ---: |
| Main-thread parsing (`VOX_LIBJS_BACKGROUND_PARSE=0`) | 4,674 ms | 4,242–5,571 ms | 43.09 billion |
| Worker-thread parsing | 4,400 ms | 4,096–5,800 ms | 43.34 billion |
| Brave with V8 | 2,222 ms | 2,178–2,416 ms | 20.68 billion |

Only four of seven pairs are faster, at one-minute host loads of 8–11, so no
reliable wall-time gain is claimed. Three stage-logged loads per mode show
the main-thread module frontend falling from 339–374 to 130–146 ms, while
execution self time rises from 807–960 to 942–1,036 ms; outermost script
time is 1,133–1,244 ms against 1,194–1,388 ms. Brave's `ScriptDuration`
median is 216 ms in this cohort.

**Lookup index in profiled launches.** `8f8b2256a` and `2dab31231` derive the
build identity from the main executable's file identity through
`_NSGetExecutablePath` (Linux: `/proc/self/exe`). V's `os.executable()` reports
dyld image zero, which is the inserted library under `DYLD_INSERT_LIBRARIES`,
so profiled launches previously ignored the index.

**Where LibJS's time goes.** One stage-logged load of each engine on the same
publication: LibJS spends 873 ms in script execution and bindings and 128 ms
in the module frontend; JSC spends 487 ms plus 191 ms of module source
completion. LibJS's posted-task, parser-end and animation-frame tasks also
enter script outside that scope (152 and 91 ms of other/rendering task time
against 6 and 15 ms with JSC). Style, layout and paint are similar for both
engines and remain well above Brave's (Brave reports 19 layouts in 52 ms and
78 style recalculations in 95 ms). A launch-to-capture profile (injected
startup delay, `MallocSpaceEfficient=1` to avoid the allocator re-exec) puts
about half of the busy main thread in script and half in style, layout and
paint. Within script, cost is spread over own-property scans (~15%), array
growth (~10%), call frames (~7%), bytecode compilation (~7%) and binding walks
(~5%); no single routine dominates. `Object` is 1,112 bytes, but object
creation is under 0.5% of samples.

**What parity needs.** Reaching Brave requires structural work on both halves:
property inline caches over object shapes, compiled call paths and
environment-coordinate binding reads (native-cache ABI changes that need a
grouped-cache rebuild), lazy function parsing with a pre-parser, and
incremental style/layout or off-main-thread rendering. Local receipts are
under `docs/benchmark-results/libjs-github-v8-e2-20261119/receipts`.

### Lexical, arrow and async bindings in registers, 2026-11-20

**Register lowering coverage.** Before this round only ordinary
simple-parameter functions with no arrow syntax and no nested declarations
kept their uncaptured parameters and `var`s in local slots, and every
`let`/`const`, block and loop head used a declarative environment. GitHub's
bundles declare about 14,100 `let`s, 4,100 `var`s and 10,500 arrows (regex
counts over the 87 archived scripts), so most bindings took the environment
path: each block entry allocated an environment, each loop iteration copied
its bindings, and each access was a by-name lookup.

| Commit | Change |
| --- | --- |
| `9df74e65d` | Arrow functions and functions with nested declarations use slots; a hoisted function name stays in the environment. |
| `61c614099` | Uncaptured `let`/`const` in blocks, loop heads and the function body use slots; blocks and loops whose lexical bindings are all slots allocate no environment and copy no per-iteration bindings. |
| `ff0d575e7` | Async functions use slots (await copies the initialized frame). |

Upstream checks the TDZ at run time with an empty local and `ThrowIfTDZ`.
This port proves instead, in emission order, that every read follows the
binding's initialization: within a block, code emitted after a declaration
only runs after it in the same block entry. A read or write before the
initialization, or a `const` assignment, rejects that binding and recompiles
the function with it in the environment, which raises the ReferenceError or
TypeError. Case-block declarations keep the environment because a case can
jump past them.

Optimized same-build A/B microbenchmarks (slots toggled by a test switch):

| Case | Environment | Slots |
| --- | ---: | ---: |
| `let` loop, 200,000 iterations | 64.5 ms | 2.3 ms |
| block `const` in a loop | 143.9 ms | 4.3 ms |
| `for (const x of a)` | 35.9 ms | 11.5 ms |
| arrow calls with a `const` | 131.4 ms | 27.9 ms |
| destructuring `const {a,b}` | 72.1 ms | 8.6 ms |
| call, 200,000 (arrow/declaration commit) | 64.98 ms | 30.41 ms |

Functions whose parameters stay in the environment (destructured or default
parameters, observable `arguments`) now keep their own `let`/`const` in slots
too (`a9201c8e7`): a component-like function with destructured parameters,
100,000 calls, 236.0 -> 75.0 ms; one with a default parameter, 200,000 calls,
230.3 -> 91.6 ms. Object literals skip descriptor validation for fresh keys
(`fcd054795`, 300,000 two-property literals 74.6 -> 66.1 ms) and constant keys
no longer emit a conversion instruction (`227a40e2b`).

**Page result.** Bundle `e4168684…` (`9fe7bccea`, before the last three
commits) with a rebuilt grouped native cache: the workflow's grouped reopen
matches the separate-cache screenshot pixel for pixel. Its trace stage first
failed because a visit learned the lookup index inside the pinned cache;
`6e590dd44` keeps that index read-only in benchmark visits unless seeding is
requested. Three learning visits seeded the index; five alternating rounds
then used it read-only, at one-minute host loads of 3–6 (the earlier
worker-parsing cohort ran at 8–11, so absolute times across sessions are not
comparable):

| Five alternating rounds, `e4168684…` | Median launch to PNG | Range | Median observed instructions |
| --- | ---: | ---: | ---: |
| Vox with compiled LibJS | 3,571 ms | 3,542–3,718 ms | 43.34 billion |
| Vox with JavaScriptCore | 2,991 ms | 2,956–3,036 ms | 29.86 billion |
| Brave with V8 | 1,948 ms | 1,874–2,093 ms | 20.96 billion |

All 15 visits pass the repository audit. Relative to JSC in the same cohort,
LibJS fell from 1.26x (4,465/3,547 ms) to 1.19x; relative to Brave from 2.03x
to 1.83x. Two stage-logged LibJS loads put outermost script CPU at 834 and
837 ms (previous session 1,133–1,244 ms) and execution self time at 688–689 ms
(942–1,036 ms); the module frontend is 103–108 ms. Brave's `ScriptDuration`
median is 154 ms, so LibJS script time is still about 5.4x V8's. Whole-process
instruction counts did not fall with the shorter script time.

**Remaining gap.** A stage-logged JSC load on the same bundle spends about
730 ms of main-thread CPU in style (21,194 style constructions, mostly
pseudo-element probes, over about 5,400 element restyles), about 510 ms in
layout (114 document layouts), 372 ms in JavaScriptCore and about 250 ms in
paint; Brave reports 78 style recalculations in 95 ms and 19 layouts in 52 ms.
So even with V8-speed script, Vox would trail Brave by roughly the rendering
difference. Within LibJS, the measured page samples remain spread out: no
property inline caches over shapes, array elements stored as numeric-keyed
properties, about 150 ns per JS-to-JS call (frame pool, environment set-up and
context push), and by-name environment walks for captured bindings. Measured
and rejected this round: per-opcode interpreter tables (no change, clang
already emits jump tables), shrinking the 1,112-byte `Object` (object creation
is under 0.5% of page samples) and an environment-coordinate cache for
captured reads (about 2.5% of page samples). The last three commits change
bytecode, so measuring them needs another grouped-cache rebuild.

### Array lookups, a property-miss filter and the layout passes, 2026-11-20

**Last round on the page.** Bundle `856437379b93…` (`867d80f41`) with its own
rebuilt grouped cache (pixel-exact reopen): five alternating rounds at
one-minute host loads of 24–27 (another session's test batches) give compiled
LibJS 3,825 ms (41.45–43.40 billion instructions, median 43.21), JSC 3,203 ms
and Brave 1,957 ms (`ScriptDuration` 158 ms). All 15 visits pass the audit.
The load inflates every wall time (JSC was 2,991 ms in the quieter cohort), so
only the instruction counts compare: the last three commits of the previous
round save about 0.1 billion instructions (43.34 -> 43.21 billion).

**Array element lookups.** `dae2a9d21`: arrays keep elements as numeric keys in
the property vector, and large arrays used the hashed position hints, which
remember only hits. Every miss scanned the vector, so each `push` (a lookup
of the new index) and each method read (`a.push`, `a.map`,
`a[Symbol.iterator]`, which miss on the array before `Array.prototype`) was
linear in the length, and the 4,096-entry hint table thrashed on bigger
arrays. An array never owns an index at or above its length, element i is
verified at position i, and arrays count their appended non-index keys so a
name or symbol miss is answered without a scan.

| Optimized same-build A/B | Hints | Array invariants |
| --- | ---: | ---: |
| 3 x 20,000 pushes | 3,043 ms | 11.4 ms |
| 200,000 index reads (5,000 elements) | 711 ms | 47 ms |
| 20 `for-of` passes over 5,000 elements | 345 ms | 37 ms |
| index writes | 740 ms | 122 ms |
| three-element literals | 50.1 ms | 55.5 ms (noise; path not reached) |

**Rejected: a property-miss filter.** Two filter bits per string or symbol key
on objects with four or more properties made a method call on a nine-field
object 47.7 -> 40.5 ms (300,000 calls) and a missing-field check
26.1 -> 21.5 ms. It assumes keys only arrive through `define_direct_property`,
but ordinary objects keep a public property vector whose direct edits the
position hints deliberately tolerate (`property_lookup_test.v` renames a key in
place), so it was not committed. Arrays document the stricter contract instead.

**Layout passes.** A JSC load with `VOX_DOCUMENT_LAYOUT_DIAGNOSTICS=1` shows
eight main-document layouts of 26–139 ms (the first builds the tree twice); the
other calls lay out separate SVG image documents in 0.1–3 ms each. Most passes
rebuild the layout tree for a few dozen style changes or insertions (for
example 29 `a`, 23 `li` and 13 `div` style changes in a 94 ms pass) and then
lay out the whole document, as upstream Ladybird does. Blink lays out only
dirty subtrees (Brave: 19 layouts in 52 ms), so incremental layout is the main
rendering lever, with per-element style cost the other.

**Array lookups on the page.** Bundle `de068a36652b…` (`1a5138aaa`) with its
own rebuilt grouped cache (pixel-exact reopen). Other sessions' builds pushed
one-minute host loads to 36–51 during the five alternating rounds, so wall
times (LibJS 4.9–11.6 s, Brave 2.4–3.4 s) are not usable; all 15 visits pass
the audit. Instruction counts compare with the previous bundle: compiled LibJS
falls from a median 43.21 to 40.86 billion for the whole load, JSC reads
29.20 billion (29.55 before) and Brave 20.84 billion. Two stage-logged LibJS
loads put outermost script at 12.30 and 12.38 billion instructions against
12.86 and 12.97 before, and script execution at 10.01–10.09 against
10.59–10.68 billion, so the array change removes about 0.55 billion script
instructions (4.4%); the larger whole-load drop also reflects layout-pass
variation, which moves JSC's count by about a billion between cohorts.

### Style substitutions, literal and constructor writes, and worker-parsed document scripts, 2026-11-20

A sampled JSC load (host load about 4) puts style construction at 203
samples: rule matching 73, cascade 61 and computed properties 51 (font
metrics 20). Most cascade time was resolving `var()`, and most of that was
parsing the substituted tokens.

| Commit | Change | Measured |
| --- | --- | --- |
| `dbd1351cb` | Within a style pass, reuse the parse of a declaration's substituted `var()` tokens, keyed by a fingerprint of the substituted values (Primer's fallback chains bypassed the single-`var()` cache). | 95% hit rate (15,337 of 16,168); `style_cascade` 1.15 -> 0.99 billion instructions in three alternating JSC loads, the other style stages unchanged. |
| `9390b6f99` | Object literal keys that no earlier definition of the literal can have created skip the duplicate lookup (identifier/string keys before any spread or computed key; numeric spellings excluded), and every literal key needs at most one lookup. | 200,000 five-key literals 80.4 -> 57.9 ms; 50,000 thirty-key literals 132.9 -> 51.2 ms (literal paths off/on). |
| `ccc01d827` | Start a worker parse when a document script body arrives; execution reuses it only when ready, error-free and identical in text. | Two alternating stage-logged LibJS loads: worker parses 80 -> 86, main-thread script instructions 14.70–14.96 -> 12.92–13.28 billion (`libjs_module_frontend` 1.6 billion leaves the main thread). |
| `6c8b0b76b` | A write that adds a property to an ordinary receiver walks a plain ordinary prototype chain once and appends, instead of re-reading the receiver three more times. | Constructor adding ten fields, 50,000 objects, 96.3 -> 64.6 ms; four-field class 77.7 -> 60.0 ms; existing-field updates unchanged. |

Stage-logged instruction counts include their own counter reads (logged loads
run about 52 billion instructions against 43 unlogged, and style issues about
70,000 substage calls), so `style_construction`'s exclusive count is mostly
instrumentation; sampled profiles attribute style. In LibJS loads,
`html_other_task` and `html_rendering_task` (2.0 and 1.4 billion) are mostly
script run from posted tasks and animation frames outside the script stage.
The literal and constructor commits change bytecode or `object.v`, so their
page effect needs another grouped-cache rebuild.

**Page result for this round.** Bundle `fe01881e6f67…` (`c62b26514`) with its
own grouped cache (built while another session edited the benchmark driver,
so the pinned reopen check was repeated with `--verify-packed`; pixel-exact).
Five alternating rounds at one-minute host loads of 7–9, all 15 visits valid:

| Five alternating rounds, `fe01881e6f67…` | Median launch to PNG | Range | Median observed instructions |
| --- | ---: | ---: | ---: |
| Vox with compiled LibJS | 3,667 ms | 3,573–3,941 ms | 40.90 billion |
| Vox with JavaScriptCore | 3,132 ms | 3,051–3,357 ms | 28.44 billion |
| Brave with V8 | 2,043 ms | 1,977–2,087 ms | 20.54 billion |

LibJS is 1.17x JSC and 1.79x Brave in this cohort (1.19x and 1.83x in the
quieter cohort before these commits); Brave's `ScriptDuration` median is
198 ms. The round's gains are below the page's run-to-run variation: the
whole-load LibJS median is unchanged (40.86 -> 40.90 billion), and two
stage-logged loads differ by 3 billion instructions in style alone (11.4 and
14.4 billion) because the number of style and layout passes depends on
timing. Reaching Brave needs the structural changes already identified:
incremental layout, cheaper per-element style, and an engine with inline
caches over object shapes; this round's local fixes do not close it.

## Layout and style passes, 2026-11-20 evening

The JSC path isolates rendering from the engine, so this round measured
same-binary JSC loads with an environment control for each change.
`VOX_DOCUMENT_LAYOUT_DIAGNOSTICS=1`, `VOX_INCREMENTAL_LAYOUT_DIAGNOSTICS=1`
and the new `VOX_STYLE_PASS_DIAGNOSTICS=1` (one line per style pass with
the elements computed again by cause, followed by the properties that
required a relayout and an example old -> new value) located the costs.

Findings before the fixes, with diagnostics enabled:

- Two script-driven passes (about 120 ms each) rebuilt every box and reused
  no layout result: any element entering, leaving or renaming an `id`
  forced a full layout tree rebuild in case an SVG `url(#id)` reference
  changed, and GitHub inserts many elements with ids after hydration.
- `justify-items` flipped between `normal` and `legacy` in every style
  pass (4 to 22 elements), each flip a relayout: the inherited-value
  refresh restored the specified `legacy` and skipped the alignment step
  that the complete computation runs.
- Passes with one dirty node still cost 30–45 ms: the incremental relayout
  root must sit above every box an ancestor's intrinsic measurement sized
  (about 2,000 of 5,184 nodes relaid for one span or one animated button),
  and the renderer adapter costs about 5 ms in every pass.
- The largest style pass computed 1,256 newly rendered elements in 40–50 ms,
  about 35 µs each; the work is legitimate, the per-element cost is not.

| Commit | Change | Measured (JSC, instructions per load) |
| --- | --- | --- |
| `1d1941bb7`, `5f67bf5f1` | Layout and paint resolve URL fragments through `rendering_element_by_id`, which records the id; only a recorded id entering, leaving or changing forces the rebuild. Control `VOX_REBUILD_LAYOUT_FOR_EVERY_ID_CHANGE=1`. | Four alternating rounds: median 29.47 -> 28.28 billion, lower by 0.93–1.46 billion in every round. The two full rebuilds became partial (about 72 and 78 ms). The nine SVG source-switch and paint-server mutation reftests stay pixel-exact. |
| `fedefacdc`, `125dfb82b`, `ad57cd648` | The inherited refresh runs the alignment step, and resolves only `justify-items` when that is the element's sole parent-dependent value and no inherited value changed; the font input refresh no longer rejects elements for that keyword. Control `VOX_RETAIN_JUSTIFY_ITEMS_REFRESH=1`. | Four alternating rounds: median 28.21 -> 27.81 billion, lower in every round (0.04–0.80 billion). Four failing object-reuse assertions in `css/font_input_refresh_test.v` now pass. |
| `caa69de30` | Under the tree order the committed pass was keyed by, a node without values at its current index (a whitespace-only anonymous flex item) no longer blocks the reuse of its ancestors. Control `VOX_DISABLE_UNLAID_NODE_REUSE=1`. | `VOX_VERIFY_INCREMENTAL_LAYOUT=1` finds no geometry mismatch. No page gain in four rounds (median 28.05 control, 28.25 change; the pass schedule varies between loads). |
| `3cc7ecffe` | Opt-in `VOX_RETAINED_FLOW_ABSOLUTE=1` keeps absolutely positioned boxes of block parents in the retained flow salvage. | No gain in four rounds; left off. |

All cohort visits were pixel-valid against the Brave reference. Host load
was 7 to 34; only instruction counts are compared. Vox with JavaScriptCore
is now about 27.8 billion instructions per load against Brave's 20.5.

Unit-test caveat: with the current shared compiler, `v -b fastc ... test`
reports a failed assertion as passing, and C-backend test builds of the
html and layout modules exceed the 12 GiB guard in the transform stage's
automatic `str()` synthesis. Layout tests in this round were compiled with
FastC to a binary (`-o`) and run directly; FastC binaries of SVG paint tests
crash in a closure in `typed_paint_adapter.v` with or without these changes,
so the SVG behaviour was checked with the reftests above.

Remaining rendering levers, by size: per-element style cost (rule
collection and matching, cascade and value computation are a flat tail; a
style sharing cache for repeated rows is the structural option), the
height of incremental relayout roots under measured flex and grid items,
the first automatic-height call of a stretched flex item (it never matches
the item's last record), and the per-pass renderer adapter.

## Style sheet rule caches and animated images, 2026-11-20 night

A sampled JavaScriptCore load put 86 of 347 style samples in rule cache
builds: each of the two sheets GitHub inserts after its first style pass
rebuilt the caches for about 7,000 rules, 69% of it building invalidation
sets. Matching sorts its candidates by specificity, scope proximity, sheet
index and rule index, and every structure a build fills is additive, so the
document cache can be extended instead (`css/rule_cache_extension.v`):

| Commit | Change | Measured |
| --- | --- | --- |
| `b275d7572`, `68d7cb6db`, `53c713ef0` | Adding a sheet keeps the published document cache aside; the next build adds the new sheets' rules when every kept sheet is still present in order and no other invalidation happened. Complete builds number sheets with a stride of 4,096 and inserted sheets take indexes in the gaps; layered sheets join and the layer order is read again; imports, and keyframes or functions inserted before a kept sheet with rules, keep the complete build. Control `VOX_DISABLE_RULE_CACHE_EXTENSION=1`. | Both later GitHub sheets extend (26 -> 27 -> 28). Three stage-logged alternating rounds: `style_rule_cache` 0.984 -> 0.342 billion instructions in every round. The faster style pass shifts the page's frame schedule (92-93 layouts against 97-108, four full text paints against five or six), so whole-load totals in two cohorts were within the page's variation. |
| `ae8e869f6` | Animated image frames repaint through the paint transport instead of marking the image box for layout. Control `VOX_RELAYOUT_ON_EVERY_IMAGE_DECODE=1`. | No animated images on this page; one layout pass per frame removed on pages with animated GIF or WebP images. |

The rule cache test compares every bucket (as a set keyed by rule and
sheet), the pseudo-subject index, subject masks, keyframes, invalidation
plans, insights, function definitions and layer order of an extended cache
with a complete build, and checks that sheet indexes follow cascade order;
the image test checks the shown frame's bitmap on the paint command.

**Page result after the layout, style and rule cache rounds.** Bundle
`8be37a6bc450…` (`ae8e869f6`), round 6's grouped LibJS cache reseeded for
the new executable, three alternating rounds at loads of 6-9, all nine
visits valid:

| Three alternating rounds, `8be37a6bc450…` | Median launch to PNG | Median observed instructions |
| --- | ---: | ---: |
| Vox with compiled LibJS | 3,402 ms | 40.44 billion |
| Vox with JavaScriptCore | 2,863 ms | 26.80 billion |
| Brave with V8 | 1,979 ms | 20.34 billion |

Against round 6 (`fe01881e6f67…`: 3,667 ms / 40.90, 3,132 ms / 28.44,
2,043 ms / 20.54 billion), the rendering work brought the JavaScriptCore
load from 28.44 to 26.80 billion instructions. Compiled LibJS still runs
13.6 billion more instructions than JavaScriptCore on the same rendering,
which is now the largest part of the gap to Brave.

## Where the remaining time goes, and per-element style, 2026-11-20 late

Both browsers' captures wait for the page's ready selector and then a
one-second settle period, so launch-to-PNG is the time to rendered React
content plus one second. Thread stage times of one stage-logged load per
engine (`Vox thread stage time` lines) place readiness at about 2,026 ms
with JavaScriptCore and 2,870 ms with compiled LibJS (Brave about 980 ms).
Before readiness the main thread is idle for 337 and 384 ms respectively;
LibJS reaches readiness later because of about 800 ms more main-thread work
(script 756 against 424 ms, posted tasks 245 against 23 ms, and more layout
and style passes interleaved with the slower script). JavaScriptCore runs
about 340 ms of layout and 250 ms of style after readiness, inside the
settle second. Most layout passes come from the browser's draw callback,
not from script; script-forced layout is small.

`tools/benchmark_style_passes.v` styles the frozen page's DOM with its 32
sheets outside the browser, built like the browser. With thread instruction
counts: a full style pass costs about 550,000 instructions per element, and
the first style of inserted content (a deep copy of the body, as script
inserts rendered content) about 405,000 (27 µs). Matching is 43% of
`compute_style`, computed values 26% and the cascade 22%; within matching,
the ancestor-filter checks, compound matching and per-candidate scope
filtering lead, and the earlier per-layer bucket lookups were a smaller
share than expected.

| Commit | Change | Measured |
| --- | --- | --- |
| `aab5a1d32` | Per-target entry counts let style computations skip the animation storage scan for elements without CSS animations. Control `VOX_DISABLE_ANIMATION_TARGET_COUNTS=1`. | Entries of removed elements are never dropped, so the scan grew without bound; repeated insertion in the benchmark reached 14% of style time. |
| `693d65d2a` | Author rules are collected once from a cache indexing every layer, then split by layer. Control `VOX_DISABLE_COMBINED_AUTHOR_MATCHING=1`. | 412,000 -> 405,000 instructions per inserted element, 556,000 -> 549,000 per element of a full pass. |

The benchmark's `signatures` mode finds 273 distinct matched-rule sets
among 2,663 elements: 90% of elements match exactly the rules of an
earlier element (198 have inline styles). A cascade cache keyed by matched
rules, presentational hints, inline style, link state and writing mode
could skip most of the 22% cascade share; that is the next per-element
style lever.

## Per-element style, 2026-11-20 night

A diagnostic build of the style benchmark (`-d vox_css_diagnostics`) lists
the candidate selectors that fail most often after the ancestor filter.
About twenty rules failed for every element: `:link`, `:visited`,
`:heading(n)`, single-argument `:where()`/`:is()` combining a class or
attribute with other conditions, attribute lists such as
`:is([data-color-mode="light"], [data-color-mode="auto"])`, and
`:is(.Banner .Banner-visual) > *`, whose ancestor compound the filter did
not hash. A profile then showed candidate collection costing more than
selector matching, a bounds check emitted out of line by the runtime, and
parse and substitution work repeated for every element.

| Commit | Change | Instructions per inserted element |
| --- | --- | --- |
| `8c3761b88` | Link and heading pseudo-classes bucketed by the tags they require; multi-condition `:is()`/`:where()` subjects by their class, id or tag. Control `VOX_DISABLE_PSEUDO_CLASS_TAG_BUCKETS=1`. | 405,000 -> 382,000 |
| `078f082c3`, `5b9b34225` | `:is()`/`:where()` subjects by a required attribute name (kept out of the disjunctive subject masks). | 382,000 -> 375,700 |
| `1b62906b7` | Single `:is()`/`:where()` arguments of ancestor compounds supply ancestor-filter hashes. Control `VOX_DISABLE_IS_WHERE_ANCESTOR_HASHES=1`. | 375,700 -> 366,700 |
| `e8ac2743d` | The staged prealloc runtime replaces V's fixed-array bounds checks with ones whose panic message is built in a cold helper; clang had kept `v_fixed_index` out of line in every fixed-array index. Applies to the whole browser. | 366,800 -> 327,300 |
| `11cabe765`, `2e5538222` | Shadow-root relevance and quirks checks made once per bucket; ancestor hashes read in place. | 327,300 -> 316,900; 273,100 -> 264,400 |
| `d3237a949` | The style pass asks the pseudo-subject index whether a generated pseudo-element can match. Control `VOX_DISABLE_PSEUDO_CANDIDATE_INDEX_LOOKUP=1`. | 316,900 -> 305,000 |
| `98e3886de` | Computed-longhand reuse covers SVG elements. Control `VOX_LONGHAND_REUSE_HTML_ONLY=1`. | 305,050 -> 303,700 |
| `5ada0bb21` | Parsed SVG presentation attributes (fill, sizes, `d` paths) shared within a style batch. Control `VOX_DISABLE_SVG_PRESENTATION_HINT_REUSE=1`. | 304,000 -> 289,000 |
| `24854b0b0` | A `var()`/`env()` declaration resolves once per custom property environment within a style batch. Control `VOX_DISABLE_ENVIRONMENT_SUBSTITUTION_REUSE=1`. | 288,400 -> 273,100 |

Every change was checked with the benchmark's digests against its control:
`signatures` hashes each element's matched rules, restyle bits and
pseudo-element candidacy, and `computed` hashes every computed longhand of
the page and one inserted copy (5,169 elements, 2,005,572 values). The
earlier signature counts were taken with an empty ancestor filter, which
rejected every rule with ancestor hashes; with ancestors pushed (`539c0fbb2`)
the page has 336 distinct matched-rule sets among 2,663 elements, 87%
repeats.

Rejected after measurement: reusing longhands for equal `d` path data
(+4%: unique paths filled the 256-entry reuse cache; neutral with a larger
cap), skipping the interning of pages already canonical in the batch
(-0.2%), and skipping the descendant walk after a display change when the
document has no CSS animations (the page has some, so the walk stays).

Per element the style computation is now 264,000 instructions: selector
matching 32%, computed values 29%, the cascade 16%, page publication 6%.
Longhand reuse still runs the full computation for pseudo-elements (8% of
computations) and for cascaded values without a snapshot (19%: `d` paths,
`clip-path: inset(50%)`, `calc()` margins and border widths with `rem`),
counted by the rejection report of `f6b73246b`.

A status cohort of the published bundle `f125d53bc05b` (three alternating
rounds) ran while other jobs held the host's load average at 52 to 87 and
the shared pixel-diff tool aborted, so its rows are unvalidated and its
times unusable. Its instruction medians: LibJS 39.4 billion, JavaScriptCore
27.0 billion, Brave 20.6 billion. Whole-load totals include the settle
second, in which faster style lets more frames run; a stage-logged
JavaScriptCore load shows rule matching at 1.54 billion instructions
(2.12 in round 8) and the cascade at 0.85 billion (0.99).

With a pixel-diff build that loads (the shared one links a removed
`libgc.dylib`) and the host back to a load average of about 7.5, four
alternating validated rounds of bundle `f8d1df8f6650` (the same code as
`2e5538222`) gave launch-to-PNG medians of 3,223 ms for compiled LibJS
(40.28 billion instructions), 2,870 ms for JavaScriptCore (27.08 billion)
and 2,069 ms for Brave (20.41 billion), against 3,402, 2,863 and 1,979 ms in
the previous status cohort: LibJS moved from 1.72 to 1.56 times Brave's
time and JavaScriptCore from 1.45 to 1.39. Brave's own time rose by 4.5%,
so part of that is host load. Script remains the largest single difference:
a stage-logged load spends 774 ms in outermost LibJS script against 366 ms
with JavaScriptCore.

Two later changes take the per-element cost to 248,400 instructions,
39% below the 405,000 of the evening:

| Commit | Change | Instructions per inserted element |
| --- | --- | --- |
| `34fc570ef` | The cascade of an earlier element with the same matched rules, hint values, custom property environment, logical context and pseudo-element is replayed within a style batch (complete entry chains, order and presence bits); inline styles, position-try overrides and non-`var()` substitutions cascade anew. Control `VOX_DISABLE_CASCADE_REUSE=1`. | 264,800 -> 253,700 |
| `91636c644` | Parsed SVG presentation attributes are kept for the document across style batches, keyed with the quirks mode. | 253,700 -> 248,400 |

Also measured and rejected: identity-matched longhand reuse for `calc()`
inputs (+8.6% with the 256-entry cache, still no gain with a larger cache
or second-sighting admission), admitting longhand entries only on their
second sighting (-0.6%), copying ancestor-filter hashes into each matching
rule to avoid a pointer load (no time difference beyond noise, more
instructions), and sharing styles between siblings, which only 407 of 2,663
elements could use.

## The capture timeline and layout passes, 2026-11-21

`VOX_TRACE_CAPTURE_READINESS` lines now carry wall-clock microseconds and
the ready selector's state (`2c4b9278f`), comparable with the request
server's `VOX_CURL_TRANSFER_LOG` and the new `VOX_RESOURCE_FETCH_LOG` of
worker fetches (`ee3a1f273`). On an ordinary JavaScriptCore load the
selector matches about 1.41 s after the first trace line; the capture then
waits about 400 ms more for eight image requests and a script-inserted
module stylesheet (`q4…module.css`), which Brave's harness does not wait
for (it polls `readyState` and the selector). Those transfers take 17 to
32 ms; their results wait for the main thread. The initial scripts reach
the main thread 250 to 380 ms after they are requested: the request server
is driven from the main thread's run loop, busy with the first style and
layout then. Letting curl's multi timer fire at cooperative checkpoints
(`8ffe803b2`) did not change those times in alternating loads and was
reverted (`b3778596f`).

With cheap per-pass diagnostics (`VOX_STYLE_PASS_DIAGNOSTICS`,
`VOX_DOCUMENT_LAYOUT_DIAGNOSTICS`, `VOX_LEAF_TIMING_DIAGNOSTICS`) placed
between the readiness transitions:

| Window | Style passes | Layout passes | Paint replay |
| --- | --- | --- | --- |
| launch to interactive (858 ms) | 77 ms | 217 ms in 14 | |
| interactive to selector (551 ms) | 17 ms | 145 ms in 5 | |
| selector to capture readiness (436 ms) | 41 ms | 74 ms in 1 | 200 ms in one frame |

The first painted frame replays its 910 steps in about 200 ms (an inset
box shadow 23 ms, a backdrop filter 20 ms, outer shadows 3 to 6 ms each),
later frames about 58 ms; that is the native drawing backend.

`tools/benchmark_layout_passes.v` (`13a725834`) lays out the frozen page
(3.08 billion instructions for its first style and layout) and times one
layout after a chosen mutation. Any layout tree update cost about 200
million instructions and a complete rebuild 831 million. A script inserting
a `<link>` or `<script>` into `<head>` paid that because the insertion and
the new element's first style each flagged a layout tree update; `fd280697e`
leaves the tree alone when neither box exists (controls
`VOX_RETAIN_HIDDEN_INSERTION_TREE_UPDATES=1`,
`VOX_RETAIN_HIDDEN_STYLE_TREE_UPDATES=1`): 199M -> 2.7M instructions per
pass. A visible text change (`nodeValue`, as React updates text) still
costs 243 million: the incremental pass relays out 1,704 boxes from one
root, because every box laid out for an ancestor's intrinsic measurement
(grid and flex items) disqualifies the boundaries below it, and each pass
then rebuilds the whole paint tree projection (21%) and attaches every
layout node again (10%). Bounding relayout inside measured items, by
showing their min- and max-content sizes unchanged, and retaining the paint
projection of unchanged subtrees are the next layout levers.

The style benchmark's `parse` mode measures the page's 4.1 MB of CSS as
responses are parsed: 982 million instructions, 45% in selector parsing,
which serializes each prelude back to text and parses that again.

## Layout tree updates, paint tracing and frames, 2026-11-21

`VOX_DOCUMENT_LAYOUT_DIAGNOSTICS` on the real load shows that most layout
passes after the first follow a layout tree update (`rebuilds=1`): one
`<img>` receiving a shadow root or one element inserted into `<body>` costs
57 to 127 ms. After a tree rebuild the pass is a complete pass that restores
clean subtrees (`same_tree=false`); incremental relayout roots are only used
when the tree was kept.

The layout benchmark reproduces this with a `<head>` insertion and the
boxless-update controls on (`VOX_RETAIN_HIDDEN_INSERTION_TREE_UPDATES=1`,
`VOX_RETAIN_HIDDEN_STYLE_TREE_UPDATES=1`): a tree update that changes no box
cost 198 million instructions.

- Every screen-reader-only heading is positioned against the initial
  containing block, and an out-of-flow descendant whose containing block was
  outside a subtree blocked that subtree's reuse, so each ancestor of one was
  laid out again. `97d7f5c94` restores such subtrees and lays out the escaping
  absolute boxes again afterwards (control
  `VOX_RETAIN_ESCAPING_ABSOLUTE_BLOCKING=1`; `VOX_INCREMENTAL_LAYOUT_DIAGNOSTICS`
  reports `reuse=blocked reason=`): 198M -> 167M, and a paragraph text change
  244M -> 231M, with no differences from complete passes
  (`VOX_VERIFY_INCREMENTAL_LAYOUT=1`). On the page the change is within the
  run-to-run spread (seven JSC pairs: 26.63B -> 26.52B median instructions).
- Clean subtree reuse rejects any subtree containing a form control
  (`clean_subtree_blocker`: `control`), so the header's `<input>` rebuilds its
  whole ancestor chain (`<body>`, `<main>` and 23 `<div>`s) in every tree
  update. Treating that input as reusable lowered the no-op update to 130M
  instructions in an experiment; doing it safely needs a signature of what the
  input's internal boxes are built from (type, value and placeholder
  attributes and the `::placeholder` style).
- The rest of a no-op update is whole-tree work: the paint tree projection
  (31%, mostly boxes outside the ordinary snapshot path; SVG paths are
  serialized and clip paths converted on every pass), DOM layout attachment
  (13%), counter resolution for kept subtrees that contain list items (9%),
  the style walk (7%) and scrollable overflow (6%).
- Answering a flex item's first (automatic-height) layout call from its
  first-call record in layout passes, as measurements already do, answered
  about four calls per pass and changed nothing measurable.

The benchmark harness enabled `VOX_DIAGNOSTIC_PAINT_LAYER` and
`VOX_DIAGNOSTIC_SCALED_PNG` among its raster parity switches. Both only
trace: every paint command of every frame went to the log (about 10,000 lines
per load), and the paint-layer switch was read with `getenv` inside
per-command loops. `52fe6816f` reads it once and keeps the parity paths
quiet; `ee6cce958` leaves both out of timed runs. In seven alternating pairs
the paint tracing accounted for 0.87 billion instructions (26.68B -> 25.81B
median); wall times in that cohort are unusable (host load rose to 60). The
capture's ready selector (one `:has()` per file row) was evaluated over the
whole document on every frame, about 50 ms per load; `445e6f802` keeps its
answer while the document's tree and attribute versions are unchanged.

A sampled JSC load (main thread, about 1.8 ms per sample) spends about 440 ms
in layout, 600 ms in paint replay with the tracing on, 280 ms in JavaScript and
150 ms in style; the rest of the window is the one-second settle. Stylesheet
parsing does not appear on the main thread. `VOX_LEAF_TIMING_DIAGNOSTICS`
counts four document frames before the capture, each replayed completely:
207, 69, 54 and 56 ms. The glyph rectangle clip parity switch draws each
clipped glyph run through a GPU surface and reads it back synchronously
(`GpuSurface.read_pixels` waits for the command buffer), about 288 runs and
100 ms per load; that switch is enabled only by the benchmark's parity
options.

## Clean subtree reuse on the real load, 2026-11-21

`VOX_CLEAN_SUBTREE_REUSE_DIAGNOSTICS=reasons` on the real load lists the
subtrees each layout tree update rebuilds although nothing in them changed;
each rejected element gets a new box, so its ancestors are laid out again.
The capture renders at device pixel ratio 2 and lays out in device pixels,
which the frozen-page layout benchmark did not do; `6449e5eee` adds
`VOX_BENCHMARK_LAYOUT_SCALE=2`. Fixed in this round:

| Rejection | Cause | Commit | Control |
| --- | --- | --- | --- |
| `replaced` (README badges) | images showing an SVG document | `3bb58511b` | `VOX_RETAIN_SVG_IMAGE_TREE_REBUILDS=1` |
| `marker` (ordered lists) | counter-text markers | `9d9abbdc2` | `VOX_RETAIN_ORDINAL_MARKER_BLOCKING=1` |
| `marker:style` (94 items per load) | under device layout a box keeps a projected style, never the `::marker` object | `db9e6734c`, `32c1fecca` | `VOX_RETAIN_MARKER_STYLE_IDENTITY=1` |
| `anonymous-parent` | inline-level boxes in mixed-content wrappers | `43ccc289e` | `VOX_RETAIN_WRAPPED_SUBTREE_REBUILDS=1` |
| `control` (header search) | text inputs, now kept while their build inputs are unchanged | `0afa74ffc` | `VOX_RETAIN_INPUT_TREE_REBUILDS=1` |

`5ddf3bbe8` makes the diagnostic name the failing marker condition. The
ordered-list test now runs at layout scales 1 and 2. The FastC test runner
crashes on any document with list markers (`attach_list_item_marker`), and
C-backend builds of layout tests exceed the 12 GiB guard, so the list tests
were run as main-module copies, which compile within it.

At scale 2, a layout tree update that changes no box went from 285 to 168
million instructions (marker style alone 285M -> 173M), and the first style
and layout from 3.37 to 3.20 billion; complete-pass verification found no
geometry differences. On the page, seven alternating JSC pairs with all
four reuse controls against none: PNG median 2,868 -> 2,805 ms (faster in
six pairs), instructions 26.00B -> 25.58B; host load 8 to 11.

Still rebuilt in every tree update: an `<svg>` styled `display:flex`, which
the SVG salvage rules accept only with flow display, and SVG elements whose
styles are animated (`VOX_RETAINED_LAYOUT_STYLE_DIAGNOSTICS=1` reports
`differs=animated` 80 times per pass under device layout, where a box's
projected style never shares the DOM style's identity).

## Attribute invalidation reach and the layout gap to Brave, 2026-11-21

`VOX_TRACE_STYLE_INVALIDATION_SOURCES=1` named the cause of the real load's
30 ms style pass that recomputed 1,255 elements for one changed `span`:
React adding class `loaded` to `<react-app>`. No rule mentions `.loaded`,
but the element had no class attribute before, so `[class]` (from
`a:not([class])`) flipped and the attribute name's whole plan applied,
including `[class^=…]>[class^=…]`, which restyles every descendant with a
class attribute. `6637be30c` records whether each attribute test is only
used in the subject compound of its selectors and restyles the element
alone when only such tests flip (control
`VOX_RETAIN_SUBJECT_ATTRIBUTE_INVALIDATION=1`). On the frozen page at scale 2
that class change restyles one element instead of 1,005 (layout pass 307M ->
1.8M instructions). In seven alternating JSC pairs on the page the control
used 26.03 and the change 25.00 billion instructions (median; every run of
the change below the control's median), PNG median 3,664 -> 3,497 ms at a
host load of 14 to 18. `9bcc774dc` keeps `:nth-child(… of S)` arguments out
of the element's own tests, since they count siblings.

The layout benchmark's class mode now takes any element and attribute
(`VOX_BENCHMARK_CLASS_SELECTOR`, `VOX_BENCHMARK_CLASS_ATTRIBUTE=name=value`)
and an insert mode appends and removes an element (`VOX_BENCHMARK_INSERT_SELECTOR`).
The real load's attribute mutations (`style`, `aria-*`, `data-*`, `popover`,
`tabindex`, classes on `<body>`) now restyle one element each; insertions
restyle one to three. Their cost is layout: a script insertion costs 168 to
262 million instructions at scale 2, the floor of the complete pass that
follows any layout tree update (geometry 32%, paint projection 26%, tree
build 12%, DOM attachment 11%, counters 7.5%). The benchmark document has
native storage and no scripting, so it never keeps paint projection
templates (`keeps_paint_projection_templates`) and overstates that share.

Brave's renderer reports for the whole load 159 ms of script, 34 ms of
layout over 16 layouts and 60 ms of style recalculation (82 times). Vox
spends about 280 ms in JavaScriptCore, 350 ms in layout passes and 150 ms
in style, plus about 390 ms replaying paint on the main thread. Blink's
passes are proportional to the change; each Vox pass after a tree update
walks the whole document: elements whose descendants changed get new boxes
(so the root changes and no incremental relayout runs), and the DOM
attachment, counters and paint projection are rebuilt for every box.
Keeping the boxes of elements that only have changed descendants, keeping
the viewport so the incremental relayout path applies after tree updates,
and making attachment and paint projection skip unchanged subtrees are the
structural steps toward Blink's per-pass cost.

## In-place layout tree updates, 2026-11-21

Every layout tree update used to build the whole tree again from a new
viewport: each ancestor of the change got a new box, so the committed root
changed, the incremental relayout could not run, and the pass laid the
document out again from the top while restoring kept subtrees, resolved
counters for every kept element and walked each kept subtree to validate it.
`layout/in_place_tree_update.v` keeps the committed tree when every flagged
element's box is an ordinary block, flex or grid container: it re-syncs that
box's child list (kept child boxes, new boxes for new or restyled children,
dropped boxes for removed ones, anonymous wrappers made again through the
builder's own attachment), gives new boxes layout indexes past those of the
tree, marks the parent for layout and continues with the same-tree path.
Anything else (list items, counters and quotes, SVG, tables, controls,
shadow hosts, first-letter, inline boxes containing blocks) keeps the
complete builder for the whole update, and so does any box built from state
no flag covers once that state changed (image kind and availability, input
build inputs, SVG viewport metrics): the complete builder revalidated those
on every update, so a scan of the kept tree checks them first. Controls:
`VOX_DISABLE_IN_PLACE_TREE_UPDATE=1`,
diagnostics `VOX_IN_PLACE_TREE_UPDATE_DIAGNOSTICS=1` (each decline names its
reason and parent).

On the frozen page at scale 2, appending an element to `<body>` or
`<react-app>` and removing it again costs 121 million instructions per pass
instead of 168 million (insertion) and over 500 million (removal); averages
339M -> 122M. Those parents have no relayout boundary below `<html>`
(`no-root`), so the pass is still a complete one, now over the kept tree. The
remaining per-pass cost is the paint tree projection (overstated by the
benchmark, which keeps no projection templates), geometry and the DOM layout
attachment, which runs twice per pass over every box. Complete-pass
verification found no differences; the tests compare each update's display
list with a complete rebuild (they run as main-module copies: FastC crashes
on list markers). `retained_flow_image_trees_test.v` suspends in-place
updates (`in_place_tree_update_suspended`) to keep exercising the builder's
salvage path. The frozen page's remaining declines are header and box
containers whose rebuilt children hold lists (`counter`).

## Where an in-place pass spends its time, 2026-11-21 morning

Real-page diagnostics (`VOX_IN_PLACE_TREE_UPDATE_DIAGNOSTICS=1`,
`VOX_DOCUMENT_LAYOUT_DIAGNOSTICS=1`, now also naming every request for a
complete rebuild as `VOX_FULL_LAYOUT_TREE_UPDATE reason=`): the main
document's tree updates mostly go in place. Of 18 passes with a tree update
in one load, 14 skip the in-place path for a complete rebuild, but these are
first layouts of small sub-documents (0.2-4 ms each); the page itself asks for
a complete rebuild twice, for its display density at startup. Main-document
declines in three loads: `image-state` (an image not built from an ordinary
or current SVG source), `parent-box` (a flagged `span.prc-Button-Label`
without a box of its own), `anonymous-child` (`article.markdown-body`, whose
README tables have anonymous table wrappers) and `unstyled` (a flagged element
inside a closed popover). Setting an input's `type` requested a complete
rebuild even for an input not in the document; it now flags only a connected
input (d41605962). GitHub's primer stylesheet contains `@position-try`
rules, which also request a complete rebuild when that sheet changes.

Every main-document pass after a tree update, in place or not, is still a
complete geometry pass over the kept tree with subtree reuse: the changed
parents (`<body>`, flex columns, size containers) have no relayout root below
`<html>` (`no-root`). Main-document passes in one uncontended load: 167 ms
(first update, two passes), then 43, 52, 73 and 44 ms; the 44 ms one went in
place. The first update makes two or three passes because container queries
change 14 elements' display from `none` to `flex` once their containers have
a size; Blink styles container descendants during layout instead.

One in-place insertion into `<body>` in the scale-2 benchmark is 118 million
instructions: paint projection 59M, DOM attachment 19M, formatting contexts
17M, style and mutation 10M, scrollable overflow 8M, the in-place update 2M.
Enabling projection templates (as for scripted pages) does not change it.
Two fixes: the in-place update left the tree order invalid, so attachment
kept every box in a hash map instead of its array slot and intrinsic seed
visits were off (779ba0beb renumbers the same order object); attachment
walked each box's whole containing block chain for its absolute offset
(1a2ea67fd memoizes it with projection's coordinate session). The pass is
now 110.4M (attachment 12.7M, formatting contexts 16.0M) and the first update
3.17B -> 3.12B; the complete-pass verifier reports no mismatches in the
insert, class, text and head modes.

Inside projection (44% of the pass): text line rebasing 20%, SVG path
serialization to strings 10% (the string is only read by an SVG export and a
non-empty check; the renderer uses the packed segments), clip-path conversion
9%. Inside attachment: the fixed-position containing block test 13% (ten
`will-change` lookups per box), user-select 6%. These walks visit every box on
every pass; skipping subtrees whose geometry and style the pass restored
unchanged is the structural step that remains.

Same-binary page cohort, 7 alternating pairs, `VOX_DISABLE_IN_PLACE_TREE_UPDATE=1`
against the default (bundle 081b7c69, before the two fixes above): host load
average 16-18 from other sessions' test suites, so times (4.2-5.5 s) are not
usable. Instructions: control median 25.13B, in-place median 24.78B (-1.4%),
with two in-place runs at 27.9B and 28.1B; inconclusive at this noise.

## Wider in-place coverage, 2026-11-21 late morning

The in-place update now handles the real page's earlier declines:

- Flagged elements whose own box cannot keep a re-synced child list (inline
  boxes, buttons and other special elements, elements without a box of their
  own, text nodes whose text became or stopped being white space) escalate:
  the nearest ancestor whose list can be re-synced rebuilds that child
  (1e2f4a555, control `VOX_DISABLE_IN_PLACE_ESCALATION=1`). A rebuilt atomic
  inline no longer counts as an inline box containing blocks.
- A kept box built from state that changed without a flag (an image's kind
  or availability, an input's build inputs, an SVG viewport's natural size,
  other replaced boxes and controls) is rebuilt through the same escalation
  instead of declining the whole update (e8409381d, control
  `VOX_DISABLE_IN_PLACE_STALE_REBUILDS=1`).
- Tables keep their anonymous wrappers (f369c3204); changes inside subtrees
  that are not rendered are skipped (17c3d86ae).
- Each style pass no longer walks every author sheet's effective rules for
  `@property` registrations: sheets record whether they have any and keep
  their registrations until their revision changes (188f28080, control
  `VOX_RETAIN_PROPERTY_RULE_WALKS=1`; -1.0M instructions per benchmark pass).

All of these keep the complete-pass verifier at zero mismatches on the
benchmark's insert, class, text and head passes, and each has a test that
compares the display list with a complete rebuild. Real-page diagnostic load
on bundle 3ab2643a (one load, png 2,711 ms): main-document passes 108 ms
(first update), then 28, 33, 32, 51 and 29 ms, against 167, 43, 52, 73 and
44 ms in the morning load (bundle c86bed6c, host load differed). Remaining
declines: `table-wrapper` on the README article, whose tables sit in inline
`<markdown-accessiblity-table>` elements (block-in-inline), and `table` for
a table added inside a rebuilt subtree.

## Tables, the README article and large relayout roots, 2026-11-21 noon

- New and removed subtrees containing tables update in place: each new
  subtree gets the builder's table fixup pass and a wrapper when its root
  is a table (18ff8b824, control `VOX_DISABLE_IN_PLACE_TABLES=1`); a table
  part outside a table still keeps the complete builder (`table-part`).
- The README article declined every update (`table-wrapper-box`): GitHub's
  markdown clearfix `::before { display: table; content: "" }` sits in a
  table wrapper. The wrapper now counts as the parent's generated box
  (f3e0be85d). Insertions into the article then went in place but cost more
  (337M against 270M with the complete builder in the scale-2 benchmark):
  the incremental attempt laid the article out, its automatic height
  changed, no root above accepted it, and the complete pass redid the work.
- Relayout roots holding a quarter of a tree of 512 boxes or more now go to
  the complete pass directly (c6fe67b22, control
  `VOX_RETAIN_LARGE_RELAYOUT_ROOTS=1`): article insertion 340M -> 239M,
  text change 225M -> 222M, other modes unchanged, verifier clean.

A text change still costs 222M per pass: a full pass whose formatting
contexts take 128M. Its reuse rejections are flex items measured at an
automatic height whose committed record holds the final, definite-height
call (`differs=content-height`), so each rejected container lays out its
whole subtree; list item markers in those subtrees take 8% of the pass.

Same-binary page cohort, 7 alternating pairs, bundle 93fe9b07 (everything
above except c6fe67b22), `VOX_DISABLE_IN_PLACE_TREE_UPDATE=1` against the
default, host load average 5-11 with a production build compiling: PNG
median 3,302 ms (control) vs 3,087 ms (in place), instructions median
24.98B vs 25.33B. Times favour the in-place path; the instruction totals do
not, which this cohort cannot attribute (faster passes can let more frames
run before readiness).

## The JavaScript DOM bridge, 2026-11-21 afternoon

With layout passes cheaper, the DOM bridge stands out. `VOX_DIAGNOSTIC_HOST_CALLBACKS=1`
on the page: GitHub's lazy custom element loader runs, on every animation
frame, `node.matches(tag) ? node : node.querySelector(tag)` and
`customElements.get(tag)` for each added node and pending tag: 48,693
`matches` and 41,513 `querySelector` calls per load. The JSON element query
transport handles 14,655 calls (`VOX_COMPACT_QUERY_DIAGNOSTICS=1`: 112 ms of
native time, 41 ms of it layout under `geometry`; `nativeAttribute` 5,234,
`firstChild`/`nextSibling` 5,401, `documentCreateElement` 362 at 59 µs each).

A JSC microbenchmark (a main-module test timing `evaluate_host` loops with
thread instruction counters, built `-cflags -O2` and signed with the JIT
entitlement) gives per-call costs and their fixes:

| call | before | after | change |
|---|---|---|---|
| `matches(tag)` | 9.0K | 2.4K | tag selectors answered from the record (1c040155c), proxies instead of host wrappers (f9861dca1) |
| `matches(.class)` | 8.8K | 7.2K | proxies |
| `querySelector(tag)` | 8.9K | 7.3K | proxies |
| `getAttribute` | 34.7K | 7.7K | direct `__ladybirdAttributeValue` host query (6aa299b6a) |
| `hasAttribute` | 35.0K | 5.4K | same |
| `createElement("div")` | 220K | 139K | reverse index of native hosts' element maps (faf74bba0) |

Controls: `VOX_RETAIN_TAG_MATCHES_QUERY=1`, `VOX_RETAIN_NATIVE_SELECTOR_HOSTS=1`,
`VOX_RETAIN_ATTRIBUTE_JSON_READS=1`, `VOX_RETAIN_IDENTITY_KEY_SCANS=1`. Every
native host registered all ~2,700 initial elements under `__element_N` keys,
so each element's first bridge key scanned five such maps (~200K
instructions); the wheel host binds every new wrapper, which is why the index
is updated per write instead of rebuilt.

Page cohort, 7 alternating pairs on bundle 7dd00add (selector and attribute
changes, before the host index): all three selector and attribute controls
against none, instructions median 25.54B -> 25.30B, PNG median 2,838 ms ->
2,806 ms (within run-to-run spread).

What remains per element creation is the compact facade itself: native
JSON encoding of the element state (28% of a create in a profile) and JSC
building the wrapper (JSON parse, `defineProperties`, WeakMap writes, ~58%);
`querySelector(tag)` still crosses into native for absent tags (a
per-document census of created local names would let the facade answer).

### A hydration race the bridge speedups tilt

Cohorts on bundle 69e4e247 (all four bridge changes) at host load 30-60
showed loads clustering at ~25.7B or ~28.5B instructions. Per-load JSON
bridge counts explain the clusters: in the expensive loads the page creates
~1,200 elements (133 `td`, 35 `tr`) instead of ~460, i.e. React
client-renders the file table instead of hydrating its server markup. The
tag `matches()` fast path tilts this race (5 of 5 loads with it, 1 of 3
without, VOX_RETAIN_TAG_MATCHES_QUERY=1), although its answers agree with
native matching for parsed, `innerHTML`, created, inserted, shadow, fragment,
template, cloned and SVG elements (checked in a main-module probe). The
faster lazy loader upgrades custom elements before React hydrates that
region; the visible result is unchanged (paint commands 907 vs 908). Why
hydration then mismatches (what an earlier custom element upgrade changes in
the light DOM React compares) is the next thing to establish, together with
whether Brave hydrates or re-renders the table.

Follow-up: in a re-rendering load the README images and `/vlang/v/_sidebar`
are fetched twice, so React client-renders the whole repository overview
root, not just the file table. `VOX_CONSOLE_DIAGNOSTICS=1` (22822b4a0,
3c25359f7: every committed console message and every `reportError()` call)
shows nothing in either outcome: GitHub's `react-app` passes its own
`onRecoverableError` to `hydrateRoot`, which reports to GitHub's telemetry
instead of the console. The outcome follows host load (at load 30-90 most
loads re-render with or without the tag fast path). Vox runs
`requestAnimationFrame` callbacks in rendering tasks queued from the display
link into the same task queue as React's scheduled hydration work, so the
lazy loader's frame batch (which defines and upgrades custom elements inside
the server markup) can run before hydration; identifying the mismatching
upgrade needs the error React passes to that handler.

### The hydration error and what precedes it

A page-world probe installed as a content script in the capture profile
(logging fetch timing, GitHub's `react-root:*` performance marks, errors
created through a proxied global `Error`, and DOM mutations inside
`react-app[app-name=code-view]`) shows, in loads that re-render:

- `code-view` is server-rendered (`data-ssr="true"`) and starts hydrating at
  1.4-2.8 s; React then raises error #418 with argument `HTML` (a structural
  hydration mismatch) and regenerates the whole root on the client. No data
  fetch has completed when the table is recreated, so this is not an update
  racing hydration. The viewport (1024x768, media queries) is stable.
- Parsing is complete well before hydration (`readyState` interactive with
  1,829 elements under `code-view`). By hydration there are 1,948: the only
  mutations in between are GitHub's snippet clipboard behaviour adding a
  `div.zeroclipboard-container` (with its `clipboard-copy` button and icons) to
  each of the README's code blocks, ~0.7 s before hydration.

If React hydrates the README article's children as its own elements, those
inserted containers are exactly an extra-node structural mismatch; the
outcome then depends on whether hydration runs before that behaviour, which
a faster engine wins. Still to confirm: a hydrated (cheap) load showing the
containers inserted after hydration, and Chromium's ordering of the two.

Caveat: GitHub's markdown container (`MarkdownContent`, class
`js-snippet-clipboard-copy-unpositioned`) renders the README through a
component taking an `html` prop with `suppressHydrationWarning`, i.e. most
likely as raw HTML whose children React does not hydrate. Then the clipboard
containers alone would not explain #418, and the mismatching node is
elsewhere in `code-view`; the next probe step is to record which DOM node
React's hydration cursor is on when #418 is created (e.g. by snapshotting the
`code-view` skeleton at render start and diffing it against the archived
server HTML outside the markdown container).

Skeleton check: in a re-rendering load, the probe recorded `code-view`'s node
skeleton (element names, non-whitespace text, comments; the markdown
container's children skipped) when its render started and compared it with
the same skeleton of the archived server HTML: all 3,672 tokens are equal. So
Vox's DOM matches the server markup when hydration begins, and the #418
structural mismatch comes from React's first client render producing a
different tree than the server did: client state that depends on timing
(stores or globals filled by fetches and other scripts before `code-view`
renders) rather than a DOM difference. The next step is to find which
component's output differs (e.g. by hooking the fiber React fails on, or by
comparing the client-render DOM with the server markup after the
regeneration).

After regeneration (skeleton at `react-root:commit:code-view`) the tree
differs from the server's in React 19 resource hoisting (the leading `link`
and `meta` leave the container), removed text-separator comments, and
data-driven additions: `strong` counts beside the branch/tag icons and the
latest commit's avatar/author block under the heading, i.e. content filled
from the `branch-and-tag-count` and `latest-commit` responses. That fits a
client render that already has fetched data the server render did not, but
does not yet name the component React rejected; hooking React's hydration
failure (the fiber passed to its mismatch path) is the remaining step.

### Where hydration fails

Tracking the nodes `firstChild`/`nextSibling` return while `code-view`
renders, the #418 error is created right after React claims
`span.prc-Button-Label` inside a link-styled button (`a.prc-Button-ButtonBase`
> `span.prc-Button-ButtonContent`) and finds no further sibling. The
regenerated tree gives exactly those buttons extra `strong` counts: the
branch and tag count links, filled from the `branch-and-tag-count` response.

The likely mechanism: `code-view` starts its `branch-and-tag-count` and
`latest-commit` fetches as it begins rendering; the local replay answers them
within ~200 ms; Vox's hydration of ~2,000 server nodes through the DOM bridge
takes longer, so when a response lands before hydration reaches those
buttons, the hydrating component renders with the counts, mismatches the
server markup, and React regenerates the whole root (~2.8B instructions).
Brave hydrates in milliseconds, before real network responses arrive. The
engine-side remedy is faster hydration: React walks the server DOM with
`firstChild`/`nextSibling`, which cross the JSON bridge (~14-17K
instructions per call for known nodes, far more for nodes needing a new
wrapper); caching child and sibling links in the facade records, keyed by the
document's tree version, would remove most of those calls.

### Navigation cache (0d7dd3170)

Bundle with the cache, 4 alternating pairs at host load 9-39 (display kept
awake with `caffeinate -d`; an asleep display fails the capture with "Cannot
enumerate test displays"), `VOX_RETAIN_NAVIGATION_QUERIES=1` against the
default: `firstChild`/`nextSibling` bridge calls per load 6,145 -> 4,214
(first visits still cross); instructions median 25.99B -> 25.41B, PNG median
3,601 -> 3,563 ms. The file table was regenerated only in the first pair, in
both arms, so at this load the race is rare either way; the cache's effect on
it needs a loaded host to measure.

A 7-pair cohort right after (host load ~7) reverses the sign: instructions
median 24.38B (cache off) vs 24.93B (on), PNG 3,215 vs 3,305 ms, no
regeneration in either arm. Taken together the navigation cache has no
measurable whole-load effect at these sample sizes; it removes ~1,900 bridge
calls per load but the remaining first visits dominate. Its value for the
hydration race is untested (the race needs a loaded host).

`c5e6f082f` lets record-backed elements read `firstChild` through
`Element.prototype` (the shared common accessors had defined an own
`firstChild` on every wrapper, hiding the cached getter). A stage-logged load
of its bundle `b0dd6d38` makes 1,979 `firstChild` and 1,970 `nextSibling`
bridge calls (3,949 navigation calls against 4,214 with the cache before).

## Where a load spends its main thread, and clipped glyph runs, 2026-11-21 evening

**Stage logs overstate fine-grained stages.** With
`VOX_DIAGNOSTIC_THREAD_LOAD_STAGES`, the reading at a substage's end is taken
before its end line is written, so every substage charges one log write to
its parent. A JavaScriptCore load reports `style_construction` as the
largest exclusive stage (2.43 billion instructions in 14,277 style
computations, each with about six substages), and stage-logged loads run
about 31 billion instructions against about 24.6 billion without the logs.
The style pass diagnostics of the same load count 21 passes and about 4,100
visited elements. Shares of the load are better read from samples.

**Sampled load.** `/usr/bin/sample` attached from process start
(`Build/gh-e10/tools/sampled2.py`, JavaScriptCore, bundle `b0dd6d38`) has
1,664 main-thread samples, about 880 of them waiting:

| Busy main thread | Samples |
| --- | ---: |
| JavaScript (listeners, tasks, microtasks) | ~350 |
| Module evaluation through `[JSValue callWithArguments:]` | ~70 |
| Paint replay (`BrowserApp.draw_command`) | 270 |
| Layout (37 forced by `offsetWidth` reads) | 156 |
| Style | 27 |

Of the paint replay, 158 samples wait in `[MTLCommandBuffer
waitUntilCompleted]` for per-leaf GPU readbacks: clipped glyph runs 60,
SVG path regions 27, sampled images with glyphs 18, shapes 36. Among the
bridge's host functions, finding an element's wrapper for an event target
merges every provider's element map and scans it (27 samples), and
`querySelector` from elements takes 24.

**Clipped glyph runs.** With the raster parity option `GLYPH_RECTANGLE_CLIP`
(which these captures use), a text run inside a rectangular clip drew its
interior on the CPU and the whole run again on a new GPU surface with the
clip (backdrop upload, alpha mask draw, synchronous readback), then took
from that draw only the pixels outside the clip's fully covered squares.
When the glyph mask has no coverage on any of those pixels, neither draw
changes them, and the GPU draw is skipped (`67f206603`, `f4d03d113`; control
`VOX_RETAIN_COVERED_GLYPH_CLIP_DRAWS=1`). Of 286 clipped runs in a load, 258
skip it; `VOX_VERIFY_COVERED_GLYPH_CLIP_DRAWS=1` still draws and merges them
and found no differing pixel in any of the 258.

**First-call answers.** A column flex container lays each item out at its
automatic height and then at its flexed height; the committed record is the
second call's, so the next pass laid every clean item's subtree out again for
the first call. `124299978` answers that call from the first record when the
subtree is clean and the inputs match, and then always makes the second call
(control `VOX_DISABLE_FIRST_CALL_ANSWERS=1`). The scale-2 layout benchmark's
text pass goes from 219.5 to 218.2 million instructions, with the
complete-pass verifier clean; a load answers about seven calls.

Five alternating rounds of bundle `4e5a2f6497f2` (`f4d03d113`), all 20 visits
valid, host load average 12-17 from other sessions:

| Arm | Median observed instructions | Median launch to PNG |
| --- | ---: | ---: |
| Vox with JavaScriptCore | 23.91 billion | 3,722 ms |
| `VOX_RETAIN_COVERED_GLYPH_CLIP_DRAWS=1` | 24.81 billion | 4,054 ms |
| `VOX_DISABLE_FIRST_CALL_ANSWERS=1` | 24.24 billion | 3,758 ms |
| Brave with V8 | 20.97 billion | 2,424 ms |

The skipped glyph draws save about 0.9 billion instructions (the per-run
surfaces cost Metal driver work beyond the readback waits) and 330 ms at this
load. The first-call answers are within the rounds' variation. One default
visit regenerated the file table (27.87 billion, 4,484 ms). Vox now observes
1.14 times Brave's instructions; times at this host load are not comparable.

## Reused leaf render targets, 2026-11-21 evening

Removing 258 clipped glyph draws saved about 3.5 million instructions per
draw, while a main-thread microbenchmark of one draw counted about 1.0
million: most of a GPU leaf's cost lands outside the calling thread. With
process counters, a rectangle leaf on a new tile-sized (1056x416) surface ran
1.79 million instructions and 0.63 million on a reused one; creating and
freeing the surface's color, depth and multisampled images and attachments
was the difference. `e69f0cf78` gives every GPU paint leaf its render targets
from a four-entry pool kept by the staged gg.canvas surface helper
(`new_document_leaf_surface`/`release_document_leaf_surface`); each leaf still
builds a new `GpuSurface`, so draws, clips and matrices start empty, and only
image contents carry over, which leaves overwrite, clear or (region leaves)
read back only where they uploaded. Control `VOX_GG_FRESH_LEAF_SURFACES=1`.
A test compares 60 pooled region and glyph leaves with new surfaces byte for
byte.

Five alternating rounds of bundle `0e4e77d8ddb3` (`e69f0cf78`), all 15 visits
valid, host load average 12-20:

| Arm | Median observed instructions | Median launch to PNG |
| --- | ---: | ---: |
| Vox with JavaScriptCore | 23.76 billion | 2,751 ms |
| `VOX_GG_FRESH_LEAF_SURFACES=1` | 24.49 billion | 2,730 ms |
| Brave with V8 | 20.81 billion | 2,074 ms |

Every Vox capture of both arms has the same pixels (the PNG files differ only
in their encoding metadata). The pool saves about 0.73 billion instructions;
times are within the round-to-round variation at this load. Vox observes 1.14
times Brave's instructions.

## Custom element construction and the wheel host's element map, 2026-11-21 night

Summing the bridge's native time per action (`VOX_COMPACT_QUERY_DIAGNOSTICS`)
put `documentCreateElement` first: 69 ms for 537 calls, 50 ms of it in 73
`relative-time` elements at about 683 µs each. A JavaScriptCore
microbenchmark on a 2,700-element document showed `createElement` of a custom
element with an empty constructor at 14.9 million instructions, against 153
thousand for a `div`: the HTMLElement constructor asks for the new element's
wrapper, and the wheel host answered by copying every element provider's map
into its own and scanning it, which also invalidated the reverse key index
that the next identity lookup then rebuilt. `7c877c6eb` resolves the wrapper
key from the providers' reverse indexes when they know the element by a
single key (the only entry the refresh would have added or changed for it);
several keys keep the refresh. Control `VOX_RETAIN_WHEEL_ELEMENT_REFRESH=1`.
The microbenchmark goes to 257 thousand instructions per custom element (the
`relative-time` constructor pattern 18.2 million -> 385 thousand). On the
page, `relative-time` creation fell to about 188 µs and `div` creation from 76
to 7 µs on average.

Seven alternating rounds of bundle `f1ce8fd57ebb`, all 21 visits valid, host
load average 22-40: instruction medians 23.41 billion (default), 23.47
billion (control) and 20.73 billion (Brave). The expected saving, about 50 ms
of main-thread work, is below the rounds' variation at this load; the
captures of both arms have identical pixels. Times at this load are not
usable.

## Frames during the load and repeated shadow leaves, 2026-11-21 night

`VOX_LOAD_RENDER_THROTTLE_DIAGNOSTICS` and `VOX_LEAF_TIMING_DIAGNOSTICS` on
one load: about ten frames. The first costs 350-700 ms (the first style pass
65 ms over 2,552 elements, the first layout 118 ms in two passes, the second
for container queries, and a 108 ms paint replay of 910 steps); each later
frame replays the same ~910 steps in 28-34 ms. The slowest later steps were
four box shadows at 2-3.4 ms each, every frame. `beece9cb0` adds
`VOX_DIAGNOSTIC_PAINT_FINGERPRINT`, a hash of each recorded display list's
dump; six consecutive recordings hashed alike, but the dump omits glyph,
image and path content, so equal hashes do not prove equal pixels and no
frame skipping was built on it.

Two of the shadows carry a filter clip and were drawn on a whole tile
(1056x416 at scale 2) holding only the leaf's backdrop rows. `5251059d5`
let whole-surface shape draws use the leaf raster cache, which helped only
small surfaces: a tile's transfer exceeds the cache's 512 KB entry limit.
`981c11e35` therefore caches such tile leaves by what the tile holds (the
descriptor, tile size, sample count, the leaf's position and backdrop rows)
and keeps only the leaf rectangle, which is all the caller publishes
(control `VOX_RETAIN_WHOLE_TILE_SHAPE_DRAWS=1`). Those two shadows left the
slow list; two alternating pairs against the control had identical pixels.
The other two slow shadows belong to shadowed avatar images drawn through
another path; only 14 image tile draws happen in a whole load, too few to
cache.

## Bridge writes and insertions, 2026-11-21 late night

A JavaScriptCore microbenchmark of common DOM operations on a 2,700-element
document showed writes costing 15 to 100 times a read (`getAttribute` 8
thousand instructions; `setAttribute` 146 thousand, `appendChild` of a
created element 157 thousand, moving an existing node 327 thousand). Two
protocol costs dominated:

- Every native attribute write first replayed the facade: it evaluated
  `__ladybirdFinalize(true)` as script text, encoded the facade state as JSON
  and decoded and applied it natively, even with nothing pending. The facade
  now passes whether it has pending edits or canvases, and without them the
  native side only settles custom element reactions (`fec4001cd`, control
  `VOX_RETAIN_TRUSTED_ATTRIBUTE_REPLAYS=1`): `setAttribute` 147 thousand -> 79
  thousand instructions, `className` writes 215 thousand -> 148 thousand.
- Insertions sent the child's whole facade state (about 1 KB) with every
  request, although the native handler reads it only for a child it does not
  own. Requests now carry the keys, and the facade sends the state only when
  the native side answers "Unknown child node" (`6ba648122`, control
  `VOX_RETAIN_COMPACT_CHILD_STATES=1`): `appendChild` of a created element 157
  thousand -> 53 thousand, moving a node 327 thousand -> 153 thousand.

(A whole-document walk for `<meta name="color-scheme">` after each
`textContent` write appeared only in the benchmark: GitHub's page has that
meta early in its head, where the walk stops.)

On the page the bridge's native time (`VOX_COMPACT_QUERY_DIAGNOSTICS`) fell
from 193 to 139 ms per load; `appendNode` went from 20 to 7.5 µs per call.
The largest remaining action is `geometry`, 18 script-forced layouts at about
3.6 ms each.

Seven alternating rounds of bundle `7a2e4ab4f2c7` (`6ba648122`), all 21
visits valid, host load average 10-28:

| Arm | Median observed instructions | Median launch to PNG |
| --- | ---: | ---: |
| Vox with JavaScriptCore | 22.33 billion | 3,623 ms |
| both controls above | 22.47 billion | 3,743 ms |
| Brave with V8 | 20.61 billion | 2,362 ms |

The two bridge changes are within the rounds' variation on their own; the
arms' captures have identical pixels. With the leaf, shadow and custom element
changes of this session, Vox observes 1.08 times Brave's instructions
(against 1.14 at the start of the session).

## JIT thresholds, network work and layout roots, 2026-11-22

**JIT thresholds.** `JSC_dumpOptions=1` shows that the system JavaScriptCore
honours `JSC_*` options and already runs with `thresholdForJITAfterWarmUp=10000`
(its documented default is 500); nothing in Vox or the harness sets it. Four
alternating rounds at host load 5-10: 22.97 billion instructions and 2,605 ms
(as shipped), 22.88 billion and 2,575 ms (warm-up 500, soon 100), 23.58
billion and 2,573 ms (100/20). Earlier tier-up adds compilation without
reducing total work; no change was made.

**Network work on the main thread.** A sampled load spends about 115 ms of
main-thread time in curl (`curl_multi_socket_action`: TLS record reads,
handshakes, header handling); the request server is driven from the main run
loop, so the four XHR responses requested at 1.62-1.70 s all completed at
about 1.93 s, when the main thread returned to the run loop. Brave does this
in its network service. Running the curl multi handle on a dedicated thread
and queueing header, body and completion events to the main thread would free
that time; it needs the multi handle's add, remove and pause operations
marshalled to that thread and is not done.

**Layout roots.** Of the hydration passes with tree updates, two declined the
incremental path for `no-root` and one for too many changes. Every box laid
out during an ancestor's intrinsic measurement is marked
`sized_by_ancestor_measurement_`, and no relayout root may sit below such a
box; on this page that is nearly everything below the flex columns. A box with
both dimensions fixed or with size containment would be a safe boundary, but
the page uses `contain: layout size` once and `content-visibility: auto`
sixteen times, so it would not apply to the hydration changes. Allowing roots
inside measured subtrees needs proof that each measuring ancestor's inputs are
unchanged, the main remaining layout project.

**JavaScriptCore's own profile.** `23a7f2e61` adds `VOX_JSC_SAMPLING_PROFILE=PATH`,
which enables JavaScriptCore's sampling profiler (the exported
`JSContextGroupEnableSamplingProfiler` SPI) and writes its stack traces when
the capture writes its audit. One load (bundle `bc8837a4fb6a`) recorded 328
samples at 1 ms while JavaScript ran: 183 (56%) had a native host function as
the innermost frame, 43 were in the interpreter (LLInt), 22 in baseline code
and 8 in the optimizing tiers. The host samples split into:

- forced layout from geometry reads (`__compactReadElementGeometry`, called
  by primer-react), the single 65 ms `offsetWidth` layout;
- selector queries from GitHub's lazy custom-element loader (`pb-*.js`), which
  checks every added element against each pending tag with `matches` and then
  `querySelector`; about 28 samples;
- tree navigation and writes during React hydration and commit (`get`
  accessors, `flushDOM` from setters, insertions, inline style writes).

So about half of the time inside JavaScript is spent in the native DOM work it
calls, and the page's own code accounts for the other half.

**Settle frames and the retained raster.** Per-thread counters (an injected
dylib reading `PROC_PIDTHREADCOUNTS` at exit) put 19.6B of 23.2B process
instructions on the main thread. `VOX_DIAGNOSTIC_PAINT_FINGERPRINT` and
`VOX_LEAF_TIMING_DIAGNOSTICS` then showed 8-11 frames after the last layout,
while Primer skeleton placeholders animated `mask-position`
(`prc-Skeleton-shimmer`), each re-rasterizing the whole display list (~910
commands, ~22 ms, ~0.3B instructions). Three backdrop-filtered header buttons
kept the scroll raster ring from retaining pixels
(`VOX_SCROLL_RASTER_REJECT reason=unsupported-command:apply_backdrop_filter`).
`13d04cee8`/`400ca99a9`/`3a8b525dc` let the ring keep lists with bounded
backdrop filters, also inside effect layers: a backdrop's key ink is the
region it reads, and damage touching it repaints all of it. Same-binary
cohort on bundle `9587655f69f2` (5 alternating pairs, host load 6-7.7):

| Arm | Median | Range |
|---|---:|---:|
| ring keeps backdrops | 22.474B | 21.696-22.922B |
| `VOX_RETAIN_BACKDROP_RASTER_REJECTION=1` | 23.818B | 22.498-25.084B |
| Brave | 20.729B | 20.103-20.824B |

Every Vox capture differed from the Brave reference by the same 2 pixels in
both arms. The earlier bimodal totals (~22.9B vs ~24.5B) track how long the
skeletons stay visible, which sets the number of such frames.

**Hydration order.** In Brave the deferred module scripts run back to back
after parsing, the code view's React root starts and commits, and only then
does GitHub's lazy element loader (which scans in an animation frame) start
the page's React partials. Vox took rendering opportunities between its
deferred scripts, so the partials sometimes started first and the code view's
hydration failed with React #418. `9b0f47818` skips rendering updates while
deferred scripts can make progress; probe loads then always commit the code
view first, as Brave does. That ordering did not change the totals, which were
dominated by the settle frames above.

**Layout roots.** The `VOX_INCREMENTAL_LAYOUT_DIAGNOSTICS` census
(`c1923f3bd`/`69a551b86`) found three reasons for complete passes: block
layout's min-height probe marked the `min-height: 100vh` app shell as
measured (`3923309c1` releases those marks when the probe is ignored),
detached origins left by in-place tree updates (`813cb4349` drops them), and
origins under plain blocks near the top, which have no recorded ancestor.
The incremental pass also carried every committed retained layout, so a
replaced inline box could be painted from stale lines; `923d3d3d4` carries
only those outside the relayout roots. The GitHub hydration passes still
run complete (large roots, plain-block ancestry), so these did not change its
totals.

**Validated state.** The tighter backdrop read region (`3a8b525dc`) and the
group-end ink fix (`3af83c53e`) keep the expected capture. Damaging
reordered commands instead of the paint-order fallback (`e2463b19b`,
reapplied as `23e225131`) left 273 stale skeleton pixels in most captures
and was reverted twice (`9d93490d5`, `c79c319c6`). Same-binary cohort on
bundle `1960b37b1aa9` (6 alternating pairs, host load 5.3-6.1):

| Arm | Median | Range | Pixels vs Brave reference |
|---|---:|---:|---:|
| current | 22.455B | 22.303-22.844B | 2 in every run |
| `VOX_RETAIN_BACKDROP_RASTER_REJECTION=1` | 23.778B | 22.709-24.721B | 2 in every run |
| Brave | 20.456B | 19.993-20.604B | 0 |

The median ratio to Brave is 1.10; the conservative highest-Vox to
lowest-Brave ratio is 1.14.

**Raster layers in retained-raster keys.** The one full replay left per load
was the paint-order fallback when the sponsor button's `pulse-in` animation
ended: its effect layer left the display list, and the header buttons'
equal group ends matched the removed end out of order. Removing that
replay exposed 273 stale pixels on the branch button. The animation had
given the heart a Chromium raster layer of its own and moved the following
button into another layer, so the button rasterized with a different
origin and phase, yet its key did not change; the fallback's full replay
had been repainting it. `573ac81e5` mixes each command's raster-layer
signature into its key (`VOX_RETAIN_LAYER_BLIND_RASTER_KEYS`), which
repaints moved commands and also separates the ends, so the animation's end
now repaints only what changed. `0e132a3d6` additionally keys each group end
by its begin (`VOX_RETAIN_SHARED_GROUP_END_KEYS`); on this page it is neutral
(8 pairs: 22.101B vs 22.134B median). Cohort on bundle `fca5a9cf1543`: Vox
about 22.1B, Brave 20.63B median (6 runs, 20.40-20.86B); every Vox capture
2 pixels from the Brave reference.

**Paint projection.** Stage-logged loads (`5103a3826`, `465cbc3db`,
`021646346`, `344b253c8`) split the remaining work. Pulse frames of the
sponsor heart's `pulse-in` animation re-record, hash and plan the whole
viewport (about 40-60M each), and how many occur before capture varies
between loads. The largest repeated cost, though, is the renderer box
projection: about 12 complete projections per load at 70-80M each
(stage-logged), 8 of them inside layout passes and the rest full paint
refreshes after compositor-category or non-local style changes. In the
layout pass benchmark's text mutation pass (scale 2) the projection was a
quarter of the pass, and SVG paths alone (serialization, bounds,
flattening for about 190 octicons) a sixth of the projection.

- `06b1c9033` memoizes each SVG path's serialization, bounds and packed
  segments by complete path content (verified on every hit), in capped
  persistent storage (`VOX_DISABLE_SVG_PATH_PROJECTION_MEMO`): text pass
  218.6M -> 198.8M.
- `97af4b88a` resolves scroll-margin only for snap areas and scroll-padding
  only for snap containers, the only readers
  (`VOX_RETAIN_ALL_SCROLL_SNAP_EDGES`): 198.8M -> 195.9M.

Same-binary cohort on bundle `97af4b88a` (6 alternating pairs, host load
5.9-7.7; control sets both switches):

| Arm | Median | Range | Pixels vs Brave reference |
|---|---:|---:|---:|
| current | 21.263B | 20.827-22.009B | 2 in every run |
| both switches | 22.005B | 21.237-22.191B | 2 in every run |
| Brave | 20.490B | 20.400-21.101B | 25 in every run |

The candidate is lower than its control in every pair (0.18-1.13B). The
median ratio to Brave is 1.04; the conservative highest-Vox to lowest-Brave
ratio is 1.08.

**Changed-subtree paint refreshes.** Four or five complete projections per
load were paint refreshes the local refresh could not apply: the heart's
`pulse-in` animation adding and removing its transform (a compositor
category change) and transitions sampled on header buttons. `392eec0ef`
projects the retained parent of each changed box again in place, in the
snapshot's own storage, and then rebuilds the plans that read box
identities exactly as a complete refresh does; roots, body children,
fragmented boxes and updates of more than 64 boxes keep the complete
refresh (`VOX_DISABLE_PAINT_SUBTREE_REFRESH`). Every refresh on the page
takes the subtree path (16 changed buttons collapse to one subtree).
Same-binary cohort on bundle `392eec0ef` (6 alternating pairs, host load
4.1-7.3):

| Arm | Median | Range | Pixels vs Brave reference |
|---|---:|---:|---:|
| current | 21.089B | 20.547-21.759B | 2 in every run |
| `VOX_DISABLE_PAINT_SUBTREE_REFRESH=1` | 21.462B | 21.187-21.910B | 2 in every run |
| Brave | 20.526B | 20.349-20.908B | 25 in every run |

The candidate is lower than its control in every pair (0.10-1.00B). The
median ratio to Brave is 1.03; the conservative ratio is 1.07.

**Hardware SHA-256 and stationary culling.** A main-thread sample showed
vlib's portable SHA-256 block function at about 12 sampled milliseconds per
load: the disk cache hashes every response body when a fetch worker stores
it and again when the document reads the script back, and image sampling
keys hash encoded bytes. `790a8dde7` adds `fastsha256` (CommonCrypto on
macOS, identical digests, `VOX_PORTABLE_SHA256`). `1fdbd2abe` skips canvas
culling in the per-frame stationary eligibility scan when no video exists
(`VOX_CULL_STATIONARY_COMMANDS_WITHOUT_VIDEO`, about 3.9M per frame
stage-logged); its 7-pair cohort was within noise (21.129B vs 21.057B
control). Cohort on bundle `790a8dde7` (7 alternating pairs, host load
3.4-4.0):

| Arm | Median | Range | Pixels vs Brave reference |
|---|---:|---:|---:|
| current | 21.343B | 20.436-21.476B | 2 in every run |
| `VOX_PORTABLE_SHA256=1` | 21.611B | 20.730-22.046B | 2 in every run |
| Brave | 20.516B | 20.363-20.862B | 25 in every run |

The candidate is lower than its control in 6 of 7 pairs (mean 0.30B).
Medians move between cohorts with the number of `pulse-in` frames before
capture; the paired deltas are the reliable signal. The conservative
highest-Vox to lowest-Brave ratio is 1.05.

Remaining identified cost outside the engine: TLS. The page's responses are
decrypted on the main thread by macOS's system libcurl, whose LibreSSL
runs AES-GCM in portable C (`gcm_ghash_4bit`, `AES_encrypt`: about 27
sampled milliseconds per load). Homebrew's libcurl (OpenSSL with ARMv8
crypto, TLS 1.3, Apple trust) would remove most of it, but
`platform/curl_api_darwin_test.c` deliberately pins the system library.

**Duplicate style sheets.** `VOX_CSS_PARSE_DIAGNOSTICS` (`57c0786da`)
showed the 300 KB `primer-react-css` module sheet converted five times: the
archived page links it once in each server-rendered React partial. Each
repeat reused the cached rule syntax (about 24M instead of 123M
stage-logged), but every copy's rules were indexed again, multiplying the
candidates each element tests and the invalidation sets each mutation
consults. Removing the four repeated links from a copy of the archive
lowered a load from 21.33B to 20.66B (4 runs each, 2 px). `fd524cb06`
indexes one copy at the latest copy's sheet index (complete builds skip
earlier copies; an extension appending a copy moves the indexed rules to
its index). Copies qualify when they come from the same cached source
bytes at the same location and media, CSSOM has not changed their rules or
declarations, and they contain no `@import`, `@scope` or anonymous
`@layer`; keyframes are still registered from every copy
(`VOX_INDEX_DUPLICATE_STYLE_SHEETS`). Cohort on bundle `fd524cb06` (6
alternating pairs, host load 6.4-7.5):

| Arm | Median | Range | Pixels vs Brave reference |
|---|---:|---:|---:|
| current | 20.277B | 20.043-21.160B | 2 in every run |
| `VOX_INDEX_DUPLICATE_STYLE_SHEETS=1` | 20.788B | 20.349-21.383B | 2 in every run |
| Brave | 20.613B | 20.512-21.114B | 25 in every run |

The candidate is lower than its control in 5 of 6 pairs (mean 0.42B). Its
median is below Brave's (ratio 0.98); the conservative highest-Vox to
lowest-Brave ratio is 1.03, so the spread of Vox runs (mostly the number of
`pulse-in` frames before capture) still keeps the bound above parity.

**What sets the upper tail.** Diagnostic loads on bundle `fd524cb06`
correlate the spread of Vox runs with two timing effects. The sponsor
heart's `.anim-pulse-in` (0.5 s `scale3d`) produced 0 to 16 main-thread
frames before capture; loads without them measured 20.19-20.49B, loads
with 16 measured 21.09-21.58B (roughly 40-55M per frame). Brave runs that
transform animation on its compositor. Each such frame re-records the
display list, hashes every command's retained-raster key (about 6.2M
stage-logged) and rebuilds the Chromium raster layer plan (6.6-7.4M, 80%
of it in layerization, `ad5eec55b`). Separately, how page work batches
into rendering updates varies: one slow load ran 11 layout passes where
another ran 5, and each extra pass is a complete pass of 15-30 ms even for
one changed node (an image switching to alt text, a removed span).

JSC tier-up thresholds are not a lever: an earlier Baseline JIT
(`JSC_thresholdForJITAfterWarmUp=100`) measured 21.05B and an earlier DFG
22.36B against 20.76B default (5 runs each); a later JIT and a disabled DFG
stayed within noise of the default (20.65B, 20.35B vs 20.19B).

**Per-frame plan and replay costs.** `c4e5cd82f` asks the damage plan
before culling a leaf (a reused frame skipped about 890 of 910 commands
only after computing each one's ink bounds; `VOX_CULL_DAMAGE_SKIPPED_LEAVES`).
`f55a26f30` split layerization: hit-test metadata collection was 4.0M of
the 6.6M plan, chunk construction 1.4M. `cc266556e` resolves each box's
clip, compositor effect scope and paint client once per layerization
(`VOX_DISABLE_RASTER_PLAN_MEMOS`): metadata 4.0M -> 2.7M, chunks 1.4M ->
1.0M, plan 6.6-7.4M -> 5.7-6.4M per recording (stage-logged). A 7-pair
cohort with both switches as control could not resolve these frame-level
savings (candidate 20.976B, control 20.727B, Brave 20.621B; pair deltas
-0.26 to +0.88B, 2 px in every Vox run); the spread between cohorts on the
same bundles is larger than the effect.

JavaScript reads of `offsetWidth` force layout for 47 sampled
milliseconds per load, 28 of them geometry and 4 paint projection.


**A second complete raster, and why it stays.** The first document frame
always chose layer deferral, because the choice followed the previous
frame's scroll-raster eligibility, and a deferred frame cannot enter the
retained-raster ring. The next frame then found no retained pixels and
rastered the whole viewport again (450M stage-logged). Native deferral has
been a no-op since the Skia removal. `772a5ce56` decided from the frame's
own commands and removed the second raster, but in 2 of 7 cohort runs the
Star button's top-left corner kept a lighter anti-aliased pixel pair (233
instead of 223; 4 differing pixels instead of 2). The control and Brave
were unchanged, and the gain was within noise (pair mean -0.08B; candidate
20.831B, control 20.904B, Brave 20.565B), so `06c7eadd8` reverted it. The
corner comes from a complete raster: no damage rect covers the button, the
button stays in the root raster layer, and root tile 0 multisamples in
every state. It has the same signature as the long-standing 2 px at the
Notifications button's corner, and the second complete raster had been
hiding it. Diagnostic runs (8 loads with damage logging) never reproduced
it.

**Where the rest goes.** In an uninstrumented sample of a 20.06B load, the
main thread has 78% of busy samples (1023 ms). By category: JavaScriptCore
276, style 185, layout 136, copies and allocation 114 (spread over many
callers), network 49 (22 of them LibreSSL AES-GCM), DOM 40, bridge 39,
HTML parsing 36, text 34, paint 34, JSON 24. The coalition total also
includes `VoxAdblockWorker` at 0.63B per load: a JavaScriptCore context
running the filter engine.
- The compact bridge made 11,005 host calls in one load (1,854
  `nextSibling`, 1,828 `firstChild`, 2,593 attribute reads, 707 DOM
  flushes, 594 `querySelectorAll`). Most take a few microseconds. Three
  `offsetWidth` reads took 59 ms, all in the first, which forced a layout
  of 4,401 nodes that hydration had just inserted (76 detached relayout
  origins, `too-many-changes`). That is new content, not a reuse miss.
- JavaScriptCore's sampling profiler puts 137 of 262 JavaScript samples in
  host functions and about 25% under `__queryElements`. React reads a
  bridge getter (19 samples), and GitHub's `pb-*.js` calls
  `querySelector`/`matches` (about 24).
- Stylesheet parsing is 52 sampled ms: rule conversion 24, of which
  selector lists 19 (12 in uncached selector parsing), tokenizing 14. The
  parse benchmark (`style_passes ... parse`) runs at 250 instructions per
  byte but bypasses the document selector memo, so it overstates selectors.
- A complete layout pass in `layout_passes ... full` costs 829M for 2,663
  elements. Its hotspots (cmap table lookups that allocate a string per
  table record, `viewBox`/path re-parsing, the style-computer hook checks)
  come from rebuilding every layout node. Each has at most 3 samples on
  the real page, where layout nodes and their caches persist.

**TLS library.** The macOS system libcurl (8.7.1, LibreSSL 3.3.6) runs
AES-GCM in portable C. A local benchmark measured each library's client
instructions: a C client loaded the library, then downloaded 160 MB five
times from a Python `ssl` server configured like the replay server.

| Library | Instructions per MB | Fixed per process | Notes |
| --- | --- | --- | --- |
| System, LibreSSL | 25.9M | about 26M | |
| Homebrew curl 8.23, OpenSSL 4.1 | 14.2M | about 93M | its dependencies are outside the dyld shared cache |
| System, SecureTransport | 7.4M | about 39M | about 3x slower to transfer, TLS 1.2 only, needs `serverAuth` certificates |

The replay serves 160 responses totalling 10.4 MB per load. Homebrew curl
(`72544becc`, with SecTrust verification through `CURLSSLOPT_NATIVE_CA`)
would therefore save only about 55M on this page, and make every page
under about 6 MB slower (Hacker News by about 4%), so `4a04a85f8` reverted
it. Preferring ChaCha20 does not help: the replay server, like most servers,
chooses ciphers in its own order.

**Adblock responses, bridge navigation, inline runs and in-place updates.**
- `364379e53`: the request-stage check now also reports whether any
  headers-realm filter could match the request with some response headers
  (`mayMatchHeaders`, which treats header conditions as satisfied; filters
  are conjunctions). `check_response` answers from that retained verdict
  without serializing headers or asking the worker. On the archived GitHub
  manifest all 164 responses (239 KB of header JSON) have no candidate; the
  load makes about 508 such checks. `VOX_CHECK_ALL_ADBLOCK_RESPONSES=1` is the
  control.
- `00ac2cff4` and `7e35714df`: the document keeps its tree version in a
  native cell, which JavaScriptCore reads as a `Uint32Array` without a host
  call. Text, comment and other nodes now share the elements' version-keyed
  `firstChild`/`nextSibling` cache, which React hydration (`getNextHydratable`)
  walks. The controls are `VOX_RETAIN_TREE_VERSION_HOST_CALLS=1` and
  `VOX_UNCACHED_NODE_NAVIGATION=1`.
- Inline runs (`ddc04088f`, `VOX_INLINE_RUN_REPEAT_DIAGNOSTICS=1`), measured
  on `layout_passes` over the GitHub style benchmark page:

  | Mode | Runs building items | Exact repeats in the same pass | Repeats in the same layout state |
  | --- | --- | --- | --- |
  | `full` | 40,000 | 25,850 | 20,820 |
  | `insert` | 23,000 | 18,045 | 14,722 |

  All repeats are normal-mode, definite-width runs, mostly in the main state.
  In `full` mode, 7,392 repeats are in contexts whose inputs can be
  collected but are skipped by the retained-inline backoff (8,026 backoff
  outcomes). The rest are blocked by content that snapshots cannot record:
  generated content 4,359, table-cell roots 1,789, atomic inlines 1,274,
  inline-block roots 1,082, SVG 624, replaced 312. The backoff limits
  durable snapshot growth between passes, so letting same-pass repeats
  collect would need memory measurements as well as instruction counts.
  Generated, atomic and SVG children need a snapshot of their own subtree.
- In-place layout tree updates (`20ee24d78`,
  `VOX_IN_PLACE_TREE_UPDATE_DIAGNOSTICS=1`) report the boxes they build, by
  why the element's previous box was not kept. Two passes after hydration
  laid out 2,011 and 4,710 nodes without committed values, through in-place
  updates that added 35, then 9, subtree roots. React creates about
  460–550 elements through the bridge, and `setInitialProperties` is its
  busiest bridge caller, so part of this is client-rendered DOM. The new
  counts separate it from restyled existing elements, whose clean
  descendants an in-place update currently builds again
  (`allow_subtree_reuse = false`). Clean-subtree reuse in the complete
  builder never runs on this page (0 roots in every pass).

**Measured on bundle `0aaaa21ac`.**
- `a036cce9a` replaced the one-field `json2.decode` of the retained request
  decision with an exact suffix test. With the decode, the production bundle
  aborted on this page with a garbage allocation size.
- `233a81a21` calls `voxAdblockCheck`/`voxAdblockCheckResponse` directly with
  JSON-parsed arguments instead of evaluating a new script per check
  (`VOX_EVALUATE_ADBLOCK_CALLS_AS_SCRIPTS=1` is the control).
- `0aaaa21ac` fetches a parent's first 64 children on its first navigation and
  records their siblings (`VOX_DISABLE_NAVIGATION_PREFETCH=1` is the
  control). Bridge queries on one load:

  | Arm | `firstChild` | `nextSibling` | `childNodes` | All queries |
  | --- | --- | --- | --- | --- |
  | prefetch | 0 | 54 | 1,875 | 9,281 |
  | control | 1,887 | 1,915 | 15 | 11,024 |

- The 7-pair cohort compares every new behavior against all five controls,
  with 2 px in every Vox run:

  | Process | Pair deltas (candidate − control) |
  | --- | --- |
  | adblock worker | −25M to −43M in every pair (median 608M vs 642M) |
  | main process | +89M to −731M (mean −71M), within noise |

  Medians: Vox 20.965B, control 21.017B, Brave 20.677B.
- On the real page, in-place updates built 2,476 boxes for elements that
  already had one (display change 1,091, escalation 770, restyle 419,
  flagged 196), against 519 for new elements. Of 22,000 inline runs that
  built their items, 15,965 repeated an earlier run with the same constraints
  in the same pass; about 9,900 of those were in contexts whose inputs could
  be collected (main state 6,274, measurements 3,648).

**Measured on bundles `5125e515` (descendant reuse) and `014af799` (generated inline inputs).**
- `78fe4e3f8` keeps the boxes of clean descendants when an in-place update
  builds an element again (`VOX_DISABLE_IN_PLACE_DESCENDANT_REUSE=1` is the
  control). Boxes built for existing elements on one load:

  | Arm | display | escalated | restyled | flagged | pseudo | kept | nodes laid out without committed values |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | reuse | 28 | 457 | 19 | 196 | 24 | 1,594 | 3,171 |
  | control | 1,091 | 770 | 419 | 196 | 38 | 0 | 6,342 |

  Subtrees restored from committed layout rose from 1,318 to 1,791. A 7-pair
  cohort, 2 px in every Vox run, gave medians of 20.541B (reuse), 20.643B
  (control) and 20.820B (Brave); main process 19.930B vs 20.030B. Pair
  deltas ran from −594M to +712M: runs fall near either 20.1B or 20.7B, so
  the −101M median difference is within that spread.
- Correction to the inline-run repeats above: the diagnostic counted contexts
  holding only discarded white space, which return before building any item.
  With those separated and each run's calling-thread instructions summed
  (`cbf64c18e`, `608db2a90`), one load spends 917M in runs that build items
  (nested runs counted in their outer run too):

  | Runs | Count | Instructions |
  | --- | --- | --- |
  | first run of a context and constraint in its state | — | 640M |
  | white-space-only contexts | — | 29M |
  | repeats in the same state | 3,478 | about 250M |

  The repeats are contexts the retained caches reject: atomic inlines in the
  main state (357 runs, 85M) and in measurements (73, 18M), generated
  content in the main state (1,780, 101M), table-cell roots (367, 17M), SVG,
  replaced and inline-block content (under 30M together). Collectable plain
  contexts do not repeat.
- The repeated contexts were not what retained inline lines reject in
  general. With the generated node described (`5e669ef16`, `ce2dc2b52`),
  the main-state "generated" repeats were outside list markers, whose list
  items the committed layout rejected as roots, although measurements reuse
  them. `6e6d3d8a2` accepts generated content from authored strings and
  `attr()` (`VOX_DISABLE_GENERATED_INLINE_REUSE=1`); `be3438ece` and
  `9eecb4366` let committed layouts retain list-item, outside-marker and
  table-cell roots under the measurement path's closed-root rule
  (`VOX_DISABLE_COMMITTED_LIST_AND_CELL_INLINE_REUSE=1`). One load then
  spends 785M in runs that build items, against 919M, with 126M of
  same-state repeats left: atomic inlines 84M, SVG and replaced content
  most of the rest.
- A 7-pair cohort on bundle `85d92b56` (both controls against neither), 2 px
  in every Vox run:

  | Arm | Median | Min | Max | Main process median |
  | --- | --- | --- | --- | --- |
  | candidate | 19.966B | 19.850B | 20.260B | 19.362B |
  | control | 20.245B | 19.934B | 20.547B | 19.640B |
  | Brave | 20.571B | 20.433B | 21.158B | — |

  Pair deltas were −582M, +168M, −568M, −333M, −81M, −84M and −165M. Every
  candidate run used fewer instructions than every Brave run; the 10%
  criterion (`10 * max(Vox) <= 9 * min(Brave)`) is not met.

**Where the remaining instructions go (bundles `85d92b56`–`d8f524a0`).**
- Per thread at exit (injected `PROC_PIDTHREADCOUNTS` reporter, one load of
  20.45B): the main thread 16.26B of the main process's 19.82B, JSC JIT
  worklists 0.86B, heap helpers 0.25B, other threads about 0.5B; the adblock
  worker 0.62B.
- Coarse process-level stages (`VOX_DIAGNOSTIC_LOAD_STAGES=1` with
  `VOX_PROFILE_INSTRUCTIONS=1`, under 0.2B overhead; the per-thread stream
  adds about 150K instructions per stage boundary and inflates style several
  times over): JavaScript execution and bindings 4.9B, module completion
  1.6B, style updates 1.5B, flow layout 1.5B, CSS parsing 1.3B (0.97B on the
  main thread alone), document replays 1.7B, of which the first full replay
  is about 1.2B (text 486M over 87 leaves, shadows 231M and filters 203M,
  both mostly first use, dispatch 98M, SVG 78M). Process-level stages also
  count other threads' work while they are open.
- A sampled load (1 ms) splits the busy main thread into JavaScript 35%,
  layout 26% (geometry 268 samples, paint-tree projection 81, tree building
  and in-place planning about 90), style 9%, HTML parsing 6%, paint 3% and
  the rest in networking, frames and module fetches. No leaf in layout or
  paint exceeds 10% of its subsystem. In `layout_passes` full mode the
  inline item iterator is 21% of a pass, but on the page it is 40 samples:
  the per-text-node chunk cache answers the repeats there.
- Run-to-run spread (six loads 19.81B–20.84B) follows how many frames run
  before capture: the slowest load had 88 frames (a 12-frame train of about
  33M each from a transition) against about 60, and 145 layout passes
  against about 100.
- The adblock worker (`VOX_ADBLOCK_WORKER_DIAGNOSTICS=PATH`, `dbc226255`,
  `6cb8d7c22`): engine startup 157M, 158 request checks 258M (about 0.8M
  each, with first-of-a-kind checks of 17M to 90M), 171 response checks 31M
  and 6 document filter queries 22M.
- A `document.cookie` write saves the cookie file each time, but an injected
  `open` counter found 99 cookie-file opens costing 3.5 ms in a whole load;
  the 254 samples a sampled run showed in that `open` were an artifact of
  the sampling setup.

**CSS parsing and adblock worker follow-ups.**
- The page links 37 style sheets but only 29 distinct URLs: `primer-react-css`
  (303 KB) five times and four theme sheets twice. Repeated copies already
  reuse their token and rule syntax (about 25M each against 126M for a first
  parse of the 303 KB sheet), so first parses of the 2.56 MB of distinct CSS
  dominate. `dd952dba2` adds a `document-parse` mode to
  `tools/benchmark_style_passes.v` that parses the page's sheets into a fresh
  document's native storage as a first load does (885M for the 33 sheets,
  against 975M the browser's main thread spends in its 37 parses).
  `e5d48c154` clears only each rule's own caches when it is re-parented
  (887M to 879M). Storing a sheet's rule syntax only on its second parse was
  rejected: it saves the copy for sheets that never repeat but costs one
  cache hit per repeated URL, about 40M worse on this page. Selector parsing
  re-serializes tokens to text and parses that text again; replacing that is
  the remaining structural lever.
- The benchmark cohorts pin a 2026-11-17 engine
  (`libjs-github-continue-20261117/replay-assets`). With the bundled engine,
  this archive fails validation because its GitHub site optimizations request
  compatibility scripts the replay does not serve, so the adblock results
  below compare the worker processes of 7 loads per arm, built from the same
  tree into private asset directories.
- `0305dfd41` keeps uBO's `parseQueryPruneValue` and `parseRedirectValue`
  eager: through the lazy parser stub, the first removeparam or redirect
  directive evaluated the whole parser bundle (about 100M). Worker median
  626M to 534M.
- `0e6fa9517` restores the filter reference table as a plain array that loads
  entries on first read: matching read it about 80 times per check through a
  proxy trap while a page loads only about 190 of its 7,499 entries. A warm
  check drops from 282K to 142K instructions; worker median 528M to 502M.
- Where JavaScript time goes (`VOX_JSC_SAMPLING_PROFILE`, 939 samples on
  one load): host functions, that is the V bridge and the DOM work behind
  it, 53% of self time; GitHub's own scripts about 27% (react-dom 67,
  react-core 23, code-view 22, pb 21, core 19); the rest is Vox's injected
  facade code and builtins (`JSON.parse` 17, `JSON.stringify` 8). In the
  process sample the heaviest bridge entry is MutationObserver delivery
  (121 samples), almost all of it GitHub's own observer callbacks (105); the
  bridge's JSON marshalling is about 12% of the time under JavaScript calls,
  spread across many actions, with first-time element states the only JSON
  replies (later replies are identity references).
- A same-binary JSC tiering cohort (`JSC_useFTLJIT=false`,
  `JSC_numberOfGCMarkers=1`) gave no usable result: host load averages were
  100-120, and every arm spread from 19.9B to 23.6B with load times of 4.2 s
  to 5.4 s. Repeat it on a quiet host.

**Selector sources and the quiet-host tiering cohort, 2026-11-23.**
- `0dccae685` copies a selector prelude straight into its owned source when
  every token serializes as text it already owns: plain names, punctuation,
  strings that need no escape and numbers with their source spelling. A name
  is plain when its decoded value equals its source span and the span holds
  no backslash. Other preludes keep the general serializer and its
  per-selector scratch arena (`VOX_DISABLE_DIRECT_SELECTOR_PRELUDE=1`).
  `39bddd814` keys the rule selector memo by the selector text, with one
  graph per mode and policy in each entry, instead of building a combined
  key for every lookup. Document-parse benchmark, GitHub's 33 sheets
  (deterministic counts, matched pairs):

  | Change | Before | After |
  | --- | --- | --- |
  | direct copy, per-byte name check | 869.1M | 832.2M |
  | spelling-based name check | 826.0M, 834.3M | 798.2M, 805.9M |
  | text-keyed memo | 840.9M, 839.9M | 835.0M, 834.5M |

  The absolute counts move by up to 8M with host load, so compare within
  pairs. Altogether about 70M of the 975M the main thread spends parsing
  CSS in a load.
- Further parse costs, each measured over five interleaved rounds of the
  same benchmark (medians):

  | Commit | Change | Before | After |
  | --- | --- | --- | --- |
  | `497202eb3` | name code points from two bitmasks; leaf tokens copied once | 809.3M | 801.9M |
  | `597456053` | single-character spellings share the tokenizer's literals when owned | 805.4M | 800.3M |
  | `7dad4922a` | combinator and bracket scans skip runs of plain bytes | 806.0M | 774.0M |
  | `cf1063031` | selector names without an escape are one slice | 772.6M | 758.7M |

  The GitHub sheets now parse in about 759M against 869M at the start of
  the day. Reading nested blocks in place in the cache's node count made no
  difference (the compiler already avoids those copies). Re-slicing owned
  token spellings into the cache's copy of the input was not attempted:
  owned stylesheet strings are individually terminated, which the
  ownership tests require. What remains is spread out: struct copies
  (`memmove`, 10% of the parse), the code-point tokenizer (ident scanning
  5%), component consumption 5%, owning the rule tree for the cache 13%,
  and the cache's node count 4%.
- The JSC tiering cohort, repeated on a quiet host (load averages 7-18) on
  bundle `86bda0b3`, same binary, 7 alternating pairs, 2 px in every Vox
  run:

  | Arm | Median | Min | Max | PNG median |
  | --- | --- | --- | --- | --- |
  | control | 19.639B | 19.538B | 19.832B | 3,267 ms |
  | `JSC_useFTLJIT=false` | 19.693B | 19.281B | 19.932B | 3,400 ms |
  | `JSC_numberOfGCMarkers=1` | 19.654B | 19.529B | 20.193B | 3,424 ms |
  | Brave | 20.732B | 20.434B | 20.966B | 2,416 ms |

  Neither switch helps; both make the load slower. On a quiet host the
  control spreads over only 0.3B, and every control run used fewer
  instructions than every Brave run. The 10% criterion needs a Vox maximum
  of at most 18.39B against this Brave minimum, about 1.44B below this
  control's maximum.

**Custom property environments in full style passes, 2026-11-23.**
- In `tools/benchmark_style_passes.v` full mode (every element of GitHub's
  document restyled), `report_custom_property_change` took 30% of a pass.
  The root's custom property record holds 2,140 properties, and `<head>`
  with its ~270 children declares none, so they all share it. The strict
  environment check that keeps an unchanged record failed at its first
  entry, `--csstools-color-scheme--light: initial`, because `initial` and
  failed substitutions resolve to a fresh guaranteed-invalid value on every
  pass. The root then got a new record, and each head element compared the
  old and new 2,140-entry maps value by value. `c82d0717d` treats two
  guaranteed-invalid values as equivalent: a full pass drops from 941.1M to
  583.7M instructions (insert mode unchanged).
- A 7-pair cohort on bundle `c6d3e937` (all of today's CSS commits), host
  load averages 9-12, 2 px in every Vox run:

  | Arm | Median | Min | Max | PNG median |
  | --- | --- | --- | --- | --- |
  | candidate | 19.879B | 19.554B | 19.995B | 2,594 ms |
  | `VOX_DISABLE_GUARANTEED_INVALID_ENVIRONMENT_EQUIVALENCE=1` | 19.785B | 19.283B | 20.021B | 2,726 ms |
  | Brave | 20.719B | 20.377B | 20.865B | 2,162 ms |

  The load does not restyle the root and head the way a full pass does, so
  the fix changes nothing measurable there; the CSS parse reductions
  (about 0.1B) are also below this spread. Every Vox run used fewer
  instructions than every Brave run; the 10% criterion needs a Vox maximum
  of at most 18.34B, about 1.65B below this cohort's.

**CoreText first-use costs, 2026-11-23.**
- An interposed census of CoreText calls (one load, instructions on the
  calling thread) found two expensive answers asked repeatedly:

  | Call | Calls | Instructions |
  | --- | --- | --- |
  | `CTFontManagerCreateFontDescriptorsFromURL` | 4 | 237.6M |
  | `CTFontCopyVariationAxes` | 11 | 163.2M |
  | `CTFontDrawGlyphs` (glyph masks) | 519 | 88.6M |
  | `CTFontDescriptorCreateMatchingFontDescriptors` | 41 | 20.9M |
  | `CTFontCreateWithFontDescriptor` | 527 | 16.8M |

- Registering a replay face whose PostScript name CoreText will not
  resolve by name re-created the font file's descriptors for every key.
  The system UI font's hidden names (`.SFNS-Regular`; CoreText substitutes
  Times New Roman for them) take that path, and each key parsed
  `SFNS.ttf` into 369 descriptors, about 60M instructions. `fe7488c09`
  keeps the descriptors of the last eight files (path, device, inode, size
  and modification time) and selects from them as before
  (`VOX_DISABLE_FONT_FILE_DESCRIPTOR_CACHE=1`).
- `CTFontCopyVariationAxes()` localizes every axis name: about 30M
  instructions for the system UI font. Face flags only need whether axes
  exist, and system font matching only the `wght` range. `0cf538911` reads
  the axis count from the `fvar` table header; `9717e8165` reads the `wght`
  limits there when they need no rounding (CoreText truncates limits to
  four decimals: Skia's 0.479996 reads 0.4799) and asks CoreText otherwise
  (`VOX_DISABLE_FVAR_WEIGHT_AXIS_RANGE=1`). Fixtures compare both answers
  for installed faces.
- On bundle `04b49cea` (the first two commits) the census reads 1 descriptor
  parse (59.7M) and 2 axes queries (57.2M, both from the `wght` range that
  `9717e8165` then removes): about 0.28B less per load, 0.34B with the third.
- Other system costs checked: TLS (above; system LibreSSL runs AES-GCM in
  portable C, but Homebrew OpenSSL nets only about 55M on this page), Core
  Image's first backdrop filter (Metal context creation; replacing it would
  change filter pixels), and allocator `madvise`/`munmap` calls.
- A 7-pair cohort on bundle `90bbd3ac` (all three), host load averages 4-6,
  2 px in every Vox run; the control switches off the descriptor cache and
  the `fvar` weight range (the face-flags change has no switch):

  | Arm | Median | Min | Max | PNG median |
  | --- | --- | --- | --- | --- |
  | candidate | 19.609B | 19.097B | 20.239B | 2,544 ms |
  | control | 19.847B | 19.557B | 20.031B | 2,549 ms |
  | Brave | 20.947B | 20.809B | 22.012B | 1,917 ms |

  The medians differ by the census's 0.24B; pair deltas were +0.50B,
  +0.21B, −0.29B, −0.75B, −0.05B, −0.05B and −0.74B. Every Vox run used
  fewer instructions than every Brave run; the 10% criterion needs a Vox
  maximum of at most 18.73B against this Brave minimum.

**Load frames and the hydration race, 2026-11-23.**
- Frames are the largest cost that varies between loads. On bundle
  `bfdf3dd1` (host load averages 35-97), four rounds of the same binary:
  the default throttle rendered 8-10 frames per load (19.56-20.86B),
  `VOX_DISABLE_LOAD_RENDER_THROTTLE=1` rendered 30-39 (28.28-30.60B), so
  each additional loading frame costs about 0.4B. A stage-logged load puts
  an intermediate frame's main-thread work at roughly 190-250M of layout,
  30-370M of style, 45-85M of paint tree projection and 30-45M of paint
  recording, even when scripts changed little.
- The expensive outliers are the hydration race described above: frames of
  60-550 ms between the first paint and the end of hydration let the
  page's branch/tag and latest-commit responses arrive before React reached
  those buttons, and React regenerated the overview. Such loads replay 172
  requests (the five README badges twice) instead of 158-160 and use about
  3B more instructions. Six alternating rounds, host load averages 14-78,
  every capture 2 px from the Brave reference:

  | Throttle | Median | Min | Max | PNG median | Frames | Regenerated |
  | --- | --- | --- | --- | --- | --- | --- |
  | 3x cost, at most 500 ms (old default) | 22.869B | 19.746B | 23.302B | 7,344 ms | 7-10 | 4 of 6 |
  | 6x, at most 1 s | 19.788B | 19.447B | 23.270B | 6,358 ms | 7-8 | 1 of 6 |
  | 8x, at most 1.5 s | 19.686B | 19.299B | 19.815B | 6,189 ms | 7-8 | 0 of 6 |

  `a0c53a321` makes eight times the frame cost, at most 1.5 s, the default
  (`VOX_LOAD_RENDER_THROTTLE_RATIO=3 VOX_LOAD_RENDER_THROTTLE_MAX_GAP_MS=500`
  restores the old cadence). Deferred frames still render once the page has
  been quiet for a display frame; with the new gap most later loading
  frames are such quiet releases. This is a scheduling change, not a
  cheaper frame: Chromium renders more frames during hydration, each much
  cheaper than Vox's.
- 7-pair cohort on the published bundle `c1bdcf86` (head `be0bad757`,
  includes `a0c53a321`), the old cadence as a same-binary control arm, host
  load averages 12-84 rising through the run:

  | Arm | Median | Min | Max | PNG median | Regenerated | Valid |
  | --- | --- | --- | --- | --- | --- | --- |
  | 8x, 1.5 s (default) | 19.626B | 19.463B | 22.499B | 5,400 ms | 1 of 7 (load 81) | 7 |
  | 3x, 500 ms | 22.544B | 19.748B | 23.081B | 5,789 ms | 6 of 7 | 7 |
  | Brave | 21.200B | 20.716B | 21.381B | 3,183 ms | | 5 (2 abnormal exits) |

  Vox captures were 2 px from the reference except one control capture at
  4 px. At host load 81 the new cadence also lost the race, so the throttle
  narrows it without removing it; faster hydration is the remedy.
- Paint tree projection: 12 complete projections per load at about 45M
  each (36 in all, 612M on the main thread). Five of the twelve are
  replaced by another layout before any paint reads them (two at document
  install, one of two layouts within a frame, a timer and a script-forced
  layout: about 0.26B). Deferring the projection would also mean deferring
  the visual contexts and scroll state that `Document::update_layout`
  assigns from it after every pass, as upstream does. In the scale-2
  layout benchmark (text mode, 2,663 elements) a projection costs 34M, and
  a census of its nodes finds no reuse at all: both the ordinary-box and
  the retained-block projection templates require an identity ancestor
  transform, and at device scale 2 every box inherits the layout-to-CSS
  scale. At scale 1, 670 of about 2,000 boxes reuse a template and the
  projection costs 30M; the other boxes are flex, grid and other
  non-flow containers (420), anonymous boxes (226), positioned boxes
  (200), generated content (129) and list items (106).
- Each paint recording that first reaches a README badge lays out its SVG
  document and the badge's embedded logo document (five badges, 0.3-10 ms
  each); these are first layouts, not repeated work.
- A text change in the layout benchmark costs 175M per pass: geometry 62%
  (the flex containers above the change measure their items again: about
  a quarter of the pass in intrinsic sizing, and restoring the committed
  records of clean siblings 16%), projection 23%, style 5%.

**Selector queries for unseen element names, 2026-11-23.**
- A page-world probe (a content script wrapping `querySelector` and
  `matches`) counted about 90,000 selector calls in the first 3.2 s of a
  load. Nearly all come from GitHub's lazy custom element loader and selector
  observers: `matches(name)` and `querySelector(name)` for each added node
  and each of about 400 pending element names (24,440 each, none matching),
  `querySelector('react-partial[partial-name="…"]')` for about 165 partial
  names (17,060, none matching), and `matches()` against observer attribute
  selectors (about 23,600, nearly all false). The JSON query transport itself
  is now small (8,899 calls, 88 ms in one load).
- A JavaScriptCore microbenchmark (2,700 elements, 104 roots) costs a
  `querySelector` of an unseen name about 8.3K instructions: JSC drops and
  retakes its locks around every C-API callback (~19% of a call), both
  argument strings are converted (~20%), and the native side settles
  reactions and consults the parse cache before the existing name-history
  check answers.
- `8e229e269` lets the facade answer those queries: the native state query
  reports whether the document's local name history rules a selector out
  (every subject names an element the document has never seen) and whether
  the root is connected, and the facade keeps both facts until the history
  gains a name or the tree version changes. Microbenchmark: 8.3K -> 2.6K
  instructions per call (8.7K -> 2.8K with a tree change before each root);
  the react-partial queries are unchanged. Control
  `VOX_DISABLE_SELECTOR_ABSENCE_CACHE=1`.
- 7 alternating pairs on bundle `9b6345db`, host load averages 9-10, every
  capture 2 px:

  | Arm | Median | Min | Max | PNG median |
  | --- | --- | --- | --- | --- |
  | candidate | 19.102B | 19.040B | 19.442B | 3,075 ms |
  | control | 19.149B | 19.012B | 19.318B | 3,048 ms |

  Pair deltas were +0.05B, +0.43B (that load replayed 164 requests instead
  of 160), −0.05B, −0.17B, −0.14B, −0.02B and −0.12B: about 0.05B, below
  the 0.14B the call counts suggested, presumably because new element names
  keep arriving during hydration and clear the recorded facts.

**Style passes after the reuse caches, 2026-11-23 evening.**
- `tools/benchmark_style_passes.v` on the archived page: an insert pass styles
  2,506 elements in 515M instructions (205K each), a full restyle 216K per
  element. With `-d vox_css_diagnostics`: rule collection about 30% (bucket
  gathering and the ancestor bloom check over large candidate lists, then
  about 7 candidates per collection), computed properties about 28%, the
  cascade (already replayed for 87% of elements) small.
- Of about 3,900 longhand reuse lookups in a first pass plus one insert pass,
  3,207 hit; 1,038 elements never look up because a cascaded value has an
  unsupported type (SVG `d` paths 390, `clip-path` shapes 192, calc() margins
  106, transforms 60), and 432 are pseudo-elements. Supporting `path()` and
  absolute or percentage `inset()` values in the reuse snapshot (tried, not
  kept): those elements then filled the 256-entry batch cache with unique
  paths and hits fell to 2,192; remembering path keys only when repeated
  restored 3,241 hits, but the extra key work made the longhand loop slower
  (638M against 601M per two passes). The icon paths are mostly unique within
  a style batch.

**Stale LaunchServices records again, and a blocked Brave, 2026-11-23 night.**
- `tools/prune_stale_launchservices.py` reported 599 missing-on-disk Vox
  registrations (temporary `Vox.app` copies under `/var/folders/…/T/vox-svg-*`
  and similar, from other sessions' scripts) on top of the 699 pruned on
  11-04. Same bundle (`2e833c3e`), four loads each: 19.195B-19.321B before
  `--apply`, 18.687B-18.940B after (about −0.48B and about 0.6 s less to PNG).
  The records only inflate Vox launches on this machine (see 11-04); the
  prune also removed Brave's stale helper records, so both browsers share the
  cleaned environment. Earlier cohorts today ran with the stale records.
- 7 loads on `2e833c3e` after the prune, host load averages 10-36: 18.845,
  18.706, 18.669, 18.684, 18.852, 18.505 and 18.580B (median 18.684B,
  max 18.852B), PNG median 3,886 ms, every capture 2 px, every load 160
  requests (no regeneration). The 10% criterion would need a Brave minimum of
  at least 20.947B; today's earlier Brave minimums were 20.38B-20.81B.
- The Brave arm of that cohort failed in all 7 runs ("Chrome debugger did not
  start"): Brave's `chrome_crashpad_handler` blocks in `getxattr()` on the
  shared database `~/Library/Application Support/BraveSoftware/Brave-Browser/Crashpad`,
  whose directory listing fails with EINTR, and the browser waits for that
  handshake before creating its profile. Every new Brave process is affected
  until that directory is repaired, so no matched Brave comparison was
  possible.

**LibJS operand slots, 2026-11-23 night.**
- The grouped native cache from 11-20 no longer matches current builds
  (LibJS changes since then, and native-cache ABI files such as `operand.v`,
  `instruction.v` and `object.v`), so `libjs-native` loads are invalid
  ("cache_misses must be zero") until it is rebuilt with
  `tools/prepare_github_grouped_cache.py`. Interpreted LibJS (`--engines
  libjs`) needs no cache: 35.6-35.7B per load against 18.4-18.6B with
  JavaScriptCore on the same bundle.
- A sampled interpreted load spent 39% of busy main-thread samples in
  LibJS: the dispatch loop 211, `Operand.slot()` 82 (a checked call that
  returns a result type, for every operand of every instruction, although
  `run_executable()` has validated the executable for the frame), result
  stores through `array__set` 38, frame allocation 75, linear property and
  binding scans 75.
- `b54cc7e01` resolves operands of the running executable directly in the
  dispatch loop; `0bb03a786` reads per-opcode input counts and result flags
  from tables; `53f7ef0f9` does the same for call arguments and
  `get_callee_and_this`. Control `VOX_LIBJS_CHECKED_OPERANDS=1`. A
  standalone interpreter benchmark (private `/tmp` driver over `libjs`,
  constructor/method/closure calls, object and array literals, strings)
  goes from 2.187B to 1.895B instructions (−13%).
- 5 alternating pairs of interpreted LibJS loads on bundle `7d9b3101`
  (`b54cc7e01` only), host load averages 6-8, every capture 2 px:

  | Arm | Median | Min | Max | PNG median |
  | --- | --- | --- | --- | --- |
  | candidate | 33.309B | 33.244B | 33.328B | 3,311 ms |
  | `VOX_LIBJS_CHECKED_OPERANDS=1` | 35.778B | 35.681B | 35.811B | 3,490 ms |

  Every pair differs by 2.44B-2.51B (−6.9%).

**LibJS bytecode, dispatch and calls, 2026-11-23/24.**
- A standalone interpreter benchmark (private `/tmp` driver over `libjs`,
  with immutable compiled executables as `browserjs` enables them) showed a
  trivial function-local loop iteration costing about 3,500 instructions:
  17 bytecodes, 11 of them `mov`s that copied locals into temporaries or
  statement completions into the accumulator, and about 200 instructions
  per bytecode. Stepping through single dispatches with lldb: a `nop` costs
  64 instructions in `execute_instruction()` (stack protector, seven saved
  register pairs) and a `mov` about 120, because V emits the opcode `match`
  as an if-chain that clang lowers to a chain of small jump-table clusters.
- Landed: `5fa78a5b2` Number fast paths for arithmetic, comparison and
  bitwise operators; `35a68dee5` reads uncaptured locals in place unless
  later evaluation might assign them (codegen.rs's
  `might_contain_assignment_expression`) and drops function-body completion
  copies (control `VOX_LIBJS_COPY_LOCAL_READS=1`); `1f2bd8b05` dispatches
  `mov`, jumps, boolean branches and Number arithmetic/comparisons inline in
  the dispatch loop (control `VOX_LIBJS_SLOW_DISPATCH=1`); `0db447472`
  builds each body's call plan (parameter slots and environment vars) once
  instead of scanning register bindings per parameter and hashing every var
  name per call; `9d56adb5d` tests the most frequent slow-path opcodes first.

  | Benchmark (instructions) | `53314a15b` | `1f2bd8b05` | `9d56adb5d` |
  | --- | --- | --- | --- |
  | local `while` loop, 200,000 iterations | 700M | 96M | 95M |
  | 400,000 calls to 80 functions with 1-80 vars | | 5.89B | 2.67B |
  | 3,000,000 calls to a 1-argument function | | 10.17B | 9.65B |
  | mixed script (calls, objects, arrays, strings) | | 1.73B | 1.61B |

  The first column predates the trusted-executable harness; only the loop,
  which makes no calls, is comparable across all three.

- Interpreted LibJS page loads (`COHORT_VOX_ENGINE=libjs`, both controls
  set in the control arm), every capture 2 px from the Brave reference:

  | Bundle | Arm | Median | Min | Max | PNG median | Host load |
  | --- | --- | --- | --- | --- | --- | --- |
  | `707cce7c` (through `1f2bd8b05`) | candidate | 31.428B | 31.264B | 31.897B | 3,193 ms | 14-17 |
  | `707cce7c` | control | 33.688B | 33.524B | 33.809B | 3,680 ms | 14-17 |
  | `8022312d` (through `9d56adb5d`) | candidate | 30.476B | 30.215B | 30.627B | 3,976 ms | 27-35 |
  | `8022312d` | control | 32.608B | 32.313B | 32.829B | 4,250 ms | 27-35 |

  Five alternating pairs each. In-place locals and inline dispatch save
  2.1B-2.4B per pair (−6.7%); the call plan and opcode order save another
  ~0.95B across bundles (−3.0%; the controls moved by 1.08B, as both arms
  use them). The second cohort ran under heavy host load from other
  sessions, which shows in the PNG times.
- A sampled candidate load still spends 34.5% of busy main-thread samples
  in LibJS. Remaining interpreted costs, stepped on the benchmark: one
  JS-to-JS call about 2,300 instructions (frame recycling and its
  `memset`s ~300, V `array.push`/`array.set` helpers ~290,
  `run_executable()` setup ~380, `call_body()` ~350); an own property read
  about 350 inside `execute_property_read()` (key conversion, a hash-map
  probe for objects with eight or more properties, UTF-16 key comparison).
  The hint map caches only positive positions, so an inherited read on a
  large receiver scans all of its own properties first.
- Tried and not kept: giving the oldest pooled frame fresh value storage
  when no pooled layout fits (−4.6% on 80 distinct frame sizes, +1.1% on
  the mixed script); a parallel capacity index for the pool scan (slower);
  filling fresh frame storage with direct stores (no measurable change);
  handling `get_property`/`call`/`get_binding` in the inline dispatch loop
  (−4.5% mixed, but +7% on the arithmetic loop from the larger loop body;
  moving those handlers out of the loop lost the gain).
