# Repository instructions

## Development branch

- Do all development and commit all changes directly on `master` in the
  canonical checkout at `~/code/vox`.
- Do not create or use feature branches, detached checkouts, or Git worktrees
  for development. Serialize edits and commits in the canonical checkout.
- Build and test from the canonical checkout; do not copy or clone the source
  tree into `Build/` for individual sessions.
- `Build/` is scratch and must not grow. It keeps the shared bundle and its
  libraries (`Build/v`), native dependencies (`Build/deps`), the production
  build state and `Build/pixel-tools/pixel_diff`; everything else is per-job
  output. Never copy V sources, tools, generated C or app bundles into it: try
  candidate changes in the canonical checkout, then commit or revert them.
  Delete a job's directory, lock and guard report when the job finishes.
  `tools/prune_build.py` runs after each production build and removes entries
  idle for 12 hours; production receipts keep generated C only for the
  published and newest builds.
- Do not copy browser app bundles or snapshot repository tools into session or
  benchmark directories under `Build/`. Reference `Build/v/Vox.app`, installed
  comparison browsers, and the canonical tools directly. Verify input hashes
  throughout measurements and reject runs whose inputs change.
- Keep new history linear with focused commits; do not rewrite existing shared
  history. Remove an existing worktree only after its committed and uncommitted
  logic has been incorporated into `master` and verified.
- The one exception is `/Users/alex/code/vox2-release`: `./deploy.vsh` checks
  out the release commit there and builds it with its own `Build/`, so releases
  contain only committed code. Do not edit, build, or test in that checkout.

## Source layout

- The browser's `module main` is `main.v` plus the directories listed in
  `v.mod`'s `subdirs` (`browserapp/`, `compact/`, `scroll/`, ...). V compiles
  them as one module. Put new `module main` files and their tests in the
  matching directory, not in the repository root. A new directory's name must
  not match any module or submodule name (such as `ui`, `gg`, or the `memory`
  of `sokol.memory`): the repository root is first on `-path`.
- From those directories, reach root files through `@VMODROOT`
  (`#include "@VMODROOT/native/include/native_x.h"`, `$embed_file('@VMODROOT/Tests/...')`);
  `@DIR` and relative includes resolve against the subdirectory.
- Name files in those directories without a `main_` or directory prefix:
  `chromium/caret_paint.v`, not `chromium/main_chromium_caret_paint.v`. Keep
  a name before platform suffixes; V only honors `_linux.v` or `_darwin.v`
  after another word (`native/browser_linux.v`), so a bare `linux.v` would
  compile on every platform.

## Commits

- Open browser pull requests against `vox-browser/vox`.
- Keep the CPU raster differential suite and bulk generated migration receipts
  in `vox-browser/vox-tests`. Pin its revision in `tools/raster_tests.json` and
  run it with `tools/raster_tests.py` (or the existing CPU shell launcher).
  Keep focused unit tests beside the implementation and concise results in
  `docs/GG_MIGRATION.md`; do not add generated receipts to this repository.
- Commit every completed feature and fix after running the relevant checks.
  Do not leave implemented work uncommitted unless the user explicitly asks.
- Every commit must request an automatic production rebuild through the managed
  post-commit hook (`sh tools/run_v_tool.sh rebuild_browser --install-hook`). The hook
  selects the C backend with literal V `-prod` in one C unit; FastC remains
  available for explicit builds. Keep requests coalesced under the shared worker
  and memory guard.
- Commit each completed translation feature separately with a focused commit
  message. Do not combine unrelated translation slices in one commit.
- Include the feature's focused tests in the same commit as its implementation.
- Keep documentation-only and tooling-only changes in separate commits when
  they are independently reviewable.
- Keep generated measurement and diagnostic dumps (`.json`, `.jsonl`, `.ndjson`)
  under `docs/performance/` and `docs/benchmark-results/` local. Never add or
  force-add them to Git; commit a concise Markdown summary instead. The ignore
  rules and pre-commit check enforce this for new files and tracked updates.
- Never commit evidence or measurement archives (`.tar.gz`, `.zip`, `.gz`) or
  force-add ignored files under `docs/`; keep archives local and commit the
  report or manifest that describes them. The pre-commit hook
  (`tools/pre_commit_check.vsh`, installed by
  `sh tools/run_v_tool.sh rebuild_browser --install-hook`) rejects archives outside
  `adblock/`, `tools/adblock/fixtures/` and `Tests/Browser/Brave/candidates/`,
  anything under `Build/`, and files over 32 MiB. Do not bypass it with
  `--no-verify`.

## UI implementation

- Always implement Vox-owned UI in V using UI2. This includes browser chrome,
  tabs, bookmarks, menus, context menus, pickers, settings, dialogs, and status
  overlays. Keep UI layout, styling, interaction state, hit testing, and action
  routing in shared V/UI2 components used across supported platforms.
- Do not add or expand application UI in Objective-C `.m`/`.mm` files, included
  native headers, direct AppKit calls from V, or hand-drawn GG/Sokol controls.
  Writing a platform-specific widget in V without UI2 does not satisfy this rule.
- If UI2 lacks a required capability, extend its V components or the repository's
  UI2 embedding/backend adapter. Do not create a separate Cocoa or GG UI fallback.
  Existing platform-specific UI is migration debt, not a pattern for new work;
  see [the UI2 migration audit](docs/UI2_MIGRATION_AUDIT.md).
- Keep native code limited to necessary platform integration and engine services:
  window hosting, normalized input delivery, clipboard/OS calls, timers,
  document rendering, graphics, media, and JavaScript runtime bridges. Put
  application-specific UI policy in V and expose platform operations through
  UI2's backend boundary. Native code inside UI2's platform backend is expected;
  a second browser-owned Cocoa widget implementation is not.
- Preserve behavior when migrating UI, including keyboard shortcuts, editing and
  focus, accessibility, tab/process ownership, and popup dismissal. Add focused
  tests with the migration. Audit included headers as well as `.m` wrappers;
  moving widget code into a header does not change its ownership.

## LibWeb V translation

- This repository (`~/code/vox`) is the canonical LibWeb V translation workspace.
- Use `~/code/3rd/ladybird/Libraries/LibWeb` as the upstream source reference.
- Keep all translated V implementation code, tests, generated translation assets,
  and translation-specific documentation in this repository.
- Do not place V translation files in the Ladybird upstream checkout.
- Preserve working translated behavior when replacing generated placeholders;
  add focused tests for each completed translation slice.

## LibJS translation

- Keep refreshed LibJS V code and tests in `libjs/` in this repository. Use
  `~/code/3rd/ladybird/Libraries/LibJS` as the upstream reference and
  `libjs/PORT_STATUS.md` for the completed slices, deviations, and remaining
  runtime work. The VM record (`vm.v` and the runtime records it depends on)
  translates `Runtime/VM.{h,cpp}` directly; keep new runtime slices in the same
  package with focused tests.
- Run `v -enable-globals test libjs` with current V; exercise heap ownership
  with the same command plus `-gc none`. Both modes also pass with the 0.5.2
  compatibility compiler (`-old-compiler`).
- Compare the current upstream AST fixtures with
  `v -enable-globals run tools/libjs_ast_corpus.v --all`.
  Keep these comparisons exact; the driver has no case overrides.
- The browser still uses JavaScriptCore. The parser's 32-call recursion limit,
  absent regex backend, and the pending bytecode generation, interpreter loop,
  builtin objects, and module linking must not be described as full LibJS
  parity.

## Build and run Vox

- All sessions share this `master` checkout and `Build/v/Vox.app`. Reuse the
  latest successfully completed production browser while each commit requests
  an automatic rebuild. Check the bundle and build receipts before scheduling
  an additional manual build; do not queue duplicate production builds or wait
  hours when a completed bundle is available. Request an additional manual build
  only on explicit request or evidence that no available bundle contains the
  required change. If the build guard is busy, use the available bundle for
  applicable checks and report validation that still needs a newer build. An
  older bundle cannot establish that new code works. Preserve the memory guard
  below and pin build identity for comparisons.

- Run expensive builds, test binaries and benchmarks through
  `sh tools/run_v_tool.sh run_memory_bounded --lock Build/UNIQUE-job.lock --report Build/UNIQUE-job.json -- COMMAND...`.
  Keep its default 12 GiB aggregate process-tree RSS budget; use `--limit-gib 3`
  for focused runtime tests. Use a separate lock per independent job; a busy
  shared lock must not queue unrelated work. Independent capped jobs may run
  concurrently; record host contention when assessing benchmark results.
  Supply `-memory-limit 10G` to V compiler invocations and never use
  `-no-memory-limit`. This sampled guard can overshoot between observations;
  it is not a kernel allocation limit. Do not run broad suites concurrently or
  format complete DOM/layout/paint owner graphs in test assertions.
  Release each job's lock when its submitted checks finish; prepare the next
  job's commands and inputs before acquiring its lock.

- Build the native macOS bundle from this repository with:

  ```sh
  cd ~/code/vox
  sh build-prod-browser.sh
  ```

- `build-prod-browser.sh` uses `V_BIN` when set, then `v` from `PATH`, and finally
  `~/code/v/v`. It writes `Build/v/Vox.app` and ad-hoc signs the bundle.
- Automatic commit builds use the C backend with literal V `-prod` in one C unit.
  Manual builds without `--prod` compile the generated C with V's `-parallel-cc`
  (split units linked with ThinLTO). `sh build-prod-browser.sh --no-parallel-cc`
  compiles one sealed C unit for maximum binary performance; it is several
  times slower to build. Without a V that supports native-header splitting
  (`V3_PARALLEL_CC_REQUIRE_SPLIT`), or when native code cannot be split, the
  build falls back to one unit. The receipt's `c-compile.json` and
  `Build/production-build/latest.json` (`c_compile`) record the mode used.
  The shared `~/code/v/v` is built from the `vox-parallel-cc` worktree
  (`~/code/v-worktrees/vox-parallel-cc`: upstream V plus the split commits),
  whose vlib it uses. Rebuilding `~/code/v/v` from another V tree drops the
  split until those commits are upstream.
  Keep mutable native header state in `VOX_NATIVE_STATE` so the split remains
  possible.
- Performance comparisons (instruction counts, scrolling, timings) must use
  builds with the same C mode, recorded with the build identity. Builds before
  the parallel default used one C unit; compare with them only through
  `--no-parallel-cc` builds. The measured difference per site is in
  [single C unit vs -parallel-cc](docs/PARALLEL_CC_PERFORMANCE.md).
- The browser builds with current V and fails rather than falling back to the
  0.5.2 compatibility compiler; an outdated `v` on `PATH` needs `V_BIN`.
  `LADYBIRD_V_GC=prealloc` builds use `-prealloc -gc none` and need V's
  bounded `v_realloc` copy under `-prealloc`. Under current V, `int` is 64-bit:
  hand native code `i32` data, and compare references with
  `voidptr(a) == voidptr(b)` (`==` compares the referenced values).
- The experimental compile-time `-d vox_v8` backend (`VOX_V8=1` in a
  supervised build) implements the JavaScriptCore C API on V8 (Homebrew
  node's libnode); the default build uses JavaScriptCore. Build it as a
  private bundle, never the shared `Build/v/Vox.app`, and check backend
  changes with `sh tools/test_jsc_on_v8.sh`. See [the V8 backend](docs/V8_ENGINE.md).
- Launch the browser with `open Build/v/Vox.app`, or pass a URL, an HTML
  file, or literal HTML directly to its executable:

  ```sh
  Build/v/Vox.app/Contents/MacOS/Vox https://example.com
  Build/v/Vox.app/Contents/MacOS/Vox ./page.html
  ```

- Run the non-windowed engine/JavaScript startup check with:

  ```sh
  Build/v/Vox.app/Contents/MacOS/Vox --headless-smoke
  ```

- Run all translation tests from this repository with `v test .`. When `v` is
  not on `PATH`, use `~/code/v/v test .`.
- The V bundle is independent of upstream Ladybird at
  `~/code/3rd/ladybird/Build/release/bin/Ladybird.app`.
- On Linux, `sh build-prod-browser.sh` builds `Build/linux/vox`. See
  [Linux setup](docs/LINUX.md) for system dependencies. Neither platform uses
  Skia or vcpkg; macOS dependencies come from Homebrew (see the README). Linux uses JavaScriptCoreGTK, GLib, Fontconfig, and the portable
  X11 renderer; the Cocoa painter and native media adapter remain macOS-specific.
- Run the Linux port checks with `python3 tools/test_linux_native.py` and
  `python3 tools/test_linux_browser.py`; the latter uses Xvfb and xdotool for
  actual window rendering and address-bar keyboard navigation. Use
  `python3 tools/test_linux_native.py --gc none` for ownership diagnostics.

## CPU instruction comparisons against Brave

- Choose and record the measurement scope before collecting the acceptance
  cohort. The default for site comparisons and `OPTIMIZED_SITES.md` is a fresh
  browser launch through completed document PNG capture, including startup and
  native window/target setup in both browsers. Read cumulative counters from
  process or exclusive coalition creation; subtracting a post-launch sample
  silently removes startup. Record exact endpoints, including PNG encoding,
  CDP delivery, audit and teardown work that either endpoint includes.
- A navigation-only comparison must start both browsers after equivalent
  window/target setup and finish at matching documented capture boundaries.
  Hacker News's Vox `navigation_started` marker precedes native window setup,
  while Brave's `Page.navigate` follows blank-window creation and resizing.
  Their deltas are an asymmetric diagnostic and cannot establish comparable
  page-only costs. Use `tools/hacker_news_browser_instructions.py` with
  `--instruction-scope launch` for its acceptance result; it records both
  intervals. Keep selected counts and scope labels consistent in progress,
  summaries and reports. A scope correction must retain the earlier results,
  explain the error and rerun the corrected protocol; moving boundaries earns
  no engine optimization credit.
- Use the same hardware-counter backend and ownership policy for both browsers
  within a comparison. Pin executable/native-library hashes, browser versions,
  fixture/resource hashes and references; launch fresh processes for each trial
  and verify identities throughout. Audit helper ownership and include exited
  tasks where the backend supports them. Disclose process-sampler lower bounds,
  missing final samples and excluded GPU/outside-service work. An exclusive
  coalition counter includes exited helpers and explicitly allowed owned system
  services; do not mix its totals with a process-tree count or an unrelated
  inherited coalition.
  Polled process-tree sums are lower bounds for both engines: missing Vox
  children do not become an upper bound because Brave also has omissions.
  Label the gate as a comparison of observed counts unless complete Vox
  coverage or an actual upper bound is established. Preserve exact raw counts
  in durable evidence, recompute catalog statistics from it, and distinguish
  historical claims with missing receipts from independently verified cohorts.
- Match the page bytes, author-script policy, viewport, backing/capture scale,
  cache/network policy, settle period and window placement between engines.
  Use fresh private profiles/caches and remove ambient measurement/proxy
  overrides. State whether OS filesystem/shader caches are retained. Replayed
  fixtures establish frozen-page results; validate live behavior separately
  before claiming a live-site fix. Require successful document identity,
  readiness and complete content audits, plus unchanged pixel-reference checks.
  Distinguish per-engine reference stability from cross-browser pixel equality;
  never change references or tolerances to obtain instruction credit.
- Use at least seven complete alternating Vox/Brave pairs for an acceptance
  claim. Retain every attempt, including first-launch outliers, failures and
  regressions; do not retry or exclude samples to pass. Report medians and the
  conservative highest-Vox-upper-bound/lowest-Brave-lower-bound ratio. For the
  default 10% goal, require `10 * max(Vox upper) <= 9 * min(Brave lower)` using
  integer arithmetic; honor a different user-requested threshold explicitly.
  Failed loads, mismatched pixels/content, unavailable counters, abnormal exits
  or changed identities invalidate acceptance. Preserve prior failing cohorts
  and qualify any later passing result by its pinned build and cache conditions.
- Run the cohort through the memory guard above. LaunchServices reparents
  windowed browser processes, so pass the same private PID registry to the guard
  as `--adopt-pids-from PATH` and to the Hacker News driver as
  `--memory-guard-registry PATH`; verify that adoption and browser RSS accounting
  succeeded. Write raw commands, logs, counters, PNGs, PID identities, host CPU
  count/load/timestamps and actual browser/benchmark/guard exits to a unique
  `Build/` directory while the cohort runs; record the counts, identities and
  exits the claim needs in the site report, then delete the directory.
- Keep `v -profile` and other instrumentation in separate diagnostic runs.
  Record the selected JavaScript backend and separately verify whether the
  page-script runtime initializes and executes code. `--enable-javascript` or
  an engine selector is not evidence of execution. Before attributing engine
  performance, verify the selected path and absence of fallback in a separate
  diagnostic; a script-free capture whose runtime stays uninitialized measures
  startup/rendering workflow. Report unsupported scripting/DOM behavior explicitly.
  Attribute an optimization only after confirming its path executes on the
  workload and comparing unprofiled matched control/candidate trials. Preserve
  the focused checks and 5,000,000-instruction broad-check cadence below.
  Add a qualifying result to `OPTIMIZED_SITES.md` with its statistic, exact
  workload/capture scope, rendering limitations and linked evidence; startup
  instruction counts do not establish isolated rendering time or scrolling fps.

For the archived Hacker News homepage, use unique output/receipt/registry names
and an existing verified pixel-diff binary, for example:

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
    -u all_proxy -u http_proxy -u https_proxy \
  sh tools/run_v_tool.sh run_memory_bounded \
    --lock Build/hn-brave-UNIQUE.lock \
    --report Build/hn-brave-UNIQUE-guard.json \
    --adopt-pids-from Build/hn-brave-UNIQUE-pids.json -- \
  python3 tools/hacker_news_browser_instructions.py \
    --output Build/hn-brave-UNIQUE \
    --memory-guard-registry Build/hn-brave-UNIQUE-pids.json \
    --home-archive Tests/Browser/Brave/hn-home-instructions \
    --instruction-scope launch --target-vox-fraction .9 --repeat 7 \
    --diff-tool Build/hn-home-instructions-20261031/pixel_diff
```

See [the Hacker News scope audit](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md) for
the corrected comparison and retained historical results. Use the latest
completed production bundle by default, following the shared-build rules above.

## Scrolling performance measurements

- Measure the requested production bundle and page with precise wheel events
  through the native input view. Use `tools/measure_precise_scroll.py` on macOS;
  run it inside the memory guard above with `VOX_TEST_WINDOW=1`. Record the
  executable and native-library hashes, URL, viewport, backing scale, cache and
  network policy, settle period, input schedule, and actual input timestamps.
  Use an empty private `VOX_PROFILE_DIR` for each trial, as the tool does, so
  saved proxy settings and bookmark-bar visibility cannot change the workload.
  File/loopback fixtures blocked by the optimized-site allowlist can use
  `--allow-fixture-navigation`; it seeds only `allow_any_site=true` in that
  private profile. This settings file disables profile proxying, so the tool
  rejects combining it with `VOX_PROXY`. Original-origin replay of an allowed
  site should keep the profile empty and use its explicit replay proxy.
  Verify the observed document viewport, excluding native toolbar/status
  overlays. The tool checks it against `--width`/`--height`; use
  `--chrome-height 84` for older bundles and `112` for default bookmark bars.
  Keep these conditions identical in before/after comparisons. A frozen cached
  page isolates a change; also validate the installed bundle on the live URL
  before claiming the user's live scrolling problem is fixed.
- Launch a fresh process for each measured or manually checked build. An
  existing Vox process can keep the old executable and native libraries mapped
  after the bundle on disk is replaced. The measurement tool spawns directly;
  for a manual check use `VOX_TEST_WINDOW=1 open -n Build/v/Vox.app --args URL`.
  Record the new PID and build identity. A successful `open` against an already
  running app does not prove that the rebuilt executable was launched.
- Verify that the intended document loaded successfully before measuring.
  For Pikabu pass `--require-title 'Пикабу'`; the settle period then starts
  after the requested title appears and restarts if that identity changes.
  A fixed delay from process startup can include navigation in the input
  window and is not a readiness check. A matching title establishes document
  identity, not network idle; retain the settle period and recorded start title.
  Cached files alone do not guarantee an offline navigation will succeed.
  When navigation requires a fetch, replay the archived response at its original
  URL and record the fixture, response-body hash, proxy route and private TLS
  trust. Reject navigation-error pages even if their animations publish frames.
- Count changed native frame publications after `updateLayer` completes. Report
  scroll-changing publications separately so animations cannot inflate scrolling
  fps. Verify that the document scroll position moves. Report the measurement
  endpoint explicitly. Native publication does not establish physical display
  scanout; use a display presentation measurement for claims about displayed
  frames. Record actual input cadence: a nominal 60 Hz timer can deliver late
  when the main thread is blocked.
- Brave's signed app can be observed without injected libraries or macOS capture
  permissions using `tools/measure_brave_scroll.py`. It drives CDP wheel input
  and joins damaging scroll frames to Chromium presentation feedback, validating
  renderer/input identity, complete compositor frames and unchanged references.
  Label these as instrumented CDP observations: they bypass Cocoa input, enable
  frame-event tracing and use a different boundary from Vox's layer publications.
  They cannot supply unprofiled optimization acceptance or a matched browser FPS
  ratio. Preserve animation-only controls, raw traces and the original failed
  injection diagnostics; see [Brave scrolling FPS](docs/BRAVE_SCROLL_FPS.md).
- Run at least two complete, unprofiled trials for each measured build. For
  optimization credit use alternating matched control/candidate trials, retain
  every result, and report regressions as well as gains. Profile separately;
  samples, instrumentation, or changed animation/paint/raster settings cannot
  supply unprofiled performance credit.
  Independently verify that the proposed fast path executes on this workload.
  Timing differences cannot be attributed to a path that remains ineligible.
  Check eligibility in a separate diagnostic run before timing a new fixture;
  a loaded archived page can exercise different paint paths from the live page.
  Separate startup/settle counters from counters during the actual input
  window. A path used only while loading cannot explain scrolling gains.
  Conversion microbenchmarks and load-time samples are diagnostic evidence,
  not scrolling fps measurements.
  Retain host CPU count, load averages and run timestamps, as the precise
  measurement tool records. Assess contention and variation across controls;
  do not attribute a faster trial to code when unmatched host load or widely
  varying controls leave the cause unresolved. Keep those results in the report.
  Validate the probe's executable identity and symbol ranges. With injected
  libraries, dyld image zero may be the probe rather than Vox; use the actual
  executable header when filtering caller addresses. Zero counters from an
  unvalidated probe are inconclusive.
- Report mean scroll-changing publication fps together with median, p95 and
  maximum scroll intervals, the fraction exceeding the target frame budget (16.67 ms at
  60 Hz), and the completed input/frame counts. Use the entire first-to-last
  input period as the throughput denominator and report leading/trailing
  publication gaps; averaging only between publications hides boundary stalls.
  Keep reciprocal interval timings separate from full-window throughput.
  Average throughput alone does
  not establish smooth 60 fps. Keep the target open when representative input
  still runs near 30 fps or has substantial deadline misses. Do not describe a
  different workload's faster result as the user's current scrolling fps.
- `tools/measure_browser_scroll.py` and `VOX_PROFILE_SCROLL` are synthetic
  draw-callback benchmarks: integer 42 CSS-pixel steps, self-paced callbacks,
  and completion-log receipt timing. Label their results as synthetic. Their
  callback durations, reciprocal timings, GPU throughput, and log receipt
  cadence cannot prove native publication cadence or smooth real scrolling.
  Do not infer raster reuse from integer steps; inspect the recorded reuse
  counters. The historical Pikabu 61.7/68.7 figures used this workload and did
  not establish the 60 fps goal; see `docs/PIKABU_SCROLLING.md`.
- Record commands, summaries, and actual browser/guard exit codes in the report;
  keep raw logs in a unique `Build/` directory only while the work is in
  progress. Missing publications, stationary input,
  crashes, timeouts, or changed build identities invalidate an acceptance run.
  A compile-only check does not execute tests. Keep pixel correctness and the
  existing focused/broad verification cadence while optimizing.

## Screenshot conformance workflow

- Run windowed tests and visual checks on the display away from the pointer
  when two monitors are connected. Screenshot launches select it automatically;
  use `VOX_TEST_WINDOW=1` for other test launches. See
  [test window placement](docs/TEST_WINDOW_PLACEMENT.md).

- Capture only the rendered document viewport from the native V browser (excluding
  its toolbar, status bar, and macOS title bar) with:

  ```sh
  ./capture_screenshot.sh SOURCE OUTPUT.png [WIDTH [HEIGHT]]
  ```

  The default viewport is 800x600. The script rebuilds a stale bundle, captures
  the native Cocoa content view without Screen Recording permission, accounts
  for Retina scale, crops the browser chrome, and writes a logical-pixel PNG. Set
  `SCREENSHOT_SETTLE_SECONDS` when a page needs longer than the default two
  seconds to settle. Normal-height captures retry one failed browser launch
  before reporting an error, covering the intermittent AppKit/Metal window-
  initialization trap without hiding deterministic failures.

- Compare canonical upstream screenshot inputs pixel by pixel with:

  ```sh
  ./compare_screenshots.sh
  ./compare_screenshots.sh inline-node ordered-list
  ```

  With no arguments the current smoke set is `inline-node`, `ordered-list`,
  `text-decorations`, `line-clamp-properties`, `canvas-text`, the three
  live-selection reftests (`selection-focus-between-text-controls`,
  `selection-insert-between-boundaries`, and `selection-moves-between-subtrees`),
  `empty-caret-with-placeholder`, `caret-after-first-character`, and
  `default-ignorable-code-points-not-painted`.
  A case name first resolves against upstream
  `Tests/LibWeb/Screenshot/{input,expected}`, then against `Tests/LibWeb/Ref/input`.
  For a reftest, the command follows its
  `<link rel="match">` or `<link rel="mismatch">` and captures both pages through
  the V browser. An input HTML path is also accepted. The command prints differing-pixel,
  maximum-channel-error, MAE, and RMSE metrics and writes `*.actual.png` plus an
  amplified `*.diff.png` heatmap under `Build/comparisons/`.
- Keep `svg-image-source-switch-same-size` pixel-exact when changing the compact
  script bridge or image invalidation. Script-visible `img.src` replacements
  must reach the live DOM, refresh the image model, and invalidate both layout
  and retained paint input even when the replacement has identical dimensions.
- Keep the SVG paint-server mutation reftests pixel-exact when changing the
  compact script bridge. Preserve tree-order identity when IDs collide, SVG
  attribute case and namespaces, script-created SVG children, `moveBefore()`
  ordering, retained animation end values, and paint-resource invalidation when
  an ID enters or leaves the document lookup map.
- Override the defaults with `LADYBIRD_SOURCE_DIR`, `V_BIN`, and
  `SCREENSHOT_OUTPUT_DIR`. The capture workflow is macOS-specific because it uses
  the Cocoa view snapshot helper and `sips`; the PNG diff tool itself is portable and
  can be run directly with `v run tools/pixel_diff.v EXPECTED ACTUAL DIFF`.

