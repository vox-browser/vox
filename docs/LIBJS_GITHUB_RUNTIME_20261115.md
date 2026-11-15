# GitHub compiled-JavaScript continuation, 2026-11-15

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
a complete 297-file sweep is not claimed. Fetch remains unbound, so the latest
full-browser rendering result remains a failure.
