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
no duplicate production build was queued. A separate unoptimized diagnostic
executable is being prepared from canonical sources for page diagnosis.

The unchanged archive has 87 JavaScript URL records and 86 distinct script body
hashes. `tools/libjs_module_probe.v`, using explicit local aliases from the flat
archived import map, loads 50 module records and links all six original entries.
Execution still fails: some functions need destructuring, and the standalone VM
has no browser Performance/DOM host. This is a language diagnostic, not a browser
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
