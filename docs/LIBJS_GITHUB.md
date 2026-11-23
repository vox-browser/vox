# GitHub with LibJS — work in progress

**Pixel-perfect acceptance is not achieved.** LibJS now loads synchronous module
graphs, but does not complete GitHub's React hydration. Rendering the server's
file names is insufficient: the commit messages, dates, latest commit and active
controls must appear as well. JSC remains the default backend.

## Original-response baseline, 2026-11-14

The retained November 8 `https://github.com/vlang/v` archive has 164 responses
and 161 distinct response bodies, with original scripts and headers. Its entry
HTML is 427,595 bytes, SHA-256
`a0f615f45a8745e26aa57443182e238ddcb678f19aa2915c69d5ef66ff7b1a08`.
The manifest SHA-256 is
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`.
It was recovered from the existing local
`~/Library/Caches/Vox/benchmarks/github-site-optimizations-20261108/evidence.tar.gz`,
member `Build/site-opt2-20261108/complete-archive/`.

Both browsers used the original HTTPS origins through an offline replay proxy,
private process TLS trust, separate private profiles, scripts enabled, and a
1024×768 document viewport at 1×. Missing responses never reached the network.
Windowed checks used the test display away from the pointer. Vox captured after
a five-second delay; Brave captured two seconds after every pinned row had its
commit link and Sponsor was enabled. This is a functional baseline, not a timing
or instruction comparison.

| Observation | JSC | LibJS |
| --- | ---: | ---: |
| Directory rows present | 33 | 33 |
| Commit links present | 56 | 0 |
| Latest-commit section present | 1 | 0 |
| Complete retained text matches Brave | Yes | No |
| Pixels differing from Brave, out of 786,432 | 76,414 | 105,191 |

All three browser processes and their memory guards exited zero. Zero process
exit status does not establish complete content or matching pixels. The original
LibJS audit also contained no diagnostics because parser-time module failures
were being consumed by the script element model; `68e4cec4f` fixes that omission.

The Vox executable was SHA-256
`731ef68c901b8be1ce7858eef0c1d5d93c2b8df7584cc7b4f61a80d42bcef604`,
receipt `20261114-165954-ab3a34ed`; fresh PIDs were 55209 (JSC) and 55584 (LibJS).
Its executable and native-library hashes were checked before and after each
capture. Brave PID 88840 reported Chrome `157.0.8103.79`, revision
`52886f99c599c22139930531da30c7c8be9f38a`, and no script exceptions. Its executable
SHA-256 was `019e37a757d8dca6dadf7d8e2407d90bd52a0ac31a4e5a49d1cf0a444ab3d3d0`.

The diagnostic PNG identities are retained here without changing references:

| Capture | SHA-256 |
| --- | --- |
| Brave | `649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3` |
| Vox/JSC | `5036e2b8a347f6eb797ff3fbbf136af04ba36e65e0f3312df4acdf368d4f5cd7` |
| Vox/LibJS | `97508e4aabeb1a335b99f61b06315b19a5036151f51301b34b5d25982e0055aa` |

## Completed prerequisites

- `68e4cec4f` preserves LibJS script failures and console messages across the
  parser boundary. Later scripts continue to run after a failed script.
- `4efb87698` parses long conditional alternatives iteratively and generates
  their bytecode without recursive alternate traversal. A 1,000-branch lookup
  executes correctly, preserving right associativity and evaluation order.
- `fceef5933` retains the public frontend's default depth of 32 while allowing
  the browser to request 256. Both parsing and bytecode compilation retain a
  512 KiB native-stack reserve; hostile nesting and deep AST spines fail with
  diagnostics and leave later scripts runnable.
- `04e2385e5` executes import-free ES modules in private ModuleEnvironments.
  Local exports remain live, functions initialize during linking, lexical exports
  retain their temporal dead zone, default anonymous functions receive their
  names during creation, and module evaluation/results are cached. Browser
  modules preserve `this === undefined`, `document.currentScript === null`,
  separate inline scopes and native DOM mutation. No JSC context is created.
- `0a8382c79` fixes live host getters without ordinary property storage, including
  descriptors that override a cached ordinary getter.
- `be5ee7464` loads and evaluates synchronous module graphs with live imports,
  re-exports, function hoisting, lexical TDZ, cycles, asynchronous host loading,
  cached failures and one instruction budget across dependency bodies. Imported
  bindings reject assignment. The namespace adapter preserves sorted live reads,
  null prototype, stable identity and non-extensibility; accessor descriptors
  remain a deviation from full namespace data-descriptor/freeze semantics.
- `ad2f1db4a` executes `import.meta` against the defining module, including calls
  from functions after another module has run.
- `723554d44` connects those graphs to native browser Fetch, HTML module maps and
  import maps, including coalesced requests/preloads, native DOM changes, script
  completion events, load delays and diagnostic recovery. Classics still execute
  directly through LibJS; installing the loader creates no JSC context.
- `bf0b88c25` executes synchronous `try/catch`, including optional catch bindings,
  native/callee errors, nested handlers/rethrows, var hoisting, return and loop
  control. Catch entry restores the correct lexical environment. `finally` and
  destructured catch parameters still fail explicitly before execution.

- `e1a753359` exposes native module URLs and import-map resolution through
  `import.meta`, including the final base after an HTTP redirect. Its source-built
  native fixture passes without initializing JSC.

These are ten completed runtime fixes since the preceding 253-file LibJS/HN
broad baseline. Tooling, documentation and added coverage do not increment that
counter. The full GC-disabled sweep passes **261/261** files. Default-GC coverage
is a disjoint **184 + 77 = 261** file union: the machine restarted during the
original sweep, whose terminal status is unknown. That interrupted run also
found one outdated test expecting `try/catch` rejection; `225188bef` preserves
its early-rejection assertion with the still-unsupported `finally` construct.
The 77-file recovery passes with child and guard exits zero. All 678 recorded
LibJS/Unicode files remain unchanged from recovery through the GC-disabled and
AST runs, and the compiler hash is unchanged. The exact upstream AST driver
passes **100/100**, without overrides. Production screenshot validation remains
pending; no visual gate or complete broad-cadence reset is claimed.

The following runtime slice, `f49e6c730`, binds LibJS `performance` to the actual
native document timeline: `now`, `timeOrigin`, marks with optional `startTime`,
entry queries, stable entry wrappers, `toJSON`, and clearing marks/measures.
Native entries own their copied names in the document arena. Two focused native
functions pass with default GC and without GC; the final name-ownership copy is
exercised by the GC-disabled executable. Non-null structured-cloned detail,
creating measures, observers, constructors and the full EventTarget interface
remain outside that slice. No marker is replaced by a JavaScript no-op.

The initial frontend probe parsed 77 of 86 archived JavaScript resources with
the default depth. Iterative conditional parsing raises this to 78. At depth
128, an unoptimized default-GC probe parses 85; the remaining deeply nested `dp`
resource still stops at the native stack reserve. The optimized default-GC probe
at depth 256 parses **all 86**, with zero diagnostics, under the 3 GiB runtime
guard (sampled peak aggregate RSS 1,940,832,256 bytes).

The aggregate optimized GC-disabled probe exceeded the 3 GiB guard before
completing: child exit 137, guard exit 125, sampled peak 3,891,167,232 bytes.
That attempt supplies no whole-corpus pass. The isolated `dp` resource parses
successfully in optimized GC-disabled mode. GC-disabled unit tests are listed
separately below; neither result establishes a whole-page memory bound.

## Subsequent runtime work

Ten runtime slices follow that checkpoint (including the Performance binding
above). The source-pinned checkpoint passes 271/271 package files with default
GC and 271/271 with GC disabled, plus 100/100 exact upstream AST comparisons.
All 693 recorded source inputs and the compiler hash remain stable across these
checks. The compatibility compiler attempt rejects `-memory-limit` before
execution and receives no test credit. Production visual acceptance remains open.

| Commit | Implemented behavior |
| --- | --- |
| `d3a56b696` | Object declaration bindings: aliases, nested patterns, defaults and enumerable rest copies, including symbol keys, getter ordering, TDZ and module exports. Array, parameter, assignment and catch patterns remain separate work. |
| `dda9c7ea3` | `Object` construction and 21 static methods for definitions/descriptors, own-key enumeration, assignment, prototypes and integrity levels. `fromEntries` and `groupBy` remain absent. |
| `5ed3e8155`, `32f590d3d` | Object-literal prototype setters, computed-key conversion before value evaluation, and inferred string/symbol function names. Accessors and spread remain absent. The first commit also captured concurrent native-tier work in the shared index; that experiment supplies no GitHub compatibility credit here. |
| `8b9f5ffaa` | Functions reuse their executable's decoded source buffer and copy only the function's source span. |
| `e50f606bb` | Strict UTF-16 `JSON.parse`, including lone surrogates, duplicate keys, ordinary `__proto__` data properties, revivers and exact primitive source context. Parsing/revivers share the caller's instruction budget and retain finite native-stack/depth guards. `stringify`, raw JSON objects and JSON modules remain absent. |
| `0d6c5a339` | Native Error constructors/prototypes, VM error ancestry, message/cause conversion, branded `Error.isError`, string conversion and cached stack accessors. AggregateError remains absent. |
| `2c4c8ba5e` | Ordinary expressions skip the tagged-template helper's unnecessary heap copy; five focused upstream AST cases remain exact. |
| `c4584a35b` | Expression values no longer force every parser temporary onto the heap; retained AST edges still allocate. Delayed closures and expression owners pass GC-disabled and AddressSanitizer stack-use-after-return checks. |
| `ab28d5a7d` | Strict reserved-word checks compare ASCII grammar terminals directly, avoiding repeated UTF-16 conversions for ordinary identifiers. Strict/sloppy and escaped-name checks pass in both GC modes. |

For the function-source fixture (1,000 closures from a script with a 512 KiB
comment), the two GC-disabled executions both exit zero and preserve exact
UTF-16 function text. Sampled peak process-tree RSS is 3,216,818,176 bytes before
source reuse and 24,117,248 afterward. These are single functional diagnostic
runs, not a site performance or whole-page memory result. The later complete
preallocated module probe still exceeds the 3 GiB guard.

The local module probe now gets beyond React's `{__proto__: null}` initialization
and, after the later loop slice, reaches missing Performance/Date globals. It
loads 50 records and links all six original entries; all six still fail execution.
The standalone VM intentionally has no browser Performance/DOM host.
No source bytes or original imports were rewritten.

## Date runtime follow-up — 2026-11-15

`ad6b2991e` installs Date's wall clock, numeric/copy/component constructors,
TimeClip, Gregorian calendar arithmetic, UTC and local getters/setters, ISO
parsing, native string round trips, generic primitive conversion and `toJSON`.
Local conversions select the earlier instant during an overlap and the prior
offset during a skipped hour. Locale/Intl formatting, Temporal conversion and
other implementation-defined legacy parsing remain absent.

The seven Date cases and realm/Object-prototype neighbors pass in both GC
modes with `TZ=America/New_York`; a separate UTC run passes all seven Date cases.
A deterministic 500-case diagnostic compares UTC construction and UTC/local
setters against a pinned Node executable with the same New York timezone; all
cases pass. It is functional differential evidence, not site performance credit.
Initial fixture/compile failures and the discovered historical-offset bug are
retained. The unchanged 50-record GitHub module probe now passes the Date access
and stops at missing `Set`; other entries still require browser Performance.
No GitHub hydration or pixel equality follows from these runtime checks.

## Iterator and loop follow-up — 2026-11-15

`334af98d4` installs the existing Array/String iterator implementations in each
realm, including Array keys/values/entries, the values/@@iterator alias, shared
iterator ancestry, Unicode string iteration and primitive receiver preservation.
Four selected files pass with default GC and GC disabled. Iterator helpers,
the Iterator constructor and async iteration remain separate work.

`b61911374` executes synchronous for-of with lexical iteration environments,
iterator stepping, and protected cleanup paths. Break/return close once; continue
and normal exhaustion do not. Throws retain their original reason, next/done/
value failures respect the iterator's done state, and close errors bypass catches
inside the loop body. Eight new cases pass in both GC modes; for-in, catch and
script-evaluation neighbors pass too. Assignment/parameter/catch destructuring,
async iteration and finally remain incomplete. The new loop code is not present
in the native observation below.

The shared Object file changed during that commit and included two unfinished
collection fields. A subsequent commit removes only those incidental fields
from the committed snapshot while preserving the concurrent worktree edits.
No shared history was rewritten. The initial array-binding selection failed to
compile against those in-progress collection types/realm initialization; it
receives no execution credit. After concurrent `d925de78e` completes Set, the
array-binding selections pass.

`5bf37acb9` executes array binding declarations through the same iterator records:
elisions skip value getters; exhaustion supplies undefined without repeating
next; defaults, named functions, nested patterns and rest preserve source order.
Normal and exceptional completion close only unfinished iterators. Five new
cases and object-binding/for-of/script neighbors pass with default GC; the same
selection plus Set checks passes with GC disabled. The browser diagnostic below
predates these changes; new native verification is pending.

A new canonical C-O0/Boehm diagnostic includes Date and for-in, but predates
that iterator registration. Its executable SHA-256 is
`c8257c6b735946c143ec9a1fccb92d6d760665dcf7f349a1391742b2c6985783`.
Both fresh headless backends pass. The full 60-second LibJS observation exceeds
the 3 GiB guard after 43.98 seconds (sampled aggregate peak 3,227,926,528 bytes;
controller 137, guard 125, browser terminal status unknown; no audit/PNG).
A separate early 20-second observation with a 10-second stack sample exits zero
(browser/controller/guard) after 39.86 seconds, captures 33 rows, zero commit links
and zero latest sections, and remains interactive. Its input pins are unchanged;
sampled aggregate peak is 3,175,366,656 bytes. This shorter diagnosis does not
replace the failed full observation or establish hydration/memory acceptance.
The sole recorded error is the high-contrast module's unsupported for-of loop.
The stack sample observes module parsing and scope allocation/GC; it supplies
no allocation-size or performance credit.

## Native diagnostics after graph integration

`tools/libjs_browser_diagnostic.py` observes a fresh, active native window against
the unchanged original-origin replay. It pins the executable, runtime assets,
shared native libraries and archive manifest, registers the browser with the
memory guard, records readiness/content/errors and schedules normal capture and
exit. Its PNG includes the whole window: this is not a document pixel gate.

An unoptimized C diagnostic with sparse fonts and Boehm completed a matched
40-second observation for both backends. JSC PID 38615 reached `complete`, with
33 rows, 56 commit links and one latest-commit section. Every retained row,
commit, latest section and README text exactly matches the immutable Brave audit.
LibJS PID 41640 captured 33 rows but no commit links/latest section, remained
`interactive`, and reported `Cannot convert object to string` while logging an
initialization error. At that build, JSON parsing and Error prototypes were still
missing; later focused fixes above cannot be validated by this older executable.
Both observations used a visible, fully active 1024×768 document at 1×; browser,
controller and guard exits are zero and input pins remain unchanged. Sampled
aggregate peaks are 1,588,903,936 bytes (JSC) and 3,202,170,880 (LibJS).

Earlier unoptimized no-GC attempts exceeded the 3 GiB guard with both backends.
Sparse fonts alone did not resolve that. With the production preallocator, a
15-second JSC capture completed before hydration; the longer JSC observation and
LibJS observations exceeded the guard. Source reuse alone also failed the native
LibJS guard (sampled peak 3,484,467,200 bytes). Failed attempts retain their receipts;
when the guard killed the controller before finalization, the browser's terminal
exit remains unknown. No capture, pixel pass or memory bound is inferred.

Allocation diagnosis confirms substantial parser allocation, including repeated
expression copies and strict-identifier conversions. The staged compiler lacks
the optional preallocation sampler hook, so its first two probe attempts provide
no allocation-site evidence. A separate C diagnostic explicitly instruments the
generated allocator entry outside `Build/`, then terminates after 0.2 seconds:
its sampler is active and records 123.2 MB, including tagged-template copies.
That partial, instrumented run exits 143 deliberately and is not load acceptance.

Managed production requests remain coalesced. Earlier HTTP/Brotli and inline
iterator compile failures are retained; concurrent build fixes allowed receipt
`20261115-004720-a7e0da7f` to complete, executable SHA-256
`05e6ace1a48deb21b40a1b731885229088f8b5abf6940df2ebbd205dcc044e33`.
Its source manifest contains optional chaining but predates for-in. A fresh
LibJS launch against the same archive exceeds the 3 GiB guard before auditing
(sampled aggregate peak 4,295,917,568 bytes; controller 137, guard 125; browser
terminal status unknown). Post-stop input pins are unchanged. No capture or
rendering result is inferred. No engine fallback, memory bound, pixel reference
or tolerance was weakened.

A later unoptimized Boehm diagnostic, SHA-256
`8786d018a39e40ff6f8b8bf8b75c6c4ddb0f42d6732906a939aaf226cb6d5854`,
includes all ten runtime slices but predates optional chaining/for-in. Fresh
headless checks pass for both backends. Matched 60-second native observations
exit zero (browser/controller/guard), retain all pins and capture PNGs. JSC
PID 63871 reaches complete with 33 rows, 56 commit links and one latest section;
all row/commit/latest/README content equals the original Brave audit. LibJS
PID 46054 remains interactive with 33 rows and zero commit links/latest sections.
Its six diagnostics identify optional chaining, React for-in, and a native-stack
parser limit in the unoptimized code-view graph. Sampled aggregate peaks are
1,809,039,360 bytes (JSC) and 3,161,784,320 (LibJS). This is functional diagnosis,
not document pixel conformance or performance acceptance.

The retained eleven-case screenshot smoke uses that diagnostic's JSC backend.
Initial comparison commands all fail to compile the pixel tool under FastC;
`3c04b9ceb` selects its C backend. Recomparison of unchanged captures/reference
bytes passes eight cases under their existing limits. `inline-node`,
`ordered-list` and `text-decorations` still fail. Original failed commands remain
in evidence; neither references nor tolerances changed. This is not a complete
visual pass or a broad-check cadence reset.

Later focused language slices: `0c5091df4` executes optional chains (including
receiver and delete behavior); `0e836d1f0` executes for-in with ordered
prototype-aware enumeration and lexical iteration environments. Both pass their
focused checks in both GC modes. `15cac679b` refreshes the stale unsupported
optional-chain expectation to still-unsupported for-of. These postdate the
271-file checkpoint. The unchanged module probe now reaches missing Date in
the code-view graph; it supplies no browser hydration evidence.

## Focused verification

- Conditional/runtime/frontend regression selection: four files pass with
  default GC; the conditional cases also pass with GC disabled.
- Five exact upstream AST cases pass without overrides: assignment targets,
  await precedence, comma forbidden-token reset, ternary forbidden-token reset,
  and yield/comma expressions.
- Configurable parser limits and existing stack-info checks pass. Parser-limit
  and conditional cases pass with GC disabled. The compiler rejects a 5,000-node
  binary spine safely in both GC modes.
- Module execution, ordinary functions and interpreter checks pass with default
  GC. Module execution and ordinary functions pass with GC disabled. Existing VM
  module-loading cases pass in both modes after replacing the old placeholder
  expectation with a real local-export evaluation.
- Source-built browser parser tests pass for diagnostics, later-script recovery,
  explicit unresolved-import failure and bounded deeper input. Native module
  tests pass for private scopes, currentScript, document.head, cached evaluation
  and error recovery. The external-module fixture also passes: its load listener
  observes the module's native DOM change exactly once.
- Core graph, module execution and VM loading cases pass with default GC; graph
  and module execution also pass with GC disabled. The host-accessor regression
  passes in both modes, and ordinary cached-accessor behavior remains covered.
- Import-metadata execution passes alongside graph/interpreter tests; metadata
  and graph cases pass without GC. Catch execution, execution-context ownership
  and VM handler tests pass; catch/context checks also pass without GC.
- The source-built native browser module executable passes all five functions:
  private scopes, cached evaluation/recovery, external completion after a DOM
  change, fetched import-map/re-export graphs, and 404/MIME/syntax-error recovery.
  The three parser diagnostic/recovery functions also pass. Every new native
  check confirms that no JSC context was initialized.
- The hydrated GitHub comparison tool's four existing tests pass. Its new
  `--vox-js-engine=libjs` option preserves all full-content and unchanged-reference
  checks. The frontend probe returns 0 for valid input, 1 for syntax failures,
  and 2 when no input is supplied.

Compiles used the 12 GiB aggregate guard and V's `-memory-limit 10G`; separate
runtime executables used 3 GiB guards. The root browser tests used the existing
shared worker compiler/vlib at
`~/code/v/.codex-worktrees/fix-clang-linux-examples-43218932205/v`, because the
other compiler's HTTP compatibility adapter cannot resolve Brotli's callback
API. Package tests and optimized probes used current `~/code/v/v`.
The ten-fix package/AST checkpoint is recorded above. The interrupted default
command receives no wholesale success credit; its 184 completed files and the
77 successful recovery files provide the stated disjoint coverage.

## Remaining acceptance work

GitHub still needs additional bytecode forms and builtin/Web
APIs, including class execution, `finally`, iteration/destructuring,
dynamic imports, promises and native asynchronous operations. Synchronous module
support alone does not complete its React graph. The 76,414-pixel JSC mismatch shows
that rendering differences also need investigation after hydration is available.

The source-built tests above validate the new code. At the earlier checkpoint,
the newest completed production receipt, `20261114-180014-82702051`, executable SHA-256
`e19259550bdc6ba53f2e3aae16f557aa3099416a1ba0d48b6f4f2291b36ac8d8`, contains
the conditional and parser-limit changes but predates the module execution
integration. Each commit requested its normal managed production rebuild; no
duplicate manual build was queued. Full-page validation of the new module
integration remains pending, and no pixel improvement is attributed to it.

A fresh live navigation on that completed bundle (PID 83956) loaded the current
repository title and all 34 current file rows, with browser and 3 GiB guard exit
zero. It still had zero commit links and no latest-commit section. The new parser
diagnostics correctly recorded six rejected module entries rather than reporting
a clean hydration. The live asset hashes differ from the November 8 archive;
the 86-resource parser result applies to the archived workload. No live-site or
pixel-perfect fix is claimed.

The later completed bundle `20261114-191855-433aa86a`, executable SHA-256
`aa19da698743326eca456245c2d5550accf2d33daee9c75e43d845522723f5f8`, contains
the core graph linker but predates the native browser module host, `import.meta`
and catch continuation. Its parsed-source manifest cannot validate those later
changes. Commit rebuild requests remain coalesced under the managed worker;
no duplicate production build was queued. The later native diagnostics above use canonical source-built executables for
page diagnosis.

The unchanged archive has 87 JavaScript URL records and 86 distinct script body
hashes. `tools/libjs_module_probe.v`, using explicit local aliases from the flat
archived import map, loads 50 module records and links all six original entries.
Execution still fails: the standalone VM has no browser Performance/DOM host
and Date remains absent. This is a language diagnostic, not a browser
hydration or pixel result. Local-alias loading never rewrites the script bytes.

For the eventual full-content comparison, use the original scripted archive and
retained audit with `tools/github_hydrated_render.py --vox-js-engine libjs`.
For pixel equality against Brave, provide the same immutable Brave PNG for
`--expected-vox` and `--expected-brave`; separate per-engine references establish
stability only. The tool's timing acceptance remains a distinct, stricter gate.

## Local evidence

The unchanged reference PNGs, audits, input identities, successful and failed
attempts, commands and guard reports are retained in
`~/Library/Caches/Vox/benchmarks/libjs-github-20261114/evidence.tar.gz`.
All 127 archived evidence members were read back and SHA-256 verified. The archive
SHA-256 is `850f3a95ca7a0aeb5551578994f622d73372b5ce1847e80f4deaa1104d9f288b`;
its adjacent manifest records source and excluded test-binary identities.
Browser bundles, compiled tests, source snapshots, private profiles and response
bodies are excluded. Original response bodies remain in the separately retained
November 8 archive. Per-job Build outputs are removed after recording this report.

Continuation evidence is stored locally at
`~/Library/Caches/Vox/benchmarks/libjs-github-continuation-20261115/evidence.tar.gz`
(SHA-256 `105afdf2a38eed76ee29af3c799cd4a483e65e06c28d046a5224db5d0fa0e464`).
All 774 selected members were read back and checked against the embedded
manifest before removing completed job scratch. Generated C, executables and
disposable profiles are excluded; commands, identities, guards, failed attempts,
audits, screenshots and source fixtures remain. The newer production memory
failure remains in the active November 15 job and is not in this archive.
