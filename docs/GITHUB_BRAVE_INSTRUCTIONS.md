# github.com/vlang/v: Vox versus Brave instructions, 2026-11-08

Goal (user): load `https://github.com/vlang/v` with at least 10% fewer retired
instructions than Brave. **Not met.** The current Vox median is 10,319,156,939
versus Brave's 11,160,582,445. The conservative observed-count ratio is
0.94051244; the required maximum is 0.90.

## Workload and scope

- Input: Brave's serialized DOM of the hydrated repository page, with every
  `<script>` removed and `<base href="https://github.com/vlang/v">`, plus the
  Sponsor heart's decorative `anim-pulse-in` class removed (Brave captured
  the 0.5 s pulse at varying phases). HTML SHA-256 prefix `4379cf699ec3e09b`.
  The page has 2,986 elements, 42 stylesheet links (2.56 MB of CSS loaded),
  33 directory rows and 38 images.
- Responses: 248 cache entries recorded by one networked Vox run (fingerprint
  prefix `97f637eaeda5b331`). Vox reads a fresh copy per run behind the
  process-local network-deny dylib; Brave replays the same bodies through CDP
  `Fetch`. Responses Vox never requested fail in Brave too.
- Scope: fresh launch through completed document capture, 1024×768 document
  viewport, 1× capture, fresh private profiles, no settle period. Vox counts
  its process tree from launch to exit after the capture (including teardown,
  about 47M); Brave counts its observed process tree from launch to the last
  complete sample before the CDP screenshot response (a polling lower bound,
  9 processes, browser shutdown excluded). Neither includes GPU execution or
  WindowServer.
- Pixels: each engine is compared with its own fixed reference (Brave
  `fbb453c8b70af3ba`, Vox `c4afc9a43569d7c4`). The two references differ in
  1,015 pixels (0.13%); this is not a cross-browser pixel-equality claim.
- Driver: `tools/github_browser_instructions.py` (`61917182c`), run under the
  memory guard; JavaScript enabled in both, no page scripts remain.

## Current cohort: 2026-11-08 (seven alternating pairs)

The shared single-C-unit production executable is SHA-256
`c6b62c77913a18117f269fda73097c703b64e3d789b1ffe607f07c3f09efae95`,
built with V `-prod`, preallocation and JavaScriptCore. Its frozen compilation
receipt is `20261108-040315-4aba4e3c`. It contains the CoreText match cache
(`9f92e7888`), deferred PNG decoding (`72dabae0e`), inline element measurement
reuse (`a856c1160`), borrowed CSS syntax accessors (`56b74e474`), and the
pending closed-inline question normalization. Other concurrent canonical
changes are included; this cohort establishes the combined build result.

Each trial launched a fresh process. A shared publication lease held the bundle
fixed throughout all seven pairs. All fourteen captures were pixel-exact against
the unchanged per-engine references, and the identity, readiness, viewport and
33-row audits passed. No samples were retried or excluded. Profiles/caches were
fresh; OS filesystem and shader caches were retained. Host load and process
identities, counter coverage and exact exits are in the
[durable cohort receipt](performance/github-vlang-brave-instructions-20261108-c6.json).
Both engines use the same process-tree polling counter; their counts remain
observed lower bounds. This is a frozen script-free rendering workload, not a
live GitHub JavaScript-performance result.

| Pair | Vox | Brave |
| --- | ---: | ---: |
| 1 | 10,346,246,925 | 11,219,964,913 |
| 2 | 10,331,029,004 | 11,196,977,886 |
| 3 | 10,319,156,939 | 11,164,294,445 |
| 4 | 10,285,961,644 | 11,160,582,445 |
| 5 | 10,288,987,068 | 11,000,648,629 |
| 6 | 10,335,736,124 | 11,083,115,023 |
| 7 | 10,317,367,064 | 11,013,385,790 |
| **Median** | **10,319,156,939** | **11,160,582,445** |

`10 * max(Vox) = 103,462,469,250` exceeds
`9 * min(Brave) = 99,005,837,661`. The conservative ratio is
0.94051244. The largest Vox count must fall by at least
445,663,159 instructions against this Brave minimum.
The benchmark and memory guard both exit 1 because the instruction gate fails;
individual browser observations complete successfully. The guard's peak is
1,471,004,672 bytes, below its 12 GiB cap.

Regression tests are deferred until the instruction gate passes, as requested
by the user. Earlier completed checks remain historical evidence; this does not
claim that pending changes have passed the final verification batch.

## Historical cohort: 2026-11-07 (seven pairs)


Vox: private single-C-unit build of the canonical tree including
`376272155`, executable SHA-256 prefix `8e63a3693630a02f`. Brave
156.1.98.60 (Chromium 156.0.8078.48). All exits zero, all captures exact
against their references, all 33 rows present in order.

| Pair | Vox | Brave |
| --- | ---: | ---: |
| 1 | 12,293,413,600 | 11,108,817,812 |
| 2 | 12,352,003,793 | 11,056,159,242 |
| 3 | 12,268,078,994 | 10,897,522,076 |
| 4 | 12,326,536,648 | 10,876,864,218 |
| 5 | 12,213,277,249 | 10,985,556,298 |
| 6 | 12,278,125,302 | 10,896,091,333 |
| 7 | 12,295,985,694 | 11,022,444,115 |
| **Median** | **12,293,413,600** | **10,985,556,298** |

Worst Vox over best Brave: 1.136. The 10% gate requires
`10 × max(Vox) ≤ 9 × min(Brave)`, i.e. Vox at or below about 9.79B here.

## Earlier scroll-timeline change

`376272155` samples scroll-driven animations after each layout pass inside
`Document.update_layout()`. GitHub's repository tabs reveal their More
button through `animation-timeline: scroll(self)`; the change used to appear
only at the next animation frame and forced a third full layout after the
first paint. Same binary, three runs each: 12.40B with the change versus
13.62B with `VOX_DISABLE_SCROLL_TIMELINE_LAYOUT_VALIDATION=1` (−1.22B), with
identical captures.

## Historical ~12.3B phase breakdown

| Phase | Instructions |
| --- | ---: |
| First style pass (`build_boxes`) | 2.78B |
| Stylesheet fetch and parse (`preload_resources`) | 1.76B |
| First layout pass | 1.66B |
| First frame raster (`frame_complete`) | 1.52B |
| Second layout pass (size container queries) | 1.49B |
| AppKit/window setup and first frame preparation | 0.84B |
| Image hooks: synchronous full decode of every `<img>` | 0.69B |
| Startup, parsing, paint recording, capture | ~0.7B |
| Adblock worker process | 0.26B |

## Earlier remaining-work assessment

1. **Second layout pass (~1.5B).** GitHub hides tab icons with
   `@container (width<48rem)`; the second tab strip is 604 px wide, which is
   only known after layout. About 11 elements change `display`, but the tree
   builder rebuilds every layout node on the path from the root, and clean
   siblings are retained only when every element passes its whitelist. In the
   second pass 3,128 of 5,408 formatting-context lookups find no cache entry.
   Options: rebuild only a size container's subtree (container queries can only
   affect descendants, and `container-type` implies layout containment), or
   interleave container-query restyling with layout as Chromium does.
2. **Style (~2.8B for 2,986 elements).** Rule matching, property computation,
   CoreText face matching per (family, weight, size), rule-cache building and
   `:has()` invalidation each cost tens of milliseconds.
3. **CSS parsing (~1.5B for 2.56 MB).** Tokenizing, selector parsing and rule
   conversion; declarations could be parsed lazily per matched rule.
4. **First frame raster (~1.5B).** SVG icons and rounded rects are drawn through
   per-primitive GPU round trips with synchronous readback (gg.canvas/Graphite);
   Brave rasterizes on the GPU outside the counted CPU work.
5. **Image decoding (~0.5B).** Every `<img>` and preloaded image is fully decoded
   with stb at installation, including 1 MB README screenshots and header-menu
   PNGs outside the viewport; only natural sizes are needed before paint.

Same-binary GPU canvas capture (`VOX_ENABLE_GPU_CANVAS_CAPTURE=1`) did not
change Vox's total (13.70B versus 13.69B). Allowing absolutely positioned
subtrees in retained flow reuse did not shorten the second pass and was not
kept.
