# Hacker News rendering

The discussion is <https://news.ycombinator.com/item?id=50231722>.
The small text in the reported screenshot is the opening sentence of
<https://news.ycombinator.com/item?id=50225695#50226323>:
“This statement stood out to me.” It belongs to the comment body.

Commit `5ffc75c8` projects the parent's inherited style into physical layout
coordinates before creating an anonymous block for bare text beside paragraph
blocks. Previously, that wrapper used the unscaled font while the paragraphs
used the physical font. The focused layout regression covers quirks and
standards modes, scale changes and live font-size changes.

## Native Brave references

Brave 156.1.98.60 references use a fresh profile, sRGB, a native window on the
display away from the pointer, and the display's actual device scale 2. They
use `tools/capture_brave_reference.py --windowed --native-scale`; device
emulation gives different font metrics and is unsuitable for these references.

| Fixture | CSS viewport | Stored reference |
| --- | --- | --- |
| `hacker-news-comment-initial-text` | 800×600 | 800×600, normalized with `sips --resampleHeightWidth 600 800` |
| `hacker-news-item-50231722-complete` | 1024×768 | Raw 2048×1536 |

Text-control intrinsic widths are rounded after projection into physical layout
coordinates. The 80-column reply textarea is 664.5 CSS pixels wide at native
scale 2, including its padding and borders; rounding in CSS pixels first
incorrectly added one physical pixel. The control regression checks scale
changes and the neighboring text input.

The textarea resize grip uses overlapping translucent SVG strokes. Consecutive
solid butt-ended line strokes share a GPU raster pass so their sample coverage
survives until the common antialiasing resolve. Resolving each stroke separately changed 19
physical pixels. The focused grouping tests retain clip, effect, raster-layer,
gradient, dash, curve, join, cap, non-scaling-stroke, and combined fill/stroke
boundaries.

The complete fixture freezes the 2026-10-25 response, removes scripts, and
retains all 101 comment rows, including collapsed and hidden rows. Both
fixtures reuse the archived local Hacker News assets.

Reference SHA-256:

- Comment: `b3dc205771f33b20b452baf5346f49deed96ffad57d4085624b3ba65dfa142fc`.
- Complete discussion: `8d7ac5db8f497cddcc93f28077f7577a411aceef327ed174b948458379fd5b44`.

Run the original discussion, complete Retina discussion, and comment pixel tests with:

```sh
V_BIN=~/code/v-latest/v python3 tools/run_memory_bounded.py \
  --report Build/hn-pixels-job.json -- python3 tools/hacker_news_pixels_test.py
```

## Instruction comparison

```sh
python3 tools/run_memory_bounded.py --report Build/hn-instructions-job.json -- \
  python3 tools/hacker_news_browser_instructions.py --output Build/hn-instructions
```

This runs three alternating pairs by default. Each observation needs exact
reference pixels, all 101 comment IDs, the intended URL, complete readiness,
the correct viewport and a successful kernel-reported exit. A failed load
cannot earn performance credit. The gate requires the largest Vox count to
be at most 90% of the smallest Brave lower bound, including sampling uncertainty.

The measured interval starts at navigation request and ends when the encoded
document PNG is available. Both browsers use fresh processes, profiles and
caches with the same frozen page and local HTTP replay. Vox's native marker
precedes file writing; Brave's CDP endpoint includes PNG base64/IPC delivery
and readiness polling. Both use inactive native windows away from the pointer.
Exclusive resource-coalition counts include live and exited helpers and owned
Metal compiler services. GPU execution and services outside those coalitions
are excluded. This compares the capture workflows; their internal endpoints
differ, so it does not establish identical internal first-render work.

The regular screenshot tests normalize the raw complete-discussion reference
to logical pixels using the same `sips` conversion as the capture workflow.
The instruction gate additionally requires exact raw native-resolution pixels
on every observation.

The benchmark pins app contents, Vox native dependencies, fixtures, reference,
assets and harness files throughout the trials and saves all raw counts,
endpoint brackets, membership checks and actual exit statuses.

## Validation cadence

The rendering follow-up contains three fixes: anonymous text-wrapper font
projection (`5ffc75c8`), physical textarea width rounding (`956b1d79`), and the
resize-grip stroke resolve. Focused layout, style, control and SVG grouping
checks accompany those changes; the page regressions retain exact pixels.
These checks do not reset the repository's existing broad-verification
cadence or claim completion of a broad suite.

The Brave comparison is a cross-browser acceptance check. It does not assign
optimization savings to a Vox change: that requires matched Vox control and
candidate observations at the same endpoint and workload. No reduction is
credited to the repository's 5,000,000-instruction optimization ledger here.

## Verified production build and remaining target

The pinned production bundle is `Build/hn-small-text/retina-controls-8/Vox.app`.
Its executable SHA-256 is
`9140ff0b754f7cf420af3b2e8ffa66a13e945cfe56d033c6c985d76cea410b17`;
its Graphite library SHA-256 is
`23eaccf96e0bf85b56350784606e39ee4d7addc07884ba2956a7f9be36a56b59`.
It was built from the shared working tree at `8b5ffc58`, with independent native
and message-channel edits in progress. `build-provenance.json` and the full
source manifests in that directory preserve the actual build inputs; the
executable is not claimed to come solely from that commit.

That bundle passes the three regular page tests, exact raw native-resolution
comparisons for the reduced comment, complete discussion and fractional inline
controls, the startup smoke check, and all eight instruction-harness unit tests.
The six focused SVG grouping cases compiled and executed successfully under
`retina-controls-7`; the focused control, anonymous wrapper and device-style
cases passed under `retina-controls-4`. The grip fix is commit `6be8b470`.

The first complete native comparison is retained under
`Build/hn-small-text/retina-controls-9/instructions`. All six observations exited
successfully, matched the unchanged raw reference exactly, and retained all 101
comment IDs:

| Pair | Vox instructions | Brave lower bound | Brave upper bound |
| --- | ---: | ---: | ---: |
| 1 | 7,844,436,549 | 7,156,784,864 | 7,219,008,367 |
| 2 | 7,866,837,218 | 1,735,672,585 | 1,790,574,814 |
| 3 | 7,875,866,652 | 1,727,774,620 | 1,768,761,111 |

**The requested 10% instruction reduction is not achieved.** The strict ratio
is 4.5584, above the required 0.90; Vox's median is 7.867 billion instructions.
Brave's first observation was substantially more expensive than its later
observations; it remains in the results. No observations are discarded or
credited as a Vox optimization. The benchmark and memory guard both returned 1
for the failed acceptance gate, with a sampled peak RSS of 1,148,223,488 bytes.
Earlier disk-space and build failures remain alongside the successful checks.

Fresh live checks of both original URLs also passed, with actual browser exits
zero, the requested URL/title/readiness, and comment identity validated.
Their PIDs were 80439 (discussion) and 80516 (reported comment). Document-only
screenshots and audits are in `retina-controls-9/live-discussion` and
`retina-controls-9/live-comment`. The latter visibly renders the opener at the
comment body's font size. These live checks establish loading and the reported
font correction; exact comparison uses the frozen fixtures above.

## Device projection follow-up

Commit `f207dcb9` skips unchanged dimensionless values and zero pixel lengths
when projecting a computed style into device coordinates. Keyword border
widths and dimensional transforms still scale. The regression checks shared
property identity, percentages, keyword widths, matrix translations and cache
reuse at four scales. Both `device_layout_style_test.v` (12 cases) and
`device_layout_projection_storage_test.v` (two cases) compiled and executed
successfully. The initial new-test crash and its corrected optional-value
handling remain in `Build/hn-small-text/projection-1` and `projection-2`.

The diagnostic sample in `Build/hn-small-text/profile-5` contains real page
installation, CSS projection and table layout stacks; its capture matches the
raw Brave reference exactly. Earlier samples missed rendering and remain
marked unsuitable for attribution. The delayed-response diagnostic earns no
instruction credit.

The current pinned production bundle is `Build/hn-small-text/projection-2/Vox.app`:

- Executable SHA-256: `768900a341df3d56a999e1e8b222d48b403beff0257543ed5fbe06b0db5bd106`.
- Graphite SHA-256: `8cd61beccc720e6e8a1c579b15ff8ddaec87f9b05c16bcdfbbe4575517646a23`.

The production build, startup smoke and all three raw native pixel comparisons
passed. Source manifests preserve the shared working-tree inputs. During the
build HEAD advanced from `d4a75b41` to `1f9184c2`; only the independent
`html/window_post_message_test.v` changed in the source manifest. The two
projection files were unchanged throughout compilation and verification.

The fresh three-pair acceptance check is retained in `projection-2/instructions`:

| Pair | Vox instructions | Brave lower bound | Brave upper bound |
| --- | ---: | ---: | ---: |
| 1 | 9,449,779,492 | 6,966,571,659 | 7,025,559,875 |
| 2 | 7,738,148,309 | 1,792,062,357 | 1,844,963,273 |
| 3 | 7,732,440,745 | 1,739,734,765 | 1,809,886,421 |

All six browsers exited zero, matched the reference exactly and retained all
101 comment rows. **The 10% instruction target still fails**: the strict ratio
is 5.4317 versus the required 0.90. The median Vox count is 7.738 billion and
the median Brave lower bound is 1.792 billion. Both first observations remain
in the results. The benchmark and enclosing guard returned 1 for the failed
acceptance gate; sampled peak aggregate RSS was 7,604,387,840 bytes.

These observations do not isolate the projection change from the other
working-tree changes since the earlier build. No matched Vox optimization
savings, broad-verification credit or ledger reset are claimed.

Fresh live checks of the projection bundle also passed. The discussion process
was PID 30850 and the reported-comment process was PID 30923; both exited zero
and passed URL, title and readiness checks. The comment audit also verified its
identity and opening sentence. Each launch used a new private profile, an
inactive test window, a 1024×768 document viewport at backing scale 2, and a
three-second settle period. The executable hash above was checked again.
`projection-2/live-discussion` and `projection-2/live-comment` retain the native
document-only screenshots, audits, browser logs and actual exit codes. The
comment screenshot visibly renders “This statement stood out to me.” at the
body's font size. The enclosing live-check guard returned zero, with a sampled
peak aggregate RSS of 1,132,789,760 bytes. Live loading and the reported font
correction passed; the frozen fixtures establish exact Brave pixel agreement.
