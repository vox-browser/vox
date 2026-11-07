# Wikipedia memory usage

The [corrected arena measurements](WIKIPEDIA_NOJS_MEMORY.md#corrected-arena-beforeafter-50-mb-remains-unmet)
now record **50.68 → 50.20 MB** with `-prealloc -gc none`. The largest candidate
settled observation is 50,267,528 bytes, so the strict 50 MB gate remains unmet.
The user accepted the preceding 50.46 MB result. Three alternating pairs have
identical viewport captures; these runs disable page scripts. The earlier
results below used Boehm.

The verified final bundle is installed at `Build/v/Vox.app`. Its complete file
tree matches the measured candidate; strict signature verification and the
installed headless startup check pass.

The [2026-10-21 HTML/CSS-only measurement](WIKIPEDIA_NOJS_MEMORY.md) records
**123.2 → 87.3 MB settled physical memory** for Wikipedia, with unchanged
viewport captures across five before/after pairs. Every candidate settled
observation is below 100 MB. Sampled startup peaks remain above 500 MB.

The [2026-10-18 no-JavaScript comparison](WIKIPEDIA_NOJS_MEMORY.md) measures
**71.1% less settled RAM than Chrome**, with page scripts disabled in both.
It identifies its validated production bundle. The October 15 app measurements
below describe earlier builds and conditions.

The core memory fix is commit `4606e121fe1227f845c25f09210cd821d4386ce4`.
The RAM status-bar feature is commit `4eb6a162935708f6aa0db73d8c7a353652ee857f`.

## Current app verification

A fresh comparison on 2026-10-15 checks the installed app after later repository
changes. Both browsers use the same frozen portal, JavaScript, 1024×768 CSS
viewport, 2× raster scale, fresh profiles/caches, and 15-second settling interval.
Five accepted foreground runs per browser give these physical footprints:

| Browser | Settled median | Settled run range | Median sampled startup peak |
| --- | ---: | ---: | ---: |
| Vox | 315.7 MB | 312.0–322.5 MB | 333.4 MB |
| Chrome for Testing | 602.7 MB | 600.9–610.7 MB | 788.2 MB |

Vox uses **47.6% less RAM** by settled median. Every Vox run
also falls below 80% of the lowest Chrome run. All five Vox document captures
match one another. The installed executable, renderer, snapshot and app metadata
still match the measured bundle at completion; its signature verifies.

Foreground monitoring is fixed in `89cd504f`. The observer checks activity once
per second and rejects focus changes around the settled sampling window. Two
Chrome attempts failed that check and were excluded; their logs are retained.
All accepted runs pass the window checks and Chrome's document focus audit.
The observer/target suite passes all 14 tests.

Evidence, raw samples, rejected-attempt logs and document captures are under
`Build/wikipedia-chrome-memory/current-foreground-20261015-184349/`.
`comparison.json` lists the accepted observations and target result;
`manifest.json` records runtime hashes. The measured executable SHA-256 is
`f280defce2d3fad4953f147d26ed8acda9a38e34ec9a95730038cd4839580653`.

## Initial fix verification

The signed app meets the 20% reduction target for the frozen Wikipedia portal.
On 2026-10-15, five fresh foreground runs per browser gave these physical
footprints (decimal MB):

| Browser | Settled median | Settled run range | Median sampled startup peak |
| --- | ---: | ---: | ---: |
| Vox | 332.5 MB | 316.7–336.1 MB | 346.7 MB |
| Chrome for Testing 155.0.8059.79 | 607.3 MB | 604.2–610.1 MB | 797.2 MB |

Vox's settled median is **45.2% lower**. Every Vox run also falls below 80% of
the lowest Chrome run. Both browsers use JavaScript, a 1024×768 CSS viewport,
the same frozen HTML and subresources, a 2× Retina display/raster scale and a
15-second settling interval. The measurement includes the browser and every
live descendant; Vox's normal filter pack remains enabled. These results apply
to this portal and these browser builds.

The Chrome observations come from the preceding five alternating foreground
pairs. After packaging the current app with its matching renderer library,
five fresh Vox processes were checked against that unchanged Chrome cohort.
All five final captures match the corresponding full app's document pixels
before the packaging change. The earlier standalone executable captures use
different app display settings and are kept as historical evidence.

Evidence is under `Build/wikipedia-chrome-memory/`:

- `final-comparison17.json`: final observations, pixel checks, installed-file
  identity and signature verification.
- `audited-comparison17.json`: the result after checking Chrome's actual
  URL, viewport, raster scale, focus and visibility.
- `verified17-vox-{1..5}-1.json` and `confirm14fg-chrome-{1..5}-1.json`:
  raw simultaneous process samples, runtime identities and conditions.
- `verified15-install.json`: preserved previous app and the installed
  executable/library/resource hashes. Repackaging preserves executable and
  library code/data sections.
- `verified15-library-smoke.json`: normal startup resolves the packaged Skia
  bridge without a library-path override.

The installed `Build/v/Vox.app` passes strict signature verification and the
headless smoke check. Focused coverage includes collector policy, document/JS
retention with and without GC, native font/media ownership, snapshot COW
ownership and file replacement, adblock request/cosmetic parity, and 11 memory
observer/target tests. Broad translation suites were not rerun for this work.

The browser lets Boehm grow its heap as needed. It no longer counts parsed
elements and expands the managed heap to 4 GiB when a document reaches 1,024
elements. Explicit native collector settings such as `GC_INITIAL_HEAP_SIZE`
and `GC_MAXIMUM_HEAP_SIZE` remain available.

The RAM status bar reports the process's current physical footprint, including
document, JavaScript, rendering and browser overhead. It does not report reserved
virtual address space or the process's historical peak.

## Browser memory policy

Startup applies a collection divisor of at least 64 without reserving a fixed
heap. Explicit collector settings retain precedence. Bulk document work uses
the existing activity scope, and the browser returns unused managed pages after
500 ms without new document painting, navigation, or pending resources. It
checks at most once per second and repeats collection only after document work
or another 32 MiB of managed allocations. Live page state remains managed.

## Native resource ownership

The native renderer presents a bounded raster layer and releases unused Metal
drawables. Emoji fonts open on first use, and the Skia replay cache shares the
configured face with later glyph runs. FFmpeg libraries are resolved once, with
the header's ABI major version, on the first media decode. Static documents do
not load the codecs; VP9 decoding, seeking, and both pixel-conversion paths
remain covered by focused checks.

The app packages the adblock snapshot as a file-backed resource. The host maps
and validates it, then creates private copy-on-write mappings for large snapshot
buffers and typed-array clones. Standalone executables keep an embedded fallback.
Every restored engine still owns independent mutable data.
The bidirectional trie uses the same copying host boundary instead of making an
additional eager buffer copy. Small buffers and failed mappings retain the
ordinary copying path. Native ownership, offsets, context lifetime, GC, invalid
view types, source mutation, and file replacement are checked, including
sanitizer runs. Packaging replaces the snapshot atomically so rebuilding cannot
truncate an inode still mapped by a running browser.

The build also packages its matching Skia bridge inside the app and resolves it
relative to the executable. The library and completed bundle are ad-hoc signed.

The generator keeps its JavaScript copying fallback. The native snapshot and
metadata payloads are byte-identical before and after this backend change;
only the executable JavaScript bundle changes. Full request decisions,
cosmetic/scriptlet behavior, and default/custom/default reinitialization remain
checked. The before/after asset identities are recorded under
`Build/wikipedia-chrome-memory/snapshot-assets-{before,after}-clones.json`.

## Repeating the comparison

`tools/compare_browser_memory.py` measures an isolated GUI browser and every
live descendant with macOS `proc_pid_rusage` physical-footprint counters. It sums
simultaneous samples rather than summing unrelated per-process historical peaks.
It writes raw samples, executable identities, conditions, Chrome document/target
audits, screenshots, a settled median, and a sampled startup peak. The final
one-second measurement window ends before screenshot allocation.

Use the same frozen page URL, 1024×768 CSS viewport, native 2× raster scale,
15-second settling interval, fresh Chrome profiles and fresh copies of the Vox
cache. Pass `--foreground` to both browsers and
`--vox-arg=--enable-javascript` to Vox. Run five rounds and alternate which
browser goes first. Chrome's document audit records its focus and visibility.
The observer checks application activity once per second, reactivates its owned
browser when needed, and requires stable foreground checks covering the final
two seconds of RAM sampling. It rejects a run if focus changes around that
window. Chrome's final document audit must also remain focused and visible.
Background Chrome observations use less GPU memory and are unsuitable for a
comparison against foreground Vox; earlier uncontrolled observations are retained
only as diagnostic data. `tools/check_browser_memory.py --vox VOX_JSON... --chrome
CHROME_JSON... --output RESULT.json` exits nonzero when Vox's settled median is
above 80% of Chrome's. It rejects mismatched conditions, changing executables,
diagnostic libraries, collector overrides, JavaScriptCore overrides, and runs
without explicit foreground activation. Individual
run ranges and the stricter worst-Vox/best-Chrome comparison remain explicit.

## Earlier 4 GiB regression verification

On 2026-10-15, fresh browser processes loaded the saved Wikipedia portal through
a local server, with identical copies of the existing resource cache, a
1024×768 document viewport and a 15-second capture delay. JavaScript was disabled,
matching the normal automatic policy for Wikipedia. No collector heap overrides
were set. Physical-footprint measurements include the complete browser process
through screenshot capture.

| Build | Peak physical footprint |
| --- | ---: |
| Automatic 4 GiB expansion | 4,934,537,584 bytes |
| Normal heap growth | 909,854,304 bytes |

The peak fell 81.6% in this single controlled comparison. The two document
screenshots have zero differing pixels. This is a memory comparison, with no
new CPU-instruction or timing claim. Evidence, logs, binaries and captures are
under `Build/wikipedia-ram-fix/`; `comparison.json` also verifies that the installed
executable matches the tested binary.

`document/memory_test.v` crosses the old threshold with hidden elements
and exercises actual page installation, visible painting and document retention
after collection. It fails on the old code's exact 4 GiB heap size and passes
after removal, both with Boehm and with GC disabled. The rebuilt bundle passes
signature verification and `--headless-smoke`. Broad suites were not rerun.
