# Hacker News: another 15% below current Vox

The frozen Hacker News startup-through-PNG benchmark now uses **17.080% fewer
instructions by median** than the original current-Vox baseline:
**4,793,590,625 → 3,974,847,245**. Its conservative reduction is **16.115%**.
The requested 15% gate passes without changing pixels, content, references,
tolerances, author-script policy or measurement boundaries.

The selected final cohort has seven alternating ImageIO-control/default-candidate
pairs in one production executable. All fourteen observations pass exact pixels,
all 30 story identities, readiness, native endpoint ownership and normal-exit
checks. All fourteen native audits have zero JavaScript/native errors. Candidate
trials use the packaged production defaults; only controls disable the new PNG
encoder. The original baseline executable was replaced in the shared bundle,
so the overall percentage compares historical and final cohorts. It does not
isolate every intervening shared-checkout change. Separate same-executable
codec and PNG controls establish those changes' savings.

## Scope and build identity

The endpoint remains exclusive browser resource-coalition creation through
completed encoded document PNG availability: startup, window setup, filtering,
JavaScript, layout, paint and PNG encoding. Vox's native endpoint precedes PNG
file writing, capture audit and teardown. Counts include exited owned helpers
and audited owned system services. GPU execution and outside services are
excluded. The protocol's native counter markers remain enabled throughout;
acceptance runs use no V-profile, sampler or injected probe.

The unchanged archived homepage and five resources are at
`Tests/Browser/Brave/hn-home-instructions`. Trials retain author scripts, private
profiles/caches, a 1024×768 CSS viewport at 2× backing/capture scale, document-only
capture, two-second settle and the existing pixel reference. Ambient proxy
settings are removed; resources replay over loopback. OS filesystem/shader
caches remain warm. These figures establish frozen-page startup/capture CPU
work, not isolated rendering time, live-network performance or scrolling FPS.

Original executable SHA-256:
`f769e44dbef6c5c309654f532cadf36bc7d5288a4b99c9f4a03f40845649be49`.
Final executable SHA-256:
`937e8774bf4fd32a0e6796251b81c3faf60d2d7d1fa1a72943edb596ae5b5365`.
Production receipt `20261102-181235-9c224617` has identical before/after build
inputs and includes `f174534c2`. The harness pins the whole app, native libraries,
resources, reference, fixture, tools and runtime-read checkout assets, rejecting
changed identities. Runtime-file pinning was added in `74269a058`; earlier
cohorts did not independently pin checkout-read codecs. Their receipts and
archived original assets supply historical provenance, rather than a rerun of
the complete original executable. Fresh LaunchServices processes and helpers are
adopted by the same private PID registry used by the memory guard.

## Selected counts

| Trial | Original Vox baseline | ImageIO control, final executable | Default final candidate |
| --- | ---: | ---: | ---: |
| 1 | 4,790,319,809 | 4,118,626,245 | 3,991,019,928 |
| 2 | 4,778,040,604 | 4,077,943,968 | 3,973,772,458 |
| 3 | 4,862,329,540 | 4,093,518,240 | 3,973,505,339 |
| 4 | 4,813,725,682 | 4,089,239,188 | 3,974,847,245 |
| 5 | 4,799,324,150 | 4,080,396,242 | 3,984,274,159 |
| 6 | 4,793,590,625 | 4,081,594,127 | 3,969,011,049 |
| 7 | 4,757,734,898 | 4,079,244,985 | 3,976,091,410 |
| Median | **4,793,590,625** | **4,081,594,127** | **3,974,847,245** |

The integer acceptance gate is:

```
20 × max(final upper) = 79,820,398,560
17 × min(original lower) = 80,881,493,266
79,820,398,560 <= 80,881,493,266
```

The selected coalition intervals have equal lower/upper counts. The final PNG
change saves 106,746,882 between medians; its median paired saving is
112,583,078. Every paired difference is positive, ranging from 96,122,083 to
127,606,317. Its conservative candidate/control ratio is 0.978684.

The host has 18 logical CPUs. The original cohort began at one-minute load 7.48.
Final matched control loads range 3.263–3.825 and candidate loads 3.286–3.810.
Concurrent host work and retained system caches qualify comparisons across
historical builds; the paired PNG controls share the final build and conditions.
No sample is removed or retried to pass.

## Retained implementation

- `3a6d15860`: LaunchServices supplies `MallocSpaceEfficient=1` before libraries
  load, avoiding the allocator constructor's second browser execution. Direct
  launches retain the fallback; explicit settings, including zero/empty, win.
- `66adaca3e`, `81ac79316`, `dafe2687b`: indexed cosmetic/request/resource tables
  restore queried values, and the full pinned list parser loads on demand.
  Mutation, iteration, Unicode and independent default/custom/default restores
  retain their behavior. Resource scriptlets remain source data until requested.
  No site-specific path or reduced blocklist is used.
- `6ac45140b`: explicit diagnostic codec assets allow matched old/new controls
  in one installed executable. Invalid selected inputs fail without fallback.
- `fa4cb5794`, `5530478c4`: the helper omits unused direct dependencies; the
  production linker removes unreachable code and unused libraries.
- `84d5ba47e`: deferred background-resource patches force a fresh resource/style
  snapshot when they cannot complete. This restores vote arrows lost after a
  concurrent retained-viewport change while retaining layout geometry.
- `f174534c2`: opaque 8-bit RGBA sRGB captures use bounded smaller DEFLATE tables,
  retaining the 32 KiB match window, PNG row format, profiles, Exif dimensions
  and integer density. Other spaces/layouts, transparency, fractional density
  and oversized input retain ImageIO. The default HN PNG is 464,045 bytes versus
  461,920 for ImageIO, a 0.46% size increase. All seven pairs retain exact pixels,
  profiles, density, metadata chunks and unfiltered rows.

The indexed snapshot grows from 19,286,472 to 28,093,263 bytes, while compressed
engine source shrinks from 322,016 to 112,087. This exchanges bundle data size
for less parsing; no memory-reduction claim is made. Shared commit `9076bb9bd`
packages the complete codec/metadata/data set, preventing non-`-prod` V embeds
from mixing changed checkout codecs with an older bundled snapshot.

## Verification

The final pinned production bundle passes signature verification, real
JavaScript/native startup, helper startup and all **21 screenshot comparisons**,
including **eight exact SVG mutation guards**. Existing fuzzy bounds are
unchanged. The final broad batch covers all retained optimizations through
`f174534c2`; additional measured savings after that batch are zero.

All **180 PNG comparisons** pass: 45 varied pixel/profile/density/metadata cases,
normal and forced fallback paths, ARC and non-ARC. Sanitized execution also
passes. The adblock implementation passes 17 files/52 functions under each of
Boehm and no-GC at the indexed-resource stage, with fresh helpers; all 28
Node/native cases pass, including actual restored scriptlet/dependency execution.
The resource-refresh fix passes nine cases in three layout files per GC mode.
Benchmark/counter/guard/runtime-identity checks pass 107 tests.

A separate injected diagnostic on the preceding packaged build verifies
JavaScriptCore evaluation of the exact 5,215-character archived `hn.js`; it is
not a script-free startup measurement. No injected diagnostic contributes
acceptance counts. The final default bundle also passes a fresh live HTTPS
navigation: correct title/viewport, all 30 stories and zero script/native errors.
That is functional live-site validation, not a paired live performance claim.

The matched cohort, final broad batch and final live guards all exit zero.
Observed process-tree RSS peaks are respectively 422,199,296; 292,847,616; and
388,546,560 bytes. Memory sampling is a safety guard, not a complete footprint
comparison. The PID adoption checks report no errors.

## Retained failures and earlier observations

The initial installed diagnostic (`ca64e029…`) had median 4,513,035,599, 5.853%
below baseline, but included an automatically built rejected PNG prototype and
unrelated shared changes. It receives no final-source or allocator-only credit.
The restored-ImageIO cohort (`bafbc4c0…`) has Vox median 4,596,752,343, but Brave
pair four fails helper ownership, invalidating that cross-browser cohort.

The first matched cosmetic cohort (`c9f2ba4f…`) loses 2,982 vote-arrow pixels in
all fourteen captures. It receives no optimization credit. After selecting the
same older correct renderer for both variants, seven valid old/parser-codec
pairs have medians 4,548,208,499 and 4,167,276,019. These are diagnostic settings.
The later resource-only matched diagnostic has medians 4,101,963,701 and
4,088,209,170, with every pair improving but overlapping ranges.

The first default `4bc878b1…` cohort fails Brave ownership in pairs five/seven;
a matched codec cohort fails a stable native endpoint-task audit in control pair
five. A one-pair pilot is rejected before launch, and a later pilot has another
ownership failure. All attempts remain available. The packaged `118eb720…`
build later passes seven original-codec/default pairs with candidate median
4,073,122,805: a 15.030% median reduction whose conservative gate still fails.
It also passes live and 21 screenshot checks before the final PNG change.

The additional final Vox/Brave cohort retains all seven successful Vox trials,
but **Brave pair three fails outside-coalition private-helper ownership**. The
whole cross-browser cohort is invalid and supplies **no new Brave comparison
credit**. The selected acceptance cohort above is the complete, valid Vox/Vox
encoder-control cohort. The request's comparator remains original Vox.

Root tiles, integer-list metadata, early PNG filter/codec variants, raw RGB
experiments and a hardware-CRC experiment remain rejected diagnostics. The CRC
microbenchmark saved about 3.4 million instructions without whole-page credit;
uncompressed PNG made files about 27 times larger. No such path is retained.
The final retained RGBA codec uses smaller tables than the earlier rejected
prototype. A failed native test link missing zlib and failed/superseded shared
builds are retained, including a disk-full build and a running shell script
edited by another session. The old default live run that mixed checkout codec
and bundled data is also retained as a failure, resolved by complete packaging.

[Durable raw counts, hashes and receipts](performance/hn-vox-reduction-20261102.json)
retain every reported cohort and its qualification. Full inputs, commands,
per-trial host loads/timestamps/PIDs, audits, PNGs, counters, probes, logs and
actual exits remain under `Build/hn-15-20261102-baseline/`,
`Build/hn-15-20261102/`, `Build/hn-continue-20261102/` and the other directories
named in that JSON. References and tolerances were never changed for credit.
