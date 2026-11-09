# GitHub homepage stylesheet deduplication

## Status

The new policy removes three redundant Primer Brand stylesheet owners from the
captured, unauthenticated `https://github.com/` homepage. **A 10% reduction in
full-render instructions has not yet been established.** Source-byte reductions
and isolated parser or initial-layout measurements do not establish that gate.
No complete instruction cohort has been collected for this change yet.

Private Xvfb now works and a native browser PNG was captured. The functional
preflight was invalid: the unchanged Linux JavaScriptCore backend cannot
execute the homepage's ES modules, and replay exposed a missing favicon.
Acceptance requires a module-capable platform, such as macOS, and complete
replay coverage; a working Linux display alone is insufficient. The current
environment also lacks an accessible hardware instruction counter
(`perf_event_open` returns `ENOENT`). Callgrind remains available for explicitly
labeled guest-instruction diagnostics.

## Change and rollback

[The initial stylesheet policy](../site_optimizations/initial_stylesheets.v)
already deduplicates the reviewed Primer React asset. It now also recognizes
this exact Brand URL:

```text
https://github.githubassets.com/assets/primer-react-brand-css.6485cac7edcdca27.module.css
```

During initial-document setup, before stylesheet preload, it retains the last
eligible owner and inserts `@layer primer-brand;` at the first owner's position.
Parser-time scripts may already have executed. The
reviewed body has one named layer and no imports or anonymous layers. Each
stylesheet family receives its own marker, preserving the order between layers
for both normal and important declarations.

The existing GitHub/script-enabled boundary remains. Eligible links must be
unconditional, unnamed stylesheet owners without IDs, integrity, nonces, or
load/error handlers. Copies must also have identical `crossorigin` presence and
values, and identical `referrerpolicy` values (absent and empty are equivalent
for this comparison). Unknown URLs, including changed versions or query
suffixes, are retained. Scripts and the retained stylesheet bytes are unchanged.

Set `VOX_DISABLE_GITHUB_BRAND_STYLESHEET_DEDUP=1` for the control. This disables
only the new Brand policy while preserving Primer React deduplication. Unset
that variable for the candidate, and leave the broader
`VOX_DISABLE_GITHUB_INITIAL_STYLESHEET_DEDUP` unset on both sides. Run optional
`VOX_GITHUB_INITIAL_STYLESHEET_DIAGNOSTICS=1` tracing separately from measurements.

This same-binary comparison isolates Brand deduplication. Both sides include
the accompanying generic token-sharing changes; it is not a comparison of
original master with the complete proposed change. A combined improvement claim
requires matched baseline/candidate builds, or separately established effects
that account for the other changes.

## Pinned input: November 9, 2026

The locally retained canonical archive contains 125 responses and 14,789,662
body bytes. Original HTML, scripts, CSS, images, media, and author clocks are
preserved. It includes one observed HTTP 404 for the CSS-linked
`/assets/images/modules/signup/icons/alert-fill-12.svg`; the corresponding
`/images/modules/signup/icons/alert-fill-12.svg` response is present with HTTP
200. Replay never forwards missing requests. Script-discovered resources still
require an audit during execution.

| Input | SHA-256 |
| --- | --- |
| Canonical homepage HTML | `0e262f8419899081921deda5107d58c28ed9230428e4c69c99101d4bfd00fa92` |
| Sealed archive manifest | `ccaab0a7f91115928f817cf59ce74408e4723df6fde967ac178f9ef699b863cf` |
| Primer Brand CSS, 821,460 bytes | `0c74c44d8d52e6f8af8d68225471b6be34fdbfa953bf1a627940ab230848a3ab` |

The HTML has 28 active stylesheet links for 20 unique URLs. Four eligible links
reference the identical Brand asset; six reference the existing Primer React
asset. The following counts describe the initial policy, before subsequent
script-driven stylesheet insertion:

| Initial stylesheet work | Existing Primer policy | With Brand deduplication |
| --- | ---: | ---: |
| Remote stylesheet owners | 23 | 20 |
| Source bytes across those owners | 5,021,410 | 2,557,030 |
| Generated layer markers | 1 | 2 |
| Generated marker bytes | 56 | 76 |

The 2,464,380-byte difference represents three redundant Brand owners. It is
neither a network-transfer measurement nor an instruction count. The separate
CSS parsing corpus uses the same 20 stylesheet hashes; its original HTML is a
different capture and must not replace the canonical document above in page
comparisons. Raw archives, JSON evidence, and logs remain local.

## Validation and measurement scopes

The six cases in
[the initial stylesheet tests](../site_optimizations/initial_stylesheets_test.v)
cover cascade/layer order, retained final ownership, interleaved families,
eligibility and request-policy boundaries, and unchanged handling of unknown
assets. All six cases pass under preallocation, including request-attribute
presence checks. The tested local policy commit
`c309a1b630cbfa9c0211e51c98a40072552febaf` and published policy commit
`1221866a5c8dedf902701ef56aefa8ba4484dd9f` have the identical source tree
`544d9bc9c41c7d344fa0de7286c9243da364601f`. Actual test and memory-guard exits
are zero. The test binary runs in
0.627 seconds with peak sampled RSS of 172,580,864 bytes; compilation and test
preparation peak at 6,859,149,312 bytes under the normal 12 GiB guard. Native
full-browser visual validation remains pending.

Separate supporting token-ownership checks pass: 12 cases across three files
under preallocation, and six cases in one file under Boehm. These results do not
validate the new site policy or supply page-performance credit.

The retained `github-native-prepresence-01` functional preflight used the older
executable with SHA-256
`e88a739969c856e146e4f8855e6b814d0b3853363ef551a381e250ff6b1512a5`.
It predates the final `crossorigin` presence guard and cannot validate that
revision. The first control exited normally with a PNG and audit: correct URL
and title, 1024 by 768 viewport, and 847 paint commands. However, the audit
reported five identical module-execution diagnostics and five native errors;
the hero area was visibly blank. [The runtime](../browserjs/runtime.v) rejects
module execution without a module host, and
[module-host installation](../browserjs/module_host_jsc.c.v) is explicitly
Darwin-only. These restrictions are unchanged from the baseline.

Replay recorded 41 requests, including one unarchived
`GET https://github.com/favicon.ico`, rejected with HTTP 404. This is distinct
from the archived CSS-linked 404 described above. The attempt stopped at its
invalid first control: no candidate ran, no pair completed, and no instruction
count or performance credit was collected. Preserve this evidence when sealing
a complete replacement archive.

Two final-revision production build attempts were killed with exit
137: approximately 241.7 seconds and 7.395 GB peak sampled RSS with default
workers, then 141.45 seconds and 7.943 GB with `VJOBS=1`. Neither produced a
compiler source diagnostic. Both failures remain retained.

The final production build subsequently passed using sequential C emission and
optimization through a private `V_BIN` adapter, without changing tracked build
files. The ordinary supervisor, source-identity checks, 12 GiB memory guard and
production smoke test remained active. V exits before Clang starts optimizing
the emitted, preprocessed C. The build uses the C backend, staged preallocation
runtime, Clang `-O2`, GG renderer, `VJOBS=1` and no literal V `-prod` flag.
Explicit `-glibc` preserves the native libc selection during C-only emission;
a separate guarded check verified matching conditional definitions and staged
allocator/closure inputs.

The completed executable is SHA-256
`46fb4d5e135ed2df6bae9bfd934242dddfa4b834a5feb95d0c62a14925a6faf7`, production
receipt `20261109-081114-0084fb2f`. Build and guard exits are zero: 432.523 seconds,
7,997,001,728 bytes peak aggregate sampled RSS. C emission and optimization
peaked separately at 7,939,174,400 and 2,254,659,584 bytes. The production smoke
passes JavaScript DOM mutation, click handling and wheel routing, with exit
zero in 0.633 seconds and 92,614,656 bytes peak RSS. This validates the compiled
revision; it supplies no GitHub page-performance credit.

### Hosted macOS capability check

The separate [capability workflow](../.github/workflows/macos-instruction-probe.yml)
runs [a bounded probe](../tools/probe_macos_instructions.py) on `macos-15` and
`macos-15-intel`. It records architecture, physical RAM, every native counter
sample (including a rejected zero), three fixed CPU-work deltas, and Metal
device availability. Its workload is limited to 60 seconds and 3 GiB, and
failed observations are retained as Actions artifacts. This workflow is
independent of the existing browser/lifecycle gates.

This is only a host-capability check. A successful Cocoa lifecycle job or a
positive probe does not establish a working full-browser SDK, a complete
GitHub render, or any performance improvement. A module-capable host still
needs matched baseline/candidate builds and the complete page acceptance
cohort below.

`--headless=layout-tree --enable-javascript --js-engine=javascriptcore` can
compare the production initial layout and its serialized geometry/text without
a display. Its endpoint includes startup, loading, initial layout, tree
serialization, and exit. It excludes native window setup, raster painting, PNG
encoding, and complete asynchronous hydration. Preserve any layout mismatch;
an exact layout tree is not a pixel comparison and does not cover all painted
colors, decorations, or decoded image pixels. The current browser has no
display-free document-to-PNG CLI path: the layout-tree mode returns before GG
window setup, while Linux screenshot capture uses the Sokol window framebuffer.

The full-render gate uses fresh processes through completed document PNG capture
and exit, including startup, readiness, audit, encoding, and teardown. Use one
counter backend throughout. Linux hardware counters and Callgrind `Ir` are
different metrics; neither includes external X server or GPU execution. See
[the Linux measurement contract](LINUX_INSTRUCTIONS.md).

## Reproduce Linux capture diagnostics

These commands reproduce Linux diagnostics, not acceptance of the scripted
homepage with the current backend. Missing ES-module support invalidates full
page validation even when capture and exit succeed. Build using
[the Linux instructions](LINUX.md), and provide the sealed archive at the
placeholder path below. A new live capture is a new workload and needs its own
hashes and baseline. Start replay in a separate terminal:

```sh
python3 tools/page_archive.py replay /path/to/sealed-github-home \
  --output Build/github-home-replay
```

In another terminal, use the exact proxy and CA from its `ready.json`. Create a
capture audit and a reusable invocation:

```sh
github_proxy=$(python3 -c 'import json; print(json.load(open("Build/github-home-replay/ready.json"))["proxy"])')
github_ca=$(python3 -c 'import json; print(json.load(open("Build/github-home-replay/ready.json"))["ca"])')
mkdir -p Build/github-home-cohort
cat > Build/github-home-cohort/audit.json <<'JSON'
{"selectors":[{"name":"body","selector":"body","limit":1},{"name":"headings","selector":"h1,h2,h3","limit":100},{"name":"links","selector":"a[href]","limit":1000,"attributes":["href"]},{"name":"images","selector":"img","limit":1000,"attributes":["src","srcset","alt"]}]}
JSON

github_capture() {
  github_label=$1
  github_control=$2
  shift 2
  env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
      -u all_proxy -u http_proxy -u https_proxy \
      -u VOX_DISABLE_GITHUB_INITIAL_STYLESHEET_DEDUP \
      -u VOX_GITHUB_INITIAL_STYLESHEET_DIAGNOSTICS \
      -u VOX_PROFILE_INSTRUCTIONS -u LADYBIRD_DEBUG_TIMING \
      -u VOX_CAPTURE_READY_SELECTOR -u VOX_TRACE_CAPTURE_READINESS \
      NO_PROXY='' no_proxy='' \
      VOX_PROXY="$github_proxy" SSL_CERT_FILE="$github_ca" \
      VOX_DISABLE_GITHUB_BRAND_STYLESHEET_DEDUP="$github_control" \
      LADYBIRD_ENABLE_SNAPSHOT_CACHE=0 VOX_COOKIE_FILE='' \
      GC_MARKERS=1 LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
      LP_NUM_THREADS=1 MESA_SHADER_CACHE_DISABLE=true \
    python3 tools/run_memory_bounded.py \
      --lock "Build/github-home-cohort/$github_label.lock" \
      --report "Build/github-home-cohort/$github_label-guard.json" -- \
    xvfb-run -a -s '-screen 0 1280x1024x24' \
    python3 tools/measure_browser_instructions.py \
      --engine vox --counter-backend linux-perf --binary Build/linux/vox \
      --vox-arg=--enable-javascript --vox-arg=--js-engine=javascriptcore \
      --url https://github.com/ --width 1024 --height 768 \
      --expect-title 'GitHub · Change is constant. GitHub keeps you ahead. · GitHub · GitHub' \
      --settle-seconds 0 --timeout 1800 \
      --capture-audit-config Build/github-home-cohort/audit.json \
      --output "Build/github-home-cohort/$github_label" "$@"
}

github_capture control-1 1
github_capture candidate-1 '' \
  --expected-png Build/github-home-cohort/control-1.run-1.png
```

The driver creates fresh private profiles and empty caches. Pin the executable,
native libraries, fonts, fixture, and observer versions. On hosts without a PMU,
explicitly substitute `--counter-backend callgrind` and label every result as
software guest instructions. Do not substitute elapsed times for instructions.

On a module-capable platform, first pass functional validation with complete
replay, then use the corresponding supported instruction driver. Retain the
first valid control PNG unchanged for every subsequent capture. Complete at
least seven pairs, alternating control/candidate order; keep zero settle on
both sides and retain every attempt. Require exact RGBA pixels and matching
body text, headings, links, image inventory, visible-image readiness, and fonts.
The canonical primary heading must be `Software still starts with you`.
Check replay logs for missing resources and native/JavaScript diagnostics as
well as normal browser exits. The generic driver records additional semantic
selectors but does not automatically compare their contents.

The native audit provides `javascript_diagnostics` from the application's shared
diagnostic list and `native_reported_error_count` from the document's native
global scope. Require both fields and reject nonempty diagnostics or nonzero
errors. This checks the recorded state when the audit is collected; it does not
observe every console message or subsequent asynchronous error. On Linux the
portable screenshot code reads `SCREENSHOT_SETTLE_SECONDS`; the Darwin capture
code reads `LADYBIRD_SCREENSHOT_DELAY_SECONDS`. Explicit zero values for both
keep the intended no-delay policy clear when invoking the executable directly.

Report all counts and both medians. The conservative 10% gate is
`10 * max(candidate) <= 9 * min(control)`, together with the complete content
and pixel checks. Failed loads, changed inputs, mismatched output, or abnormal
exits invalidate acceptance; no reference or tolerance should change to obtain
performance credit.
