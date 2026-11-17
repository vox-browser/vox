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
All twelve compile/replay processes succeed; the guards exit zero in
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
using direct current responses and the normal clock. The document viewport
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
