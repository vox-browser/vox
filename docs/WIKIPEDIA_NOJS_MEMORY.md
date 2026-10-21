# Wikipedia without page JavaScript: memory

## Allocator correction for the 50 MB target

The earlier measurements below used **Boehm**, including the 100 MB result.
They do not establish the memory usage of `-prealloc -gc none`. In the macOS
`vmmap` report, `VM_ALLOCATE` names an operating-system virtual-memory region;
it does not identify a JavaScript VM or a collector. The previous attribution
of roughly 60 MB of those regions to the collector does not apply to an arena
build.

The macOS builder now defaults to `-prealloc -gc none`. The Wikipedia benchmark
checks both binaries' allocator symbols before launching them, requires arenas
by default, rejects mixed arena/collector builds, and records allocator identity
in its protocol. Explicit historic Boehm comparisons require `--allocator boehm`.

### Corrected arena before/after: 50 MB remains unmet

The latest V-source comparison, three alternating optimized pairs, measures
**81.59 → 80.53 MB**, a **1.31% reduction**. The largest candidate settled
observation is **80,545,160 bytes**. The **50,000,000-byte limit still fails**.
All six raw viewport images match, all frozen-input guards pass, and all six script audits
report no page runtime, sources, source bytes or preloaded scripts.

| Arena comparison | Before median | After median | Reduction |
| --- | ---: | ---: | ---: |
| Text, parser and decoder lifetimes | 157,959,656 bytes | 142,624,256 bytes | 9.71% |
| Fixed markers and embedded SVG ownership | 142,837,224 bytes | 132,236,728 bytes | 7.42% |
| Full-pass style invalidation and static paint templates | 132,433,384 bytes | 127,288,808 bytes | 3.88% |
| SVG path parsing, formatting and paint projection workspaces | 127,223,248 bytes | 118,851,024 bytes | 6.58% |
| Inline CSS lengths, parser payloads, decoding and idle lifetimes | 118,785,560 bytes | 109,381,096 bytes | 7.92% |
| Updated native graphics providers with the same V executable | 109,381,096 bytes | 109,413,912 bytes | -0.03% |
| Native tokenizer, inline geometry and selector workspaces | 109,282,792 bytes | 106,104,272 bytes | 2.91% |
| Cascade contexts, pseudo traversal and SVG metadata | 105,924,048 bytes | 103,712,184 bytes | 2.09% |
| URL parser workspaces and immutable DOM URL snapshots | 103,859,664 bytes | 101,238,248 bytes | 2.52% |
| Selector workspaces, decoded SVG metadata and cache storage | 101,107,152 bytes | 97,060,328 bytes | 4.00% |
| XML tokens, static animation work and arena idle cleanup | 97,240,600 bytes | 96,028,088 bytes | 1.25% |
| Inline chunk and independent geometry workspaces, cache ownership | 95,765,968 bytes | 93,455,800 bytes | 2.41% |
| Matching-rule list workspaces and exact paint fragment reservations | 93,406,672 bytes | 92,620,216 bytes | 0.84% |
| Initial resolved-style sharing, counters, font handles and formatting tokens | 92,423,680 bytes | 89,474,440 bytes | 3.19% |
| Native HarfBuzz cache retirement | 89,195,888 bytes | 89,130,376 bytes | 0.07% |
| Glyph-index font initialization and native allocator relief | 89,032,072 bytes | 87,836,064 bytes | 1.34% |
| Updated native wrappers with unchanged V code/data | 88,229,256 bytes | 88,163,744 bytes | 0.07% |
| Retained geometry, scalar background queries, stylesheet and parser workspaces, geometry bounds | 87,819,656 bytes | 85,394,824 bytes | 2.76% |
| ASCII names, reusable scratch descriptors and numeric counter keys | 85,411,208 bytes | 84,002,160 bytes | 1.65% |
| Local SVG transforms, slimmer nodes and static layout queries | 84,002,208 bytes | 82,838,872 bytes | 1.38% |
| Exact text buffers, cached-header decoding, table flags and CSS probes | 82,920,816 bytes | 82,036,128 bytes | 1.07% |
| Iterator records, insertion snapshots, rendered text and counter targets | 82,199,920 bytes | 81,577,328 bytes | 0.76% |
| Empty reusable arena and allocator recycle-cache pages at idle | 81,593,736 bytes | 80,528,728 bytes | 1.31% |

Each row is its own three-pair cohort; these are aggregate build comparisons,
not isolated savings attributed to individual commits. Evidence is in
`Build/wikipedia-50mb/arena-text-lifetimes-paired2/` and
`Build/wikipedia-50mb/arena-svg-lifetimes-paired/`, followed by
`arena-static-paint-paired/`, `arena-svg-workspace-paired/`,
`arena-inline-length-paired/`, `arena-inline-native-queue-paired/`,
`arena-parser-workspaces-paired/`, `arena-cascade-workspaces-paired/` and
`arena-url-snapshots-paired/`, `arena-cache-lifetimes-paired/` and
`arena-idle-xml-paired/`, `arena-inline-chunks-paired/` and
`arena-style-lists-paired/`, `arena-initial-snapshots-paired/` and
`arena-native-font-idle-paired/`, `arena-glyph-index-fonts-paired/` and
`arena-native-frame-pool-paired/`, `arena-match-text-geometry2-paired/` and
`arena-scratch-counter-keys-paired/`, `arena-static-layout-queries-paired/` and
`arena-text-header-fixup2-paired/`, `arena-iterator-rendered-text-paired/` and
`arena-idle-pages-paired/`, including summaries, raw
process samples, allocator checks, resource audits and captures. Matching
`arena-{text,svg}-lifetimes-build-protocol.json` files pin the complete source
inputs, current compiler and native libraries. The static-paint and SVG protocols are
`arena-static-paint-build-protocol.json` and `arena-svg-workspace-build-protocol.json`.
The inline-length build protocol also pins its frozen V source, generated C,
compiler and native libraries. Its sampled launch peaks are 533.6–547.5 MB, so
this is a settled-memory reduction. The parser and cascade workspace cohorts
likewise pin their complete frozen inputs in matching build protocols. Their
sampled launch peaks are 539.5–544.7 MB and 536.2–546.4 MB respectively; these
changes do not meet a 50 MB peak budget either.

Replacing the native wrapper and Metal providers with the completed code from
`57c321a4`, while preserving the V executable byte for byte, measured
**109.38 → 109.41 MB**. It establishes no reduction for this static page. All
six captures and input guards pass; its largest settled observation is
109,626,832 bytes. `arena-inline-native-queue-build-protocol.json` pins the
providers and their verified source inputs. Both comparisons fail the 50 MB gate.

The changes retire stylesheet tokenizer/rule workspaces and raster-decoder
intermediates, avoid UTF-16 buffers for whole text replacement, reuse parser
scope boundary lists, keep preload work in its retiring document owner, resolve
fixed marker styles without loading the full counter catalog, and independently
own embedded SVG payloads and their recyclable paint trees. Retained SVG scenes
keep their document bytes alive until the last reader releases them. Focused
checks cover each completed change; later unmeasured changes receive no RAM
credit here. These private signed measurement bundles preserve the canonical
installed app.

The later cohorts also skip selective mutation histories during a pending full
style pass, avoid duplicate native static-page paint templates, reuse SVG number
scanners, parse raw SVG presentation paths directly, and retire numeric-formatting
buffers and temporary Canvas contours after copying their final strings, packed
segments and bounds. The inline-length V-source cohort additionally stores plain CSS
lengths and percentages inline, reuses parser character buffers, transfers
immutable token payloads, retires navigation-decoder work, discards unused
physical arena pages after reset, and avoids idle microtask/channel/chrome
allocations. The two latest V-source cohorts also retire the native no-JS HTML
tokenizer after parsing, retire inline geometry workspaces after publishing the
final flat pieces, reuse cascade matching contexts and pseudo-rule iterators,
avoid fixed selector-origin list allocations, and skip inapplicable SVG
presentation attributes and typed path geometry during resource discovery.
The final source-position preservation fix is included in the cascade cohort.
URL parser/snapshot work and the scripted-tokenizer extension are excluded
from that cascade executable. The cascade candidate
uses the original pinned native providers, not the separate queue experiment.
Its generated C SHA-256 is
`c6ed937bd1e619ebb2645fdc55924b5e80a25de693839d813978a47615a725fe`.

The URL-snapshot cohort freezes committed source `e06ea99f`, including
the URL parser workspaces, compact immutable DOM URL snapshots, and intervening
stylesheet parser and scripted-tokenizer fixes. It excludes later selector
invalidation workspaces, SVG background metadata reuse and idle shaping-cache
retirement. This is an aggregate comparison; individual changes receive no
isolated RAM attribution. Nine DOM URL checks and 29 URL parser checks pass in
both allocator modes and with retired arenas poisoned. The signed private app
passes headless startup and retains the original native providers. Its generated
C SHA-256 is
`67487a42646f8e7d313ddb36447445181d82527c0776bb5b4ca814d5fb5f82fd`.
Its sampled launch peaks are 513.7–525.6 MB. The build protocol records recovery
of an interrupted compilation from those exact generated C and native object
inputs; the final bundle is signed after moving the preserved compiler work out
of the app. No canonical installed app is replaced.

The cache-lifetimes cohort freezes committed source `f4723673`. It adds
selector-invalidation workspaces, retained SVG background dimensions, separately
owned text-shaping cache storage, and intervening replaced/flex sizing fixes.
XML token allocation changes and the arena idle-timer integration are excluded.
In particular, the frozen build still arms automatic text-cache cleanup only
under Boehm: no saving from automatic arena cache retirement is claimed. This
row measures the aggregate implementation, not individual commit savings.
Its sampled launch peaks are 509.8–524.4 MB, and its generated C SHA-256 is
`7cfc9933ca4fea30dc73a5011eceb1d77dfa10a38c8631e122944d20546b96e6`.
It passes signing and headless startup with the original native providers.

The selector workspace's 26 focused cases and shaping cache's 16 focused cases
pass in both allocator modes and with poisoned retired arenas. The shaping
fixture explicitly supplies the upstream test-font root after its first copied-
module run could not find the font. The SVG metadata batch has 13 passing cases
per mode, including all three new cases, and one failure in the existing
`test_ratio_only_svg_background_resizes_its_viewbox_without_changing_natural_metrics`
assertion (`commands.len` is zero instead of one). Restoring the unchanged SVG
implementation reproduces that failure; the committed production source snapshot
also reproduces it. Full-batch exit is one, and no whole-batch pass is claimed.
The six accepted Wikipedia viewport images remain byte-identical.

The idle/XML cohort freezes `d44437bf`, adding entity-free XML token reuse,
allocation-free prefix probes, namespace copy-on-write, and small-attribute
checking without a hash table. It also arms arena text-cache cleanup after a
completed static native frame and avoids animation lists/name maps for static
styles. Intervening committed CSS parser component-span changes are included;
this row gives no isolated attribution. Inline chunk workspaces and the later
invalidation-copy memo changes are excluded. Ten XML cases, 17 browser idle/
maintenance cases and eight static-animation cases pass in both allocator modes
and with poisoned arenas. The root fixture redirects only its V-side native
queue entry points to the existing deterministic test adapter. The corrected
idle-readiness fixture explicitly starts its document in `loading`.

The idle/XML signed private app passes headless startup. Its generated C SHA-256
is `31ad3f9c7da588d75a6d9fbec129e9289992e538b19e96777b46d4ff1ddbec88`.
Sampled launch peaks are 507.4–510.9 MB. All six raw viewports keep the prior
`3010d840c8adaf0a5b71254499c27d9888d21b0cc92246c2ce989af60d8bb1fd`
SHA-256, and all six script audits again report zero page runtimes and sources.
The 50,000,000-byte gate still fails.

The inline-chunks cohort freezes `57888c11`. It includes retained text-chunk
construction workspaces, font cache ownership across workspace retirement,
process-owned idle timer storage, invalidation-copy memo retirement and
independent inline geometry workspaces. The intervening frozen-replay audit is
included. Matching-rule list and counter-resolution workspaces and exact paint
fragment reservations are excluded. No individual change receives isolated RAM
credit. The 35 selected inline/font cases pass in both allocator modes and with
poisoned retired arenas; the revised timer fixture passes 18 arena cases and a
poison run. The signed app passes headless startup and retains the same pinned
native providers. Its generated C SHA-256 is
`8d9e8aaa58fb21c15ae7bccc532d2422bc86d2500a9751032eb88b9f05ed229f`.
Sampled launch peaks are 507.3–511.3 MB. All six raw viewport hashes remain
`3010d840c8adaf0a5b71254499c27d9888d21b0cc92246c2ce989af60d8bb1fd`;
all input guards and no-script audits pass. The budget remains unmet.

The style-lists cohort freezes `efc4c7d6`. It adds matching-rule list
workspaces and exact-sized text fragment buffers. Counter-resolution workspaces,
initial resolved-style interning and later geometry-copy changes are excluded.
The comparison is aggregate. Matching-rule checks pass 26 cases per allocator
mode plus a poison run; paint fragment checks pass four cases per mode plus
poison. Two larger paint test bundles exceeded the compiler memory ceiling and
are not counted as passes. The signed app passes headless startup. Its generated
C SHA-256 is `c7d9e461c83b124e9a0c1ce5a6e978767999f0789517e6b94a1eef76f58c497a`.
Sampled launch peaks are 505.5–508.8 MB. All six viewport hashes and script audits
match the earlier accepted cohorts. The largest settled observation is
92,702,184 bytes; the 50 MB budget remains unmet.

The initial-snapshots cohort freezes `5eb253e3`. It adds initial native
resolved-style interning before allocating a permanent duplicate, with each
style retaining its own raw-graph proof and copy-on-write behavior. Animated,
scripted and untyped compatibility styles keep the existing path. Counter
resolution retires intermediate vectors and owns final strings; formatting-token
snapshots retire at the existing tokenizer EOF boundary. Stable font handles
also avoid repeated HarfBuzz path-key allocation. Later native HarfBuzz cache
retirement and the glyph-index-only font initializer are excluded. This row is
an aggregate comparison, not isolated credit for individual commits.

The 35 selected style/cache cases pass in both allocator modes, with poisoned
arenas and under AddressSanitizer. Counter resolution passes 22 cases per mode
plus poison, formatting storage passes 29 cases per mode plus poison, and font
handle caching passes seven cases per mode plus poison with the explicit test-
font root. Poisoning exposed a copied counter-string lifetime error in an
intermediate revision; the accepted revision owns those strings. The signed
private app passes headless startup. Its generated C SHA-256 is
`a49feee519e004aa2289326b20bbdf492f3ba50acef0a2ea507192fe04644131`.
Sampled launch peaks are 499.6–501.4 MB. All six raw viewport hashes retain
`3010d840c8adaf0a5b71254499c27d9888d21b0cc92246c2ce989af60d8bb1fd`,
with every frozen-input and no-script guard passing. The 50 MB gate still fails.

The native-font-idle cohort freezes `b1396aaf`, adding native HarfBuzz
font/face/blob retirement, generation-protected borrowed handles, cleared bitmap
classification and reusable scaled-font slots. Thirteen focused cases pass in
both allocator modes and with poisoned arenas, including retained glyph runs,
late font availability and repeated idle/refill capacity. The later native
allocator pressure-relief call and glyph-index initializer are excluded.
The 65,512-byte median difference establishes no substantial page RAM saving.
The signed app passes headless startup; generated C SHA-256 is
`064ffcbbdb647c3459258a65ccb7158b2393d378345ed0ec9f08e0cb9e8d7d5a`.
Sampled launch peaks are 509.4–515.7 MB. All six viewport hashes, no-script
checks and frozen-input guards pass. The 50 MB budget remains unmet.

The glyph-index-fonts cohort freezes `7ad241b3`. The macOS arena builder now
stages an additional x.ttf entry point that follows the active compiler's exact
initializer order while omitting its dense cmap construction. The compiler
checkout and its ordinary initializer remain unchanged. Vox already uses sparse
Unicode lookup and calls the reader by glyph index for metrics, outlines and
kerning. Nine focused font cases pass in both allocator modes with the staged
entry point enabled and under arena poisoning; three staging unit tests pass.
The idle cleanup also asks the native malloc zones to return freed pages after
font retirement, covered by 13 checks per allocator mode plus poison. Both
changes are included in this aggregate comparison. The generated C SHA-256 is
`2a4bc3bf7a9e2a95100f0bf49dd4a34fc48378bd50c9c4f0b69d96b28f48002a`;
the build protocol also pins the complete staged font-runtime manifest.
Sampled launch peaks are 498.6–500.6 MB; the largest settled observation is
87,901,576 bytes. Signing, startup, all viewport hashes and no-script/input
guards pass. The 50 MB budget remains unmet.

The native-frame-pool cohort uses the same V code and data with committed
Skia/Metal wrappers from `3649ed83`, including per-frame autorelease draining.
The original pinned Dawn provider remains. Native graphics lifetime and redraw
checks pass against the actual new wrappers. Re-signing the bundle changes its
executable signature bytes: `arena-native-frame-pool-code-sections-identity.json`
verifies identical sizes and contents for all 34 Mach-O sections rather than
claiming identical whole-file hashes. The aggregate 0.07% median difference
establishes no substantial RAM saving; independent cohorts must not be combined
as isolated change savings. Sampled launch peaks are 495.0–509.3 MB and the
largest settled observation is 88,556,984 bytes. Signing, startup, all six raw
viewport hashes and every no-script/input guard pass. Later retained-geometry
copies, scalar background queries and callback traversal changes are excluded.
The 50 MB budget remains unmet.

The `arena-match-text-geometry2` cohort holds those native libraries
fixed and includes scalar background-list queries, committed retained-geometry
copies, stylesheet insertion workspaces, borrowed callback vectors, parser text
storage, and streaming SVG bounds accumulation. It freezes `6002e21c` plus ten
explicit source overlays, subsequently authenticated against committed
`a3487c6a`. The build protocol pins every file and generated C SHA-256
`82226bb8ee21285d371984226ae64b14a3ed1f655d23065856613e3506b28b1b`.
These are aggregate savings, not isolated credit for individual changes.

The stylesheet, callback, parser and geometry selections respectively pass
18, 3, 13 and 6 cases per allocator mode plus arena poisoning. The callback
selection excludes one older test whose failures were reproduced on its
unchanged baseline; its failed whole selections remain preserved. The first
geometry attempt failed its allocation budget because V boxed a mutable
accumulator. Returning scalar records fixes that failure without changing the
assertion. The stopped first private build receives no measurement credit.

All six captures retain raw viewport SHA-256
`3010d840c8adaf0a5b71254499c27d9888d21b0cc92246c2ce989af60d8bb1fd`;
signing, startup, input guards and script audits pass. Sampled launch peaks are
490.97–492.64 MB, so this does not meet a 50 MB peak budget either. The signed
executable SHA-256 is
`703e2246faa536851db5aaea8ef78bf026be3a423b882c3d2a99787bbe4ec117`.
Later ASCII name validation and reusable scratch descriptors are excluded.
The canonical installed application remains untouched.

The `arena-scratch-counter-keys` cohort freezes `e6c3b06a` plus two
counter-key overlays, authenticated against committed `1b469a16`. It includes
the intervening committed source and keeps the same native libraries. ASCII
name validation avoids rune and delimiter vectors on its ordinary path.
Scratch descriptors reuse thread-owned native slots, with generation checks
protecting stale copied handles. Counter history uses node/pseudo-element
numeric keys instead of formatting strings. Three name cases, 13 platform
lease cases, seven lease/layout integration cases and six counter-key cases
pass per allocator mode plus poisoning. Four corrected existing counter
fixtures also pass with the original string keys. Their optional arguments
are bound before calls, preserving inputs and assertions. An unrelated
diagnostic-label test still fails on both key implementations and is excluded;
the original failures and private binding probes remain recorded.

Its generated C SHA-256 is
`30300a199068a25a96c666b4de9aee01baee795bc759b04b95c561068f306a42`;
the signed executable is
`56cb24c027de7eea177504694e92c5827babebf21f98c4003ba263fdce3d9bde`.
Signing, startup, all six raw viewport hashes, script audits and input guards
pass. Sampled launch peaks are 489.88–492.90 MB. The settled and peak 50 MB
budgets both remain unmet. Later local SVG-transform projection is excluded,
and the canonical installed bundle remains untouched.

The `arena-static-layout-queries` cohort freezes `2190b5c6` plus two
scroll-snap overlays authenticated against committed `23eaec44`. It includes
local SVG-transform projections, removal of the duplicate listener-type array
from every DOM node, borrowed line-box queries, fixed pseudo-element inventories
and a no-work scroll-snap preflight. Their selections pass 9, 10, 8, 7 and 14
cases respectively in both allocator modes plus poisoning. It retains the same
native providers; intervening committed source is included in this aggregate
comparison. Later anonymous layout-cache interning is excluded.

Its generated C SHA-256 is
`43b1cfc387296d3f913e5a00f4712d68cd4239d74fe8821e7f9fd1bace986179`;
the signed executable is
`f6195e412e384b25a0d9ff3268fad8fb04aa0be44deb1f2c504c78404f11aa4a`.
Signing, startup, all six raw viewport hashes, script audits and input guards
pass. Sampled launch peaks are 488.90–491.24 MB. The settled and peak 50 MB
budgets both remain unmet. The canonical installed bundle remains untouched.

The `arena-text-header-fixup2` cohort freezes `b98e59d7` plus five CSS
probe/validation overlays authenticated against committed `43d09d1c`. It retires
cached-header JSON work, allocates DOM text results once, retires table-fixup
flags and substitution-validation argument records, and avoids constructing a
Parser for custom-property keyword probes. The respective focused selections
pass 5, 9, 5 and 16 cases per allocator mode plus poisoning. Existing text-smoke
selection was narrowed after unrelated clone fixture C-generation failures;
the retained selected bodies and assertions are unchanged. An initial new
allocation assertion exposed discarded substitution grammar records. Retiring
those records passes the same assertion; the stopped first candidate receives
no RAM credit. Intervening committed cache and event-loop changes are included.

Its generated C SHA-256 is
`070ea61680e1e3f9a5a3bdc3f8a281155861f7fc496530c8a2b0cc57b0aa791f`;
the signed executable is
`a399d71dbb63859c4bd79458447a71feebf304d67c6a5ade89b9295a01d9b33a`.
Signing, startup, all six viewport hashes, script audits and input guards pass.
The same native providers are retained. Sampled launch peaks are 488.16–490.15 MB;
both 50 MB budgets remain unmet. Later iterator-record, post-connection snapshot,
rendered-text and counter-target changes are excluded. The installed app is
unchanged. A separate production-frontend flag experiment failed compilation
and receives no memory credit or build-setting change.

The `arena-iterator-rendered-text` cohort freezes `8d0712e3` plus seven
counter-target overlays authenticated against committed `d3de6275`. Iterator
records retire with their item buffers; insertion snapshots retire after their
last post-connection step; ordinary rendered text avoids UTF-16 and duplicate
whitespace buffers; counter target queries pass scalar records by value.
Ten iterator cases, five insertion cases, seven rendered-text cases, 32 existing
transform/grapheme/first-letter guards and seven counter cases pass per allocator
mode plus poisoning. The insertion fixture needs a test-only C macro to enable
its existing Boehm helper bodies with current V. The merged transform fixtures
alias the html import to avoid a collision with existing local variable names.

The counter fixture originally required its full traversal to allocate. Both
paths now allocate zero in that empty workload, so the guard additionally
accepts zero/zero while preserving the original ratio for nonzero results and
all counter value/origin assertions. Original failures remain recorded.
The older diagnostic-label case remains excluded for its prior baseline failure.

Generated C SHA-256 is
`d7a53a65a84841239f3e3a81885eb9bf90a53cb3f983ca0a9425afd4ede06b0c`;
the signed executable is
`8f019fac16c2c5f4be22f38bae9d1ed91e003ea4831feeba2d575b9d2b19fe6e`.
Signing, startup, all six viewport hashes, script audits and input guards pass,
with the same native providers. Sampled launch peaks are 487.95–489.23 MB.
Both 50 MB budgets still fail. Later idle arena-page trimming is excluded,
and the installed app is unchanged.

The latest `arena-idle-pages` cohort freezes `73223a08` plus three idle CSS/layout
overlays authenticated against committed `c9fa7be3`. It discards physical pages
from reset empty shaping, matching, font-input, property-index and inline-item
workspaces, and from detached dead blocks in V's thread-local recycle cache.
Mappings, capacity and live allocations remain intact. Kernel residency tests
verify page retirement and refill; nine platform, six shaping, 12 CSS and seven
selected layout cases pass in both allocator modes and under poisoning.

Three older layout cases fail identically before the new trimming calls and
remain excluded: hover, compositor/caret and resized-output snapshots. The
original whole-batch failures are retained. Poisoning also exposed stale-list
and SVG fixtures holding earlier scene data without leases; `4e72b6ce` adds the
required leases while preserving their inputs and assertions. Passing layout
checks use this candidate's exact frozen source, excluding unrelated dirty
viewport work. Only those seven selected cases receive pass credit.

Generated C SHA-256 is
`dc9348d27726163dbc1bc88e4b77632cf22d6a27b2dc5d5de7c9d21c8d112d1f`;
the signed executable is
`db5d1c5e746f23ff780f5c633fa236474ea7d2f824ac13cc19913e1412a3815a`.
Signing, startup, all six viewport hashes, script audits and input guards pass,
with unchanged native providers. Sampled launch peaks are 487.46–489.11 MB.
The settled and peak 50 MB budgets still fail. Later lazy custom-function maps,
shared empty content records and layout child snapshots are excluded. The
installed app remains unchanged.

The conditions below also apply to these cohorts: `-prealloc -gc none`, optimized
C, the unchanged 40-file cache, 1024×768 CSS pixels at DPR 2, a visible background
window, and simultaneous app/descendant physical footprint measured before PNG
allocation. Diagnostic samplers and unoptimized pilot builds are excluded.

Reproduce the latest V-source cohort with:

```sh
python3 tools/benchmark_wikipedia_memory.py \
  --before Build/wikipedia-50mb/arena-iterator-rendered-text.app/Contents/MacOS/Vox \
  --after Build/wikipedia-50mb/arena-idle-pages.app/Contents/MacOS/Vox \
  --cache Build/wikipedia-100mb/cache \
  --network-deny Build/pikabu-instructions-network-deny.dylib \
  --activity background --repeat 3 --allocator prealloc \
  --output Build/wikipedia-50mb/arena-idle-pages-recheck
```

The command exits nonzero while the 50 MB budget is exceeded.

### Initial corrected arena cohort

Three fresh alternating pairs measure **158.8 → 158.0 MB**, a **0.46% reduction**.
The largest candidate settled observation is **158,172,672 bytes**. The
**50,000,000-byte limit fails**. All six viewport images are byte-identical, the
input guards pass, and both binaries verify as arena builds without Boehm.

| Metric | Arena before | Arena after |
| --- | ---: | ---: |
| Median settled physical footprint | 158,778,856 bytes | 158,041,576 bytes |
| Range of three settled medians | 158.5–158.8 MB | 158.0–158.2 MB |
| Largest individual settled observation | 158,844,416 bytes | 158,172,672 bytes |
| Median sampled launch peak | 605.3 MB | 602.6 MB |

The candidate packs optional generated content and shared builtin marker data
out of ordinary computed-style records (`6a7157ee`) and avoids resolving counter
registries for content with no counter references (`96d6a3e5`). These changes
do not provide a substantial Wikipedia RAM reduction. The separate earlier
style-only comparison also showed less than 1% improvement. No reduction from a
Boehm measurement is credited to the arena build.

Both variants use the same optimized current V frontend and native libraries,
with `-prealloc -gc none -cflags -O2` and no compiler fallback. The compatible
compiler used here is `/Users/alex/code/v-latest/v`, SHA-256
`dfd0ac6c17cd0c10e804be6720f363c13fe242bdaba5d4315f1a6961c06ce607`.
The compiler on the default `PATH` fails the repository's bounded arena
reallocation check. Source inputs are fixed measurement archives of canonical
commit `905348a0`, with the candidate's exact changes recorded separately.
These are benchmark artifacts; development and commits remain on canonical
`master`. The installed `Build/v/Vox.app` still contained Boehm when inspected;
these measurements describe the preserved arena bundles.

Conditions remain the same 40-file frozen portal cache, 1024×768 CSS viewport,
DPR 2, visible background window and 15 seconds after readiness. The last-second
physical-footprint window precedes screenshot allocation and includes browser
descendants. Page runtime, sources, source bytes and script preloads are all zero.

Evidence is under `Build/wikipedia-50mb/`: `arena-content-paired/summary.json`
and its six raw observations, `arena-{before-head,content}-build-protocol.json`,
the frozen source/generated C, signed bundles and startup logs. Earlier attempts
rejected by activity or sampling guards remain separate. The initial style-only
composite explicitly identifies its successful pairs and rejected later samples.

An unoptimized diagnostic of the baseline found about 73 MB allocated in the
main thread's base arena and 53 MB in the native document arena. Those totals
include live and obsolete allocations; they are not JavaScript heap sizes or
an independent RAM result. Resetting or releasing complete owners is necessary
to reclaim arena allocations; merely dropping a reference does not do so.

Validation passes the arena style regressions, focused collector ownership
checks, 12 content/counter invalidation tests in each allocator mode, all three
bundles' headless startup checks, four arena-runtime staging tests and 26
benchmark/observer tests. An exploratory 29-case Boehm bundle failed its
default-allocation comparison; that failed log is preserved under
`style-storage-regressions4/boehm-run.log` and receives no full-batch pass credit.
This does not claim a full repository test run.

Reproduce the corrected comparison with:

```sh
python3 tools/benchmark_wikipedia_memory.py \
  --before Build/wikipedia-50mb/arena-before-head.app/Contents/MacOS/Vox \
  --after Build/wikipedia-50mb/arena-content.app/Contents/MacOS/Vox \
  --cache Build/wikipedia-100mb/cache \
  --network-deny Build/pikabu-instructions-network-deny.dylib \
  --activity background --repeat 3 --allocator prealloc \
  --output Build/wikipedia-50mb/arena-recheck
```

The command exits nonzero while the 50 MB budget is exceeded.

## 2026-10-21: below 100 MB settled RAM

Five fresh alternating before/after pairs of the Wikipedia portal measure
**123.2 → 87.3 MB**, a **29.1% reduction**. Every candidate observation in every
settled window is below **87.7 MB**, passing the **100,000,000-byte** limit.
All ten native document captures are byte-identical. MB means 1,000,000 bytes.

| Metric | Before | After |
| --- | ---: | ---: |
| Median settled physical footprint | 123,159,776 bytes | 87,328,064 bytes |
| Range of five settled medians | 121.6–123.5 MB | 86.6–87.6 MB |
| Largest individual settled observation | 123,602,168 bytes | 87,622,976 bytes |
| Median sampled launch peak | 558.7 MB | 521.9 MB |

**The 100 MB result applies to settled memory. Startup still exceeds 500 MB.**
Peak counters cover launch through the pre-capture endpoint and are polling
lower bounds, including the normal filter helper while it is alive.

The saving comes from the native allocator startup policy
(`c2875366`): macOS libmalloc's `MallocSpaceEfficient=1` takes effect before V
globals, parsing and painting. A small native constructor restarts the same
executable once, preserving its PID, arguments and inherited descriptors.
Explicit caller settings, including `0`, retain precedence. Helpers inherit
the setting. The policy is included in the native host and the packaged Skia
bridge, so ordinary bundle launches and direct executable launches use it.
The benchmark supplies no allocator setting, GC override or extra collection.

The separate idle stylesheet-syntax cleanup (`31a8afb5`) passes borrower,
deferred CSSOM and collection tests, but its portal pilot showed no RAM saving;
it receives no isolated reduction claim. Font-catalog retirement, manual malloc
pressure relief and encoded-frame experiments were also ineffective and are
excluded from the shipped rendering changes.

Both variants use the same verified 40-file frozen cache at
`https://www.wikipedia.org/`, a 1024×768 CSS viewport and DPR 2. Page JavaScript
runtime, sources, source bytes and script preloads are all zero. The observer
checks document readiness, fonts, the decoded Retina globe and 21 sprite
elements. Windows stay visible in the background on the test display; the
last-second median follows 15 seconds of settling and precedes PNG allocation.
Memory is the simultaneous physical footprint of the browser and its discovered
descendants, rather than summed RSS. Foreground attempts failed the activity
guard and receive no accepted measurement credit.

The measured bundles, generated C, build logs, hashes, screenshots and raw
samples are retained in `Build/wikipedia-100mb/`. The accepted cohort is
`final-paired/summary.json`; its input and capture guards pass. Failed attempts
remain separate. `cache-restoration.json` records restoration of the exact
historic cache hashes after a diagnostic accidentally wrote to the template.
The canonical app received the measured allocator library while preserving its
existing executable and other rendering libraries, followed by bundle signing
and a successful headless startup check. See `installed-policy.json`. A fresh
verification of that installed bundle snapshot measures **86.4 MB** (largest
settled observation **86.5 MB**) with the same viewport bytes;
`installed-background/result.json` retains that separate observation.

Validation passes the three native bootstrap integration tests (default,
explicit settings, argument/PID/descriptor preservation), native graphics
ownership and pixel checks, CSS borrower/deferred-CSSOM tests with explicit
Boehm and no GC, Boehm lifetime tests and existing syntax-cache regressions,
24 benchmark/observer unit
tests, and native startup. This does not claim a full repository test run.

Reproduce the accepted comparison with:

```sh
python3 tools/benchmark_wikipedia_memory.py \
  --before Build/wikipedia-100mb/before.app/Contents/MacOS/Vox \
  --after Build/wikipedia-100mb/allocator-candidate.app/Contents/MacOS/Vox \
  --cache Build/wikipedia-100mb/cache \
  --network-deny Build/pikabu-instructions-network-deny.dylib \
  --activity background --repeat 5 --limit-mb 100 --allocator boehm \
  --output Build/wikipedia-100mb/recheck
```

## Earlier Chrome comparison

On 2026-10-18, five fresh alternating pairs measured **110.5 MB for Vox versus
382.6 MB for Chrome: 71.1% less settled physical memory**, with page JavaScript
disabled in both browsers. MB here means 1,000,000 bytes. All five Vox document
captures match the previous Vox baseline exactly.

| Pair | Vox settled bytes | Chrome settled bytes, JS off | Reduction |
| --- | ---: | ---: | ---: |
| 1 | 110,511,280 | 383,627,288 | 71.193% |
| 2 | 111,019,184 | 386,215,816 | 71.255% |
| 3 | 110,494,968 | 380,645,112 | 70.972% |
| 4 | 111,494,368 | 382,398,104 | 70.843% |
| 5 | 110,314,744 | 382,644,008 | 71.170% |
| Median | **110,511,280** | **382,644,008** | **71.119%** |

Both acceptance gates pass: the median Vox result is below 30% of Chrome's
median, and the largest Vox result (111,494,368 bytes) is below 30% of the
smallest Chrome result (380,645,112 bytes). The latter comparison saves
70.709%, with 2,699,165.6 bytes of margin below the target.

This is a settled-memory result. Median sampled launch peaks were **544.8 MB
for Vox and 779.4 MB for Chrome**; observed ranges were 531.4–559.5 MB and
776.3–784.3 MB respectively. These are simultaneous polling lower bounds,
reported separately. The work does not achieve a 70% reduction in startup peak.

## Conditions

Both browsers replay the same frozen `https://www.wikipedia.org/` page at
1024×768 CSS pixels and DPR 2: 40 cache files, 10 response bodies, declared
synthetic HTTP metadata, and no live fallback. The HTML SHA-256 is
`5c0de7d8a1af1dc8c06cc2a517265ff96db0ed11114a62be2625ed13c9cdb466`.
Both windows remain visible in the background during readiness and settled
measurement, away from the pointer, with matching activity checks. Chrome briefly
activates at launch, before the controlled interval. Chrome is for Testing
155.0.8059.79. The host is an
Apple M5 Max, 18 logical CPUs, 128 GiB RAM, macOS 26.5 (25F71), with shared
machine load recorded in the raw observations.

The strict v4 observer samples the simultaneous task physical footprint of the
browser and every discovered descendant, including GPU, renderer, utilities,
filter workers and discovered reparented helpers. WindowServer and shared system
services are excluded for both. Polling is requested every 5 ms; short-lived
processes between polls can be missed. Readiness is followed by 15 seconds of
settling, and the final-second median ends before screenshot allocation. RSS
and sums of unrelated task lifetime peaks are not the target metric.

Chrome disables page scripts before navigation and enables its script-based
document audit only after the memory endpoint. Vox reports no page runtime,
script sources, source bytes or script preloads. Font/resource/readiness,
density, activity and actual process-exit checks pass for every observation.
No GC overrides, manual benchmark collections or memory-profiler/ledger/GC
diagnostic injections are used. Vox retains the pinned, process-local offline
network-deny guard. The ordinary filter worker exits at idle and is included
while alive.
Every 2048×1536 Vox frame has PNG SHA-256
`52bb9be634a7a01d6e673509d53d6807bdcd90e3d0404164ae661fc6ba319322`.
Pixel equality refers to the previous Vox baseline, not to Chrome.

## Implementation and checks

The reductions preserve the HTML/CSS rendering path and normal interaction
state. They reduce common record sizes, share immutable values, avoid empty
optional state, and release retired document and paint graphs at ordinary idle.

- [Shared computed-property pages](../css/computed_property_store.v) (`ca92ef73`)
  use copy on write and transient
  exact-pointer interning. CSS checks pass in both GC modes and normal C-O2;
  eight layout functions pass in both modes. Ownership guards verify retired
  styles and images are not retained by the interner.
- [Optional grid metadata](../dom/document.v) (`0e2b4500`) reduces LayoutNode
  from 880 to 752 bytes;
  default reads and empty updates allocate nothing. Six functions pass in both
  GC modes, including live CSSOM and snapshot independence.
- [Lazy element interaction/HTML snapshots](../dom/element_interactive_data.v)
  (`722f9bcb`) reduce ordinary concrete
  element allocation buckets to 2,048 bytes. Both GC modes and normal C-O2 pass
  the selected checks: 100 invocations, 8,404 assertions, including ownership.
- [Compact selector variants](../css/simple_selector_storage.v) (`201f3f90`)
  reduce SimpleSelector from 496 to 176
  bytes. All 93 selected functions pass in each GC mode and normal C-O2. The
  ordinary Boehm result combines preserved 92+1 runs after correcting one
  assertion about a private tag; the original failed controller stays failed.
- Earlier committed changes compact computed caches, avoid empty pseudo state,
  replace retaining callback contexts, release paint scratch after drawing,
  and isolate the default filter engine in a worker that exits at idle. The
  worker's isolated browser RAM saving is not claimed separately.

C9 broad validation covered 797 unique functions per GC mode and 100 exact
upstream LibJS AST fixtures through an audited composite. Original failed
attempts and reviewed harness repairs remain preserved. This does not claim
all 797 ran again after the later features; broad flags omitted production
Skia text. The final **11 smoke cases and 8 mandatory SVG guards pass** through
the reviewed 6+13 composite described below. All eight SVG cases are pixel-exact;
the original fuzzy bounds and sparse platform allowances are unchanged. Canvas
text uses its existing sparse allowance: maximum channel error 8 and 577 pixels
above its base tolerance, within the unchanged limits of 41 and 1,700.

## Build and evidence

The measured production bundle is
`Build/wikipedia-nojs-ram-70/candidate-integrated-v13/source/Build/v/Vox.app`.
Its source commit is `a5c6fd2ba7e833d8c8ee68fe3adc51bd270ca730`, an isolated
C9-based integration of the 12 exact canonical patches listed in
`candidate-integrated-v13/integration-requirements.json`. It contains 6,280 Git
blobs plus the private build script. It excludes unrelated concurrent changes,
including selector borrowing commit `e289178a`, and is not byte-identical to
the current canonical HEAD. The feature commits themselves are in the canonical
repository.

That historic measured bundle used V's compatibility compiler, Boehm and native
Clang `-O2`, without V `-prod`. Build, linked-library closure, signature, worker-input
preflight and headless startup all exit 0. Source/native/toolchain/runtime pins
remain unchanged. The executable SHA-256 is
`9925a47e76a1457ead9ada6fd6495db5d22505944d57eb0567add11feda87683`.
Private validation does not replace the concurrently owned canonical
`Build/v/Vox.app`.

Evidence is retained under `Build/wikipedia-nojs-ram-70/`:

- `final-five-paired-c13-v1/{manifest,result}.json` and `raw/`: all ten raw
  timelines, readiness/resource audits, process identities and five exact frames.
  The raw summary SHA-256 is
  `ddb60c910be3c34404afb67018e11c2a3ea63c4c54ada0138e986d273cb42058`.
- `candidate-integrated-v13/`: committed archive, source proof, generated C,
  compiler response, production logs and preflight/runtime receipts.
- `regression-integrated-c13-v2/` and `regression-integrated-c13-v3/`:
  guarded visual results and the final `composite-result.json`, SHA-256
  `d4771bd37029dc6939cf5fd3739bc80b17854a98ca6b940a67e78a9d6682dbf0`.
- `broad-integrated-v9-composite-result.json`, focused pager/grid/DOM receipts,
  and `simple-selector-compact-v1/handoff-final.json`: functional and ownership
  checks, including preserved failed controls and attempts.

C10 and C12 were valid setup-only checkpoints at 64.592% and 67.9066% less
settled RAM. C10's separately labeled normal-JS Chrome supplemental result reused
its Vox row and is not the final comparator. C11's GUI navigation failed because
the old executable lookup selected the injected offline-guard dylib as its
worker; it has no RAM credit. Kernel-path fix `0109242b` is included in valid
C12 and C13. All failed output remains retained; the final cohort contains five
fresh complete pairs without retries or excluded observations.

The first visual attempt, `regression-integrated-c13-v1/`, captured its first
frame but could not compile the comparator: inherited `VEXE` selected a newer,
incompatible V standard library. That attempt remains failed. The unchanged
comparator accepted the retained frame with the original bounds after setting
`VEXE` to the explicitly selected fallback compiler. This environment-only
correction is recorded in `regression-integrated-c13-env-recovery-v1/`, with
18,518 compiler/library/native/source/artifact pins unchanged. The browser,
capture policy and comparison tolerances were not changed.

The second visual controller stopped when the separately owned canonical app
changed during private capture. Its first six cases completed every guard; the
seventh pixel comparison passed but was excluded from accepted coverage because
the canonical-app guard then failed. All private-source/binary/provider pins
remained unchanged. The final visual result combines those six accepted cases
with 13 guarded passes from a fresh manifest. That continuation exits 0 and
retains the unchanged canonical-app guard. Together they cover the original 19
cases exactly once in accepted coverage. Both failed controllers remain failed;
no guard or tolerance is waived.
