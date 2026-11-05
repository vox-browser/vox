# BBC homepage instruction comparison

Current result — **cohort 115**, on pinned parallel production `01ba55f53219`:
all 21 capture audits pass, but the 10% target fails. Launch-to-PNG medians are
**27,202,806,333 Vox**, **27,328,966,175 control**, and **17,646,731,221 Brave
lower bound** instructions. The strict integer check fails
`283596498230 > 158209489989` (conservative ratio **1.61328**).
Closed SVG tree retention has a noisy 126,159,842-instruction median reduction
(0.4616%), with four paired improvements and three regressions. The conservative
control ratio is **1.15502**, so no robust saving or catalog entry is credited.
History is 111 measured cohorts / 2,398 acceptance browser attempts; 104, 110,
111 and 113 are preflight-only.
[Complete current evidence](performance/bbc-flow-svg-tree-cohort115-20261105.json).
Earlier checkpoints below retain their historical wording and counts.

The closed SVG tree change (`cfec8ea09`, isolated control `8142a72c7`) retains
only validated shape-tree structure and computes fresh geometry. Native checks
confirm candidate-only execution before PNG, exact original pixels/content, all
72 external author scripts, actual native-library pins and normal exits. All
210 initial focused executions and 335 tooling tests pass; the later formatting
assertion correction passes 234 focused executions across three GC modes.
[Focused evidence](performance/bbc-flow-svg-tree-focus-20261105.json).

The required broader checks cover **623 unique cases in each default/no-GC
mode: 618 passes and the same five baseline failures**. There are 1,394 actual
executions across the layout run and both main control arms. An initial obsolete
assertion requiring every SVG-containing grid to rebuild is retained as a failed
attempt; `64032a5c5` permits validated closed SVG retention while preserving the
full-builder paint oracle and image, generated-content and subgrid fallbacks.
The repeated layout checks and unchanged main checks have no new failures.
This is not a full-suite pass or a cadence reset. Cohort 115 retains the original
launch-to-PNG scope, fixture, references, scripts, cache policy and rendering
limitations. Its parallel build has complete input/compiler metadata but no
sealed generated C receipt. BBC homepage remains outside `OPTIMIZED_SITES.md`.

A fresh production **CPU sampling diagnostic** now captures the correct browser
PID/start identity, verifies the sample's Vox UUID against dyld and checks all Vox
frame addresses against the actual executable range. Native exit, original
pixels/content, all 72 external scripts and actual native-image pins pass. The
requested six-second/1-ms sample includes startup and can span PNG/audit/teardown;
its actual cadence and CPU instruction shares are not established. Worker waits
dominate the all-thread leaf summary, and recursive totals overlap. It provides
investigative leads, including repeated grid/inline work and stylesheet-subtree
invalidation, with no performance credit. See the
[sample ledger](performance/bbc-current-production-sample-20261104.json) and
[raw sample](performance/raw/bbc-current-production-sample-20261104.tar.gz).

A separate **thread CPU `v -profile` diagnostic** extends the earlier sealed
expanded-profile baseline. It passes original pixels/content, all 72 author
scripts, native exits and mapped-library identity checks. All profiler counters
and nesting state are isolated per thread; the main thread and 51 completed
finite worker wrappers print separate sections, including an empty section.
The selected rows record 94 TLS dials and roughly 811,000 stylesheet-subtree
visits. CPU-clock overhead strongly inflates frequent-call rows; these timings
are not instruction shares, comparable wall-clock shares or unprofiled savings.
Persistent network/UI threads and the separate filter process remain outside
these rows. This baseline predates SVG tree retention and later changes.
Fresh current-source code generation succeeds but its native link fails because
the completed library lacks a newly referenced graphics API; that attempt and
two corrected profiler-only compile failures remain preserved.
[Diagnostic evidence](performance/bbc-v-profile-thread-cpu-20261105.json).

The follow-up pending-full-cascade shortcut now covers pseudo-element and
trailing-universal anchor walks (`bbdaa7475`, isolated control `99c5cfdbe`).
Its exact paint oracle exposed an existing retention bug: a newly styled
generated pseudo can be omitted when its originating element reuses an old
ordinary child tree. `c878ae2a8` rejects that tree in both cached validation and
fresh collection. All **783 focused executions** pass: 64 CSS and 23 layout
cases, each across three GC modes and candidate/anchor-walk/full-walk arms.
All **336 instruction-tool tests** pass. Failed fixture compiles and the
original paint failures in all arms remain recorded. Native eligibility and
matched instructions still need validation; no saving, target acceptance or
catalog entry is credited. [Focused evidence](performance/bbc-covered-anchor-focus-20261105.json).

**Latest complete comparison — cohort 94:** seven alternating control/Vox/Brave
triples complete on pinned executable
`6c57297b8944be97201dec4dc929ac71a75f5be8272f8419830a81070942621b`.
All **21 capture audits** pass original pixels, complete content, native exits,
helper ownership and unchanged input identities. Medians are **27,412,908,500
Vox**, **27,251,436,013 SVG control** and **17,414,266,556 Brave lower bound**
instructions. The strict target fails `277582089440 > 155971057635`;
conservative ratio is **1.6017322975435115**. SVG's point result is a
**161,472,487-instruction regression (0.5925%)**, with three paired improvements
and four regressions. Conservative control ratio **1.039044797800079** fails;
no robust saving is credited. History is now **94 attempted cohorts / 2,064
attempted browser trials**, plus separate runtime diagnostics. BBC homepage
remains unqualified for `OPTIMIZED_SITES.md`. See the
[cohort/native ledger](performance/bbc-svg-cohort94-20261104.json) and
[raw evidence](performance/raw/bbc-svg-cohort94-20261104.tar.gz).

The two earlier disk preflights remain unlaunched and retained. The volume later
reaches `ENOSPC`, preventing a guard report or cleanup-script creation. Only
verified archived generated files, finished private profiles and a completed
standalone diagnostic executable are released. An old benchmark Brave copy is
fully byte-verified against the installed browser, but immutable flags stop its
removal and the OS denies clearing them. The installed browser stays unchanged;
cohort 94's input fingerprints independently verify it. No app copy supplies the
new comparison. Both preflight/native epochs and storage receipts remain in the
raw archive.

Before any cohort 94 acceptance launch, the extra absolute 2 GiB storage minimum
is corrected prospectively to a **1,111,573,390-byte planning budget**: three times
cohort 93's 215,539,733 private-profile/cache bytes plus 132,615,109 raw bytes,
then 64 MiB reserve. This is a planning margin, not an OS/write upper bound.
Every trial records free disk before/after; failed writes or missing output would
invalidate acceptance. The frozen workload, counters, original references,
author-script policy, memory guard, launch/PNG endpoints and strict integer target
remain unchanged. The gate correction earns **no engine optimization credit**.

The latest **514-case broad-check receipts** are now durable in the
[broad ledger](performance/bbc-svg-measurement-broad-20261104.json) and
[raw checks](performance/raw/bbc-svg-measurement-broad-20261104.tar.gz).
Each GC mode has 511 passes and the same three baseline failures, with no input
changes. Cohort 94 has two rejected disk preflights and no acceptance browser
launches yet; these preflights do not increase the 2,043 browser-attempt history.

**Latest completed comparison — cohort 93:** seven alternating control/Vox/Brave
triples complete on executable
`f029d0f4ec0b2648879303914eff0cc151932e08a50bf2903258a52aded645e3`.
All **21 native/content/pixel/ownership audits** pass with unchanged pinned inputs.
Medians are **27,422,343,588 Vox**, **27,673,914,013 control** and
**17,457,341,325 Brave lower bound** instructions. The strict target fails
`281695033920 > 156040138404`; conservative Vox/Brave ratio is
**1.624745614308562**. Relative reuse has a median point difference of 251,570,425
(0.9091%), five improvements and two regressions; conservative control ratio
**1.0728052475378342** fails, so no robust saving is credited. History is now
**93 attempted cohorts / 2,043 attempted browser trials**. The earlier fixture-link
preflight failed before windowed browser launch and is retained separately.
See the [cohort ledger](performance/bbc-relative-cohort93-20261104.json) and
[raw evidence](performance/raw/bbc-relative-cohort93-20261104.tar.gz).

**Closed SVG follow-up:** `1606bff4c` admits only the existing closed SVG shape
subset into grid/flex measurements. Complete SVG attribute/child identity checks
run before replay. Both path array levels are owned beyond producer scratch, and
restored consumers get separate writable arrays. All **306 refined focused
executions** pass: 34 cases across three GC modes and three arms, with executable
calls verified and unchanged final inputs. Initial compile failures from a test
array alias remain recorded. Control `27b30a001` isolates SVG eligibility;
**279 browser-instruction tests** pass. See the
[focused ledger](performance/bbc-svg-measurement-focus-20261104.json) and
[raw checks](performance/raw/bbc-svg-measurement-focus-20261104.tar.gz).

Separate fresh production diagnostics now verify candidate-only SVG reuse before
PNG, both original captures, complete content, all 72 original external scripts,
actual native-image pins and normal exits. The broader cadence exercises **514
unique cases / 511 passes** in each default/no-GC mode, retaining exactly the same
three baseline failures and unchanged checked inputs. No full pass or cadence
reset is claimed. Cohort 94 remains **unlaunched** after the disk preflight fails;
no instruction saving or target acceptance is credited to SVG yet. BBC homepage
still does not qualify for `OPTIMIZED_SITES.md`.

**Unshifted-relative measurement follow-up:** `f9cfbc509` extends grid/flex
measurement reuse to relative boxes whose insets are all `auto`, using the shared
closed-flow proof. Out-of-flow descendants, shifted/sticky positions and SVG
remain excluded. Root/descendant geometry, glyphs, ancestor bases and live inset
changes match independent uncached layout in **189 focused executions**, across
three GC modes and three control arms. All 21 executable case calls are verified.
Isolated tool control is `472936232`; **278 browser-instruction tests** pass.
Native eligibility still requires the next completed production bundle. No
instruction saving or target acceptance is credited. See the
[focused ledger](performance/bbc-relative-measurement-focus-20261104.json) and
[raw evidence](performance/raw/bbc-relative-measurement-focus-20261104.tar.gz).

The preceding decoded-image change now has two fresh production captures on
`7ce37121784a00da11f4099f0df0fbabc8a68cc48a948625d1b40739457bc552`.
Both pass original pixels/content, all 72 original external scripts, actual native
image pins and normal exits, but the new reuse marker never fires. It has **no
verified BBC workload eligibility and no performance credit**. Cohort 93 remains
unlaunched; history stays at 92 cohorts / 2,022 browser attempts. See the
[native ledger](performance/bbc-flex-image-native-20261104.json) and
[raw captures](performance/raw/bbc-flex-image-native-20261104.tar.gz).

**Decoded-image flex follow-up:** `3e85d7380` lets closed within-pass flex
measurements include available non-SVG HTML images. The existing live validator
checks source and natural size before replay. Source replacements, changed aspect
ratios, scratch release and copy-on-write match uncached layout in **153 focused
executions** across default, no-GC and preallocation modes, with 17 executable
case calls verified in every arm. Isolated control `c98a5bcf4` disables only image
eligibility; all **277 browser-instruction tool tests** pass. A separate unchanged
input-preservation suite has ten passes and one assertion-wording failure; its raw
failure remains recorded. No native workload eligibility or instruction saving is
yet credited: the latest completed production bundle lacks the new path, while
an existing shared production build is running. Cohort 93 is still unlaunched.
See the [focused ledger](performance/bbc-flex-image-focus-20261104.json) and
[raw focused evidence](performance/raw/bbc-flex-image-focus-20261104.tar.gz).

**Latest box-edge validation, cohorts 91–92 and coarse profile:** the fresh
production builds now execute `99ee0f99f`, with isolated control `0dd85ac67`.
Candidate-only reuse is verified before PNG in separate diagnostics. Original
pixels, complete content, all 72 external scripts, actual native-image pins and
normal browser exits pass in both Vox arms.

Cohort **91** is invalid after **12 browser attempts** because a shared production
publication changes the executable during the fourth triple. All attempts and
the earlier disk preflight rejection remain recorded. Cohort **92** completes
**seven alternating triples / 21 trials** with stable input identities. All 14
Vox/control audits pass, but Brave pair 6 differs from its original pixel
reference, invalidating acceptance. References and tolerances remain unchanged.
Observed medians are **27,532,694,809 Vox**, **27,741,927,552 control** and
**17,423,879,058 Brave lower bound** instructions. The control point difference
is 209,232,743 (0.7542%), with four improvements and three regressions;
conservative control ratio **1.0465803788543335** fails. No robust saving is
credited. The observed target gate also fails
`284848068570 > 155752619580`; these counts cannot qualify the invalid cohort.
See [cohort 91](performance/bbc-edge-cohort91-20261104.json),
[raw 91](performance/raw/bbc-edge-cohort91-20261104.tar.gz),
[cohort 92](performance/bbc-edge-cohort92-20261104.json) and
[raw 92](performance/raw/bbc-edge-cohort92-20261104.tar.gz).

The broader cadence again exercises **504 unique cases / 501 passes** in each
default and no-GC mode, with exactly the same three baseline failures and unchanged
checked inputs. No full pass or cadence reset is claimed. Two separate style
diagnostics pass the original capture audits. Ordinary dirty flags dominate the
logged recomputations; only six font-refresh fallbacks appear before PNG in the
first run. These counters do not establish instruction costs. See the
[broad/style ledger](performance/bbc-edge-broad-style-20261104.json) and
[raw evidence](performance/raw/bbc-edge-broad-style-20261104.tar.gz).

A fresh **`v -profile` diagnostic** also passes original pixels/content, verifies
all 72 original external scripts and pins every actual native image. After V
instrumentation, generated C retains 21 declared coarse timing scopes and disables
25,977 others. The exact transformation, inputs, actual exits and raw rows are
retained. Grid and inline layout, style matching and JSC dominate these selected
timers; box-edge resolution is smaller. Coarse self includes unselected/native
callees and waits; recursive inclusive intervals overlap, and main's unfinished
exit timer is zero. This separate instrumented run supplies no instruction saving
or unprofiled acceptance credit. See the
[profile ledger](performance/bbc-coarse-profile-20261104.json) and
[raw profile](performance/raw/bbc-coarse-profile-20261104.tar.gz).

Acceptance history is **92 attempted cohorts / 2,022 attempted browser trials**,
plus separately recorded runtime diagnostics. Cohort 90 remains the latest fully
valid target comparison, with conservative ratio **1.8101137514618793**, failing
0.9. Frozen original-origin replay, startup through encoded PNG, retained OS caches
and the scripting/font/rendering limitations below still apply. BBC **homepage
instruction optimization** remains unqualified for `OPTIMIZED_SITES.md`; the
separate BBC News screenshot entry does not establish this target.

The following sections preserve earlier follow-up states.

**Latest box-edge follow-up:** `99ee0f99f` reuses resolved absolute and
percentage margin/padding/border edges. Percentage bases remain quantized to
`CSSPixels`; the memo also checks the actual rounding policy. Every typed edge
setter invalidates it after normal copy-on-write. Relative units and calculations
keep their live font/viewport/container context. Snapshot sharing ignores this
derived scalar memo. Isolated control `0dd85ac67` disables only this reuse.

All **222 focused executions** pass: 37 cases enabled/disabled across default,
no-GC and preallocation modes, with executable calls verified and unchanged final
inputs. All **312 instruction-tool tests** pass. Initial runtime crashes are
retained: the new fixtures passed optional parsed pointers directly to setters;
binding checked locals fixes those fixtures in all modes. Those initial runs
also record changed inputs during the failed investigation and earn no correctness
credit. The existing validated `v -profile` diagnostic identified repeated edge
resolution; its instrumentation is separate from instruction acceptance.

Native candidate validation and cohort **91 remain unlaunched**. Completed shared
bundles `b3e94706` and then `487c7846` lack this path; a shared production build
already has the latest request coalesced. No duplicate production build is queued.
The bounded watcher finishes with no qualifying bundle. Build `205756-720b17c5`
fails correctly before C preprocessing because repository inputs changed; its
actual guard exit 1 and error are retained in the ledger. The shared worker has
started a newer coalesced request. A stable completed bundle is still required.
Three separate sampled baseline captures pass native exit, original content/pixels,
all 72 external scripts and native image pins, but their CPU samples are
inconclusive: a launch PID, teardown after PNG, and an empty call graph. Two earlier
observer preflights fail before browser launch. These attempts remain separate;
none validates the new cache or supplies instruction improvement credit.

The last broader cadence is still **504 unique cases / 501 passes** in each
default and no-GC mode, retaining the same three baseline failures. Acceptance
history remains **90 attempted cohorts / 1,989 attempted browser trials**. The
latest complete target cohort still has a conservative ratio of **1.8101137514618793**,
which fails the required 0.9. BBC remains absent from `OPTIMIZED_SITES.md`.
See the [box-edge ledger](performance/bbc-box-edge-reuse-20261104.json) and
[raw focused/diagnostic evidence](performance/raw/bbc-box-edge-reuse-20261104.tar.gz).

**Latest flex follow-up and cohort 90:** `0eb0c00f9` retains owned closed
flex measurements within one layout pass, with an exact root/ancestor key,
style/tree/text/font checks and normal copy-on-write restoration. The isolated
control is `304751f0e`. All **132 refined focused executions** pass across three
GC modes and four runtime arms, with 11 executable test calls verified. Initial
failures came from an exclusion fixture treating a direct flex item's ignored
`float` as an actual float; those failed attempts remain in the archive. The
refined fixture nests a real float in block flow. All **311 tool tests** pass.
Separate native diagnostics verify candidate-only reuse before PNG, all 72
original external scripts, unchanged complete content and exact original pixels,
normal exits and pinned actual native images.

Cohort **90** now has seven complete alternating Vox/Brave pairs on executable
`e25f3ed7d128f3b855bf279ee9100e9f6dff332cb6ff0c2a6905b8a2ebc6458c`.
All 14 capture audits pass, but the target fails: medians are **30,399,670,398
Vox** and **18,002,315,523 Brave lower bound** instructions. Conservative ratio
is **1.8101137514618793**; the strict gate fails
`321646940660 > 159924892212`. This target-only cohort does not establish a
marginal flex saving. A separate seven-pair enabled/disabled run on one newer executable has medians
**28,486,597,332 candidate** and **28,745,107,426 control**: a point difference of
258,510,094 (0.8993%), four paired improvements and three regressions. Its
conservative ratio **1.0582300992694578** fails, so no robust saving is credited.
All 14 capture audits pass; no Brave process is launched or target evaluated in
that diagnostic. Its two runtime preflights remain separate. The observed point
difference triggers the broad cadence: both default and no-GC batches exercise **504 unique cases / 501 passes**,
retaining exactly the same three known failures and unchanged checked inputs.
No full pass or cadence reset is claimed. The initial broad preflight rejects a
concurrent temporary wrapper with duplicate test names before compilation; the
recorded inventory then names the 53 canonical test files explicitly. See the
[broad-check ledger](performance/bbc-flex-broad-20261104.json) and
[raw broad evidence](performance/raw/bbc-flex-broad-20261104.tar.gz). See the
[matched-control ledger](performance/bbc-flex-matched-control-20261104.json) and
[raw matched evidence](performance/raw/bbc-flex-matched-control-20261104.tar.gz).

Before this new cohort, the additional absolute 18-CPU host-load launch cap was
removed prospectively. Repository policy requires recording contention, rather
than this extra cap. Per-trial load/timestamps, the memory guard, private PID
adoption, unchanged endpoints and all input/content/pixel/ownership checks remain
required. This policy correction earns no engine optimization credit. Earlier
rejected preflights and the 42 contended diagnostic attempts retain their original
classification. Acceptance history is now **90 attempted cohorts / 1,989 attempted
browser trials**, plus separate runtime diagnostics. Full compiler receipts and
preprocessed inputs are preserved before launch and in the durable archive.

These are frozen original-origin replay results, with startup through encoded
document PNG included and OS filesystem/shader caches retained. Per-engine
references are exact; cross-engine pixels still differ 82.7154%. The scripting,
font and rendering limitations below remain. BBC still does not qualify for
`OPTIMIZED_SITES.md`. See the [flex/cohort ledger](performance/bbc-flex-cohort90-20261104.json)
and [raw evidence](performance/raw/bbc-flex-cohort90-20261104.tar.gz).

The following follow-ups describe their historical, earlier states.

**Latest grid follow-up:** `7013bdd35` lets committed layout consume owned
same-pass grid measurements. The root geometry and immediate containing block
remain exact; a conservative proof can omit more distant ancestor heights when
the captured subtree has no height-dependent layout. Percentage heights/gaps,
explicit rows and flex height dependencies retain those checks. Committed misses
do not populate, reject or evict measurements. All **48 focused executions** pass
enabled/disabled across default, no-GC and preallocation modes, with executable
test calls verified. All **306 instruction-tool tests** pass.

Fresh diagnostics on executable
`70de4b58efdae04001ce2f15504dc8b736eb44f7443bb8f841f11d348766b5e4`
verify candidate-only reuse before PNG, exact original pixels/content, all 72
original external scripts, actual native image coverage and normal exits in both
arms. Acceptance cohort 90 remains **unlaunched** because its host gate fails.
The separate contended seven-triple diagnostic retains **28,204,977,170 Vox** and
**29,067,309,376 control** medians: a point difference of 862,332,206 (2.9667%),
with four paired improvements and three regressions. Conservative control ratio
**1.0704893742575525** fails, so no robust saving is credited. Brave pair 5 fails
private-helper coalition ownership and has no selected launch interval or completed
capture audit. The six available Brave counts are partial diagnostics; their
best-case partial gate also fails `296326435080 > 158492923893`.

The broader batch runs **501 unique cases / 498 passes** in each default and
no-GC mode, retaining the same three baseline failures, unchanged inputs and no
cadence reset. The acceptance history stays at **89 cohorts / 1,975 attempted
browser trials**, with **42 separate contended diagnostic attempts** across the
text and grid follow-ups. BBC still does not qualify for the catalog.

At archival time, shared cleanup has removed this measured build's compiler
receipt and generated C; the exact deletion time is unknown. Saved source-proof
hashes and per-trial runtime fingerprints remain, but complete compiler inputs
cannot now be independently reviewed. A reconstruction attempt does not match
the original hash and earns no recovery credit. Tool fix `c42c1eede` preserves
compiler JSON and preprocessed outputs before future launches, deduplicating shared
controls and pinning the preserved copies. It leaves browser bundles, native
libraries and repository tools in place. All **310 tool tests** and a separate
integration on newer build `b8701f74` pass. That newer source is not substituted
for the missing measured source. See the
[grid ledger](performance/bbc-committed-grid-20261104.json) and
[raw evidence](performance/raw/bbc-committed-grid-20261104.tar.gz).

**Latest optimization follow-up:** committed layout can consume exact same-pass
text measurements (`174b38300`), preserving the full geometry key, input checks,
document ownership and copy-on-write. It does not populate or evict measurements
on a committed miss. All **42 focused case executions** pass across enabled and
disabled controls in default, no-GC and preallocation modes; executable test calls
are verified. All **305 instruction-tool tests** pass. Separate fresh production
diagnostics verify the path only in the candidate before PNG, all 72 original
external scripts, unchanged actual native images, complete content, exact original
pixels and normal exits in both arms. The selected executable is
`4d55ec4468623f9d2449dd9fef4c3a34515da8ce9a0a99faf33035cab142bc34`.

Acceptance cohort 90 is **not launched**: host load exceeds the predeclared
18-CPU limit. A separately declared contended diagnostic retains seven matched
control/Vox/Brave triples, plus four separate runtime discovery/validation
launches. All 21 unprofiled captures pass original pixels, complete content,
ownership, input identity and native exits. Medians are **29,695,581,679 Vox**,
**30,458,334,333 control**, and **17,641,883,461 Brave lower bound** instructions.
The median point difference is 762,752,654 (2.5042%), with five paired improvements
and two regressions. The conservative control ratio **1.0704214450131349** fails;
the controls vary substantially under contention, so no robust saving is credited.
The strict Brave gate also fails `302741870920 > 157800881124`.

Broader verification exercises **498 cases / 495 passes** in each default and
no-GC mode, retaining the same three known failures and unchanged inputs. All
three new cases pass. No full pass or cadence reset is claimed. The acceptance
history remains **89 cohorts / 1,975 attempted browser trials**; the 21 contended
diagnostic attempts remain separate. BBC is still absent from the catalog. The
preceding read-only inline traces and a new 400-entry grid trace are retained as
investigative leads, without instruction or timing credit. See the
[optimization ledger](performance/bbc-committed-inline-20261104.json) and
[raw evidence](performance/raw/bbc-committed-inline-20261104.tar.gz).

**The requested 10% advantage remains open; BBC does not qualify for
`OPTIMIZED_SITES.md`.** Corrected cohort 89 retains seven alternating Vox/Brave
pairs. Median observations are **28,545,330,528 Vox** and **17,484,012,241 Brave
lower bound** instructions. The strict gate fails
`289938781390 > 156732373359`, conservative ratio **1.6649074958706724**.
Brave pairs 2 and 7 differ from the unchanged reference by 171,581 and 224,973
pixels, invalidating acceptance. All 14 native exits and complete-content checks
pass; every Vox capture is exact. No trial is excluded.

This cohort corrects a runtime identity gap: a later image audit finds **nine
late-loaded libraries absent from the recorded pins in cohorts 87 and 88**.
Their raw counts, medians and failing gates remain retained, but those cohorts
do not establish complete runtime identity for acceptance. The driver now
discovers root images in a separate traced launch, pins their transitive
dependencies using the original executable's rpaths, then validates that set in
a fresh traced launch before acceptance. Cohort 89 pins 25 runtime files this
way; all acceptance launches keep dyld tracing disabled. Scope and pin
corrections earn no engine optimization credit. All **304 instruction-tool
tests** pass, including drift and environment-restoration checks.

The selected production executable is
`1c1d291714759657ede614650af13669a0ad1eae782ef830f6d0064121cc39d4`.
A separate native diagnostic verifies exact original pixels/content, all 72
original external author scripts before PNG and pinned actual native images.
The predeclared host gate passes at load 11.09 on 18 CPUs. The total is now
**89 cohorts / 1,975 attempted acceptance browser trials**, plus two separate
runtime discovery/validation launches; older contention attempts remain
separately retained. There is no new paired engine saving or broad cadence reset.
See the [cohort 89 ledger](performance/bbc-cohort89-runtime-pins-20261104.json)
and [verified raw evidence](performance/raw/bbc-cohort89-runtime-pins-20261104.tar.gz).

A refreshed `v -profile` main-thread diagnostic passes normal exit, exact PNG,
complete content, all 72 original external scripts before capture, unchanged
inputs and coverage for all 26 actual non-system images. Its **10,979 unique
rows** cover main-thread callbacks through exit, including waits and work after
PNG. These C-O0/preallocation profile timings and counts are investigative data,
not unprofiled instruction savings. Both rejected codegens and four earlier
page attempts remain retained, including an incomplete launch, an abnormal
exit-probe teardown, an unrelated executable replacement and missing late-library
pins. See the [profile and runtime audit](performance/bbc-main-profile-runtime-audit-20261104.json)
and [verified raw evidence](performance/raw/bbc-main-profile-runtime-audit-20261104.tar.gz).

**Historical cohort 88 under the earlier pin policy:** all seven alternating matched
control/Vox/Brave triples with exact original pixels, complete content, ownership,
input identity and normal native exits in all 21 trials. Median counts are
**28,170,148,069 Vox**, **28,315,073,501 control**, and **17,115,035,937 Brave
lower bound**. The strict gate fails `287760261590 > 152821718487`, conservative
ratio **1.6946821302302713**.

The compact query decoder (`888a778d3`) avoids a generic JSON map for the exact
ordered three-string ASCII envelope. Escaped, Unicode, snapshot, extra-field and
other forms retain the existing decoder. Its marginal median point reduction is
**144,925,432 (0.5118%)**, with four paired improvements and three regressions.
The conservative control ratio **1.0261708034759418** fails; no robust saving is
credited. The host gate passes at load 14.57 on 18 CPUs. All attempts remain.

Twenty-eight focused case executions pass across memory modes and both decoder
arms, with actual test calls verified in executable disassembly. All 300
instruction-tool tests pass. A separate native diagnostic verifies the path only
in the candidate before PNG, exact pixels/content, and all 72 original external
script evaluations in both arms. All nine SVG image and paint-server mutation
comparisons remain pixel-exact. The tested and production decoder functions
match after actual C macro expansion and literal-checked string-pool mapping.
The pinned executable is
`e39d48b8a2cbbe729066e81e6f6dac3aeabb489f5f7aa146f184632db4edb8d9`.

The measured point reduction triggers broad verification: **495 entered / 492
passed** in each default and no-GC mode, preserving the same three known failures.
No full pass or cadence reset is claimed. The historical total is now 88 cohorts
and 1,961 attempted acceptance browser trials, excluding seven older contention
attempts. See the [cohort 88 ledger](performance/bbc-cohort88-query-envelope-20261104.json)
and [verified raw evidence](performance/raw/bbc-cohort88-query-envelope-20261104.tar.gz).
These remain frozen-page observations with the rendering and scripting
limitations below; no new live-site fix is claimed.

A nested inline measurement experiment (`8cc7849e3`) passes 48 focused case
executions and 301 instruction-tool tests. Both native production arms preserve
the original pixels, complete content and all 72 external scripts, but the cache
never reuses a result before PNG. A read-only debugger trace validates 400 bounded
entry observations: 172 are committed layouts, while the measured subtrees contain
positioned, replaced or atomic content excluded by this cache. This is a bounded
diagnostic, not complete inlined-call coverage or performance evidence.

The experiment is removed (`1c6a6d7a6`), with its isolated benchmark control also
removed (`160735ed5`). All 12 existing inline-cache case executions pass after
removal across default, no-GC and preallocation modes, as do all 300 remaining
instruction-tool tests. The initial fixture's optional-pointer argument compiler
failure and the strict C comparator's expected test/production assertion and
fortification differences remain retained. No exact whole-function C equivalence
is claimed. **Cohort 89 is not launched**, and the historical total remains 88
cohorts / 1,961 attempted acceptance browser trials. A newer production bundle
must validate the removal; the pinned experiment bundle is only historical
evidence. See the [unused-path ledger](performance/bbc-nested-inline-unused-20261104.json)
and [verified raw evidence](performance/raw/bbc-nested-inline-unused-20261104.tar.gz).

Earlier cohort 87 completes all seven alternating matched
control/Vox/Brave triples. All 21 original pixel, complete-content, ownership,
input-identity and normal native-exit checks pass. Vox's median is
**28,566,284,244**, control **28,680,897,060**, and Brave's lower-bound median
**17,600,850,507** instructions. The strict gate fails
`294965265120 > 156774454236`, conservative ratio **1.6933162988938066**.

The grid change has a **114,612,816 (0.3996%)** marginal median point reduction,
four paired improvements and three regressions. Its conservative control ratio
**1.0499726848480195** fails; no robust saving is credited. The predeclared host
gate passes at load 15.82 on 18 CPUs, but load rises during the cohort and controls
vary. No trial is excluded. Candidate-only grid reuse executes before PNG in a
separate native diagnostic, with all 72 original external scripts verified in
both arms. The pinned executable is
`4eee3fd0fbb5c5ed18eba9fbdff609a1bec067117e448f29a10ed0ecf16559e5`.

Broad verification preserves all 490 historical cases and the five new cases:
**495 entered / 492 passed** in each default and no-GC mode, with the same three
known failures. No full pass or cadence reset is claimed. See the
[cohort 87 ledger](performance/bbc-cohort87-grid-measurement-20261104.json) and
[verified raw evidence](performance/raw/bbc-cohort87-grid-measurement-20261104.tar.gz).

Separate native startup sampling diagnostics preserve exact original pixels,
complete content and all 72 external script evaluations. A diagnostic constructor
delays V initialization so the sampler can attach; its samples include that wait,
startup, rendering and teardown. The grouped stacks are investigative leads,
not instruction counts, elapsed-time gains or optimization credit. The first
ungated sample attached too late and remains retained. Replay files and the
author probe that disappeared from the shared workspace were restored exactly
from committed evidence, including a byte-identical rebuilt probe; no reference,
workload or policy changed. See the [sampling ledger](performance/bbc-native-startup-samples-20261104.json)
and [verified raw evidence](performance/raw/bbc-native-startup-samples-20261104.tar.gz).

A guarded within-pass grid measurement cache is committed
(`b35fac88d`), with an ancestor-key refinement (`109077f25`). The refined version
passes **30 focused case executions** across candidate/control and default,
no-GC and bounded-preallocation modes. All **287 instruction-tool tests** pass.

The first production version preserves original pixels, complete content and all
72 external script evaluations in both native arms, but its reuse path never
executes before PNG. No instruction cohort is launched for that unused path.
A corrected read-only debugger probe validates 400 complete keys and identifies
122 comparisons that differ only in copied ancestors' min/max-content labels.
The refinement omits those labels while retaining actual sizes, effective
definiteness and the grid's own constraints. It still requires a miss when an
intrinsic constraint changes effective definiteness, and compares reused results
with a separate unpooled oracle. Initial tests, failed diagnostics and manual
termination receipts remain retained.

The first archived checkpoint lacked a completed bundle with the refinement;
cohort 87 above subsequently validates its native path and records the failing
instruction comparison. The earlier pending receipts remain historical. No
robust instruction saving or catalog entry is claimed. See
the [grid measurement ledger](performance/bbc-grid-measurement-20261104.json) and
[verified raw evidence](performance/raw/bbc-grid-measurement-20261104.tar.gz).

Earlier cohort 86 retains all seven alternating
Vox/Brave pairs. All native exits, complete-content, ownership and input-identity
checks pass, but Brave pair 6 differs by 53,392 pixels (maximum channel error 6),
invalidating acceptance. Every Vox capture preserves the original reference.
Observed medians are **28,876,271,707 Vox** and **17,521,691,229 Brave lower-bound**
instructions. The strict gate fails `295183012760 > 155986818651`, conservative
ratio **1.703122826540811**. This is a current-production baseline with no new
engine optimization or savings credit. Its pinned executable is
`b82083b26572f1cbbe0302fdcc0ab954e37a3c2e290ee857aa745972d6f835a6`.

Fresh headless and separate injected native checks pass after all three previous
experiments were removed. The latter verifies all 72 original external author
scripts before encoded PNG, complete content and exact pixels. The first attempt
stops before acceptance when host load exceeds the predeclared 18-CPU gate;
the unique recheck passes that same gate. Every attempt remains in the
[cohort 86 ledger](performance/bbc-cohort86-baseline-20261104.json) and
[verified raw evidence](performance/raw/bbc-cohort86-baseline-20261104.tar.gz).

The grid follow-up uses the existing verified `v -profile` executable for a
bounded, read-only debugger trace. All 1,200 corrected entry reads validate;
among 270 full normal grid calls in temporary measurements, 140 repeat the
logged inputs. This is a lead for within-pass reuse, not proof that every hidden
input matches or a production instruction saving. The older profiled engine
still produces exact original pixels, complete content, 72 external script
evaluations and a normal exit with pinned inputs. Two current-source profile
codegens were rejected after concurrent source changes; attempts to recompile
an older generated-C grid scope fail or time out. All attempts, including the
first rejected ABI decode, remain in the
[grid diagnostic ledger](performance/bbc-grid-profile-20261104.json) and
[verified raw evidence](performance/raw/bbc-grid-profile-20261104.tar.gz).

Earlier cohort 85 retains all seven alternating
control/Vox/Brave triples. All 21 native exits, complete-content, ownership and
input-identity checks pass, but control pair 1 differs by 546,867 pixels
(maximum channel error 223) and Brave pair 4 by 53,392 (maximum error 6).
These pixel failures invalidate acceptance; every candidate Vox capture is exact.
Observed medians are **28,877,778,539 Vox**, **29,079,039,480 control**, and
**17,617,633,127 Brave lower-bound** instructions. The strict gate fails
`299167816790 > 157807174104`, ratio **1.706202754340908**.

The direct text-fragment initialization experiment has a **201,260,941** marginal
median reduction, four paired improvements and three regressions. Its
conservative control ratio **1.1020105389179364** fails, with no robust gain
credited. A separate warmed 100-by-37-fragment process-counter diagnostic also
shows no improvement across four alternating pairs. That diagnostic lacks
per-trial binary/native-library audits and supplies no acceptance credit. The
experiment and its control are removed (`d972d9e61`, `010920639`). The original
control constructor and generated operations were independently verified against
the preceding production implementation.

All 48 focused candidate/control executions pass; broad verification enters
490 cases in each of default and no-GC modes, with 487 passing and the same
three failures. No full pass or cadence reset is claimed. All 18 rollback
executions and 286 current instruction-tool tests pass. A first rollback attempt
detects a source-hash change from a separate overflow-clip edit; its rejected
receipt remains retained, and that separate change is excluded from the rollback.
At that checkpoint the inspected completed bundle still contained the direct-slot
experiment. Cohort 86's subsequent fresh native checks above validate its compiled
removal in a newer shared bundle.
See the [cohort 85 ledger](performance/bbc-cohort85-direct-fragments-20261104.json)
and [verified raw evidence](performance/raw/bbc-cohort85-direct-fragments-20261104.tar.gz).

Earlier cohort 84 retains all seven alternating
control/Vox/Brave triples. All fourteen Vox captures preserve original pixels,
complete content, ownership, input identities and normal exits. Brave pair 2
fails helper ownership validation before capture, invalidating acceptance;
the other six Brave trials pass. Vox's median is **29,223,498,814**, versus
control **28,766,020,953**: a **457,477,861-instruction regression**, with four
paired improvements and three regressions. The conservative control ratio is
**1.1074185217005499**. Only six Brave launch intervals exist, so their
17,452,948,388.5 median is a partial diagnostic. Even those observed intervals
fail the target inequality, `301714399340 > 155617781490`.

The fresh-media proof has been removed (`1abb417fe`); its 42 focused rollback
executions and all 285 current instruction-tool tests pass. The available-block-
space cache experiment was also removed (`6d62205fb`): its exact production
captures never used the candidate path before PNG. Its 18 rollback executions
and 287 tool tests passed before the later stylesheet-control removal.
No optimization credit or new broad-check cadence reset is claimed. See the
[cohort 84 and rollback ledger](performance/bbc-cohort84-fresh-media-rollback-20261104.json)
and [verified raw evidence](performance/raw/bbc-cohort84-fresh-media-rollback-20261104.tar.gz).

Earlier valid cohort 83 completes seven alternating
control/Vox/Brave triples, with all 21 original pixel, content, ownership,
native-exit and input-identity checks passing. Vox's median is
**29,609,230,829**, control **29,758,720,791**, and Brave's lower-bound median
**17,280,904,967** instructions. The strict gate fails
`299764328070 > 153994347684`, conservative ratio **1.7519337515985396**.
Skipping declaration-free conditional leaves gives a **149,489,962 (0.502%)**
marginal median reduction, five paired improvements and two regressions.
The conservative control ratio **1.0232730099238514** fails; no robust gain
is credited. The path executes before encoded PNG only in the candidate;
all 114 focused executions and 271 tool tests pass. Broad checks again enter
490 cases in each memory mode, with 487 passing and the same three failures.
Both Vox arms retain the explicitly declared historical rendering policies.
See the [cohort 83 ledger](performance/bbc-cohort83-empty-conditional-20261104.json)
and [authenticated raw receipts](performance/raw/bbc-cohort83-empty-conditional-20261104.tar.gz).

Cohort 82 retains all seven alternating
control/Vox/Brave triples. Vox's median is **29,135,895,526** instructions,
control **29,718,522,931**, and Brave's lower-bound median **17,449,185,825**.
The strict gate fails `309753061950 > 155568327714`, ratio
**1.7919955806654342**. Brave pair 4 differs by 53,392 pixels with maximum
channel error 6, invalidating acceptance; all fourteen Vox captures remain exact.
All native exits, full content audits and pinned-input checks pass.

The conditional-deletion change has a **582,627,405 (1.960%)** marginal median
reduction, four paired improvements and three regressions. The conservative
control ratio **1.0637923593249565** fails, so no robust saving is credited.
Both Vox arms explicitly retain the original logical paint/font grids and
CSS-coordinate inline-SVG layout. The explicit SVG policy restores the fixed
reference after a shared default-policy change; it earns no optimization credit.
Earlier prechecks with 445,313 changed pixels and the unsuccessful historical
WebP diagnostic remain retained. See the [cohort 82 ledger](performance/bbc-cohort82-conditional-deletion-20261104.json)
and [verified raw receipts](performance/raw/bbc-cohort82-conditional-deletion-20261104.tar.gz).

The conditional-deletion fix passes 78 focused executions, the historical SVG
option passes 42, and 269 instruction-tool tests pass. Broad checks enter all
490 cases in each of default and no-GC modes: 487 pass, with the same three
recorded failures. No full-pass or cadence reset is claimed.

Cohort 81 completes seven alternating control/Vox/Brave
triples on the 609-response frozen 2026-11-03 homepage. All 21 captures pass
unchanged pixels, full content, normal native exits, ownership and pinned-input
checks. Vox's launch-through-encoded-PNG median is **30,345,423,496** instructions;
Brave's lower-bound median is **17,780,185,581**. The strict integer gate fails:
`314877987530 > 158910923367`, conservative ratio **1.7833273054648286**.
Both Vox arms explicitly retain the historical logical-grid paint and inline
font metrics; this is not a result for the newer default Retina rendering.

The registry-negative descendant-navigable early-out executes on BBC, with
candidate-only use witnessed before encoded PNG in a separate diagnostic.
Same-binary control median is **30,494,552,948**: a **149,129,452 (0.489%)**
marginal median reduction, three paired improvements and four regressions.
The conservative control ratio **1.0745909454751965** fails; no robust saving
is credited. See the [cohort/registry ledger](performance/bbc-cohort81-descendant-registry-20261103.json)
and [authenticated raw receipts](performance/raw/bbc-cohort81-descendant-registry-20261103.tar.gz).

Prior cohorts 80 and 79 also have 21 valid captures each, but their variable
paint-cache and indefinite-height-key point reductions establish no robust
saving. Their [paint ledger](performance/bbc-cohort80-item-paint-20261103.json)
and [key ledger](performance/bbc-cohort79-inline-height-20261103.json) retain
all counts. Cohort 78's pruning regression and removal remain in the
[rollback ledger](performance/bbc-cohort78-rollback-20261103.json).

This is a **new workload**, with 609 sealed responses and 91 headlines. The
original 595-response fixture remains lost. Moving to this page establishes no
historical optimization credit. Both the complete original responses and the
new frozen replay with fixed references are now committed outside `Build/`.
See the [new cohort ledger](performance/bbc-fresh-home-20261103.json),
[original inputs](performance/raw/bbc-fresh-complete-original-inputs-20261103.tar.gz),
[frozen inputs and references](performance/raw/bbc-fresh-fixed-inputs-20261103.tar.gz)
and [raw acquisition/trial receipts](performance/raw/bbc-fresh-home-20261103.tar.gz).

The matched viewport control has a 30,086,966,767 median, with four paired
improvements and three regressions; its conservative ratio is 1.092870014869268.
That variation supplies no robust BBC instruction saving. Earlier new-workload
cohort 75 retains all 21 attempts, including two ownership rejections caused by
independent sessions launching the same installed apps during measurement.
The ownership audit now authenticates distinct private capture roots and their
live task identities in separate coalitions, retaining all measured-root and
CDP-helper checks. Its 12 focused tests and 247 existing instruction-tool tests
pass. The measurement correction earns no engine optimization credit.
History is **87 cohorts / 1,940 attempted browser trials**, excluding separately
labeled acquisition/reference/profile diagnostics.

The requested `v -profile` follow-up now covers the main thread from V's main
entry after startup initialization through exit, including waits and work after
PNG capture. Its generated scope gate is thread-local; the measured-time
accumulator was already thread-local. `-profile-no-inline` omits instrumentation
for inline-marked functions; it does not disable compiler inlining. The corrected
run retains 10,683 rows, exact original pixels, complete frozen content and 72
exact external author-script evaluations through JavaScriptCore. Its timings
are diagnostic and supply no instruction savings. The first incompatible
preallocation-runtime compile failure remains recorded.

A separate automatically continued LLDB trace identifies five full-style-update
calls from `CSSStyleSheet.deleteRule`. An invasive diagnostic wrapper identifies
the deleted groups: one `@supports` and four `@media` rules containing only style
leaves. That wrapper is excluded from acceptance. The original LLDB result read
the wrong output stream and reported zero author scripts; the retained corrected
derivation validates 72 exact external sources in debugger stdout. The first
LLDB attempt stopped at `exec` and never completed a document capture.

A separate fresh live BBC launch passes document identity and substantial content
checks, with 94 headlines and 74 successful external script evaluations. The
unsupported `performance.measure` call and incomplete image-paint audit fields
remain limitations; this is a limited functional check, not full BBC scripting
or rendering parity. See the [profile and rule-deletion ledger](performance/bbc-main-profile-rule-deletion-20261104.json)
and [verified raw diagnostic evidence](performance/raw/bbc-main-profile-rule-deletion-20261104.tar.gz).

A separate invasive hydration probe records removal of an 819-rule server
stylesheet. Removing its 139 `data-styled` metadata rules leaves exactly the
following live stylesheet's 680 rules, in the same order. The initial probe
missed an overridden method; its correction encountered the unsupported
`document.styleSheets` API. Both inconclusive observations remain retained.
The successful version enumerates style elements and preserves exact pixels,
complete content and all 72 external script hashes. This is diagnostic evidence
only, with no instruction credit.

A subsequent read-only LLDB probe finds matching URL, base, ownership flags and
empty sheet media lists, but the removed sheet has `did_match=true` while the
fresh following sheet has `did_match=none`. The existing guard rejects that
pair before comparing rule sequences. The standalone, main-thread `v -profile`
browser exits normally with exact pixels, full content and 72 exact external
script evaluations. The probe's media-entry decoder is limited to the observed
empty lists; no nonempty entry is interpreted. See the
[context ledger](performance/bbc-following-sheet-context-20261104.json) and
[raw debugger evidence](performance/raw/bbc-following-sheet-context-20261104.tar.gz).

The fresh-following-sheet proof now passes 126 focused executions in each of
two verified versions. It evaluates cloned media entries without consuming the
live stylesheet's pending match state. A later read-only trace observes 338
initialized nested-media pairs; the corrected proof accepts these only when
both cached results agree with an independent current snapshot. Stale cached
results remain rejected. The initial fixture failures and overly conservative
nested-media rejection are retained.

Production build `5283f5ee` executes the corrected path before encoded PNG in
the candidate only. Both diagnostic arms retain exact original pixels, complete
content, normal exits and all 72 exact external author-script evaluations.
The first production diagnostic never reached the path. An earlier source
checker incorrectly selected a call site as a function definition and falsely
rejected a compatible bundle; the corrected source proof authenticates the
sealed C definition. These injected diagnostics supply no instruction credit.

The requested additional `v -profile` run instruments
`CSSStyleSheetList.remove_sheet` and nested calls. The successful standalone
diagnostic uses the actual V-generated instrumentation with a thread-local
scope gate and C `-O0`. Both arms preserve pixels, content and script execution;
198 control and 818 candidate profile rows are retained. The earlier C `-O1`
compile was cancelled under contention; its guard cleanup raised a permission
error and supplies no successful compile receipt. Root-scoped timings include
different work and cannot establish whole-page savings.

The later text-cache experiment passed 54 focused executions, with exact
uncached line/glyph oracles, mutations and definite-height exclusions, plus
289 instruction-tool tests at that point. It was subsequently found unused on
BBC and removed, as described above. No cohort 84 was launched by these earlier archived diagnostics:
the selected pre-acceptance load gate required one-minute load no higher than
the CPU count, but observed 49.38 on 18 CPUs. Cohort 84 was collected later,
after host load fell below that limit. BBC remains outside the catalog. See the
[fresh-media/profile ledger](performance/bbc-fresh-media-profile-20261104.json)
and [verified diagnostic archive](performance/raw/bbc-fresh-media-profile-20261104.tar.gz).

A separately declared contention diagnostic stopped after seven browser
attempts when the shared disk filled. Missing/malformed audit and result files,
a Brave pixel mismatch, and failed receipt writes invalidate that partial run;
no partial-cohort win is credited. Removing this task's regenerable focused-test
C and binaries freed about 4 GB while preserving sources, commands and evidence.
The later cohort 84 retains its distinct complete attempt set. A separate
production `sample` run preserves exact pixels, normal exit, complete content
and 72 exact author-script hashes. Its stacks include waits and possible work
after PNG; they supply diagnostic leads, with no instruction savings credited.

## Historical results on the earlier fixture

**The requested 10% advantage remains open. BBC does not qualify for
`OPTIMIZED_SITES.md`.** Latest attempted cohort 50 has two early Vox ownership
rejections and only five complete triples, so it cannot supply an acceptance
gate. Its early text-font request experiment provides no evidence of a gain
and has been removed. Among the five completed matched pairs, two improve and
three regress; their partial median increases by 583,525,731 instructions
(1.8646894242908671%). Every attempt remains in the
[experiment supplement](benchmark-results/bbc-font-request-experiment-2026-11-02.json).
The subsequent font-input scan optimization is committed and passes focused
checks, but still awaits a completed production bundle and a new BBC cohort;
its isolated microbenchmark earns no site-level credit.

Latest complete cohort 49 uses canonical tools, the completed
production Vox bundle and installed Brave directly for seven alternating
matched triples. Vox median is **31,284,060,062**, its same-binary control
**31,433,167,681**, and Brave lower median **15,005,464,950** instructions.
The strict gate fails `318586703770 > 134536767903`, conservative ratio
**2.1312243326651696**. All native exits and complete content audits pass;
Brave pair 2 changes 304,064 reference pixels (maximum channel error 18),
invalidating acceptance. All fourteen Vox/control PNGs remain exact.

The matched median point difference is **149,107,619 (0.47436396011124593%)**;
three pairs improve and four regress. Conservative control ratio
**1.0385805274608737** fails. This protocol correction establishes no robust
speedup and earns no engine optimization credit. The
[canonical-input supplement](benchmark-results/bbc-canonical-font-sync-2026-11-02.json)
retains every attempt, including the mismatched Brave capture.

Prior cohort 48 completes seven alternating matched
triples with all 21 original pixel/content/native-exit checks and endpoint
ownership checks passing. Vox median is **31,871,477,469**, its same-binary
font-synchronization control **32,079,725,335**, and Brave lower median
**15,388,048,710** instructions. The strict integer gate fails
`326524191890 > 137741039613`, conservative ratio **2.1335091816256653**.

Keeping unchanged font registrations after selector-only CSSOM edits gives a
median point difference of **208,247,866 (0.6491572599993445%)** against control.
Four pairs improve and three regress; the conservative control ratio
**1.078985433408601** fails. This does not establish a robust speedup or the
requested advantage. No input, reference, tolerance or capture boundary changed.
All attempts remain in the [new evidence supplement](benchmark-results/bbc-selector-font-sync-2026-11-02.json).

Cohort 47 retains fourteen valid Vox/control captures and seven Brave attempts
rejected before launch because the reused installed app already had a live
process. Its Vox/control medians are 31,405,018,137 / 31,511,932,008; five pairs
improve and two regress. It has no Brave counters or comparable Brave gate.
Cohort 48 uses a newer completed production build and an unused signed Brave
path; changes between those builds receive no isolated optimization credit.
The repository's subsequently updated no-copy rule requires canonical app/tool
references for future runs. This retained private-copy cohort authorizes no
additional app or tool copies.

Prior cohort 46 remeasures the same pinned browsers
with a stronger capture-time Vox ownership check. Vox median is
**32,561,838,795**, its same-binary comment-preserving control
**32,744,163,610**, and Brave lower median **16,174,399,220** instructions.
All 14 Vox/control captures pass original pixels, content, native exit and
endpoint ownership. Brave pairs 1 and 4 each change 64,177 photo pixels and
invalidate acceptance. Every attempt is retained. This protocol correction
changes no counter boundary and receives no engine optimization credit.

The Brave integer gate fails `328013511490 > 143989597287`, conservative ratio
2.050232557790847. The separate matched-control median difference is
182,324,815 (0.5568162227980067%); five pairs improve and two regress, while
conservative control ratio 1.0199245717551637 fails.

Prior cohort 45 measured Vox **32,872,445,783**, control **33,698,209,308**, and
Brave lower median **16,080,434,504**. Omitting empty generated procedural CSS
removes a proven unnecessary stylesheet replacement; the median point
difference was 825,763,525 (2.4504670780947535%), with four pairs improving
and three regressing. All 21 original pixel/content/native-exit checks pass,
but its early Vox ownership scans do not attest the later capture-time task
set. Those raw results remain retained with that qualification. Its Brave gate
also fails `340057296670 > 143659414512`, ratio 2.1303968698649767.

Prior cohort 44's pseudo-element candidate batching regressed: Vox
**33,363,170,629** versus control **33,008,032,632**, with Brave lower median
**16,086,526,413**. It was removed. All 14 Vox/control captures preserve pixels
and content; Brave pair 2 changes 64,177 photo pixels. Its gate fails
`338824066360 > 144073049490`, ratio 2.1165767005241722. Cohort 43's callback
experiment also regressed: Vox **34,199,020,506** versus control
**33,629,819,108**, Brave lower **16,131,151,077**, failing gate
`423377827010 > 145121253876`, ratio 2.6256667037523163. It was removed,
retaining all 21 valid captures and both first-launch outliers.

The earlier retained immutable native frames in cohort 42 measure Vox
**33,233,453,967** against copy control **34,484,213,827**, a point reduction
of **1,250,759,860 (3.627050528902287%)**. Brave lower median is
**16,098,894,787**. Six pairs improve and one regresses; conservative control
ratio 1.0179027541231616 fails. Its Brave gate fails
`341199892640 > 144047362977`, ratio 2.13179816019979. Differently pinned
builds do not establish isolated before/after gains between cohorts.

The prior metric-context attempt regressed and was removed. The retained
closed-text measurement cache in cohort 40 reduced the observed Vox median by
**1,683,900,315 instructions (4.727752730701374%)** against its matched
control. All seven candidate/control pairs improve, but the conservative
highest-candidate/lowest-control ratio is 1.0341074114812472. The invalid
Brave cohort also fails the diagnostic integer gate:
`357554103320 > 144023674617`, ratio 2.234345803519834. This establishes no
10% advantage over Brave. The prior baseline-JIT experiments remain rejected;
production JIT thresholds remain unchanged.

Cohorts 37–49 explicitly use `VOX_RETAIN_INCREMENTAL_WEBP_PAINT_POLICY=1` in
both Vox arms to reproduce the historical frozen RGB workload. Production's
completed-response YUV policy changes photo pixels; an unchanged-binary
isolation confirms that the historical switch restores the original reference.
The compatibility control changes no default and earns no decoder credit.
These are historical-renderer frozen-page results, rather than current-default
or live site acceptance. Earlier invalid captures, protocol corrections,
failing cohorts and their outliers remain retained.

The machine-readable [base evidence](benchmark-results/bbc-brave-instructions-2026-11-01.json)
and [protocol supplement](benchmark-results/bbc-protocol-audit-2026-11-02.json)
retain the earlier 1,140 attempts across 46 cohorts. The
[font-synchronization supplement](benchmark-results/bbc-selector-font-sync-2026-11-02.json)
indexes **1,192 retained attempts across 48 cohorts**, including failures and
first launches. It rechecks 42 new raw trial records; the prior audit checked
952 earlier cohort records. The canonical-input supplement adds 21 cohort
records and two execution diagnostics, bringing the retained history through
cohort 49 to **1,215 attempts**. Cohort 47's seven missing Brave counter intervals
remain explicit. Private historical bundle/tool copies were removed from the
shared workspace, so their earlier input-hash receipts do not imply every
physical input is still present. Commands, ownership audits and artifact hashes
remain recorded. Raw archives, logs, PNGs, executable copies, PID registries,
compiler output and guard receipts remain under
`Build/bbc-home-instructions-20261101-054807/` in the canonical checkout.
The font-request supplement adds 21 cohort attempts and eight separate
diagnostic captures, bringing the retained history to **1,244 attempts across
50 cohorts**. Cohort 50's two missing Vox intervals remain explicit.

## Workload and endpoints

The page is **https://www.bbc.com/**, rather than `/news`. A sealed, non-forwarding
HTTPS replay supplies 595 recorded responses and preserves the original author
scripts, 88 ordered card headlines and all 70 real photo sources. Its original
document is 641,643 bytes, SHA256
`f70fea0eaef611591f788542cfe93124c2e2768784d215c44204fd8c832968fa`.
The BBC font URLs which originally returned 404 still return 404; the audit
accepts only source-proven local Arial fallback faces.

Both engines use fresh processes, empty private profiles and browser caches,
clean proxy environments, a 1024×768 CSS-pixel document viewport, capture scale
2, the same replay and two seconds of settlement. OS filesystem and shader
caches remain warm. Vox uses JavaScriptCore explicitly, author JavaScript
enabled and cookie-banner blocking disabled. Brave uses V8 and its default
Shields policy. This is a frozen-page measurement; it does not establish that
the current live site is fixed.

Both counters cover exclusive resource-coalition creation through encoded
document PNG availability, including browser startup and native window setup.
Vox ends before writing the PNG; Brave includes CDP screenshot delivery and
window/target creation. Readiness polling and settlement are included; semantic
audits and teardown follow the endpoint. Coalition totals include exited
helpers and explicitly permitted owned services. GPU execution, the replay and
observer, and services outside the owned coalition are excluded. The guard
adopts LaunchServices browser PIDs and records their RSS.

The first seven-pair cohort failed because BBC relative timestamps changed
320 pixels. It remains in the evidence. The corrected fixture inserts one
shared wall-clock shim freezing `Date` at 1793503154007; monotonic timers remain
real. Its document SHA256 is
`81cf44b6b1539aef724eda00a1e1034def2170162fcdfa84d9bb5608c06cf171`.
This correction and the later visible-image decode readiness check earn no
engine optimization credit. Neither reference pixels nor tolerances changed.

## Complete cohorts

All statistics below include every trial in the respective seven-pair cohort.
Brave figures are medians of lower bounds; Vox bounds are equal at its native
capture marker. An invalid cohort is retained for diagnosis, not acceptance. Cohorts
before 46 use their recorded earlier checks; their capture-time Vox ownership
was not verified and cannot satisfy the new ownership gate.

| Cohort | Vox median | Brave median | Maximum Vox upper / minimum Brave lower | Result |
| --- | ---: | ---: | ---: | --- |
| Corrected-clock baseline | 109,038,368,077 | 15,214,425,439 | 7.482949915090812 | Content and fixed references pass; instruction gate fails |
| Grid block-height reuse | 90,700,737,334 | 15,566,813,595 | 6.241506185808689 | Gate fails; Brave pair 5 photo differs |
| Disposable grid width probes | 71,087,924,913 | 15,830,667,000 | 4.987054269056659 | Gate fails; Brave pairs 3 and 6 photo differs |
| Stationary raster reuse | 75,303,556,310 | 15,575,369,841 | 5.409313292632096 | Gate fails; Brave pair 7 photo differs |
| Client-geometry index and tracked-arena shortcut | 65,708,093,045 | 15,584,042,718 | 4.367784478797594 | Gate fails; Brave pair 1 photo differs |
| JIT entitlement | 49,813,515,416 | 15,679,077,351 | 3.3100826753570693 | Gate fails; Brave pair 2 photo differs |
| Attribute-name buckets and scope-parent jumps | 47,129,217,196 | 15,646,633,009 | 3.2509168791412764 | All observations valid; gate fails |
| Guarded CSS-wide and border-slice reuse | 45,124,755,934 | 15,540,480,007 | 3.1224368328405316 | Gate fails; Brave pair 3 photo differs |
| Guarded RGB reuse | 44,077,336,320 | 15,549,390,499 | 3.340949257394858 | Gate fails; Brave pair 4 photo differs |
| Retained-command direct reads | 44,466,503,621 | 15,579,542,542 | 3.565802776525631 | Gate fails; Brave pair 4 photo differs |
| Retained ordinary flow items in grid/flex | 44,521,001,422 | 15,591,881,320 | 3.681015720678472 | All observations valid; gate fails |
| Selected-face display/failure invalidation | 46,582,465,131 | 15,619,372,290 | 3.3740750674717432 | All observations valid; gate fails; median regresses against control |
| Numeric-ratio, font-style and duration reuse | 44,005,434,509 | 15,397,702,164 | 3.037884119847623 | Gate fails; Brave pair 4 photo differs |
| Completed shared O3 production build | 42,995,770,723 | 15,723,370,671 | 3.110810439568189 | All observations valid; gate fails; no isolated compiler attribution |
| Intrinsic sizes across unrelated font completions | 43,359,803,356 | 15,823,854,730 | 3.368777312785835 | Gate fails; control pair 5 and Brave pairs 4/7 differ; median regresses against control |
| Original live pending-font intrinsic reuse | 40,329,352,824 | 15,970,908,247 | 2.8081095382756427 | All observations valid; Brave and matched-control gates fail |
| Text chunks and shapes with original live pending fonts | 40,577,716,115 | 15,788,336,728 | 2.6331015373715503 | All observations valid; Brave and matched-control gates fail |
| Original pending-font snapshots during style refresh | 39,333,822,066 | 15,621,067,131 | 3.1776463343078 | Gate fails; Brave pair 6 differs; median regresses against control |
| Selective style-only conditional-rule insertion | 38,669,617,935 | 15,723,338,132 | 2.5598256625689984 | All observations valid; Brave and matched-control gates fail |
| Filtering helper JIT entitlement | 37,990,584,359 | 15,546,241,164 | 3.0270279597468543 | All observations valid; median regresses against control; both gates fail |
| Skip inactive conditional-rule insertion | 37,396,821,455 | 15,731,322,435 | 2.514265550853879 | Brave pair 3 differs; Brave and matched-control gates fail |
| Classic-script import identifier filter | 37,463,386,894 | 15,655,612,802 | 2.4762586430968168 | All observations valid; median regresses against control; both gates fail |
| Viewport, grid-placement and radius longhand reuse | 37,314,150,142 | 15,652,929,710 | 2.510631500286319 | All observations valid; median regresses against control; both gates fail |
| Check own eligibility before inherited hashing | 36,574,920,629 | 15,732,111,035 | 2.43280501847826 | Brave pair 6 differs; median regresses against control; both gates fail |
| Indexed JavaScript roots | 36,723,883,384 | 15,720,570,525 | 2.4371307290010487 | All observations valid; median regresses against control; both gates fail |
| Shared geometry accessors, recovered production build | 34,949,303,465 | 15,879,294,537 | 2.31320003135991 | All observations valid; Brave and matched-control gates fail |
| Shared compact Node properties | 36,123,754,014 | 15,806,323,773 | 2.3259499042136356 | All observations valid; median regresses against control; both gates fail |
| Required attribute buckets before tag buckets | 36,673,262,472 | 16,116,361,443 | 2.3992396531867937 | All observations valid; Brave and matched-control gates fail |
| Selective ordinary style-rule deletion | 36,552,719,392 | 16,368,303,379 | 2.3885773998393387 | Brave pair 7 photo differs; median regresses against control; both gates fail |
| Plain user stylesheet subject invalidation | 36,606,121,582 | 16,121,151,447 | 2.3956684098670245 | All observations valid; median regresses against control; both gates fail |
| Necessary static predicates for user-style subjects | 36,606,121,582 | 16,121,151,447 | 2.3956684098670245 | All observations valid; median regresses against control; both gates fail |
| Repeated default cosmetic-filter queries | 36,057,458,625 | 16,480,599,153 | 2.3630417159732398 | Gate fails; Brave pair 1 photo differs; median regresses against control |
| Retained ordinary grid geometry | 35,400,964,816 | 16,625,613,691 | 2.839621547749952 | All observations valid; median falls 2.8601% against control; both conservative gates fail |
| Dense intrinsic-seed visitation | 35,348,564,657 | 16,161,771,586 | 2.8677260187784155 | All observations valid; median falls 3.2757% against control; both conservative gates fail |
| Quiet instruction counting (protocol correction) | 34,693,898,775 | 16,382,454,723 | 2.9155220150098202 | Brave pair 3 pixel mismatch; integer gate fails; zero engine credit |
| Retained font-validation memoization | 35,330,134,680 | 15,983,256,775 | 2.8075196412182386 | All captures valid; median regresses 2.2607% against control; implementation reverted |
| Direct DOM query fields, historical WebP policy | 35,760,574,950 | 16,077,980,043 | 2.7173610002528643 | All captures valid; median regresses 0.0599% against control; implementation removed; historical decoder setting required |
| Earlier baseline JIT, historical WebP policy | 35,976,507,921 | 15,918,309,134 | 2.361239852002433 | All captures valid; threshold 50 regresses 4.1131% against control; production default unchanged |
| Later baseline JIT, historical WebP policy | 35,194,223,202 | 15,768,785,889 | 2.3256469115293705 | All captures valid; threshold 5,000 regresses 1.2389% against control; production default unchanged |
| Closed text measurement reuse | 33,933,451,330 | 16,118,311,870 | 2.234345803519834 | Brave pair 7 photo differs; acceptance invalid; diagnostic gate fails |
| Value-dependent metric contexts | 34,812,815,726 | 16,130,512,650 | 2.715080947032688 | Brave pair 3 photo differs; median regresses 0.2522% against control; implementation removed |
| Immutable native stationary frames | 33,233,453,967 | 16,098,894,787 | 2.13179816019979 | All captures valid; median falls 3.6271% against control; both conservative gates fail |
| Small callback argument lists | 34,199,020,506 | 16,131,151,077 | 2.6256667037523163 | All captures valid; median regresses 1.6925% against control; implementation removed |
| Batched pseudo-element candidates | 33,363,170,629 | 16,086,526,413 | 2.1165767005241722 | Brave pair 2 photo differs; median regresses 1.0759% against control; implementation removed |
| Omit empty procedural CSS payload | 32,872,445,783 | 16,080,434,504 | 2.1303968698649767 | All captures valid; median point falls 2.4505% against control; four improve/three regress; both conservative gates fail |
| Capture-time coalition ownership audit | 32,561,838,795 | 16,174,399,220 | 2.050232557790847 | Protocol correction only; all endpoint ownership proofs pass; Brave pairs 1/4 photo mismatches and integer gate fail |
| Selector-only font registration retention | 31,871,477,469 | 15,388,048,710 | 2.1335091816256653 | All captures valid; four matched pairs improve/three regress; both conservative gates fail |
| Canonical inputs and preexisting-task identity | 31,284,060,062 | 15,005,464,950 | 2.1312243326651696 | Protocol correction only; Brave pair 2 differs; all native/content checks pass; integer gate fails |

The grid block-height cohort alternates an older control, candidate and Brave;
control/candidate medians are 101,567,929,247 and 90,700,737,334 (10.70% observed
reduction). The grid width cohort uses one binary with that path disabled only
in controls: 83,319,256,016 versus 71,087,924,913 (14.68% observed reduction).
These point estimates do not clear the conservative 10% control/candidate
gate. Shared builds also contain concurrent changes; unrelated binary changes
receive no credit for these individual paths.

The stationary cohort uses exactly the same binary on both sides, with only
`VOX_DISABLE_STATIONARY_RASTER_REUSE` differing. Its disabled control median is
73,283,491,627, so enabling the cache **regresses the median by 2.76%**. A
separate diagnostic proves 149 cache reuses and zero differing reference
pixels. Faster replay admits more native frames during settlement, increasing
preparation work; no net instruction improvement is credited to this cache.

The geometry/arena cohort uses one binary with both paths disabled only in
controls: medians 69,618,641,818 versus 65,708,093,045 (5.62% observed reduction).
Its conservative matched-control gate fails.

The JIT cohort compares the same compiled executable and libraries, differing
only in the code signature's `com.apple.security.cs.allow-jit` entitlement.
Every file-backed Mach-O section and other bundle file is verified unchanged.
WebKit's [executable allocator](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/JavaScriptCore/jit/ExecutableAllocator.cpp)
checks this entitlement on the measured system; Apple's
[entitlement documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.allow-jit)
describes its purpose. Controls have a median of 68,622,675,849 versus
49,813,515,416 with JIT (27.41% reduction). The conservative matched-control
ratio, 0.796913029622123, clears 0.9. Separate diagnostics positively observe
JavaScriptCore JIT/DFG compilation threads and identical results in a C API
probe. Probe counts are diagnostic, not BBC optimization credit. The BBC cohort
still fails the Brave target and retains its Brave photo difference.

The attribute/scope cohort compares the same binary with only attribute-name buckets
and allocation-scope jumps disabled in controls. Medians are 50,918,264,203
versus 47,129,217,196 (7.44% observed reduction); its conservative matched-control
ratio is 1.0424294404793093 and fails. Separate diagnostics execute both paths,
record one JavaScriptCore context and 2,002 evaluations, and match the original
Vox image exactly.

The CSS-wide/border cohort compares the same binary with only those cache
extensions disabled in controls. Medians are 45,745,943,469 versus
45,124,755,934 (1.36% observed reduction), but the conservative control ratio
is 1.1245313509465262 and fails. The RGB cohort leaves those extensions on
and disables only RGB reuse in controls: 44,235,991,934 versus 44,077,336,320
(0.36% observed reduction), with a failing conservative ratio of
1.2120385588929428. These point estimates do not establish optimization credit.
The RGB cohort retains the first Brave launch at 31,143,310,575 instructions;
no outlier was removed. Separate diagnostics prove both reuse paths execute
and preserve the original Vox image. RGB snapshots guard each channel, optional
name and syntax, and validate retained as well as candidate inputs against
in-place mutation. A component diagnostic reduces full property loops from
3,321 to 2,165 on copied SSR markup; it is not a browser instruction result.

The direct-read cohort uses one binary with value iteration enabled only in
controls. Generated C confirms that the old path allocates and copies each
complete retained command, while the candidate reads its fields through a
pointer. Medians are 45,081,443,598 versus 44,466,503,621 (1.36% observed
reduction); its conservative matched-control ratio is 1.2917547717477877 and
fails. Both paths preserve the fixed Vox reference in separate diagnostics,
with one JavaScriptCore context and 2,430/2,409 evaluations. Fresh processes
and all seven triples remain recorded, including first-launch outliers.
A later disassembly corrects the working diagnosis of the large sampled copy
under `begin_stationary_document_raster`: the call at offset +1212 follows
`CGContextFlush` and restores `native_stationary_raster.pixels`. The earlier
330 sample weights cannot be attributed to command scanning. Generated-C and
runtime witnesses still establish the direct-read path, but its conservative
instruction comparison fails and no accepted gain is claimed.

An initial attempt stopped after one control because another session changed
`tools/hacker_news_browser_instructions.py`. Its raw result and changed hashes
remain recorded. The complete replacement cohort uses an immutable copy of
15 exact committed measurement scripts, with the original script hash restored
by copying its committed version. No browser sources were copied. Original
failed-cohort data remain included in durable evidence.

A summary bug passed three-engine records to a strict two-engine evaluator,
which reported “Incomplete measured pair.” Commit `376a3c0b` projects the
Vox/Brave and Vox/control comparisons independently, validates all observations
and keeps the integer gate. Recomputed summaries use the original raw counts;
no endpoint, reference or trial changes. Earlier original summaries remain
retained. The corrected attribute/scope summary fails solely on the instruction gate.
Later cohorts retain their original pixel failures as well as failing counts.

For acceptance, at least seven alternating complete pairs must pass content,
pixels, identities and exits, and integer arithmetic must satisfy
`10 * max(Vox upper) <= 9 * min(Brave lower)`. No recorded cohort meets this.

## Rendering and execution limits

Every Vox image in the corrected cohorts matches its original reference
exactly. The attribute/scope cohort also has seven exact Brave captures. Earlier
recurring Brave differences affect 64,177 pixels within one photo.
The direct-read cohort differs at 304,064 pixels in that photo, with a maximum
channel error of 18. These failures have
unchanged image bytes, source URL, intrinsic dimensions and geometry.
Awaiting visible `img.decode()` did not remove these differences. Their cause remains unresolved;
those attempts are retained without exclusions or relaxed tolerances.

Per-engine stability is distinct from cross-browser equality. The reference
images differ at 2,448,723 of 3,145,728 pixels (77.8428%). Vox and Brave have
different consent/ad spacing and vertical positions; their hydrated image
counts also differ, despite matching all source headlines and real photos.
Vox rejects a BBC module fetch lacking the required CORS header, and another
BBC script reports a load timeout. These are rendering and scripting limits.

A separate injected JavaScriptCore diagnostic records one context, one group
and 1,938 evaluations, with the runtime initialized and React/CSSOM hydration
executed. The grid diagnostics separately prove the optimized paths execute.
The selected backend has no observed LibJS fallback. These instrumented runs
receive no hardware-counter performance credit.

An earlier measured executable is SHA256
`2226008c70cb493c9decd4092b9dd0e695854300ba39c488c703ce91520f45d6`.
The preceding font-display candidate is
`5aae83a4408e023380d51e4430003b519ec427bcd96b3701b634930eeda62952`.
The JIT-only candidate is
`ea63463d5d1e7c6d28c320fbf2060eead45490e549a2ac45f607ccdff8e65c89`.
Native-library identities, source snapshots, entitlement checks and generated-C
witnesses are recorded. Concurrent source edits are disclosed; same-binary
controls isolate the measured runtime switches.

One RGB validation attempt passed its image checks but is invalid because an
early executable search path loaded Skia from shared `Build/v`, where another
build replaced it during validation. Commit `b3e01505` removes that search path
before signing. The corrected private candidate loads its own bundled Skia,
verified in a fresh process with dyld logging. All file-backed executable code
and data sections and bundled libraries remain byte-identical; only load
commands and the signature change. This packaging repair receives no engine
instruction credit. The original failed identity validation remains recorded;
the later checks and RGB cohort have stable private library identities.

## Verification and remaining work

Focused grid, CSSOM, initial-value cache and native raster checks pass in their
recorded GC modes. The pinned production browser passes `--headless-smoke`,
all 11 default screenshot cases (eight exact, three under existing bounds),
and all eight required SVG mutation cases exactly. All 100 upstream LibJS AST
fixtures match exactly.

An earlier broader rerun enters all 397 cases in both normal and no-GC
modes (80 fresh no-GC processes). Each mode passes 396 cases and retains one
input baseline mismatch: Vox returns 13.5 where the unchanged test and an
independent Brave content-box oracle require 13. The prior font-fingerprint
memory failure is corrected and its previously interrupted cases now complete.
Earlier failed attempts, including the missing receipt after guard cleanup
failed, remain recorded. The input baseline failure keeps broad verification
open.

All 45 allocator checks pass in normal, no-GC and preallocated modes, including
a preallocated run with scope jumps disabled. Nine selector checks pass in
normal and no-GC modes. The benchmark tools pass 177 Python checks. The RGB cache passes 19 focused
checks in normal, no-GC, preallocated and diagnostic modes. Two real Mach-O
loader checks verify bundled-library selection and reject a missing fallback.
The newest pinned browser passes headless startup, all 11 screenshot smoke
cases and all eight SVG mutation cases. These checks do not establish full
BBC rendering or scripting parity.

The remaining work is to reduce the full launch/capture workload sufficiently
to pass the conservative Brave gate while preserving content and references.
The direct-read scan passes five focused checks in normal, no-GC and preallocated
modes, with the copy-based control also checked in each mode. Its production
bundle passes headless startup, the complete smoke set and all eight SVG cases
with stable private library identities. An initial test-wrapper attempt failed
before screenshot launches because its copied capture script lacked execute
permission; that failure is retained and the corrected wrapper passes.
Retaining unchanged ordinary flow items inside grid/flex parents passes all 20
focused flow checks in normal, no-GC and preallocated modes, with the disabled
control also checked in each mode. An initial preallocated failure exposed
unleased old paint scenes in test setup; the corrected checks retain the old
scene while asserting its unchanged dump. Both attempts remain recorded.
Fresh candidate/control diagnostics prove the path executes only when enabled,
match the original Vox reference exactly, and record JavaScriptCore execution
(2,023 and 2,083 evaluations). A separate sampled profile also matches exactly
and receives no instruction credit. The unprofiled matched control median is
45,640,904,010 versus candidate 44,521,001,422, a 2.4537% point reduction. Its
conservative ratio is 1.3286517869182544, so no accepted gain is claimed. All
21 content/pixel/exit checks pass; both Brave outliers remain included. The
integer Brave gate fails: 571,440,242,190 > 139,715,843,940.

Selected-face display/failure invalidation passes all 26 focused font checks
in normal, no-GC and preallocated modes with enabled and disabled paths. Tests
cover selected weights, fallback visibility across block/swap/failure periods,
root metrics, pseudo/shadow styles and unknown-face family-wide fallback. The
first test attempt accidentally initiated fixture network requests and applied
an equality helper which deliberately rejects pending cascades; its results
are retained, and the corrected fixtures hold pending requests explicitly.
The original screenshot and SVG checks remain unchanged and pass. The broader
397-case run again passes 396 in each GC mode, retaining the baseline failure.
The shared build had stable font implementation inputs; moving the added tests
into their self-contained existing test file changed only test inputs. A pin
wrapper failed when sorting fingerprint dictionaries after copying the app;
the corrected metadata comparison verified source and private identities.

Fresh BBC diagnostics expire 2 and 9 selected font cascades while retaining
15 and 8 others; disabled controls have no such trace. Both original Vox
references match exactly, with 2,008/2,475 JavaScriptCore evaluations. The
separate sampled profile also matches exactly and earns no instruction credit.
The unprofiled cohort has control median 45,601,371,313 versus candidate
46,582,465,131: a **2.1515% median regression**, with conservative control
ratio 1.185424334779776. No improvement is credited. All 21 observations pass
content, reference pixels and exits; Brave pairs 1 and 4 exceed 30 billion and
remain included. The integer Brave gate fails:
521,875,603,630 > 139,204,977,327. A preceding command failed argument validation
before launching any browser and remains recorded separately.

Separate CSS diagnostics use a private build from captured production C and
pinned native objects, with only diagnostic counter bodies enabled. The
production candidate keeps those counter bodies empty. Both builds retain
complete compiler commands, source hashes and memory-guard receipts. The
first private compile used a relative C path from the wrong working directory;
that failure and the corrected successful compile remain recorded.

The final cumulative diagnostic scopes report 10,835,972,177 instructions in
rule collection and 9,517,382,464 in computed-property construction. The latter
includes 7,653,319,585 in 6,709 longhand loops. These are instrumented
**per-process, overlapping inclusive scopes**, with counter overhead; they are
not coalition acceptance counts and cannot be added or credited as savings.
All diagnostic captures match the original Vox reference exactly.

A separate cache-capacity probe compares the existing 256-entry limit with a
4,096-entry diagnostic limit. Both peak at 204 entries with zero capacity
rejections, so the production limit remains unchanged. Another probe counts
2,556 first ineligible declarations: numeric aspect ratios account for 1,031,
explicit font styles for 382, and transition durations for 98. These probes
receive no instruction credit.

Commit `0cf79695` adds typed snapshots and hashes for numeric ratios, font
styles without an angle and time values. Calculated ratios and angled font
styles retain their ordinary computation path. Font snapshots also preserve
angle presence, unit and numeric payload: `normal` and `oblique 0deg` serialize
identically, so text alone cannot guard mutations. All 27 cache checks pass in
normal, no-GC and preallocated modes, with enabled and disabled controls. The
first compile failed on an invalid concrete-type name accessor; corrected
checks and all attempts are retained. The broader run enters all 397 cases in
both GC modes, with the same sole input-baseline failure. The benchmark tools
pass 177 checks. The production candidate passes headless startup, all 11
smoke cases and all eight SVG cases with stable executable/library identities.

Fresh BBC diagnostics observe a restored ratio only on the enabled path, with
2,013/2,427 JavaScriptCore evaluations in candidate/control. Both captures
retain complete content audits and match the original Vox reference exactly.
The site catalog must wait for a qualifying cohort. Startup counts establish
neither isolated rendering time nor scrolling FPS.

The unprofiled constant-longhand cohort uses the same executable for control
and candidate, with only `VOX_DISABLE_CONSTANT_LONGHAND_REUSE` set in controls.
Control median 44,338,719,862 versus candidate 44,005,434,509 is a 0.7517%
point reduction; pairs 3 and 7 regress. The conservative matched-control ratio
is 1.1304975685237806, so no accepted improvement is credited. All 21 semantic
audits and native exits pass, and all 14 Vox/control pixel checks are exact.
Brave pair 4 differs in 304,064 photo pixels (maximum channel error 18) and
remains included with its failed audit exit. No Brave trial exceeded 30 billion
instructions in this cohort. The integer target fails:
465,554,457,010 > 137,924,619,498. The guard adopts 69 process identities,
reports no adoption error and peaks at 1,478,508,544 bytes over 130.48 seconds.
The initial production build attempt found the shared guard busy; after that
separate C-capture job completed without an installed candidate, the required
production build completed in 255.44 seconds, peaking at 8,791,277,568 bytes.
Its cache implementation inputs were stable throughout the build. A separate
layout-counter diagnostic supplies no acceptance or engine instruction credit.

The first layout probe records overlapping recursive intervals, some exceeding
the entire process count. A second probe separates outermost selected intervals
and counts cache activity. It observes 402,520 intrinsic-cache hits, 14,009 empty
slots, 6,914 font-epoch expirations and 19,609 resets. Its 20,318 minimum and
20,292 maximum width probes motivate investigating font-epoch reuse. Both
captures retain complete content and match the original Vox reference exactly.
The second private compile overlaps an edit to `native_graphite_dawn_darwin.mm`;
the receipt verifies that this source was neither a direct compiler input nor
included in the generated C. The diagnostic instead links pinned native objects.

Counter overhead is material. Three separate calibrations of the same Darwin
process-counter helper each retain 10,000 consecutive-read intervals, with
medians of 6,534, 6,559 and 6,559 instructions. Nested scope totals therefore
cannot establish uninstrumented CSS or layout costs. No calibration value is
subtracted from acceptance counts or claimed as engine savings. Refined sampled
stack analysis also remains diagnostic wall-clock evidence.

The next seven-pair comparison reuses a completed shared production build
(`f73d60545c98f002b96ad3be1340d288f695593c4a8c72f24dc37e5458d8ad9f`)
with the shared O3 compiler setting. All 14 observations pass content, original
pixels and exits. Its integer gate still fails:
487,128,908,650 > 140,933,054,682. Brave's first launch exceeds 31 billion
instructions and remains included. Concurrent engine changes prevent attributing
the difference from earlier cohorts to O3 alone.

Commit `77ed7129` records a cascade's creation generation and retains intrinsic
dimensions across later unrelated font completions only when every subtree and
ancestor cascade is still original and live. Pending, unknown or replaced
cascades, changed rendering policies and containing blocks outside the parent
chain retain recomputation. Normal style/tree invalidation still resets caches.
All 11 CSS and 13 layout checks pass in normal, no-GC and preallocated modes,
including disabled layout controls. Both broad modes enter all 402 cases and
pass 401, with the same sole input-baseline failure. The matched benchmark
control in `1badee84` passes the 179-check instruction-tool suite.

The first build attempt finds the production guard busy. The completed shared
build includes an earlier version without the final containing-block guard,
as witnessed in captured compiler input, so it cannot validate that guard.
The required final build completes in 397.00 seconds, peaking at 7,088,160,768
bytes with all six implementation/test inputs stable. Its executable SHA256 is
`664599f14e25df9e0bdbdafb5f81e58e7386dd6d54bfb60511814b8d6a96801a`.
Captured C confirms the final guard and inactive CSS instruction scopes.
Startup, 11 smoke cases and eight SVG cases pass with stable identities.
The first screenshot jobs stop before browser launch because the prepared
capture helper lacks executable permission; corrected checks and both failed
attempts remain retained.

Separate BBC diagnostics observe the new path only when enabled, with one
JavaScriptCore context/group and 2,508/2,451 evaluations in candidate/control.
Both captures match the original reference exactly. The uninstrumented cohort
uses one executable, changing only `VOX_DISABLE_INTRINSIC_FONT_REUSE` in controls.
Its control median is 43,222,471,464 versus enabled 43,359,803,356, a **0.3177%
median regression**. Pairs 4 and 5 regress, and the conservative control ratio
is 1.2555710949355419. No instruction improvement is credited.

All 21 content audits and native kernel exits pass, but control pair 5 differs
in 545,271 pixels and Brave pairs 4/7 differ in 64,177/304,064 photo pixels.
The control image visibly has an underlined central headline and faded photo,
consistent with a hover effect; it remains a failed observation. All seven
enabled Vox captures match exactly. Brave pairs 1 and 2 exceed 31 billion and
remain included. The integer Brave gate fails:
526,191,905,120 > 140,577,031,557. The guard adopts 71 identities without error,
peaking at 1,468,874,752 bytes over 174.31 seconds. BBC remains outside the
optimized-site catalog.

A subsequent count-only diagnostic keeps hardware-counter scopes inactive and
matches the original Vox pixels and content. It observes 13,224 longhand-cache
hits and 1,230 lookup misses, plus first unsupported declarations led by
`background-position-x` (375), `grid-template-columns` (329), `grid-column-start`
(247) and `border-top-left-radius` (192). Of 2,084 intrinsic font-epoch checks,
471 retain the cache; 1,613 first reject pending fonts. That first-rejection
classification does not establish whether those pending cascades are still
live, so it cannot justify relaxing the guard. Concurrent edits to included
`native_capture_darwin.m` and the separately pinned Skia implementation remain
disclosed; this private build supplies diagnostic leads, not isolated
performance evidence. A follow-up probe saves its preprocessed compiler input
and distinguishes original/live pending cascades from expired or newer ones.

The follow-up count-only capture also matches the original pixels, complete
content and native exit. It observes 5,023 epoch checks: 781 retained caches and
4,242 pending rejections. All 4,242 pending cascades are original and live;
none is expired or newer than the cached geometry. This identifies a candidate
for investigation, without instruction credit. Saved preprocessed compiler
input pins included native sources despite concurrent edits. The compile
passes, but initial signing rejects compiler bitcode saved inside the bundle.
Moving only those intermediate artifacts into the adjacent evidence directory
and signing the same executable fixes the diagnostic packaging; both attempts
and artifact hashes are retained.

Commit `b8074e59` extends intrinsic reuse to original, live pending cascades.
Selected-face completion, failure and display-period changes still expire the
cascade; an already-refreshed replacement cannot validate earlier geometry.
The same proof also serves resolved CSS geometry. Unknown inputs, changed
styles and external containing blocks retain their earlier guards. All 16 CSS
and 14 layout checks pass in normal, no-GC and preallocated modes, including
disabled controls. Both broad modes enter all 403 cases and pass 402, with the
same sole input-baseline failure. Matched-control tooling `9719b766` passes all
180 instruction-tool checks.

The required production build finishes in 470.54 seconds, peaking at
6,503,596,032 bytes with its own implementation/test inputs stable. Its pinned
executable SHA256 is
`f9ae4f7c5745ab3cde140485e99f2fca41a98bd98255d27ebfbaed9b55880738`.
Captured compiler input witnesses the original/live pending guard. Startup,
11 smoke and eight SVG cases pass with stable binary identities. Separate BBC
diagnostics match the original pixels and content, observe the new path only
when enabled, and witness 2,424/2,447 JavaScriptCore evaluations in
candidate/control.

The uninstrumented pending-font cohort changes only
`VOX_DISABLE_PENDING_INTRINSIC_FONT_REUSE` between identical executables.
Control median 41,645,708,065 versus enabled 40,329,352,824 is a 3.1608% point
reduction, with pair 5 regressing. The conservative control ratio
1.1059377404151833 fails, so no accepted engine saving is credited. All 21
observations pass content, original references and native exits. First launches
and Brave trials above 31 billion remain included. The integer Brave gate
fails: 439,854,987,830 > 140,973,663,474. The guard adopts 65 identities without
error, peaks at 1,478,033,408 bytes and completes in 144.66 seconds. The requested
10% advantage remains open.

Commit `0cdb8d6c` retains inline text chunks and intrinsic shape owners across
unrelated font epochs only when style identity/revision and the original live
pending cascade are unchanged. Selected completions, changed matching inputs,
expired cascades and style changes retain recomputation. All 16 focused checks
pass in normal, no-GC and preallocated modes, with disabled controls. Two prior
attempts expose test assumptions: an unused face has no font-display timeline
to transition, and completion can synchronously run layout through
FontFaceSet.ready. The final check changes the selected Unicode range and
allows a fresh cache after synchronous layout. Both failed attempts remain
retained. Matched-control tooling `809068ef` passes 181 instruction-tool checks.

Both broad modes enter all 408 cases and pass 407, with the same sole baseline
failure. Disk exhaustion interrupts the first no-GC compile; the unchanged
composed test source subsequently compiles and enters all cases in 82 fresh
batches. Compression receipts retain logical SHA256 values and exact contents
for generated sources and completed standalone test executables. Historical
Vox copies have lossless archives with file metadata, links and attributes.
An attempted browser-copy archival consumes space instead of recovering it;
verified Brave clones are restored, and only redundant or incomplete archives
are removed. The failed compression jobs and recovery receipts remain retained.
Current candidates, page archives and PNG references are unchanged.

The production build completes in 323.35 seconds, peaking at 7,346,438,144 bytes.
Its text-cache implementation stays unchanged; only the test fixture changes
during the build. Captured compiler input witnesses the final implementation,
and the final fixture passes separately. Executable SHA256 is
`5e5a95dcbc9be81238f6b529fb55e157a0556db77dbc1f5609c39e546b11cdd7`.
Startup, all 11 smoke and eight SVG cases pass with stable identities. BBC
diagnostics match the original pixels and full content, observe the path only
when enabled, and witness 1,971/2,431 JavaScriptCore evaluations in
candidate/control.

The uninstrumented text-cache cohort changes only
`VOX_DISABLE_LIVE_PENDING_TEXT_REUSE`. Control median 41,889,164,118 versus
candidate 40,577,716,115 is a 3.1308% point reduction. Pairs 1, 2 and 7 regress;
the conservative control ratio 1.0304606563820868 fails, so no accepted saving
is credited. All 21 content, original-reference and native exit checks pass.
The Brave gate fails: 414,081,075,020 > 141,533,838,414. The guard adopts 68
identities without error and peaks at 1,438,023,680 bytes over 131.69 seconds.
BBC remains outside the optimized-site catalog.

A later outer-scope diagnostic is invalid: it treated the partial CSS candidate
bucket interval and its containing interval as two independent exits. The
counter nesting became unbalanced, and the capture counter JSON was truncated.
No numerical attribution or instruction saving is taken from that attempt.
Its raw run and `outer-scope-diagnostic-assessment.json` remain retained.
Historical Brave copies with identical complete file-content manifests now
share one immutable historical application tree through their original paths;
the current candidate and measurement copies were excluded. The manifest and
replacement receipt preserve each original path and file hash.

## Original pending-font snapshots during refresh

Commit `c0a2176e` lets a font-only style refresh preserve geometry when its
original pending cascade remains live and root/line metrics stay unchanged.
The style retains the original refresh snapshot even when a synchronous query
has already materialized a new cascade. Selected completion, failure and
block-to-swap changes still invalidate geometry. The initial broad attempt
caught a selected descriptor-change regression; its logs remain retained.
The corrected implementation passes all 18 focused compile/runtime/control
jobs in normal, no-GC and preallocation modes. Both broad modes enter 408
cases and pass 407, with only the unchanged 13.5-versus-13 control baseline.

The production build completes in 206.0163 seconds, sampled peak RSS
8,790,589,440 bytes, with the feature's source inputs stable. Its executable
SHA256 is `e5d16ddcacfe7ae6e57964b97c8bc31a1a2d64759edeb38ff0f26267709edd6b`;
the preserved generated C is
`022ee0d1ecb2ae0ba4ce2e999e1bc14a508bc6b84d0a2f7d430987694db02664`.
Startup, all 11 smoke and eight SVG mutation comparisons pass against this
private bundle. An earlier validation launcher lacked executable permission;
that attempt and the corrected launcher's receipts are retained.
Separate BBC diagnostics pass the complete audit and original pixels, observe
the new branch once enabled and zero times disabled, and prove 1,949/1,947
JavaScriptCore evaluations with one context/group in each run.

`live-pending-refresh-cohort` alternates seven control/Vox/Brave triples using
the same executable, differing only in `VOX_DISABLE_LIVE_PENDING_FONT_REFRESH`.
The conservative control ratio is 1.2910009286517528. The Brave integer gate is
`493793945720 > 139856517810`, so it fails independently of Brave trial 6's
pixel mismatch. The guard adopts 66 processes without an adoption error,
completes in 121.3829 seconds at 1,367,490,560 bytes sampled peak RSS, and exits
1 for the failed gate. Every native browser exits 0. The cohort earns no
instruction credit.

The corrected outer-scope diagnostic ignores the partial interval that reuses
the selector-collection start. It reports zero nesting imbalance, 122,784 CSS
counter reads and 1,322 DOM counter reads, with original pixels unchanged.
Its layout/style intervals overlap and include diagnostic overhead; they are
leads, not production instruction shares. A preceding launch rejected ambient
`NO_PROXY` before measurement; that failure remains retained.
A separate script-disabled diagnostic observes 21,568,974,999 instructions but
changes 443,486 reference pixels. Its author-script policy differs and runtime
initialization was not independently probed, so it supplies no optimization
credit. This suggests investigating the additional layout/resource work
triggered by scripting while preserving author behavior in acceptance runs.
Completed cache payloads now share immutable bytes by SHA256 through their
original paths: 22,639 files, 1,379,255,411 logical bytes and 82 unique payloads.
The full metadata manifest and verification receipt remain under the evidence
root; no measured result or browser application was changed by this storage work.


### Positioned image replacement diagnostic

Commit `693b1206` can repaint an absolutely positioned image when its specified
width is definite, its natural aspect ratio is unchanged, and its min/max
constraints cannot introduce an intrinsic-size dependency. Ratio changes,
in-flow images, intrinsic constraints, missing dimensions and SVG documents
retain ordinary layout. Attribute-selector changes still run style and layout.
The retained paint data receives the new URL, bitmap and intrinsic dimensions;
previously published commands keep their original image data.

All 18 focused compile/runtime/control jobs pass across normal, no-GC and
preallocation modes. The broader checks enter 415 cases in each of normal and
no-GC modes: 414 pass, with only the existing 13.5-versus-13 text-control
baseline failure. The production build completes in 357.4893 seconds, sampled
peak RSS 8,797,224,960 bytes, with these engine sources stable. Its executable
SHA256 is `047cf60c6eedaa84ea9b7be91faf81e3d5bbe866c6a9739a979e74fec936c1fe`;
the preserved generated C is
`f5afeb551c9081445ca0a2d19b410e8e8d81415593dbb282df1789d80def0a3f`.
Headless startup, all 11 smoke comparisons and eight SVG mutation comparisons
pass with exact pixels. The BBC control tooling passes 160 browser-instruction
checks and is committed separately as `415c2718`.

The original BBC fixture passes its complete content audit and fixed pixel
reference in both enabled and disabled diagnostics, with 2,404/2,408
JavaScriptCore evaluations and one context/group in each. Neither run observes
the successful image-reuse trace. This optimization therefore earns **no BBC
instruction credit**, and no acceptance cohort is justified by this inactive
path. The instrumented observations are 51,945,881,058 and 50,732,497,985
instructions; their difference is not a production saving. The raw attempts,
checks, build witness and inactive-path assessment are retained under
`positioned-image-ratio-*` in the evidence root. The target remains open and
BBC remains absent from `OPTIMIZED_SITES.md`.


### Full style passes and conditional rule insertion

Separate O2 diagnostics built from the pinned positioned-image production C
identify 12 actual layout passes and six full-document style passes. A guarded
outer-layout probe performs 690 counter reads with balanced nesting; its
reason totals overlap other work and receive no production instruction credit.
The full-style trace attributes subsequent document-wide invalidations to
`CSSStyleSheet.insert_rule`. Its 14 style passes include 15,466 element
recomputations caused by full passes. The only missing-style query is the
initial connected `html` root: the general selective missing-style bootstrap
in `c9e8680a` does not execute on this BBC workload and earns no BBC credit.
Its nine focused normal/no-GC/preallocation compile/runtime/control jobs pass;
the two broad modes each enter 415 tests, with only the known text-control
baseline failure.

Commit `becf4f52` extends the existing selector-subject invalidation plan to
inserted `@media` and `@supports` trees containing only style rules and those
conditional groups. Global registrations and unknown rule kinds retain full
invalidation. Changed existing media-query matches also retain the full path;
inactive conditions are conservatively included in the selector union. This
change passes nine focused jobs and both 415-case broad modes with the same
single preexisting baseline failure. The completed production build takes
221.3809 seconds, peak sampled RSS 8,977,956,864 bytes. Its executable SHA256 is
`aa1a84e71452debb6d14861c02e9033d972f6bb00184a19a82d22e6b12c984d9`;
the generated-C witness is
`97261941be9118b14a917588e78c3fd8bbcc9f9b7c742ec2322102033da6cf9f`.
Headless startup, 11 smoke comparisons and eight SVG mutation comparisons pass
with exact pixels. The separately committed control tooling (`59f37d09`)
passes 161 browser-instruction tests.

Enabled and disabled BBC diagnostics both pass content, native exit and the
original pixel reference, with 2,009/1,943 actual JavaScriptCore evaluations.
The conditional invalidation trace occurs only in the enabled run. The
subsequent uninstrumented seven alternating control/Vox/Brave triples produce
the latest results above. All 21 observations are retained and valid. The
memory guard adopts 71 processes without errors, observes peak RSS
1,385,938,944 bytes, and completes in 126.0775 seconds with controller exit 1
because the instruction gate fails. The separate sampled profile also matches
the fixed reference and earns no instruction credit. Its artifact prefix is
`conditional-sheet-*`; earlier full-style/layout reason probes and unsuccessful
test attempts remain in the evidence root. BBC remains outside the site catalog.


### Filtering helper signing

The separate production `VoxAdblockWorker` lacked the main browser's JIT
entitlement. Commit `9ae714ed` signs it with the existing entitlement plist.
A private candidate re-signs the helper and containing app only; every
file-backed Mach-O section in both executables and all other bundle files
remain identical to the conditional-sheet production build. The source and
candidate helper SHA256 values are
`fe28615b27bd0dceb41c5d52c52aaa24c717d027b8038af5f98e0aedead135b5` and
`4d37c67692ec3bbb2dff263dad68a92a35db4ffb8c5f25c6be3306177e35a679`.
The re-signed main executable is
`840e7d39c615af6259e8bec1cb30e28f61941274a8d524901a094738bb9c2454`.

Separate helper-process samples positively observe JSC JIT/DFG compilation
only with the entitlement. Both sampled BBC captures match the unchanged
reference and pass content/native exits. Both helpers pass actual full-engine
network/cosmetic checks and release their isolated worker normally. Headless
startup, all 11 smoke comparisons and eight SVG mutation comparisons also
pass with exact pixels. Signing and sampling evidence is under `worker-jit-*`.

The uninstrumented seven-pair cohort retains every first-launch outlier and
passes all 21 content, pixel and native-exit checks. Vox median 37,990,584,359
**regresses 0.9765%** against control 37,623,209,920; the conservative control
ratio is 1.2748969881501748. Brave lower median is 15,546,241,164. The integer
gate `464835422110 > 138205489167` fails (worst ratio 3.0270279597468543).
The guard adopts 66 processes without errors, peak RSS 1,361,756,160 bytes,
and finishes in 115.1980 seconds with exit 1 for the failed instruction gate.
This change earns no BBC performance credit.


### Inactive inserted conditional rules

The inserted-rule diagnostic preserves the fixed BBC pixels and records 695
insertions: 378 style rules, 315 media rules and two keyframe rules. Its only
new transition from clean style to a full cascade is a media rule below 599px,
which cannot match the benchmark's 1024px viewport. This diagnostic has four
full style passes and 12 partial passes; instrumentation and O2 compilation
earn no instruction credit.

Commit `0a195fac` omits currently inactive media/supports branches from a
style-only insertion's invalidation union after evaluating media matches.
Changed existing matches still fall back to full invalidation. The ordinary
media-change path makes previously skipped rules effective after a resize.
Twelve focused compile/runtime/control jobs pass across normal, no-GC and
preallocated modes, including resize in both directions with nested media and
supports groups. The first test attempt expected a universal rule to override
a class rule; the corrected fixture gives the new target rule equal
specificity. That failed attempt remains retained. Both broader modes enter
415 cases; only the unchanged 13.5-versus-13 text-control baseline fails.

The production build completes in 188.1680 seconds, peak sampled RSS
8,904,687,616 bytes, with these engine sources stable. Its executable SHA256
is `8dbdebed953798880953a47e3aa3b77b4532361efadeba2e629733ecb24611a1`;
the preserved generated C is
`81c731ae23d58b7106a942876f3d70d14fd9cd745ab6776bae1aefcf84f3e2a2`.
Headless startup, 11 smoke comparisons and eight SVG mutation comparisons pass
with exact pixels. Control tooling `21f768e2` passes 162 browser-instruction
tests. Enabled and disabled BBC diagnostics pass content, original pixels and
native exits, with 1,911/2,040 JavaScriptCore evaluations respectively. Only
the enabled diagnostic logs the inactive-group skip. Evidence uses the prefix
`inactive-sheet-*`.


The uninstrumented seven alternating triples preserve all counts and outliers:
control median 37,698,968,829, candidate 37,396,821,455 (0.8015% point
reduction), Brave lower median 15,731,322,435. The conservative control ratio
1.1054906544208132 fails. The Brave integer gate and pixel invalidity are
reported above; the first Brave image mismatch remains retained. The guard
adopts 70 processes without errors, peak RSS 1,351,057,408 bytes, and completes
in 110.6187 seconds with controller exit 1 for failed acceptance.

A further separate O2 diagnostic wraps six workflow scopes with 30,980 process
counter reads, ending at depth zero with no counter errors. Its final inclusive
CSS-update total is 7,074,836,504 instructions across 16 calls. Layout has six
calls, inclusive 4,782,319,728 and 3,525,312,075 after subtracting instrumented
nested scopes. JS function calls have 12,310 calls, inclusive 13,033,608,146
and 9,422,956,992 after that subtraction. Stylesheet insertion and font
synchronization have inclusive totals 586,764,304 and 108,166,379. These are
**diagnostic process counts**, including background work and probe/logging
overhead, with nested scope overlap. They are not production percentages or
optimization credit. The original pixels, full content and native exit pass;
`workflow-scope-*` retains the exact inputs, compiler receipts, logs and values.


### Classic-script import scan

A separate O2 diagnostic categorizes JavaScript API calls by cached function
source prefixes. It records 130 labels with no metadata errors or overflow,
passes the original BBC pixels, complete content and native exit, and observes
actual JavaScriptCore execution. Function string conversion, extra GC roots,
logging and process-wide counters can alter behavior and timing; this probe
earns no instruction credit. React's scheduler callback has inclusive total
8,807,093,258 and 6,137,354,555 after subtracting instrumented nested scopes;
another React callback has 1,679,173,598 after that subtraction. The import
rewriter has 35 calls and 803,233,728 diagnostic instructions. All categories
and compiled inputs remain under `js-target-*`.

An offline inventory of the 75 archived JavaScript resources finds 35 with
`import` substrings, but only six with a possible standalone word. The other
29 contain 1,419,281 bytes. Commit `309aa5f5` rejects classic-script sources
whose matches all adjoin ASCII identifier characters, such as `important` or
`importer`. Other boundaries, Unicode, comments and escapes remain conservative
lexer candidates. Module scripts retain their existing transformation path.

The nine focused compile/runtime/control checks pass across normal, no-GC and
preallocated modes, including actual dynamic imports and HTTPS/proxy loading.
Both broader modes enter all 415 cases with only the known text-control
baseline failure. The first composition attempt accidentally treated a raw
JavaScript import as a V import; the next compile exposed the current V
optional return from `index_after`. Both failures are retained. A subsequent
CLI continuation interrupted a build and the unfinished test modes, leaving
empty guard receipts and unknown exits. Those attempts are retained explicitly;
completed default-mode tests were reused and only unfinished modes rerun.

The completed production build takes 199.4478 seconds, peak sampled RSS
8,801,058,816 bytes. Its executable is
`46196ed8f47f6fdff9f8564daba9b90eca87933804f41144e07281a714b3721d`;
the preserved generated C is
`c7f879b27b7b8dfbba330a4660425b1beb19fc94585b1c34ceda91f30174ca2a`.
Headless startup, 11 smoke comparisons and eight SVG mutation comparisons pass
with exact pixels. Control tooling `9010cb3b` passes 163 browser-instruction
checks. Separate enabled/disabled BBC diagnostics preserve content, native
exits and original pixels with 1,985/1,995 JavaScriptCore evaluations. Only the
enabled run logs the successful import-scan bypass.

The following uninstrumented seven alternating triples produce the latest
results above. All 21 captures pass every content, pixel and native-exit check,
but both instruction gates fail and the median regresses against its control.
The guard adopts 66 processes without errors, peak RSS 1,352,007,680 bytes,
and completes in 109.8753 seconds with controller exit 1 for failed acceptance.
The raw prefix is `classic-import-*`. BBC remains outside the site catalog.


### Viewport, grid placement and radius longhand reuse

Commit `2ad3e906` allows the existing computed-longhand cache to accept
viewport-relative `vw`/`vh`/`vmin`/`vmax` lengths, simple grid auto-flow and
integer line/span placement, and scalar border radii. Snapshots preserve typed
values, optional names, component arrays and flags; retained-input mutations
still reject reuse. Font/container-relative and calculated inputs remain on
the ordinary path. Viewport changes invalidate the key, and restored properties
retain their viewport-dependency flags.

Nine focused compile/runtime/control jobs pass in normal, no-GC and
preallocated modes. A failed compile exposed unsupported negative smart-cast
narrowing in generated C; explicit guarded casts correct it. The next failed
check used a fresh oracle with a different viewport; matching that input
preserves the full-property oracle and verifies that resize rejects the old
entry and resolves 50vw to 320px at 640px. Both failures remain retained.
The broad checks enter 415 cases per mode, with only the known text-control
baseline failure. A CLI continuation interrupted the last 13 no-GC batches;
recovery uses the completed compile with a pinned, unchanged executable and
runs all 65 remaining cases successfully. The incomplete attempt remains.
Control tooling `e0cc71db` passes 164 browser-instruction tests.

The production build takes 182.1466 seconds, peak sampled RSS 8,928,722,944
bytes, with the feature sources stable. Its executable is
`8fbb7b69e680520603f17cce866ab30ab0beafae41a49378cc504dd7c20ca9e6`.
A post-build generated-C snapshot was unavailable; source-input hashes,
actual executable symbols and positive runtime-path traces are retained in
`longhand-shape-executable-witness/`. Headless startup, 11 smoke comparisons
and eight SVG mutation comparisons pass with exact pixels. Both BBC
diagnostics pass original pixels, content and native exits with 1,945/2,085
JavaScriptCore evaluations; only the enabled run reports a successful restore.

All 21 uninstrumented cohort observations pass content, pixel and native-exit
checks. The candidate median 37,314,150,142 regresses 3.4473% against control
36,070,672,871; the conservative control ratio is 1.1054633006230532. Brave
lower median is 15,652,929,710 and the integer gate
`391358005840 > 140292275157` fails. The guard adopts 67 processes without
errors, peak RSS 1,374,060,544 bytes, and completes in 110.1369 seconds with
controller exit 1 for failed acceptance. No BBC improvement is credited.
Evidence uses `longhand-shape-*` and the retained broad-recovery directory.

### Longhand eligibility ordering

Commit `cb190e09` checks an element's own declarations before hashing inherited
values. Rejected declarations can skip that inherited walk. Eligible own-value
hash contributions are XOR-combined after the unchanged parent hash, preserving
the previous key exactly. The control retains the prior ordering. Nine focused
jobs pass across the three memory modes, and both 415-case broader modes retain
only the existing baseline failure. The first extraction compile had an
unrenamed local count; it remains retained. Separately committed control
tooling `fae61ca7` passes 165 browser-instruction tests.

The production build takes 179.8584 seconds, peak sampled RSS 8,970,797,056
bytes, with feature sources stable. Executable SHA256 is
`2226008c70cb493c9decd4092b9dd0e695854300ba39c488c703ce91520f45d6`;
the captured generated C is
`33a528bd857f51d680cae27e816199d86b255443d03ed5e5d387feac5b203419`.
Headless startup, 11 smoke comparisons and eight SVG mutation comparisons
pass with exact pixels. Enabled/disabled BBC diagnostics preserve original
pixels, content and native exits, with 1,985/1,989 JavaScriptCore evaluations.
Only the enabled run reports rejection before inherited hashing.

The uninstrumented cohort produces the latest results above, including its
Brave trial 6 image mismatch. The guard adopts 72 processes without errors,
peak RSS 1,344,749,568 bytes, and completes in 109.6054 seconds with controller
exit 1. Every count and invalid observation remains retained. Neither the
point estimate nor conservative gate supplies improvement credit. Evidence uses
`longhand-eligibility-*`; the requested 10% advantage remains open.


### Indexed JavaScript value protections

Commit `49832905` replaces linear root scans and shifting removal with a
handle index and swap removal. Separate protections for duplicate handles
remain balanced against the actual JavaScriptCore GC API. A reverse position
updates a moved entry without scanning other protections of the same handle.
Unknown and already released handles remain harmless, and closing the owning
runtime releases every remaining protection before destroying its context.

Nine compile/runtime/control jobs pass across normal, no-GC and preallocated
modes. Focused checks cover interleaved duplicates, moved positions, actual JSC
collection and context teardown. The broad checks enter all 415 cases in each
mode and retain only the known 13.5-versus-13 text-control baseline failure.
Control tooling `31a8e9fe` passes 166 browser-instruction tests.

The production build completes in 199.2511 seconds, peak sampled RSS
8,968,568,832 bytes, with feature sources stable. Executable SHA256 is
`97018325d23294c8087a15a0cf03dfd8172178a04ab3f31ad6d8ef58a9b7f71d`;
the generated C is
`64efb7fb0370a28692cc491355b7f18aea5a0a704cc5b6a5ae160ca6f5ddaefc`.
Headless startup, all 11 smoke comparisons at their unchanged tolerances, and
eight pixel-exact SVG mutation comparisons pass. The first screenshot-wrapper
attempt lacked executable permission on its capture helper and never launched
those checks. That attempt remains retained; corrected wrappers use a new
validation directory. Enabled/disabled BBC diagnostics both preserve original
pixels, content and native exits. They confirm one JSC context and 1,932/1,991
evaluations; only the indexed run reports swap removal, 2,436 times.

The uninstrumented seven alternating triples produce the latest results above.
All observations pass content, fixed pixels and exits; both instruction gates
fail and the median regresses. The guard adopts 69 processes without errors,
peak RSS 1,357,119,488 bytes, and completes in 111.4603 seconds with controller
exit 1 for failed acceptance. Measurement scripts are pinned in a separate
15-file snapshot. Evidence uses `protected-value-index-*`. No BBC gain is
credited and the catalog remains unchanged.

### Further diagnostic attribution

Separate O2 process-counter probes and an external sampled production profile
retain their original BBC content, pixels and native exits. They cannot supply
unprofiled performance credit. Exclusive scope counts subtract only explicitly
instrumented nested scopes; background work and observer overhead remain.
The complete-workflow probe records 10,687 eligible longhand restores, 9,707
hits and 980 insertions. Disabling the whole cache is not supported by this
91% observed hit rate.

The grid probe records 16,062 successful auto-height seeds and 23,295
rejections involving an already definite item height. Of those, 14,605 reject
only on that initial predicate. Later CSS constraints were not evaluated for
these early rejections, so those counts do not establish that all rejected
items are safely reusable. No layout change is credited from this lead.

The deeper layout-workflow probe records 12 layout callbacks with inclusive
cost 10,128,412,117; viewport layout accounts for 7,466,729,355 inclusive.
There are 1,904 intrinsic-height measurements (2,173,393,130 inclusive) and
24,461 intrinsic-width measurements (17,368,746,850 inclusive, including nested
measurements). These inclusive totals overlap and must not be added.
The earlier roughly 11-billion “document update exclusive” value included
uninstrumented layout callbacks: the deeper probe attributes just 65,293,443
to that outer scope after subtracting its instrumented children. A separate
sample attributes most large copies to restoring the stationary raster, rather
than command scanning; it supplies no evidence that TLS dominates. Raw prefixes
are `macro-workflow-*`, `complete-workflow-*`, `grid-seed-*`,
`layout-workflow-*` and `current-workload-*`.

The engine-call v2 probe separates captured intrinsic identities without
converting function objects to strings or adding GC roots. Its ordinary call
intrinsic accounts for 5,969,821,954 exclusive instructions across 13,595
calls; function metadata setup accounts for just 6,072,946 across 358 calls.
That supports inspecting callback work rather than metadata initialization.
These are overlapping, instrumented process scopes, not accepted browser gains.
An initial probe crashed in headless startup because its C patch resized
unrelated array-index expressions as well as the counter arrays. No BBC launch
was attempted. The retained corrected probe restricts all three changes to
unique instrumentation statements; headless, content, original pixels and
native exit pass with balanced depth and no counter errors. Prefixes are
`engine-call-*` and `engine-call-v2-*`; production code was unaffected.


### Shared compact-element geometry accessors

Commit `ae931997` shares geometry getter/setter functions and descriptor records
across element wrappers. Each wrapper keeps its own properties and existing
flags. Native reads stay live; scroll setters check the receiver before numeric
conversion; the owner-bound `offsetParent` accessor stays separate. Nine
compile/runtime/control jobs pass in normal, no-GC and preallocated modes,
including native scrolling and mutation-version parent checks. Broad checks
enter all 830 selected cases and retain only the known text-control baseline.
Control tooling `55820e1d` passes 168 browser-instruction tests.

The first production build completes in 200.1532 seconds at peak sampled RSS
8,883,847,168 bytes. Its feature sources are stable, executable SHA256
`ef408c0f92b9fe3bf88ba7ac18290c004c931ef7e79eb2c9d149956795d6dc75`;
generated C is
`66944da1eafb295419cd9457f8a76076aaaba5e6d2bc9279d973ce2ab903343c`.
Headless, smoke and SVG checks pass. Its BBC captures, however, omit photos
with accessors enabled or disabled. All nine isolation attempts remain
recorded. Removing observation, disabling image-layout reuse, and swapping
either or both native libraries do not restore photos. The previous completed
production still matches the original PNG exactly. The generated function diff
identifies a temporary scripted-capture font-wait experiment captured during
compilation; that experiment is already absent from canonical source. Disabling
that captured experiment restores the original PNG bytes. The rejected build
supplies no performance cohort or optimization credit.

The next completed shared production already contains the accessor code and
the original scripted initial-layout branch. Its executable is
`aeffd1020b69961c0d9e906a452bbfdf76d264cc0f64a1289eafd18a94b8924c`.
It is reused without another production build. Its completed guard, source
hashes and identities are pinned in `shared-element-geometry-shared-recovery/`;
feature and initial-layout sources match before/after snapshots and current
source. That shared build reports three other changed native-test/cache inputs;
the actual executable and native-library identities are pinned independently.
Fresh headless, 11 smoke comparisons at unchanged tolerances and eight
pixel-exact SVG mutation comparisons pass. Enabled/disabled BBC diagnostics
preserve original pixels, content and native exits, with one JSC context and
1,961/2,011 evaluations. The separate probe observes shared getter identity only
in the enabled run. No interposer is loaded in the measured cohort.

The seven alternating triples produce the latest results above. Every trial
passes content, fixed pixels and exits. The median point reduction is 3.2035%;
the conservative control comparison and requested Brave gate still fail. The
guard adopts 67 processes without errors, peak RSS 1,358,364,672 bytes, and
completes in 110.0661 seconds with controller exit 1 for failed acceptance.
Prefixes are `shared-element-geometry-*`; the measured cohort is explicitly
`shared-element-geometry-v2-cohort`. BBC remains outside the catalog.


### Shared compact Node properties

Commit `ffd830ef` reuses accessor and method functions for native text, comment
and fragment wrappers. Per-wrapper metadata and the original own-property order
and flags remain. Descriptor initialization waits until the other Node bindings
exist. Receiver checks, live native reads, string conversion, Unicode edits,
fragments, cloning, adoption and equality are covered by eight focused cases.
Nine compile/runtime/control jobs pass across the three memory modes. All 830
broad cases execute with only the known text-control baseline failure. Control
tooling `dff36e9a` passes 169 browser-instruction tests.

The production build completes in 224.5673 seconds, peak sampled RSS
8,983,019,520 bytes. Feature and initial-layout sources stay stable, and the
compiled witness excludes the rejected scripted-font-wait experiment. Executable
SHA256 is
`303db5470a34705f1ae423319efab2be3e315ced5a65b57f382d91f461d1d1d3`;
generated C is
`c7059ede50e480d53440cbc32fec2f4280884108a4258c24a5f6f95d429d1ef3`.
Fresh headless startup, 11 smoke comparisons at unchanged tolerances and eight
pixel-exact SVG mutation comparisons pass. Enabled/disabled BBC diagnostics
preserve original pixels, content and native exits, confirming one JSC context
and 1,978/1,999 evaluations. The separate observer reads a diagnostic counter
without evaluating additional JavaScript: 385 shared wrapper constructions in
the enabled run, zero in the disabled run, with 1,598/1,609 valid observations.
The counter and interposer are absent from acceptance. Probe source/library
hashes are retained separately.

Every observation in the seven alternating triples passes content, fixed
pixels and native exits. The candidate median regresses 0.4307% and both gates
fail, so no BBC gain is credited. The guard adopts 66 processes without errors,
peak RSS 1,367,080,960 bytes, and completes in 112.7993 seconds with controller
exit 1 for failed acceptance. Evidence uses `shared-node-properties-*`.


### Font-refresh guard diagnostic

A separate O2 diagnostic counts rejections of the existing font-only style
refresh guard. It records just seven rejections: four for an unsafe stored
font context and three for changed inherited values. None has a stored raw
cascaded font-size prefix. Relaxing those guards is unsupported as a major
BBC optimization. Original content, pixels and native exit pass, with one JSC
context and 2,045 evaluations. Counters report through process exit, including
possible audit/teardown work; they are diagnostic counts, not acceptance costs.
The first diagnostic compile placed its helper after a caller and failed C
declaration checks. That attempt is retained; the corrected v2 declares the
helper before first use and passes. Production code is unchanged. Prefixes are
`font-guard-*` and `font-guard-v2-*`.


The following coarse CSS probe keeps ten nested process-counter scopes and
reports once at exit, avoiding per-event log output. It passes original pixels,
content and native exit, with 219,344 reads, balanced depth and zero counter
errors. Its largest selected exclusive scope is matching-rule construction:
19,940 calls and 3,288,325,303 instructions. Longhand key construction and restore
account for 549,695,997 and 446,435,895; the remaining property computation is
1,184,476,986 exclusive. Font-input refresh is 74,743,037 exclusive. These O2
instrumented counts include observer/background work and possible audit/teardown;
inclusive values overlap and cannot be added. They support investigating rule
matching rather than removing font safety guards or the whole longhand cache.
Raw prefix: `css-coarse-*`.


### Required attribute buckets before tag buckets

The sampled matching diagnostic records 2,458,037 selector checks, but sorting
only 52,782 matched rules: 79,768 sorts, maximum size ten and 31,361 comparisons.
Its 583,644 hardware reads add substantial overhead. Partial sampled intervals
are not full function costs and receive no optimization credit. A second probe
uses event counts without per-match hardware reads. Its 2,461,469 checks show
cosmetic-filter selectors such as `div[id^="…"]` reaching every `div`. Both
probes preserve the original pixels, content and native exits, with one JSC
context and 1,985/2,019 evaluations. Evidence prefixes are `css-matching-*` and
`css-selector-events-*`.

Commit `2a9d410e` prefers a required unprefixed attribute bucket over a tag
bucket, retaining the class/ID choices and namespace-dependent fallback. Full
selector matching still checks values, tags, namespaces and pseudo-elements.
Fourteen focused cases across six files pass in nine compile/runtime/control
jobs in normal, no-GC and preallocated modes. The first run retained an error
in the new pseudo-element test oracle; the corrected oracle also checks the
queried pseudo target. All 830 broad cases execute, with only the unchanged
13.5-versus-13 text-control baseline failure. Tooling commit `d66a1d56` passes
37 BBC driver tests.

Production build exit is zero, duration 197.0384 seconds and peak sampled RSS
9,047,392,256 bytes. Feature sources remain stable. Executable SHA256 is
`d52e041b57a4f08b9674ae33f49222587155e6c61a759f8ca1b56e9b43b76395`;
generated C is
`22e3ba5150c648cb5dc670406f4ab9f1940ee2c02cbaacb69c4b38883f4245cc`.
Fresh headless startup, eleven smoke comparisons at unchanged tolerances and
eight exact SVG mutation comparisons pass. Separate BBC diagnostics preserve
original pixels, content and native exits, with one JSC context and 2,032/2,031
evaluations. The enabled diagnostic logs 6,976 attribute-first rule placements;
the disabled control logs zero. These logs are absent from acceptance.

Every trial in seven alternating control/Vox/Brave triples passes the content,
pixel and native-exit checks. Vox/control medians are 36,673,262,472 and
37,003,319,838, a 0.8920% observed reduction. The conservative control ratio
1.080487412955897 fails. Brave lower median is 16,116,361,443 and the target
gate also fails: `381236402140 > 143008957638`. The guard adopts 67 processes
without errors, peaks at 1,387,708,416 bytes and completes in 113.5228 seconds;
controller exit 1 records failed acceptance. No BBC improvement is credited.
Evidence prefix: `attribute-tag-buckets-*`.

A subsequent event-only diagnostic records 10,140 recomputations caused by a
full style update, 3,216 directly dirty elements, 1,178 successful font-input
refreshes and eight guard fallbacks. Counters are cumulative snapshots and must
not be summed across log lines. Original pixels/content/native exit pass. This
supports tracing the transitions into full style updates before changing font
safety or stylesheet invalidation. Prefix: `style-causes-*`.

A follow-up false-to-true transition trace of full-style invalidation used the
same candidate's generated source in a separate O2 diagnostic executable. The
archived BBC capture retained exact original pixels, its semantic audit passed,
the native process exited zero, and JavaScriptCore recorded one context and
2,023 evaluations. Sixteen balanced style callbacks included four full updates
on the active document. The traced transitions identify the initial document
font policy, a CSSOM insertion, replacement of the adblock user stylesheet, and
a CSSOM deletion. The preload discovery document was marked dirty but did not
enter these style callbacks. This narrows the next investigation to stylesheet
change invalidation; it does not establish redundant or removable work, and
receives no unprofiled instruction credit. Raw stacks, generated-source and
build identities, guard receipts, and the fixed-reference comparison are in
`full-pass-trace-probe-build/` and
`full-pass-trace-diagnostic-validation.json` under the evidence root.

## Ordinary inline style-rule deletion (cohort 29)

Commit `682d53b9` projects an ordinary inline rule's selector invalidation before
CSSOM removal clears its parent stylesheet and namespace context. It rebuilds
the owning rule cache and marks the projected subjects, preserving broad paths
for constructed sheets, other owners, nested/global rules and unbounded
selectors. Independent media-match changes retain pre-deletion shadow effects
when falling back. Tooling commit `9502e54c` selects the old path with
`--control-disable-deleted-style-rule-invalidation` in the same binary.

The corrected focused selection passes 55 cases in four files, in default,
no-GC and preallocated modes, with both enabled and disabled paths: all nine
compile/runtime jobs exit zero. It exercises inheritance, generated pseudos,
namespaces, CSSOM errors, host/slot inheritance and media-change fallback.
The initial test helper's compile failure and the earlier focused success before
the media fallback review are retained. An obsolete production compilation was
explicitly stopped during that correction: guard exit 125, shell exit -15,
79.534449 seconds. It supplies no browser validation.

The corrected production build exits zero in 193.029545042 seconds, sampled
peak 9,020,604,416 bytes. Its executable SHA256 is
`9b8757b08c36857d0515dd1bf78c07bbdef68bcd3f31bfa853e571f31f0f1cf8`;
generated C is `80f2eb62651673b3b4d259722c7e627009530b8c95bc8a5096f21722480786ea`.
The three owned sources remain stable through compilation. Fresh headless
startup, eleven screenshot smoke cases with their unchanged tolerances, and
eight exact SVG mutation checks pass. The first screenshot wrapper attempts
failed before browser launch because the copied capture script lacked execute
permission; those exits are retained, and only the failed checks were rerun
after correcting the script mode.

Separate archived BBC diagnostics match the original document pixels exactly,
pass content/native exits and record one JavaScriptCore context with 1,965
candidate and 2,029 control evaluations. Thirteen candidate deletions take the
new path, versus zero control traces. They include broad reset selectors as
well as consent-overlay rules; eligibility alone does not establish savings.
All fourteen Vox captures in the cohort match the original reference. Brave
pair 7 differs in a photo region by 304,064 pixels (maximum channel error 18);
all other captures match. Every raw result is retained. The candidate/control
medians regress as reported above, so no broad-suite cadence credit or reset
is taken. The memory guard adopts 70 processes without adoption error, records
1,403,207,680 peak sampled bytes over 114.093986 seconds, and returns the
benchmark's failing exit 1. Browser kernel exits are all zero.

Receipts are `deleted-style-rule-cohort/`,
`deleted-style-rule-cohort-derived.json`, `deleted-style-rule-checks*/`,
`deleted-style-rule-build*/`, `deleted-style-rule-compiled-witness-v2/`,
`deleted-style-rule-validation/` and the enabled/disabled diagnostic validations
under the retained evidence root. This attempt adds no BBC catalog entry.

## Plain user stylesheet replacement (cohort 30)

Commit `ac71982f` projects both old and new subjects when replacing plain user
style rules. It preserves document-wide invalidation for global registrations,
nested rules, unbounded selector plans and pending full updates. Shadow roots
retain full subtree updates, including assigned-node inheritance. The parsed
replacement is retained for the ensuing rule-cache rebuild. The initial focused
run exposed stale inherited shadow-slot color; its failure is retained, and the
corrected focused selection passes 16 cases in three files, in default, no-GC
and preallocated modes with both paths: nine compile/runtime jobs exit zero.
Tooling commit `6cbe2dce` adds the isolated
`--control-disable-targeted-user-style-changes` switch; all 39 driver tests pass.

Production build exit zero: 196.156516458 seconds, sampled peak 8,992,915,456
bytes, owned source inputs unchanged. The executable is
`f246dcfdaee0b27a5d41ee380323d0021eb411a07a0a43b5d030dc88f0530f1c`;
generated C is `5a3ba293b3bdcdfdcc5cdfd9a7915619180ccd67925770d2779ef543389c4a1a`.
Fresh headless startup, eleven screenshot smoke comparisons with unchanged
bounds and eight exact SVG mutation comparisons pass. Separate BBC diagnostics
execute the new path once, retain exact original pixels/content/native exits,
and record one JavaScriptCore context with 1,979 candidate and 1,929 control
evaluations. Cumulative style-cause snapshots show 7,592 full-pass computations
and 5,693 directly dirty computations for the candidate, versus 10,140 and
3,216 for the control. Thus moving work out of a full pass mostly moves it into
coarse subject invalidation; it does not demonstrate meaningful saved work.

All seven triples pass the fixed references, semantic audits and native exits.
The raw medians, failing integer gate and control regression appear above; no
observation is omitted or retried. The guard adopts 69 processes without error,
records 1,406,107,648 peak sampled bytes over 110.135043792 seconds, and returns
the benchmark's expected failing exit 1. No positive marginal median, broad
cadence reset or catalog entry is claimed. Receipts are
`user-style-change-cohort/`, `user-style-change-cohort-derived.json`,
`user-style-change-build/`, `user-style-change-compiled-witness/`,
`user-style-change-validation/`, `user-style-change-checks*/` and the two
`user-style-change*-diagnostic-validation.json` files under the evidence root.


## Necessary static user-style subjects (cohort 31)

Commit `459d7c47` combines the required static ID, class, tag and attribute
predicates in each rightmost selector compound when invalidating plain user
stylesheet replacements. Dynamic predicates and combinators are omitted to keep
a conservative superset. Unprojectable subjects retain the existing fallback;
shadow trees retain their complete updates. Namespace, quirks and attribute
case semantics use the existing selector matcher. Tooling commit `7f25594a`
adds `--control-disable-static-user-style-filter`; all 40 driver tests pass.
The focused selection passes 48 cases in four files, default, no-GC and
preallocated modes, with candidate and control paths: all nine jobs exit zero.
Initial compilation failures are retained.

The production build exits zero in 190.724934625 seconds, sampled peak
9,121,071,104 bytes. All five owned source inputs remain stable. Executable
SHA256 is `e9f98e57e6b61c3598ca352dc1defcc3dabf440930efc510843f44643d6ed136`;
generated C is `5b85c4393d0182e0e014268ebf6e27809789280409913e8f71995f6127489096`.
Fresh headless startup, eleven smoke captures with unchanged bounds and eight
exact SVG mutation comparisons pass. Separate BBC diagnostics record 690 newly
marked, 660 rejected and 1,205 already-dirty elements. Cumulative directly dirty
style computations fall from 5,693 to 5,023; full computations remain 7,592.
Both paths match the original pixels and content, exit normally, and execute
JavaScriptCore (one context, 1,967 candidate / 1,941 control evaluations).

All seven triples pass content, fixed pixels and native exits. Candidate median
regresses 2.0841663069155247% against the control; the conservative control ratio
is 1.1037537986880996. The Brave integer gate fails as reported above. The first
cohort command had a misspelled control option and exited 2 before launching
any browser; its command, log and guard remain retained. The corrected unique
`static-user-style-filter-v2-cohort` retains every observation, including the
first control and Brave launch outliers. Its guard adopts 72 processes without
error, records 1,596,243,968 peak sampled bytes over 114.413184959 seconds,
and returns the benchmark's failing exit 1. No positive marginal credit,
broad-suite cadence reset or catalog entry is claimed.

Receipts are `static-user-style-filter-v2-cohort/`, its derived JSON,
`static-user-style-filter-checks*/`, `static-user-style-filter-build/`,
`static-user-style-filter-compiled-witness/`, `static-user-style-filter-validation/`
and the enabled/disabled diagnostic validations under the retained evidence root.


## Repeated cosmetic-filter queries (cohort 32)

Commit `6de6d161` retains successful encoded default cosmetic-filter results
under the exact URL and surveyed token sequence. The immutable bundled filter
set determines these results. Custom engines retain independent contexts;
disabled filtering still returns empty results, and procedural selectors still
execute against the live document. Each caller decodes independent arrays.
Retention is limited to 16 entries and 2 MiB of encoded keys/results; errors
are not retained, and hits do not revive an idle filtering VM. Tooling commit
`02f92973` adds `--control-disable-document-filter-memo`; all 41 driver tests pass.

Focused checks pass 33 cases in the direct-engine selection and 23 in the
worker selection, each in default, no-GC and preallocated caller modes. These
include seven cache cases exercised on both backends: 168 test executions,
all twelve compile/runtime jobs exit zero. The worker helper is compiled
separately with the required memory limit; it uses Boehm independently of the
caller's mode. The initial combined selection failed in the existing automatic
helper builder because current V rejects its `-bug-report-url` option, before
entering tests. A later worker run exposed an old release-test assumption that
cached queries always recreate a helper. Both failures remain retained; release
tests now explicitly evaluate the engine before checking a live context's
release.

The latest completed shared bundle lacked the feature flag, so it could not
validate this code. After that shared build completed, the new production build
exits zero in 190.50573975 seconds, sampled peak 9,117,220,864 bytes. All five
owned source inputs remain stable. Executable SHA256 is
`4215befae96a8b944510ab6f63af65616b6632ea5d5cfaa0967b3203bf4aa498`;
generated C is `e43d7f92a541e79c232295879af30da583ac2d1a03194637cf5ab959cf647e76`.
Fresh headless startup, eleven screenshot smoke comparisons with unchanged
bounds and eight exact SVG mutation comparisons pass. Separate BBC diagnostics
record twelve cache hits and four evaluations, versus twelve evaluations and
zero hits in the control. They preserve the original pixels and content and
normal native exits. JavaScriptCore executes one context with 2,056 candidate
and 2,150 control evaluations; these diagnostic counts earn no instruction credit.

All fourteen Vox captures match their original reference. Brave pair 1 differs
by 64,177 pixels in a photo region (maximum channel error 15); all other captures
match. Its benchmark result is exit 1 for that mismatch, while its native kernel
exit is zero. Every content audit and native exit passes. No observation is
retried or omitted. The candidate median regresses 0.0603186881863671% against
its control, so no positive marginal credit or broad-suite cadence reset is
taken. The guard adopts 67 processes without error, records 1,576,173,568 peak
sampled bytes over 111.43879375 seconds, and returns the benchmark's failing
exit 1. The requested Brave gate remains open and no catalog entry is added.

Receipts are `document-filter-memo-cohort/`, its derived JSON,
`document-filter-memo-checks*/`, `document-filter-memo-worker-checks*/`,
`document-filter-memo-worker-helpers/`, `document-filter-memo-build/`,
`document-filter-memo-compiled-witness/`, `document-filter-memo-validation/`
and both diagnostic validations under the retained evidence root.


## Retained ordinary grid geometry (cohort 33)

Commit `7d4cca37` extends the existing independent-context retention to ordinary
grids. It retains descendant geometry and the container's own used track sizes,
line names and content baselines. Restoring the container clones its rare data,
so exposed track vectors cannot mutate the retained cache or an older layout.
Subgrids keep the complete layout path, as do positioned, floating and other
unsupported descendants. Exact available space, used input dimensions,
constraints, style environment, node/style revisions, child order, text and
font dependencies still guard reuse. Tooling commit `6264069d` adds the isolated
same-binary control; all 42 driver tests pass.

Focused checks pass 17 cases in four files, with enabled and disabled retention
in default, no-GC and preallocated modes: 102 test executions and all nine jobs
exit zero. These cover track/line/baseline restoration, width and percentage
changes, content/order/span/font mutations, nesting, subgrid fallback and
ownership of exposed track vectors against a complete layout/display-list oracle.
The first harness selected a nonexistent file before compilation. A second run
passed the new grid cases, then exposed a legacy assertion that ordinary grids
must remain ineligible. That exclusion now uses subgrid; all original failures
remain retained.

The latest completed bundle lacked this path. The production build exits zero
in 214.054415458 seconds, sampled peak 9,102,753,792 bytes; all five owned source
inputs remain stable. Executable SHA256 is
`a19c6c32099b9317f45be7da69e7a78c45f19a88c39cf80898053ad726dd6067`;
generated C is `bf5bed9753d4da7d438e0d491951bc7b61da4e5c44d5df8ca8c95198761f9e26`.
Fresh headless startup, eleven smoke comparisons with unchanged bounds and
eight exact SVG mutation comparisons pass. The separate BBC diagnostics prove
that retained grid geometry executes only in the enabled path. Both captures
preserve the original pixels, complete content audits and native exit zero.
JavaScriptCore executes one context with 1,969 candidate / 2,059 control
evaluations; these diagnostic counts supply no instruction credit.

All seven triples pass their content, original pixels and native-exit audits.
The median reduction is 1,042,329,988 instructions, but the candidate's high
outlier makes its conservative control and Brave gates fail. The guard adopts
72 processes without error, records 1,726,791,680 peak sampled bytes over
119.730474167 seconds, and preserves the benchmark's failing exit 1. No
observation is retried or omitted. Broad verification enters all 432 cases in both default and no-GC modes,
including all 17 focused cases. In each mode 431 pass; only the unchanged
text-control baseline fails (13.5 versus expected 13). Both compiler exits are
zero, default-all and no-GC batch 2 exit 1, and the other 86 no-GC batches exit
zero. This is not a whole-suite pass or a broad cadence reset. The requested
10% Brave advantage and catalog entry remain open.

A separate pinned O2 raster/layout diagnostic selects this investigation:
12 viewport-layout calls account for 10,000,009,046 inclusive process
instructions, while 130 chrome updates account for only 96,573,935. Its exact
BBC capture and balanced scope stack pass. These process counters include
background work, instrumentation overhead and only subtract instrumented child
scopes; its timing and callback schedule differ from acceptance. It supplies no
optimization credit. Generated compiler sources were losslessly compressed:
36 files, 2,011,239,345 decoded bytes become 331,393,405 gzip bytes. Each decoded
hash was verified before removing its uncompressed copy; original receipts and
logical source identities remain intact.

Receipts are `retained-grid-layout-cohort/`, its derived JSON,
`retained-grid-layout-checks*/`, `retained-grid-layout-build/`,
`retained-grid-layout-compiled-witness/`, `retained-grid-layout-validation/`,
`broad-retained-grid-layout/`, both grid diagnostic validations,
`raster-layout-workflow-assessment.json` and
`generated-source-compression-v2-receipt.json` under the retained evidence root.


The subsequent pinned O2 frame-preparation diagnostic also keeps the original
BBC pixels, complete content and native exit zero. Its final 9,004 reads have
balanced nesting and zero diagnostic errors. Resource/script polling accounts
for 12,670,409,011 inclusive process instructions, viewport layout for
7,492,160,478 and style updates for 5,814,436,057. These overlapping scopes are
not additive. Fresh sampled stacks on the uninstrumented grid candidate still
show significant grid/inline layout and selected-font completion work. Sample
weights measure time, not instructions; neither diagnostic supplies performance
credit. See `frame-preparation-workflow-assessment.json` and
`post-grid-workload-profile-validation.json`.

A second lossless storage receipt preserves 66 completed focused-test binaries:
989,780,992 original bytes become 383,131,212 gzip bytes. Every decoded SHA256
was checked before unlinking the executable, and the receipt retains its mode,
mtime and restorable path. Active browser bundles and the current focused-test
binaries remain executable. See `completed-check-binary-compression-receipt.json`.


## Dense intrinsic-seed visitation (cohort 34)

Commit `edb5330e` replaces per-probe hash visitation with an epoch-stamped dense
vector scoped to one formatting pass. Each probe still copies current source
geometry, including hoisted external containing blocks. It does not cache used
geometry or remove the existing prefix-chain seeding. Valid physical ownership
and the complete tree-order identity guard index use. Mutated/reindexed trees,
foreign containing blocks and absent/closed pools use the original general
walk; epoch wrap clears the vector before restarting. The shared pool exposes
this pass-owned storage to nested probes without placing it in their shorter
scratch arenas. Tooling commit `a4d39e29` adds an isolated disabled control;
all 43 driver tests pass.

Focused checks pass 21 cases in seven files, in default, no-GC and preallocated
modes, with enabled and disabled paths: 126 test executions and nine zero exits.
Four new cases compare hoisted chains and fresh source geometry, wraparound,
nested measurements and mutated/reindexed/closed fallbacks with the original
hash walk. Existing external-percentage, pooled-probe and native workspace
ownership cases retain their original assertions.

The available bundle initially lacked the flag while another production build
was running, so no duplicate build was queued. That shared build contains all
five unchanged owned sources and a positive generated-C witness. Its compiler
and guard exit zero in 212.44877970800002 seconds, sampled peak 9,127,231,488
bytes. Other shared sources changed; both matched paths use the same pinned
completed bundle, and only the visitation flag differs. Executable SHA256 is
`d1851e59fab75fb0798cc7fdbc340f12bd0a6613c0e7e630e200284998d634f8`;
generated C is `1dc41be7bcd034bcce8af38d19803c80abbf5983e949d6a45bee616bbe17bd9b`.
Fresh headless startup, eleven smoke comparisons with unchanged bounds and
eight exact SVG mutation comparisons pass. The separate BBC diagnostic proves
visitation storage executes only in the enabled path. Both paths preserve the
original pixels, content and native exit zero. JavaScriptCore executes one
context with 1,925 candidate / 2,059 control evaluations; these diagnostics
supply no instruction credit.

All seven triples match their original references, complete content and native
exit audits. The median point reduction against control is 1,197,124,021
instructions, but both conservative gates fail. Every outlier and attempt is
retained. The guard adopts 68 processes without error, records 1,745,453,056
peak sampled bytes over 112.319832208 seconds, and returns benchmark exit 1.
Broad verification enters all 446 cases in both default and no-GC modes; each
has 445 passes and only the unchanged text-control baseline failure, 13.5
versus expected 13. Both compilers exit zero; default-all and no-GC batch 2
exit 1, all other 89 no-GC batches exit zero. This is not a whole-suite pass
or broad cadence reset. The requested Brave advantage and catalog entry
remain open.

The evidence also retains two subsequent lossless storage receipts. Old completed
app executable copies share 66 verified gzip objects: 238 original paths,
4,952,094,384 logical bytes, 637,799,621 unique compressed bytes. Their modes,
mtimes and restorable paths remain recorded; active/current bundles stay
executable. A second completed-cache pass replaces 23,496 payloads with links
to verified immutable SHA256-addressed bytes, retaining the original metadata.
It covers 1,431,116,333 logical bytes and keeps fresh private caches for each
new trial. No live cache, measurement result, PNG or fixture is modified.

Receipts are `intrinsic-seed-visits-cohort/`, its derived JSON,
`intrinsic-seed-visits-checks/`, `intrinsic-seed-visits-reused-build.json`,
`intrinsic-seed-visits-compiled-witness/`, `intrinsic-seed-visits-validation/`,
both diagnostic validations, `retained-app-executable-compression-receipt.json`
and `retained-cache-payload-sharing-v2-receipt.json` under the evidence root.


## Separate verbose font tracing from counters (cohort 35)

`27a5887e` makes the three retained-layout font-generation traces explicitly
opt-in through `VOX_RETAINED_FONT_DIAGNOSTICS`. Instruction counting previously
enabled these per-hit messages: one retained seed-visitation trial emitted
7,067 log lines, including 3,701 block, 2,211 inline and 670 text font traces.
The existing cumulative phase-counter records and encoded-PNG endpoints remain
unchanged. This corrects measurement overhead and earns no engine credit.
`6d8905d0` makes the driver retain trace counts and reject verbose font logging
in acceptance trials; explicit reference diagnostics remain permitted.

All 26 focused cases pass with counting-only and explicit verbose environments
in default, no-GC and preallocated modes: 156 test executions, nine jobs exiting
zero. Counting-only runs emit zero font traces; each verbose mode emits four.
All 47 driver tests pass, including missing-log and verbose-log rejection.

The first completed bundles could not validate this correction: one lacked
its executable flag, another failed startup after a shared favicon asset was
removed. Both busy production-build attempts returned without queuing work.
The next completed shared build was reused and privately pinned, with all four
owned sources unchanged before/after/current. Its compiler and guard exit zero
in 191.280623709 seconds, sampled peak 9,130,622,976 bytes. Only an unrelated
tool source changed. Executable SHA256 is
`a3090be3949360c1c114f55d511bb4ce4cb61691459449d2d32c595c0c65a6c7`;
the captured generated-C witness is
`a51a376f28e537f9319dee77988756e014c9a4db076c94e476ca9f93be6320b5`.
Fresh headless startup, eleven smoke and eight SVG mutation comparisons pass.
Both BBC diagnostics preserve the original pixels/content and native exit zero.
JavaScriptCore executes one context with 1,973 candidate / 1,983 control
evaluations. The dense seed-visitation path executes only in the enabled
separate diagnostic; diagnostic logging supplies no instruction credit.

The seven-triple cohort keeps the same original references, fixture, script
policy, private caches, viewport, settlement and launch-to-encoded-PNG scope.
Every Vox/control capture has zero verbose font traces and exact pixels.
Brave pair 3 has 64,177 differing pixels (2.0401%), maximum channel error 15,
within bounds `32,882 472x266`; its content and native exit still pass. Its
failed pixel audit invalidates acceptance. No sample is retried or excluded,
and no reference or tolerance changes. The gate also fails independently of
that mismatch. The median point difference against control is 3.893728157830645%,
but the conservative control gate fails and no accepted savings are claimed.

The guard adopts 68 processes without error, observes 1,733,935,104 peak bytes
over 168.53881404199998 seconds, and returns benchmark exit 1. Original
counter-enabled historical results remain retained with their logging caveat.
This correction changes no geometry and does not reset the broad-check cadence;
the unchanged text-control baseline failure remains open.

Receipts are `quiet-font-counter-cohort/`, its derived JSON, the two diagnostic
validations, `quiet-font-counter-reused-build.json`,
`quiet-font-counter-current-shared-build-witness/`,
`quiet-font-counter-validation/` and `quiet-font-counter-checks/` under the
evidence root. Additional lossless storage receipts retain completed check
binaries, generated C, broad binaries and completed cache payloads. Raw vectors,
medians and gates for all 35 cohorts and 721 complete cohort results were
independently checked; all 861 attempts remain in the durable evidence.


## Rejected retained font-validation memoization (cohort 36)

`78e878dc` attempted to remember a successful retained-layout font comparison
for the current FontComputer generation. It left the original cascade/metric
snapshots immutable and kept the complete style/tree/space validation before
reuse. Face, font-cache, display-period and policy changes advance that
generation and require a new comparison. `43a41bc1` added the same-binary
`VOX_DISABLE_RETAINED_FONT_VALIDATION` control, isolated to control trials.
All 29 focused cases pass in default, no-GC and preallocated modes, enabled
and disabled: 174 executions and nine jobs exiting zero. The positive reuse
trace appears only in enabled runs. All 48 driver tests pass.

The first reused bundle, executable
`af46b81773fa96d7c20c06cbd943c32fcca71effd03ec033cdc1b21d2d14b3dc`,
passes headless startup and all nineteen native pixel checks, but both BBC
diagnostics produce image `9dfe7a0f774032b53f1aa9d4d795cc75f9945874a9ead5386b1221ff4c78bff8`.
That is the previously rejected scripted-font-wait image: 781,504 differing
pixels (24.8433%), maximum channel error 246. Both content/native audits pass,
but original pixels fail. The enabled/control images are identical and the
new path executes only when enabled. This bundle contains the capture-font-wait
switch absent from current source; no instruction cohort is collected from it.
A subsequent shared bundle also contains that switch and is declined before
launch. Both failed BBC diagnostics and the rejected build assessment remain
retained. No reference is changed.

The next completed shared production build is reused with no duplicate build
queued. All six relevant owned/capture sources are unchanged before/after/current;
only an unrelated diagnostic tool changes. Its compiler and guard exit zero
in 216.01609158300002 seconds, sampled peak 9,046,474,752 bytes. Executable
SHA256 is `118396061fba409ea5b97842f8e47316c2d6962365b1953b92d94093d888a8fd`;
generated C is `afa3fd91bae4d7c6db1f8ead7a91861b4c2ccd645e2e6d08ca5862e93128dff1`.
Both exclude the rejected capture switch. Headless startup, eleven smoke and
eight SVG mutation comparisons pass. Separate BBC enabled/control diagnostics
match the original pixels/content, exit normally, and prove memoization only
in the enabled path. JavaScriptCore executes one context with 1,954 candidate /
2,005 control evaluations. These diagnostics supply no instruction credit.

All seven triples then pass every content, original-pixel, native-exit and
identity audit. Vox/control logs contain zero verbose font traces. Nevertheless,
the candidate median is 781,040,369 instructions higher than control, and both
conservative gates fail. The guard adopts 67 processes without error, observes
1,726,791,680 peak bytes over 111.007288208 seconds, and returns benchmark exit 1.
No observation is retried or excluded. Broad verification enters all 449 cases
in each memory mode: 448 pass in default and no-GC; only the unchanged
text-control baseline (13.5 versus expected 13) fails. Both compilers and all
other runtime jobs exit zero; no-GC uses 90 fresh processes. This is not a
whole-suite pass or a broad cadence reset.

Because the matched cohort demonstrates no benefit, `bbb4b0a0` reverts the
implementation and `007679b4` reverts its control option. Post-revert checks
pass all 156 focused executions across three memory modes and both logging
environments, plus all 47 driver tests. Counting-only traces remain zero;
explicit verbose runs still emit four traces per mode. No BBC catalog entry
or performance credit is added.

The separate task-source diagnostic uses the pinned candidate's generated C
at O2, with process-wide counters rather than coalition acceptance totals.
Its compiler exits zero in 143.801787875 seconds, peak 6,099,845,120 bytes.
All 19,378 counter reads balance at depth zero with zero errors; the original
pixels/content and native exit pass, and JavaScriptCore executes one context
with 2,051 evaluations. Six posted-message tasks total 8,128,576,989 inclusive /
3,969,505,357 exclusive instructions, whereas 3,607 timer tasks total
369,358,066. Event-loop processing itself has 241,484,590 exclusive
instructions. Fourteen viewport layouts total 6,354,883,920; sixteen style
updates total 5,737,953,739. These scopes overlap, include background work and
instrumentation overhead, and must not be added together. The diagnostic
includes the subsequently reverted memoization, establishes no gain, and
motivates finer script/resource attribution.

A finer diagnostic balances 48,410 counter reads at depth zero with zero
errors, preserves original pixels/content and native exit, and executes one
JavaScriptCore context with 2,022 evaluations. Its compiler exits zero in
145.365888042 seconds, peak 5,901,025,280 bytes. The 14,496 JavaScriptCore
function calls account for 6,435,657,482 exclusive instructions; the five
posted-message task bodies fall to 496,245 exclusive instructions when these
nested calls are measured. Fifteen typed paint projections cost 909,481,362.
Native script polling itself costs 10,060,129 exclusive instructions, image
polling 598,513,800, and background polling 6,399,318. This diagnostic uses the
same subsequently reverted candidate; overlapping scopes and diagnostic
process counters supply no instruction credit. Its assessment and raw scopes
are retained in `engine-workflow-detail-assessment.json`.

Receipts include `retained-font-validation-v2-cohort/`, its derived JSON,
`retained-font-validation-v2-reused-build.json`,
`retained-font-validation-v2-compiled-witness/`, both native-validation
folders, both pairs of BBC diagnostics, `retained-font-validation-checks/`,
`broad-retained-font-validation/`, `retained-font-validation-revert-checks/`
and `task-source-workflow-assessment.json` under the evidence root.


## Removed direct DOM query fields (cohort 37)

The native-callback diagnostic balances 130,864 process-counter reads with zero
errors, preserves original pixels/content and native exit, and executes one
JavaScriptCore context with 1,951 evaluations. Its compiler exits zero in
140.683889333 seconds, peak 6,033,981,440 bytes. Four full canvas-registry
snapshots cost only 31,701,775 instructions. The central element query executes
7,608 times, with 1,666,161,625 exclusive instructions. This diagnostic uses
the earlier pinned candidate with subsequently reverted font memoization;
nested process scopes include background work and observer overhead, and
provide no optimization credit.

`7cdf5fdd` attempted to replace the outer JSON envelope with three direct string
fields when no pending mutations require replay. Pending operations kept the
original JSON snapshot path; keys/actions containing the delimiter and other
value types retained the JSON path. Fourteen cases in seven files pass in
three memory modes, enabled and disabled: 84 executions and nine zero-exit
jobs. Cases cover pending replay, malformed packets, Unicode, newlines and
embedded NULs. The first compile lacked the staged UI2 adapter; that failure
remains retained, and corrected checks use the production module paths.
`0c48c698` added the isolated same-binary control; all 48 driver tests pass.

The first production compiler exits zero, but its outer wrapper exits one
when a concurrent `replaceChild` dispatch changes an owned file after C
emission. Removing precisely that unrelated line reconstructs the before-file
SHA256; generated C contains the query optimization and excludes the unrelated
dispatch. This line was also captured in the feature commit and is deliberately
preserved when removing the query optimization. The private executable is
`64a573e00badeb31f525ec156781d0f40cc6f6b48bc9dcd6850f6c055b8e21f7`,
generated C `392495233ca0f499c0f5394702d5eba6211ee039eaee5a275c1615fb8a9de09f`.
Headless startup and all nineteen native comparisons pass after a prepared
capture script's missing executable mode is corrected in a unique rerun;
no document capture started in the initial failed script invocation.

Both BBC diagnostics pass content/native exits and show direct-query execution
only when enabled, but produce the same changed photo pixels: 427,366 differing
pixels (13.5856%), maximum channel error 18. PNG SHA256 is
`263ed9abded8e95ca49e2443d13c5750717686ab96569d02594c7bcc07446a8a`.
Native libraries are identical to the prior passing bundle. Shared commit
`55a065fa` changed first completed-WebP paint selection from transport-informed
RGB to YUV. No instruction cohort is collected from the failed default-policy
captures, and references/tolerances remain unchanged.

`3a64fe9d` adds an explicit historical paint-policy control, leaving completed
YUV decoding as the production default. `4fb0c21b` records that setting in the
driver and applies it to both Vox arms. The WebP selection, retained-image and
query checks pass 39 actual executions across three memory modes and nine jobs;
the original completed-YUV-only case runs in each default mode and is explicitly
omitted from historical controls, which have their own selection checks.
All 49 driver tests pass. This compatibility setting earns no engine credit.

A single guarded production build then exits zero in 193.862369209 seconds,
peak 9,093,365,760 bytes. All eight relevant source files remain unchanged;
other changed inputs are retained in the build receipt. Private executable
SHA256 is `c5f61d7f1b4117d9ba9b8c75675b4778868bb2745e19b74048d3c638a2a10d7e`;
generated C is `1a6a66cc3a7e1bd9aa3b52e7e8ce13b8af3e276ecdf490abd06f850f643f8a95`.
Headless, eleven smoke and eight SVG comparisons pass. Both separate BBC
historical-policy diagnostics match the original pixels/content and exit
normally; direct fields execute only in the enabled arm. JavaScriptCore
executes one context with 2,000 candidate / 1,949 control evaluations. A further
same-binary disabled-query diagnostic with the default paint policy restores
the changed-photo PNG exactly, passes content/native exit, and executes 2,023
JSC evaluations. This isolates the decoder setting without changing references.

The seven historical-policy triples retain all original settlement, viewport,
script, cache, fixture and encoded-PNG boundaries. All 21 content/pixel/native
and identity checks pass; all 14 Vox logs contain zero verbose font traces.
The first Vox count is 43,187,172,109 and the first Brave lower count is
32,094,954,408; neither is excluded. Vox's median is 21,413,889 instructions
higher than control, and both conservative gates fail. The guard adopts 72
processes without errors, samples peak 1,755,987,968 bytes over 120.397922416
seconds, and returns driver exit one for failed acceptance.

`6c296864` removes the attempted optimization while preserving the concurrent
`replaceChild` routing. `d1081794` removes its control option and retains the
historical paint-policy option. Fresh post-removal checks pass all 87 actual
executions in nine files across three memory modes, plus all 48 driver tests.
The default-only WebP case retains the same explicit historical-control
exclusion. No measured reduction triggers an additional broad batch; the
prior unchanged text-control baseline failure remains, and the broad cadence
is not reset. No BBC catalog entry is added.

A separate per-action diagnostic balances 148,722 reads and 90 callback/action
labels with zero errors, preserves the original pixels/content and native exit,
and retains its JSC execution witness. Its compiler exits zero in 153.110694833
seconds, peak 6,114,934,784 bytes. Sixty-five geometry queries total
5,309,586,505 inclusive instructions, including nested style/layout work.
CSS-sheet actions cost 518,349,714 exclusive across 715 calls; document scalar
reads cost 331,807,917 across 1,115. The 2,487 first-child and 2,547 next-sibling
queries cost 256,355,464 and 163,465,028 exclusive respectively. These nested,
instrumented process scopes cannot be summed into acceptance totals or used
as gain evidence. They use the earlier font-memo candidate and establish no
benefit from the removed direct-query path.

Receipts under the evidence root include `compact-query-fields-rgb-cohort/`,
its derived JSON, both build folders and compiled witnesses, enabled/control
BBC diagnostics, `compact-query-fields-webp-policy-isolation-assessment.json`,
all focused-check folders, `native-callback-workflow-assessment.json` and
`query-action-workflow-assessment.json`. All failed harness invocations,
default-policy photo mismatches, completed cohorts and first launches remain
retained in durable evidence.


## Rejected baseline JIT thresholds (cohorts 38–39)

The per-action diagnostic left substantial script execution inside JavaScriptCore
calls. Tooling commit `1471c3257` exposes explicit baseline-JIT warmup settings
for each Vox arm, derives the corresponding soon threshold, and records both
in the input manifest. The shared environment cleaner removes ambient `JSC_`
controls; none were present in the preceding selected runs, and this correction
earns no engine credit. Isolation, failure restoration, argument bounds and
unchanged Brave environments are covered by the 50 BBC cases; all 206 focused
instruction-tool tests pass.

WebKit documents [environment option overrides and initialization timing](https://github.com/WebKit/WebKit/blob/main/Source/JavaScriptCore/runtime/OptionsList.h).
The actual installed system runtime reports baseline warmup 500, soon 100,
optimizing warmup 1,000, with baseline, DFG and FTL enabled. These trials change
only the two baseline thresholds. The global `jitPolicyScale` remains one;
no other tier threshold, script, replay byte or capture endpoint changes.

Both cohorts reuse the latest successfully completed shared production bundle,
without requesting another build. Executable SHA256 is
`2c61f78249e5405f134816e71a856c83ea3c0275734fd8d6c056726da165bdba`.
Its existing build/compiler and memory guard exit zero, the source receipt has
no changed inputs, and every copied executable/native-library hash matches.
This bundle contains the direct-query removal and the explicit historical
WebP policy. Fifteen benchmark tools are frozen separately. The reuse receipt
pins the existing build and guard receipts as well as every bundle file.

Two initial BBC diagnostics confirm settings 50/10 and 500/100 in the runtime's
option dump, original pixels/content, normal native exits and actual JSC
execution: one context with 1,948 / 1,986 evaluations. Two further diagnostic
captures enable compilation reporting and preserve the same correctness checks.
They positively observe 1,693 baseline compilations at 50/10 versus 978 at
500/100. A fifth diagnostic at 5,000/1,000 observes 497 baseline compilations,
with original pixels/content and a zero native exit. Optimizing warmup remains
1,000 throughout. Diagnostic logs and injected execution probes supply no
instruction credit.

Cohort 38 retains seven alternating triples using 50/10 against 500/100 and
Brave. All 21 native/content/pixel and identity checks pass. Vox's median is
35,976,507,921; control is 34,555,214,096; Brave's lower median is
15,918,309,134. Four of seven candidate pairs regress, and the median is
4.113109590498887% higher. Its maximum Vox count is 37,061,960,555 and minimum
Brave lower count 15,695,974,521. The integer gate fails:
`370619605550 > 141263770689`. The control ratio 1.0941184637550283 also fails.
The guard adopts 67 processes without errors, peaks at 1,751,564,288 bytes and
finishes in 112.516308708 seconds.

Cohort 39 retains seven further alternating triples using 5,000/1,000 against
500/100 and Brave, with all 21 checks passing. Vox's median is 35,194,223,202;
control is 34,763,549,223; Brave's lower median is 15,768,785,889. Four of seven
candidate pairs regress, and the median is 1.238866538733796% higher. Its
maximum Vox count is 36,499,197,690 and minimum Brave lower count
15,694,212,870. The integer gate fails:
`364991976900 > 141247915830`. The control ratio 1.0675891263283646 also fails.
The guard adopts 66 processes without errors, peaks at 1,716,240,384 bytes and
finishes in 109.682204083 seconds.

Both acceptance drivers and outer guards exit one because their instruction
gates fail; individual browsers exit normally. All 28 Vox/control cohort logs
have zero verbose font traces, no compilation logging and no injected probe.
Raw host load, timestamps, ownership and helper observations remain retained.
Neither setting becomes the production default or earns savings. No measured
reduction triggers another broad batch; the prior unchanged text-control
baseline failure remains and the broad cadence is not reset.

A separate seven-second wall-clock sample of the same pinned bundle at the
original 500/100 thresholds preserves reference pixels/content and exits
normally. Its exclusive stack accounting has no negative child sums. Main
thread samples still enter layout, style and native layer completion; copied
bytes are dominated by stationary native bitmap replay. These sampled weights
are diagnostic, and do not establish retired-instruction savings or justify
attributing earlier counts to copying alone.

Receipts include `jsc-baseline-reused-build.json`,
`jsc-baseline-frozen-tools.json`, all five threshold diagnostics,
`jsc-baseline-compilation-validation.json`,
`jsc-late-baseline-compilation-validation.json`, both cohort folders and
derived JSON files, `jsc-baseline-all-tool-checks.log` and
`jsc-default-profile-assessment.json` under the evidence root. Every attempt
remains retained. BBC is not added to the optimized-sites catalog.


## Same-pass text measurements (cohort 40)

A full formatting diagnostic records 1,971,908 process-counter reads with
balanced scopes, original pixels/content and a normal native exit. That
instrumentation substantially inflates the work being observed. A separate
1-in-128 fine-scope sample reduces the read count to 73,904, retains the same
correctness checks and observes 14,854 direct-text inline entries in temporary
measurement states, including 14,050 normal definite-width entries. These are
candidates for further eligibility checks, not a saved-instruction estimate.
Both probes use a historical O2 binary containing the subsequently reverted
font memoization; neither supplies current-master performance credit. The
initial sampled invocation rejects ambient proxies before launch and is retained.

Implementation `efa91a92b`, corrected by `874cefb41`, retains closed direct-text
line results only within the current layout pass's measurement pool. Keys
include layout mode, available space, root dimensions and definite-size flags;
text, tree, style revisions, font generation, font policy and style environment
must still match. Four entries per root bound the cache. Float, positioned,
atomic and clamped content remain ineligible. Empty results are excluded so
replay cannot consume a block margin when ordinary layout produces no line.
Owned line fragments and glyph runs survive the producing probe's scratch
arena; writable consumers detach cache-owned fragment buffers.

The final 24-case focused batch passes with the cache enabled and disabled in
normal, no-GC and preallocated modes. Earlier compiler/fixture failures and the
preallocated test-snapshot lifetime failure remain retained; their corrected
runs replace no evidence. Tooling `a6def7403` isolates the control environment
and records the switch. All 207 instruction-tool tests pass.

The first production build is deliberately stopped before publishing after
review finds the empty-text margin edge case. Its guard records child signal
15, controller exit 143, elapsed 138.057855791 seconds and peak
6,322,716,672 bytes. The corrected build and guard exit zero in
194.001846209 seconds, peak 9,137,307,648 bytes. Owned source inputs remain
stable; two unrelated native paths change during compilation and are explicitly
recorded. The saved generated C, executable and actual native-library hashes
pin the resulting binary; the comparison uses that same binary in both arms.
Executable SHA256 is
`4e6ade6f94b27fac5b2a51561742a7025a8beaa2ab699c99704785f58ace3cb3`.
Fresh headless startup and strict bundle-signature verification both pass.

Separate enabled/disabled BBC diagnostics preserve original reference pixels,
complete content and normal native exits. A positive reuse trace appears only
in the enabled run. Injected JSC witnesses report one context with 2,046 / 2,043
evaluations. The subsequent unprofiled cohort has no injected probe, reuse
logging or verbose font traces in any of its 14 Vox/control runs.

All seven retained Vox/control pairs reduce observed instructions, by
4.014534980735229%, 2.229922387406047%, 5.53704833851455%,
6.304474455899179%, 2.168213145138187%, 5.408958274401621% and
9.672050634775353%. Control median is 35,617,351,645 and candidate median
33,933,451,330: a point reduction of 1,683,900,315 (4.727752730701374%).
The highest-candidate/lowest-control ratio is 1.0341074114812472, so the
conservative control envelope does not establish a 10% reduction. All
first-launch and high-count observations remain included.

Brave's lower median is 16,118,311,870, but its final capture differs in
368,241 photo pixels (11.7061%, maximum channel error 18), within bounds
`32,882 1480x549`. Content and native exit still pass; pixel acceptance fails.
Chromium's [WebP decoder](https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/platform/image-decoders/webp/webp_image_decoder.cc)
permits YUV decoding after complete data arrives. Timing-dependent RGB/YUV
selection is consistent with the historical photo-only variation, but the
installed Brave branch was not instrumented, so that cause remains an inference.
No reference, tolerance or replay timing is changed, and the cohort is not
retried. Its raw diagnostic gate also fails:
`357554103320 > 144023674617`. The guard adopts 68 processes without errors,
peaks at 1,748,828,160 bytes and finishes in 109.832618959 seconds. Driver,
guard and controller exit one. This invalid cohort earns no Brave acceptance.

The valid matched Vox/control point reduction exceeds the 5,000,000-instruction
broad-check threshold. All 456 selected cases enter in each mode: 455 pass,
and only the unchanged text-control baseline (13.5 versus expected 13) fails.
Both compilers and all other runtime batches exit zero, with terminal guard
receipts and unchanged owned source inputs. This is no whole-suite pass or
broad cadence reset. No BBC catalog entry is added.

Receipts include `inline-measurement-build-v2/`, both compiled-witness folders,
all six focused-check attempts, both BBC diagnostics,
`inline-measurement-cohort/`, its derived JSON and raw quiet/control audits,
`inline-measurement-broad-cadence.json`, `broad-inline-measurement/`,
`broad-inline-measurement-validation.json`, both formatting-probe assessments
and the 207-test tool receipt under the evidence root. Verified lossless
compression retains generated compiler/check bytes and 286 completed private
profiles. Every archived profile member and symlink was checked before its
source directory retired; the restoration manifest and archives remain in
Build. Counters, logs, PNGs, audits, raw results, fixtures and references keep
their original paths and bytes.

## Rejected nested measurements and metric contexts (cohort 41)

The nested inline-measurement extension (`8704f76e2`, isolated tooling
`0b411196c`) passed its focused checks and preserved original BBC content,
pixels, native exits and JavaScript execution in enabled and disabled captures.
It did not emit a nested-reuse witness. A separate O0 eligibility probe counted
27,466 calls, 198 eligible entries, 198 stores, **zero hits and zero retained
geometry records**. There was no acceptance cohort for an unused path. The
extension and control were removed in `93dd6740a` and `3276aa39a`; the existing
direct-text cache remains. The initial probe-preparation failure is retained.
Removal restores the prior source exactly; 24 focused cases pass in both
control settings in all three memory modes (144 executions), and all 207
instruction-tool tests pass. Raw prefixes are `nested-inline-*`.

A separate current CSS/workflow probe uses an O2 build with 1-in-64 sampled
fine CSS scopes and exact entry counts. The final record has 63,580 counter
reads, balanced depth and zero metadata errors. Original pixels, content and
native exit pass, with one JavaScriptCore context and 2,115 evaluations. Style
updates account for 6,068,210,171 inclusive instructions, viewport layout for
6,041,144,578 inclusive, and engine callbacks for 6,612,688,206 selected-exclusive
instructions. Fine scopes observe 54,197 metric-context constructions and
12,725 property computations. These instrumented process scopes overlap,
include observer/background work, and have sampling phase bias; multiplying
recursive samples and adding them does not establish a saving. This diagnostic
contains the unused nested extension but no reverted font-validation memo.
Receipts are `current-css-workflow-*`, including the compact assessment.

The next experiment (`70baf68b9`, tooling `51a345bfd`) prepared full font,
viewport and query-container contexts only for values that consume them.
Ordinary property computation, dependency tracking, font-size, line-height,
math-depth, relative values, compound values and system colors retained their
normal paths. All 64 focused CSS cases passed with the fast path enabled and
forced off in default, no-GC and preallocated modes (384 executions); all 208
instruction-tool tests passed. Enabled and disabled production diagnostics
proved the intended path, original pixels/content/native exits, and actual
JavaScript execution. No diagnostic instruction total supplies performance
credit.

The production build completed in 238.514674417 seconds, peak sampled RSS
9,102,868,480 bytes. Source inputs were stable throughout the build. Pinned
executable SHA256 is
`61d23fed4b5fa73433e13b938b256bdbc4191bbacbda66ced4aa5af3e1742b9b`;
generated C is
`707559e6e1967f36194d4f119247611d50eebb1f42e7786af4215f4f55c58851`.
Fresh headless startup and strict deep code-signature verification pass.
Both cohort Vox arms use this exact executable; only the full-context control
differs. The historical WebP setting is identical in both, and verbose font
tracing and profiling are absent. All tool sources and native libraries are
pinned in the receipts. An incorrect control flag first failed argument
parsing with exit 2 before any browser launch; that attempt remains retained,
and the corrected command uses a distinct `v2` output directory.

All seven alternating control/Vox/Brave triples remain in
`metric-computation-context-v2-cohort/`. Vox median 34,812,815,726 exceeds
control 34,725,251,873 by 87,563,853 instructions (0.252161894520575%).
The candidate/control pair reductions are 2.7156098402680073%,
-28.339715225672023%, -0.21813721358538984%, 1.547023959861915%,
2.679772009153669%, -1.6533154693872731% and 5.250426604934566%.
The conservative candidate/control ratio is 1.2833971522567202. The second
Vox trial's 43,331,186,014 instructions and first Brave launch's
31,963,770,618 lower bound remain included. No outlier is excluded or retried.

All 14 Vox/control captures pass original pixels/content and native exits.
Brave pair 3 changes 64,177 photo pixels (2.0401%), maximum channel error 15,
within `32,882 472x266`; its native exit and content audit pass, but the
benchmark exits 1 for the pixel failure. The cohort therefore cannot establish
acceptance. It also fails the diagnostic integer gate
`433311860140 > 143635008213`, ratio 2.715080947032688.
The memory guard adopts 68 processes without error, peaks at 1,753,956,352
bytes and completes in 111.39216320899999 seconds; driver and guard exit 1.
Host snapshots, commands, ownership audits, raw counters, all images and
actual exits remain in the evidence root.

The regressing CSS implementation and its control were removed in
`2cd57a9fc` and `1a571768e`. The prior source is restored exactly; 61 focused
cases pass in all three memory modes (183 executions), along with 207 tool
tests. No new broad batch is triggered by a regressing median or an unused
nested path. The previous broad batch still passes 455/456 in each mode,
with the unchanged 13.5-versus-13 text-control failure; it does not establish
a whole-suite pass or reset. The requested 10% goal remains open.

Disk pressure required further verified lossless compression of closed
compiler sources, focused binaries, historical pinned executables, sampled
traces and 14 additional completed private profiles. Decoded SHA256 values,
file modes and every archived profile member/symlink were checked before
source retirement. Restore compressed inputs before reusing a historical
binary or source path. Full manifests and compact receipts remain under
`completed-profile-compression-v{2,3}-*` and
`standalone-artifact-compression-v{4,5,6,7,8,9}-*`. No counter, log, PNG,
audit, raw result, fixture or reference was removed or changed.

## Immutable stationary native frames (cohort 42)

Implementation `68702038d` retains an immutable native image instead of copying
unchanged document pixels into a fresh bitmap for every publication. V enables
the handoff for UI2 chrome, whose views are separate from the document bitmap.
All frame callbacks, resource processing, style/layout updates, animation
sampling, eligibility checks and publication still run. Other bitmap callers
keep the existing copy fallback. Nested captures retain separate targets and
image ownership; cache invalidation cannot free a frame already selected for
publication. Existing document/revision/generation/scroll/zoom/opacity,
transform, color, clip and dynamic-content guards remain in force.

The 11 focused main cases pass enabled and disabled in default, no-GC and
preallocated modes (66 executions, nine jobs). Native tests verify exact bytes
at both scales, retained ownership after cache disposal, nested target
isolation, invalidation and ordinary bitmap fallback. Prepared-wake tests pass
under ARC and MRC, including exact returned pixels and continued draw callbacks.
All 208 instruction-tool tests pass. A broader main attempt also retains two
failures under both snapshot policies: an initial layout width of 60 instead
of 30, and an animation endpoint width of 50 instead of 100. These remain
unresolved; narrowing the focused group does not erase either result or claim
a whole-suite pass.

The guarded production build and snapshot complete in 230.141771292 seconds,
peak sampled RSS 8,667,906,048 bytes. Owned inputs remain stable. Five unrelated
layout/native paths change during the build; their snapshots and actual linked
native-library identities are recorded. Both trial arms use exactly the same
binary, so no cross-build attribution is made. Executable SHA256 is
`edf40864f23109690ec562d97f85bea10fa465478774614ad30d83b7d7c7ae16`;
generated C is
`bbc9561fc0c81e73993e3960031c5e108a8cbd511aa12e7812b2b89d180d0f67`.
Fresh headless startup and strict deep signing checks pass. Original BBC
pixels/content/native exits pass in enabled and copy-control diagnostics, with
1,991/1,901 JavaScriptCore evaluations. The retained-image trace appears only
in the enabled diagnostic; neither diagnostic supplies instruction credit.

Tooling `926000d0c` isolates `VOX_COPY_STATIONARY_RASTER_PIXELS=1` to the
matched control, requires its pinned app and restores the environment after
errors. A preparation assertion caught an invalid control-flag replacement
before any browser launch. The corrected full command was parsed and checked
before the cohort; the failed preparation is retained. The acceptance cohort
uses a frozen driver and guard, fresh private processes/profiles, the same
historical RGB policy and original references. It contains no JSC probe,
verbose font traces or profiling.

All seven alternating control/Vox/Brave triples pass their original pixels,
full content, identities and native exits. Control median **34,484,213,827**
versus Vox **33,233,453,967** is an observed point reduction of
**1,250,759,860 instructions (3.627050528902287%)**. Pair reductions are
1.1460627405367463%, 2.5300494399239426%, -1.0689009283460615%,
4.172341907570088%, 3.185237126180396%, 8.174228168262509% and
5.397115914035522%. The regressing third pair remains included. The
conservative candidate/control ratio is 1.0179027541231616 and does not
establish a conservative saving across all trials.

Brave's lower median is **16,098,894,787**. Highest Vox upper is
34,119,989,264; lowest Brave lower is 16,005,262,553. The integer gate fails:
`341199892640 > 144047362977`, ratio **2.13179816019979**. The driver and
guard therefore exit 1 despite all captures being valid. The guard adopts
**67** processes without error, peaks at 1,765,834,752 bytes and completes in
111.51313474999999 seconds. Host snapshots retain other sessions' activity;
no first launch, failure or regression is excluded or retried.

The observed saving exceeds the 5,000,000-instruction broad-check threshold.
Both broad modes enter all 456 selected layout cases and pass 455; only the
unchanged text-control baseline of 13.5 versus 13 fails. Both compilers and
all other runtime batches exit zero; no owned input changes. No whole-suite
pass or cadence reset is claimed. Receipts are `stationary-snapshot-*` and
`broad-stationary-snapshot-*` under the evidence root, including all commands,
raw counters, original PNGs, ownership records and independently recomputed
cohort vectors. BBC still does not qualify for `OPTIMIZED_SITES.md`.


## Layout and JavaScript follow-up diagnostics

Three separate read-only diagnostics preserve original BBC pixels, full
content and native exit zero, with actual JavaScriptCore execution witnessed
(2,089, 2,466 and 2,301 evaluations). The retained-layout check reports 24,661
calls, 16,803 hits and 7,858 dirty-geometry rejections; no rejection occurs
solely because a style object was replaced. The conservative style-identity
check remains unchanged. The stabilization-count cache has 363 calls but only
six misses and 17,980 node visits. Dirty reasons include five text edits,
89 image-data updates, 76 layout-tree updates and 1,781 style changes.

JavaScript call scopes identify 115 native calling sites, including 2,982
microtask callbacks and 3,165 generic WebIDL callbacks. Scope depth returns
to zero and counter errors remain zero. These O0 process-wide diagnostic
counts include native DOM work, background work and instrumentation; only
nested measured JavaScript calls are subtracted. They do not estimate
production savings or earn instruction credit.

The diagnostics use already pinned historical preprocessed input, containing
the unused nested-inline experiment and lacking immutable native frames.
Historical temporary support objects disappeared. All 124 objects were pinned
before compiling; 120 missing objects were explicitly replaced by matching
named support objects from the recorded successful immutable-frame production
driver. This produces new diagnostic identities. Original pixels/content and
fresh startup are checked, rather than claiming historical binary identity.
The missing-object compile and a subsequent preprocessed `stderr` symbol
failure remain retained. The corrected compiler succeeds; signing initially
rejects inherited `Vox.gz` inside the app. That compressed executable is moved
outside the bundle with exact SHA verification, then signing, strict deep
verification and fresh headless startup pass. No browser trial is retried.

Receipts are `layout-and-js-diagnostic-assessment.json`,
`retained-style-eligibility-*`, `layout-dirty-reasons-*` and `js-callers-*`
under the evidence root, including pinned inputs, object substitution
provenance, commands, failures, native identities and raw observations.

## Rejected small callback argument lists (cohort 43)

Implementation `77a9d94b8` constructs zero- or one-argument callback lists
inside JavaScriptCore rather than allocating them through its C API. Private
captured `Reflect.apply` keeps primitive and undefined receivers, callable
proxies and original thrown values. Larger calls and native forwarding retain
their existing path. The 21 focused callback cases pass in default, no-GC and
preallocated modes under both policies (126 executions, nine jobs). Checks
include strict receiver identity, arity, symbols, callable proxies, original
exceptions, author-replaced intrinsics, Promise/microtask ordering, worker
ownership, closed contexts and retained roots. All 209 tool tests pass.

The latest completed bundle initially lacks this path. A requested build stops
with exit 75 at the busy shared production lock; it queues nothing and compiles
nothing. Instead the successful shared typed-payload production build is reused.
It completes in 197.516741792 seconds with peak sampled RSS 9,211,985,920 bytes;
build and guard exit zero. Its actual source-before/after receipts prove all
three owned inputs stable. Only an unrelated diagnostic test changes during
the build. Generated C is pinned with SHA256
`c28ecc3840253899c81bd991405674bf5aa1a7e16c63c0523a92c965f8cda1e4`;
executable SHA256 is
`399be67ffcf5f1e5168119fcad54f7223d60a312a8238a6dec79220f1d1977ae`.
Native dependencies and the private app are pinned. Fresh startup and strict
deep signing checks pass.

Enabled and C-API-array control diagnostics both preserve original pixels,
full content and native exits, with 1,919/1,945 JSC evaluations. Both new arity
traces appear only when enabled. Tooling `43f521a7b` isolates
`VOX_BOX_CALLBACK_ARGUMENTS=1` to the matched control, restores the environment
after exceptions and requires a pinned control app. The seven-triple command
is parsed before launching; frozen tools, historical RGB policy, reference
images and capture boundaries remain unchanged. The acceptance cohort has no
JSC probe, callback tracing, verbose font logging or profiling.

All seven alternating triples pass original content, pixels, identities and
native exits. Control median **33,629,819,108** versus candidate
**34,199,020,506** is a regression of **569,201,398 instructions
(1.6925496868479994%)**. Pair reductions are 2.5137859787264127%,
-2.8277258717257725%, -2.0745342020430435%, -3.3801720287358172%,
0.9063461068063661%, -1.8176190416307803% and 1.069560745613507%.
Four pairs regress and three improve; conservative candidate/control ratio
1.289368932965 fails. First-launch control **43,429,507,573** and candidate
**42,337,782,701** remain included. No outlier is discarded or retried.

Brave lower median is **16,131,151,077**; highest Vox upper is 42,337,782,701
and lowest Brave lower is 16,124,583,764. The integer target fails:
`423377827010 > 145121253876`, ratio **2.6256667037523163**. Driver, guard and
controller exit 1 solely for the instruction gate. The guard adopts 70
processes without error, peaks at 1,735,278,592 bytes and completes in
118.167855167 seconds. Host activity, every raw count and actual exit remain
recorded. No saving is attributed to this experiment or to unrelated native
changes in the shared bundle.

The implementation and its control are removed in `03ac1b2e6` and
`58e7049c1`; prior source is restored byte-for-byte. All 19 remaining focused
cases pass in three memory modes (57 executions, six jobs), and all 208 tool
tests pass. The rejected production binary remains historical evidence;
post-removal focused checks execute restored source. A regressing median
triggers no new broad batch. Cohort 42's broad result remains 455/456 in each
mode, retaining the 13.5-versus-13 text-control mismatch; its two broader main
layout/animation failures remain unresolved. No whole-suite pass or cadence
reset is claimed.

Receipts are `small-callback-*` and `small-callback-shared-*` under the evidence
root. The durable report now retains 1,068 attempts across 43 cohorts, with
889 complete cohort records independently compared to raw counters, medians
and integer gates. BBC still does not qualify for `OPTIMIZED_SITES.md`.


## Native bitmap API costs (diagnostics only)

Two read-only interposition runs examine the retained immutable-frame build
`edf40864f23109690ec562d97f85bea10fa465478774614ad30d83b7d7c7ae16`.
The four relevant frame/cache source files still match that build byte-for-byte.
Newer shared binaries contain the rejected callback experiment, so this pinned
completed production build examines the retained frame path. These diagnostics
do not validate newer unrelated rendering changes. Original BBC pixels,
full content and native exits pass, with 1,966/1,903 JSC evaluations and positive
immutable-frame traces. Counter errors remain zero across 20/33 caller groups.
Small 2-by-3 bitmap controls positively exercise every selected API. Caller
addresses resolve through their actual image with `dladdr`, avoiding the
injected probe's image-zero identity.

The first run observes 110 native frame-context creations at 2048-by-1704
costing 8,873,944 instructions and 23 snapshots costing 22,444,360. The second
observes 103 creations at 5,738,811 and 24 snapshots at 14,392,836. The native
frame extent includes chrome; the document PNG scope is unchanged. In the
second run, 80 stationary-cache `CGBitmapContextGetData` calls observe only
1,426,776 instructions. These process-wide inclusive intervals include
counter/probe/background work and may overlap. They cannot be summed as
exclusive cost, compared as an unprofiled speedup, or treated as achievable
savings. Their small observed size does not justify adding a context pool or
changing cache eligibility. Neither change is implemented.

All source, dylib hashes, positive-control logs, native identities, original
images, API caller offsets, commands and actual exits remain under
`native-context-*`; `native-context-diagnostic-assessment.json` records the
qualification and exact observations. Both attempts are retained, bringing
the report to 1,068 attempts; the 43-cohort/889-record checks remain unchanged.
No new acceptance claim, instruction credit or broad-check reset follows.


## Navigation startup and CSS component diagnostics

Two separate O2 diagnostics preserve original pixels, full content and native
exit 0, with JSC witnesses of 1,903 and 1,905 evaluations. The startup probe
records one resource-discovery parser pass at 264,384,378 instructions and
339,431,185 inclusive instructions for preflight. Runtime creation records
36,881,851, JavaScript value intrinsics 1,176,094, and initial state
90,232,899. These measured paths cannot explain the remaining multi-billion
instruction gap. No preflight/parser optimization was introduced.

The CSS diagnostic observes 12,471 element recomputations, 50,031 scope
pseudo-element candidate queries, 137,583 cache queries and 345,970 bucket
predicates. Its 93,520 process-counter reads finish with balanced depth and
zero errors. Most component scopes sample one in 32 entries. Short scopes
can be dominated by the counter read itself; their totals must not be scaled
into production costs or savings.

Both probes derive from pinned historical preprocessed input with the unused
nested-inline extension, without immutable native frames or rejected callback
changes. Explicitly pinned replacement support objects remain disclosed in
the provenance. These diagnostics identify executed paths and earn no
performance credit. The initial startup preparation selected an absent inlined
constructor, and a premature build command then found no builder; both
prelaunch failures are retained. Corrected preparation, compilation, strict
signing checks and fresh headless startup pass before either BBC launch.

Receipts are in startup-components-v2-assessment.json,
css-components-assessment.json and their linked commands, build identities,
source patches, object manifests, guard receipts and reference comparisons
under the evidence root.

## Rejected pseudo-element candidate batching (cohort 44)

Implementation b7b251529 collected shared originating-element buckets once
during each recomputation, retaining separate pseudo-specific bucket semantics
and rebuilding a local result after scope-cache replacement. It retained the
ordinary selector cascade and mutable rule-hint behavior. Tooling 6b9383395
isolated the disabled control through
VOX_DISABLE_BATCHED_PSEUDO_CANDIDATES=1.

The focused checks pass 120 runtime executions in 18 guarded jobs: the
16-case group and final four-case group each run both policies under default,
no-GC and preallocated ownership. They cover every bucket, rule-hint edits,
origins, layers, shadow scopes, removed/inserted rules, generated styles,
marker/backdrop admission and ancestor-filter restoration. All 209 instruction
tool tests pass. Four unsuccessful compiler/fixture setup attempts remain
retained, including the unrelated existing keyframe fixture's invalid Option
error binding, which was not executed in the selected group.

The production build and guard exit 0 in 229.893139875 seconds with sampled
peak RSS 9,669,869,568 bytes. Both implementation files remain stable; only a
temporary focused-test file changes during compilation. Generated source
ff6ce673f4326294e8e98c347c32648cb661e593492c0afb62bf529e6ed08ea5
and all 124 native support objects are pinned with the actual Clang driver.
The pinned executable is
6ee586840a15850a3f01ce7862dacddc97e55727e5745b7118496940a8bc928d.
The later shadow-fixture correction changes no production implementation.
Strict signing and fresh headless startup pass. Separate enabled/disabled BBC
diagnostics match original pixels and full content, exit normally, and show
JSC 1,903/1,904 evaluations; the batching trace appears only when enabled.

All seven alternating triples remain in batched-pseudo-cohort. Vox median is
33,363,170,629, control median 33,008,032,632, and Brave lower median
16,086,526,413. Candidate median regresses 355,137,997 instructions
(1.0759138569673699%); four pairs regress and three improve. The conservative
candidate/control ratio is 1.0401425748637796. Every Vox/control capture
preserves original pixels, content and native exit. Brave pair 2 changes
64,177 photo pixels; no reference, tolerance, retry or sample exclusion is
used to remove that failure.

The integer gate also fails: 338824066360 > 144073049490, with maximum Vox
33,882,406,636 and minimum Brave lower 16,008,116,610; ratio
2.1165767005241722. Browser identities, quiet-font policy and isolated control
environments pass. All raw host loads and timestamps remain recorded on the
18-CPU host. Driver, guard and controller exit 1. The memory guard adopts
71 process identities without errors and records peak RSS 1,761,263,616 bytes
over 109.364745791 seconds. No instrumentation runs in this cohort.

The implementation and control are removed in 0bafa2b98 and 0604abf7e.
Restored source passes 39 focused runtime executions in six guarded jobs and
208 instruction tool tests. The rejected production bundle remains pinned as
evidence; it cannot validate the restored default. No saving is attributed and
no new broad-check trigger is earned. The previous 456-case broad selection
still retains its known text-control baseline failure and no cadence reset;
the two broader main-test failures also remain unresolved.

The durable report now retains 1,093 attempts across 44 cohorts, with 910
complete cohort raw records independently checked against vectors, medians
and integer gates. The latest derived counters, validation, removals, frozen
tools, commands, PNGs, audits and actual exits remain linked from the evidence.
The requested 10% advantage remains open and BBC has no catalog entry.

## Comment-only procedural CSS (cohort 45)

A separate O2 diagnostic writes both exact incoming user stylesheets while
preserving the original fallback decisions. Initial installation is 41,454
bytes with a pending full style update; the later replacement is 41,483 bytes
and already uses targeted invalidation. Its only addition is the generated
29-byte `/* vox procedural filters */` comment and newline. Thus bypassing the
coarse whole-subtree guard would be ineligible; no such change was made.
Original pixels, full content and native exit 0 pass, with 1,927 JSC
evaluations. The initial controller created the output directory too early and
failed before launching a browser; that failure and the unique corrected run
remain retained.

Implementation `11052f29e` omits only that exact empty generated CSS payload
when installing adblock styles. The original nonempty apply result still
triggers live DOM mutation replay. Real procedural rules, removal of previous
rules, primed computed-style queries and user-origin precedence remain covered.
The focused selection passes 66 executions across three memory modes and both
policies in nine guarded jobs. Initial compilation rejected Option propagation
in two new and three existing property assertions; explicit `or` branches fix
those tests. The initial source, log and guard remain retained. Tooling
`79603208a` isolates the comment-preserving same-binary control; all 209
instruction-tool tests pass.

The local build attempt exits 75 on the busy production guard and queues no
duplicate. Instead, the completed shared production build is reused: build and
guard exit 0 in 227.123863959 seconds, sampled peak RSS 9,611,558,912 bytes.
All four owned source files match the shared before/after records and focused
inputs; only two unrelated test/tool files change. Actual Clang input
`824bb4273c59e11b342e80a2f5b787b1c644dc6ae62c290ce1d4912597b10ebb`
and 127 support inputs are pinned. The executable is
`49655c6888e2a864d33666a55ed8b4afddd7a1b183a2b6dd3cdac81e4323a53b`;
rejected pseudo-element batching is absent. Strict signing and fresh headless
startup pass. Enabled/disabled BBC diagnostics preserve original pixels,
content and native exit, with JSC 1,925/1,915 evaluations and the omission
trace only when enabled.

All seven alternating triples in `empty-procedural-style-cohort` pass original
per-engine pixels, full content, file identities and native exit. Capture-time
Vox ownership was not verified by that earlier protocol. Vox
median is 32,872,445,783, control 33,698,209,308, and Brave lower median
16,080,434,504. The median point reduction against control is 825,763,525
instructions (2.4504670780947535%); four pairs improve and three regress.
Conservative candidate/control ratio 1.0370097880414366 fails. Control pair 2's
43,678,988,616-instruction outlier remains included. No observation is retried,
excluded or used to change a reference.

The Brave gate fails `340057296670 > 143659414512`, with maximum Vox
34,005,729,667 and minimum Brave lower 15,962,157,168; ratio
2.1303968698649767. Driver, guard and controller exit 1 for the unmet gate.
The guard adopts 73 process identities without errors, sampled peak RSS
1,762,607,104 bytes over 112.643410458 seconds. No diagnostic instrumentation
runs in this cohort. On the 18-CPU host, load averages are
4.1474609375/4.00048828125/3.73681640625 before and
3.16064453125/3.8037109375/3.71484375 after. A foreign module-worker compile
and Pikabu capture overlap early trials. Their contention, the outlier and
three regressions limit causal attribution; this point result establishes no
robust speedup. The proven unnecessary stylesheet replacement is removed,
without claiming a guaranteed instruction reduction.

The required broad check enters all 456 selected layout cases in each memory
mode: 455 pass per mode. Only the retained text-control baseline assertion
(13.5 versus 13) fails in default-all and none-2. Every job has a terminal guard
receipt and owned inputs stay unchanged. This is no whole-suite pass or broad
cadence reset; the two previously unresolved broader main-test failures also
remain open.

The durable report retains 1,117 attempts across 45 cohorts; 931 complete
cohort raw records are independently checked against vectors, medians and
integer gates. Source dumps, hashes, the initial failures, build reuse proof,
frozen tools, diagnostics, commands, counters, PNGs, host conditions and actual
exits remain linked from the evidence. This remains the historical RGB frozen
workload, with no current-default or live-site acceptance. The requested 10%
advantage stays open and BBC has no catalog entry.

A subsequent sampled launch also preserves original pixels, content and native
exit 0; the sampler exits 0. Its stacks mostly cover idle waits, capture audit
and teardown, so they supply no startup or text-layout CPU attribution. The
prior O2 JavaScript-target diagnostic records 35 document `querySelectorAll`
calls at 81,233,149 process instructions and six `querySelector` calls at
387,413. These observations justify no new cache or instruction credit. No
additional engine change follows. This retained attempt brings the total to
1,118, with the 45-cohort/931-raw-record checks unchanged. See
`post-empty-procedural-profile-assessment.json` and linked raw sample,
commands, identities and guard receipts under the evidence root.

## Measurement protocol audit and correction (cohort 46)

The November 2 audit checks the eight requirements in
[the catalog procedure](../OPTIMIZED_SITES.md#how-to-benchmark-against-brave).
For cohort 45 it independently rehashes all 1,646 pinned files, recomputes the
launch boundaries and integer gate, and reruns all 21 comparisons against the
original per-engine pixel references. Those checks pass; no startup subtraction
or PNG-boundary correction is needed. The native capture function is recovered
from source matching the measured build snapshot: encoding precedes the
coalition marker, and PNG file writing plus the content audit follow it. Its
body is unchanged in current source.

The audit does find an ownership gap. Vox's recorded live scan occurred early,
with fewer tasks than the later native PNG marker. Aggregate coalition counts
include the later helpers and exited work, but the old live scan does not
attest the live task set at capture. Older cohorts retain their exact raw
results and original validation; their endpoint ownership remains unverified.
They cannot satisfy the new ownership gate.

Tooling `46b21a390` samples live ownership while awaiting Vox's native exit and
requires a stable owned task set with the same coalition, task-start and
task-exit totals as the PNG marker. Monotonic totals then exclude task churn
between that scan and the endpoint. New helper PIDs enter the same private
memory-guard registry. Partial scans interrupted by native exit remain logged;
acceptance still requires a complete matching scan. All 217 instruction-tool
tests pass, including rejection of an early scan, unowned tasks, identity or
task-count churn, missing proof, and unknown exit status. The counter backend,
launch scope, PNG endpoint and integer gate are unchanged. This is a protocol
correction with no engine optimization credit.

To isolate that correction, cohort 46 reuses cohort 45's exact completed Vox
and Brave copies, original fixture and fixed references. No production build
is queued. A separate diagnostic passes original pixels, full content and
native exit 0, with JSC 2,031 evaluations and capture-time ownership verified.
The seven alternating triples retain every attempt. All 14 Vox/control
captures pass their original reference, full content, native exit and the new
ownership check. Brave's seven post-capture ownership checks, full-content
audits and native exits pass. Brave pairs 1 and 4 each differ at 64,177 photo
pixels, maximum channel error 15, so acceptance fails without retries,
exclusions, reference changes or relaxed tolerances.

Vox median is 32,561,838,795 instructions, its comment-preserving control
32,744,163,610, and Brave lower median 16,174,399,220. The separate matched-control
point difference is 182,324,815 (0.5568162227980067%); five pairs improve and two
regress, with conservative ratio 1.0199245717551637. No speedup is attributed to
the protocol change. The Brave integer gate also fails:
`328013511490 > 143989597287`, using maximum Vox 32,801,351,149 and minimum
Brave lower 15,998,844,143; conservative ratio 2.050232557790847.

Driver, guard and controller exit 1. The default 12 GiB guard adopts 70
identities, including every browser root, with no adoption error; sampled peak
RSS is 1,763,770,368 bytes over 110.468905166 seconds. Every raw command, browser
exit, host CPU/load/timestamp record and failure is retained. A second
independent check rehashes all 1,646 inputs, recomputes all 21 content audits and
verifies the 14 Vox and seven Brave ownership proofs. Both Brave endpoint brackets
also match the final owned task totals in every trial. The base 45 cohorts are
also rechecked against their raw vectors, medians and integer gates: the combined
evidence now retains 1,140 attempts across 46 cohorts and verifies 952 complete
cohort raw records.

The [protocol supplement](benchmark-results/bbc-protocol-audit-2026-11-02.json)
contains the new exact counts, endpoint proofs, input hashes, raw-artifact hashes,
commands, guard and diagnostic receipts, and the unchanged base-report hash.
Raw evidence remains under `Build/bbc-home-instructions-20261101-054807/`.
Completed test executables and generated C are losslessly compressed only after
the cohort; logical hashes, original modes and round-trip checks remain in the
storage receipt. No active benchmark inputs, logs, PNGs or fixture bytes change.

This remains the explicitly declared historical RGB frozen workload. The
77.8428% cross-browser pixel difference, BBC scripting limitations, retained OS
caches, excluded GPU execution/outside services, sampled memory limits and lack
of retrospective individual exited-task identities remain disclosed. The
protocol correction establishes no current-default or live-site acceptance.
BBC still fails the requested 10% advantage and has no catalog entry.


## Selector-only font registration retention (cohorts 47–48)

Commit `884d6def7` avoids a full font registration/order rescan after inserting
or deleting an inline stylesheet rule whose tree contains only style rules,
`@media` and `@supports`. Font/global rules, imports, constructed sheets and
other owners retain the full path. Existing media-condition transitions still
synchronize fonts before invalidation returns. `4ea5517da` isolates the matched
control through `VOX_RETAIN_SELECTOR_RULE_FONT_SYNC=1`.

All 54 focused cases pass with the candidate enabled and forced off in default,
no-GC and preallocated modes: 324 case executions and nine zero-exit jobs.
All 218 instruction-tool tests pass. The first shared completed build,
executable `50c6deda76b7ebab467936e992de3a4872af557faf3c0256e69f6114debcc68b`,
passes eleven smoke and eight SVG mutation comparisons without changed bounds.
Its generated C is `73f2e5d2841978ebb1a6a65066c29621444c43edc32914db36d5f2512867805b`.
The build and startup guard exit zero, with 9,716,989,952 peak sampled bytes over
271.54104075000004 seconds. A manual build request coalesces with that existing
post-commit build and returns busy; no separate production build runs.

Cohort 48 reuses the next completed production executable,
`e9b1cdeb2197ef69aacf701bb0e12149aecfabed3f2c68cb675d34631c3f681e`.
Separate candidate/control BBC diagnostics match original pixels and full
content, pass ownership and native exits, and execute one JavaScriptCore context
with 1,896 / 1,905 evaluations. The fast-path witness appears only when enabled.
Earlier diagnostics on the first build record 1,932 / 1,930 evaluations. These
instrumented diagnostics receive no instruction credit.

The independent cohort-48 audit rehashes all **1,638** pinned files, recomputes
all 21 semantic audits, repeats all 21 unchanged PNG comparisons, verifies
14 Vox endpoint ownership proofs and seven Brave endpoint ownership brackets,
and checks every browser root's memory-guard adoption. Browser version reports
Chrome/156.0.8078.48 and V8 15.6.75.19. All native exits are zero; driver, guard
and controller exit 1 for the failed performance gate. The guard adopts 69
process identities, reports no adoption error and peaks at 1,502,691,328 bytes
over 115.252708625 seconds under the unchanged 12 GiB budget. Per-trial host
loads and timestamps remain in the raw records. Historical WebP/RGB policy,
OS caches, original scripts, fallback-font limitations and all endpoints are
unchanged.

The positive median point difference triggers broad verification. Both modes
enter all 456 selected layout cases: 455 pass in each; the existing text-control
baseline remains 13.5 versus expected 13. All compilers and supervisors complete,
owned feature sources stay unchanged, and no whole-suite pass or cadence reset
is claimed. Earlier main-suite baseline failures remain unresolved.

Preparations that failed before browser launch are retained separately: an
obsolete private Brave path, a capture-script permission error, missing copied
tools/bundles, an initial metadata/signature check, and input-verification setup
errors. They are not successful trials. The six early native sampling captures
also remain diagnostic only: three have empty call graphs, one never enters its
hook, and the first successful attach largely misses initial work. The final
sample includes the pre-navigation hold and actual load stacks; it guides the
font-rescan investigation without supplying instruction credit.

Temporary deletion protection kept cohort 48's inputs present. Vox and tool
flags clear after the run. macOS refuses to clear the owner immutable flag from
the private copied Brave bundle after launch; this copy still needs administrator
cleanup. The installed comparison browser is unchanged. The exact path, failed
cleanup receipts and remaining flags are recorded in the supplement. Future
measurements must use canonical bundles/tools under the updated repository rule.

## Canonical inputs and preexisting-task identity (cohort 49)

Tooling commit `9e53174f6` strengthens shared-app ownership checks. Each task
already running from that app must retain its PID, command, positive process
start ticks and resource-coalition ID before it can be excluded from the new
trial. A reused PID, changed coalition or vanished task supplies no exemption;
an older task in the measured coalition invalidates the trial. New unowned
helpers still fail. All 227 instruction-tool tests pass.

This cohort directly references `Build/v/Vox.app`, installed Brave and canonical
repository tools, without new app/tool copies or metadata protection. Both Vox
arms use executable
`e9b1cdeb2197ef69aacf701bb0e12149aecfabed3f2c68cb675d34631c3f681e`.
Separate candidate/control execution diagnostics preserve original pixels,
full content, ownership and native exit zero. They execute one JavaScriptCore
context with 1,937 / 1,973 evaluations; the font-retention trace appears only
when enabled. The instrumented diagnostics receive no instruction credit.

The independent auditor verifies all 21 raw records and semantic audits,
fourteen Vox endpoint proofs and seven Brave endpoint brackets, and rehashes
all 1,638 pinned inputs at its recorded audit time. Twenty original PNG checks
are exact; Brave pair 2 differs by 304,064 pixels, maximum channel error 18.
No attempt is retried or excluded. All native exits are zero; driver, guard
and controller exit 1 because acceptance fails. All browser roots are adopted;
the guard records 66 process identities, no adoption error, 1,483,292,672 peak
sampled bytes and 105.9209165 seconds under the unchanged 12 GiB budget.

The small matched median point difference does not establish a robust speedup.
Three pairs improve and four regress, with conservative control ratio
1.0385805274608737. The feature's preceding focused/broad checks remain valid;
this ownership correction changes no engine policy or capture boundary and
receives no additional engine credit. The known broad baseline failures remain
unresolved. Historical WebP/RGB policy, warm OS caches, original scripts,
per-engine references and the rendering/scripting limitations remain unchanged.
The [canonical-input evidence](benchmark-results/bbc-canonical-font-sync-2026-11-02.json)
preserves the exact counts, identities, host conditions and receipts.

## Early text-font requests, removed (cohort 50)

Commit `d311dc21a` tried starting selected text-face requests from existing clean
styles before JavaScript startup, without another style pass or geometry.
`dd2c5895f` isolates the previous request timing in the same-binary control.
Six focused cases pass in both policies and all three memory modes, for 36
case executions; all nine compiler/runtime jobs exit zero. All 228 instruction
tool tests pass. An initial test-source compilation error is retained without
execution credit.

Both arms use the completed canonical executable
`c1a609e19395dd68b7a8fa7043f55be7a89e21fb0bc3a7031559ac3fb4770540`.
Separate candidate/control BBC diagnostics prove that the new path executes
only when enabled, with original pixels, full content, endpoint ownership and
native exit zero. JavaScriptCore executes one context and 2,018 / 1,926
evaluations. Instrumented diagnostics earn no instruction credit.

All seven alternating triples are attempted. Vox pairs 3 and 7 fail the
existing early check for an app helper outside the measured coalition and
have no capture-counter intervals. The available process snapshots do not
record the outside helper's command; its cause remains unattributed. These
attempts are not retried or excluded. All nineteen completed captures pass
independent exact PNG comparisons, full semantic audits, native exit zero and
their endpoint ownership checks. The independent auditor rehashes all 1,637
pinned inputs unchanged and verifies every root's memory-guard adoption.
Driver, guard and controller exit 1. The unchanged 12 GiB guard records
1,487,077,376 peak sampled bytes over 98.551326041 seconds, with no adoption
error. Per-trial host load and timestamps remain retained.

There is no complete seven-pair gate. The five completed matched pairs supply
only a partial diagnostic: Vox/control medians 31,876,979,933 / 31,293,454,202,
with two improving and three regressing pairs. The median regression is
583,525,731 instructions (1.8646894242908671%). `6962019` removes the experiment;
both original initial-font cases pass in all three memory modes, with all six
compiler/runtime guard exits zero. No measured saving, new broad checkpoint or
cadence reset is credited. The prior broad baseline failures remain unresolved.

Separate hardware-counter diagnostics guide further investigation. Corrected
root-thread sampling observes 24,100,482,176 main-thread instructions and
2,560,293,114 on JIT helper threads. These maxima include the post-capture audit
and omit unsampled exited-thread tails. The first sampler attempt has a valid
native capture but zero thread samples after a harness API-name error; it
receives no attribution credit. A separate interposition run records
2,751,257,521 instructions in outer direct script evaluations, including any
nested native style/layout work, and reports zero counter errors.

One further diagnostic pair raises DFG warmup thresholds from 1,000 to 10,000.
Actual option dumps verify the settings with baseline and DFG JIT enabled;
original pixels/content/native exits/ownership remain valid. Observed JIT-thread
instructions fall from 2,752,842,128 to 1,771,661,439, while main-thread maxima
rise from 24,005,483,025 to 24,890,444,063. Pauses, polling, option dumps and
compilation logs perturb scheduling, so these are diagnostic observations only.
Production JIT policy remains unchanged. A preparatory audit syntax failure
and the corrected zero-exit auditor are both retained. All counters, commands,
hashes, focused/restoration checks and guard receipts are linked from the
[font-request evidence](benchmark-results/bbc-font-request-experiment-2026-11-02.json).

## Font-input index, pending production validation

`e6c401e08` replaces the repeated all-longhand scan during font-cache reuse with
a process-lifetime index derived once from the existing mutation predicate.
It compares the same 21 current font inputs in the original property order.
It retains owner/environment guards, animated values and in-place comparisons;
no element's font values are memoized. The index uses persistent allocation so
the first document's native arena cannot own its lifetime. `4ac6d68f9` isolates
the previous full scan in the matched control.

All 48 focused cases pass with indexing enabled and forced off in default,
no-GC and preallocated modes: 288 case executions and nine zero-exit jobs.
Coverage includes every longhand's font-cache behavior, animated and in-place
changes, index lifetime after document destruction, font synthesis and the
existing font-input refresh cases. All 229 instruction-tool tests pass. Earlier
compile-only preparations remain retained; only final unchanged sources receive
this execution credit.

Eight standalone microbenchmark trials use the same C-O3 preallocated no-GC
executable, five uncounted warmup calls and 200,000 measured comparisons each,
alternating equal and changed font sizes. Every trial asserts 100,000 matches.
The four indexed counts span 730,825,223–730,859,333 instructions; the four full
scans span 3,351,088,371–3,351,262,797. The retained disassembly confirms calls
to the comparison inside the loop. The first four trials lack host telemetry;
the later four retain CPU count, load and timestamps, without excluding earlier
results. A strict V `-prod` preparation fails on existing pointer-map checks;
the corrected microbenchmark retains V runtime checks and uses the same C-O3
preallocation policy as production.

This measures a function, without browser startup, BBC content or PNG capture.
It establishes no BBC saving, Brave advantage, broad-check cadence reset or
catalog qualification. The
[font-input evidence](benchmark-results/bbc-font-input-index-2026-11-02.json)
pins the exact counts, executable/generated-C hashes, guards and source checks.

At the recorded receipt time, the latest completed canonical browser remains
`c1a609e19395dd68b7a8fa7043f55be7a89e21fb0bc3a7031559ac3fb4770540`.
It lacks this change and still contains the early-font experiment already
removed from `master`. The shared production build is busy; no duplicate build
or private app/tool copy is queued. Prepared runners reference canonical apps
and tools. Fresh startup, eleven smoke/eight SVG checks, separate BBC path/JSC
diagnostics and a complete seven-triple unprofiled cohort remain pending on a
bundle containing the change. An older bundle cannot validate it. The existing
5,000,000-instruction broad-check cadence applies to measured BBC savings;
prior broad baseline failures remain unresolved.

## Font-input production validation and cohorts 51–52

The later completed production executable
`f769e44dbef6c5c309654f532cadf36bc7d5288a4b99c9f4a03f40845649be49`
contains the font-input index and excludes the removed early-font experiment.
Fresh startup, eleven screenshot smoke checks within their unchanged bounds
and eight exact SVG mutation checks pass. Eight smoke images are exact; three
use existing allowances. Separate BBC diagnostics verify the indexed path only
in the candidate and actual JavaScriptCore execution in both arms. These
instrumented runs earn no instruction credit.

Cohort 51 retains thirteen attempts: four complete alternating triples and
the fifth control. An input fingerprint check then rejects the cohort.
Immediate later hashes match the pinned inputs, but the original driver did
not retain the differing observation, so its file and cause remain unknown.
Commit `71793596d` records changed or unavailable identities before rejection;
all 232 instruction-tool tests pass. This is a tooling correction, without
engine credit. No partial cohort is pooled with the next cohort.

Cohort 52 completes seven alternating triples using canonical tools and apps,
the same launch-to-encoded-PNG coalition scope and unchanged references.
Independent auditing rechecks 1,637 input identities, all 21 complete content
audits and exact PNGs, fourteen Vox capture ownership proofs and seven Brave
counter brackets. All native browser exits are zero, and the memory guard
adopts every browser root. Driver, guard and controller exit 1 because the
instruction target fails:

| Statistic | Candidate Vox | Full-scan Vox control | Brave lower bound |
| --- | ---: | ---: | ---: |
| Median instructions | 32,105,605,236 | 31,799,655,533 | 15,063,146,742 |

The candidate independent median regresses by 305,949,703 instructions.
Five paired trials improve and two regress; the median paired reduction is
567,341,128. Both statistics and every trial are retained, without a robust
BBC optimization claim. The conservative ratio is **2.1903755525**, and the
integer gate fails: **325,813,940,150 > 133,873,182,522**. The history now
contains 1,278 cohort attempts across 52 cohorts. BBC remains absent from
`OPTIMIZED_SITES.md`.

Broad checks enter all 456 selected layout cases in both default and no-GC
modes: 454 pass in each. The text-control baseline remains 13.5 versus 13;
the toggle baseline is 16 versus 15. Both failures reproduce in a separate
five-case control with the font-input optimization disabled. All 95 broad
compile/runtime jobs have terminal guard receipts and unchanged owned inputs.
There is no whole-suite pass or cadence reset.

A separate JavaScriptCore sampling diagnostic retains 530 samples, including
356 native-host leaf samples. Geometry-read stacks account for much of the
inclusive host activity; this is time sampling, not retired-instruction
attribution. Additional stylesheet diagnostics find 641 identical server and
initial client rules, plus 139 server-only metadata rules targeting an absent
tag. Preparatory proxy rejection, an adblock-error load and an ineffective
hook are retained alongside the successful original-PNG/content/ownership
checks. This motivates a guarded redundant-sheet-removal experiment; it earns
no browser optimization credit yet.

The explicit historical RGB WebP policy, cross-browser pixel differences,
module CORS failure and other rendering limitations above still apply. These
are frozen-page observations, without current-default or live-site credit.
Exact counts, native checks, raw failed attempts, ownership proofs, host
telemetry and receipts are preserved in the
[production supplement](benchmark-results/bbc-font-input-production-2026-11-02.json)
and [compressed raw cohorts](benchmark-results/bbc-font-input-production-2026-11-02-raw.json.gz).

## Adjacent stylesheet replacement, pending browser measurement

Commits `3fc8f581f` and `c034c3ac6` narrow invalidation when removing an inline
sheet immediately followed by a replacement with the same complete selector
sequence and conditional structure. Unchanged declarations need no additional
restyling; changed declarations retain their existing selector invalidation.
Ownership changes, rule-cache invalidation and pending updates remain intact.
Global rules, different URL bases or media, disabled/constructed/shadow sheets
and changed selector order retain the previous path. Only leaf rules requiring
a tag never seen in the document can be ignored.

An initial positive fixture reparsed already serialized server rules. Testing
the original server text exposed shorthand expansion order and conservative
typed differences, including default border widths and rgba values. The final
comparison matches independent unique longhands by name, preserves competing
logical/physical declaration order, and keeps typed differences significant.
With the original server CSS and recorded document tag history, the standalone
fixture produces an invalidation plan for **22 declaration rules**, rather
than treating all 641 client rules as completely equivalent. This is parser
fixture evidence; production eligibility remains unverified.

All **75 focused cases** pass with the candidate enabled and forced off in
default, no-GC and preallocated modes: **450 executions and nine zero-exit
compile/runtime jobs**. Fourteen new cases cover ownership, pending updates,
unseen/removed tags, full sequence order, independent shorthand expansion,
logical aliases, duplicate internal declarations, media/global effects, live
CSSOM changes and selective invalidation. Preparatory failures and the earlier
normalized-only fixture remain retained. Tool commit `949526463` adds the
isolated control flag; all **233 instruction-tool tests** pass.

Two fresh native sampling runs on the available browser retain exact reference
PNGs, complete content and capture ownership checks. Eager symbol loading in
the first profile leaves mostly later capture/audit/teardown observations.
The second records 2,137 main-thread samples and substantial native layout
activity. Both include idle work and overlapping stacks; neither establishes
retired-instruction attribution or an optimization gain.

At the recorded receipt time the shared production build is busy, and the
latest completed executable remains `f769e44d…`, which lacks this change.
No duplicate build or app/tool copy is queued. Fresh production path/JSC
diagnostics, native checks and the prepared seven-triple matched cohort must
run on a completed bundle containing the final code. There is no new BBC
instruction credit, broad-check reset or catalog qualification. The latest
unprofiled cohort still fails the requested 10% target.

See the [stylesheet evidence](benchmark-results/bbc-adjacent-sheet-removal-2026-11-02.json)
and [compressed fixtures and native profiles](benchmark-results/bbc-adjacent-sheet-removal-2026-11-02-raw.json.gz)
for commands, exact inputs, failures, guards, source identities and pending
canonical runners. The earlier rendering/script limitations and private Brave
immutable-flag cleanup remain open. Generated evidence remains local in
`docs/benchmark-results/` and `Build/`, following the repository's current
ignore policy; the source, tests and this report text are committed.

## V function profiling and bounded substring search (cohort 53)

The requested `v -profile` diagnostic uses `-profile-no-inline` and
`-profile-fns main__main`, with preallocated no-GC C-O3 compilation. Both
instrumented builds finish successfully but encounter concurrent source
changes, so neither validates the current checkout. Three dated launches then
load adblock-error pages and are rejected as BBC profiles. All attempts remain
retained. No canonical browser bundle or repository tool is copied.

A successful dated diagnostic uses the supported self-worker and embedded
snapshot fallback to keep filtering enabled with matching embedded assets.
Per-PID profile files prevent helper shutdown from overwriting the root's
report. It passes complete BBC content, native-exit and capture-ownership
audits; its image retains the current 120-pixel difference from the historical
reference. Two empty helper profiles supply no call-count evidence.
Instrumentation raises this run to 239,500,337,091 instructions, which earns
no comparison credit.

The root report records **10,469 nonzero function rows**, with 25,156
instrumented functions and no negative self-time rows. It observes 399,306
attribute substring searches, 22,250 grid formatting calls, 341 document layout
updates and 345 style updates. These are instrumented observations: inline
functions are excluded, shared counters are not thread-safe, elapsed time
includes waiting, and recursive inclusive times overlap. They cannot be added
or interpreted as per-function retired instructions. The earlier stylesheet
removal helper records two early rejected attempts and no successful witness;
it receives no BBC gain credit.

The selector source is identical before/after that diagnostic build and to
the pre-change baseline. Commit `dd0add623` adds first/last-byte rejection
before comparing the interior of bounded attribute substring windows. ASCII
folding, exact slice boundaries and the existing long-pattern search remain
intact. Fourteen focused cases pass with the candidate enabled and forced off
in all three memory modes: **84 executions and nine zero-exit jobs**. Coverage
includes every byte value, embedded NULs, Unicode boundaries, borrowed slices,
overlapping matches and HTML attribute case rules. Tool commit `c0cfdbba4`
isolates the original scan; all **234 instruction-tool tests** pass.

Four alternating standalone pairs compare the same C-O3 executable over
500,000 calls after warmup. Inputs combine 262 archived URL values with seven
synthetic patterns and both case modes; every trial asserts 54,471 matches
across 3,668 cases. Candidate counts are 204,654,474; 204,565,062; 204,579,872;
204,571,570. Controls are 340,177,641; 340,168,789; 340,171,015; 340,180,390.
The median reduction is **39.8615%**. Disassembly retains the call inside the
loop. This excludes browser startup, DOM/layout, page scripts, PNG capture and
Brave; it is not a BBC saving or a broad-check cadence reset.

Cohort 53 separately measures the latest completed unprofiled browser,
`c9f2ba4f4f37f7308a435ee6aad419c074817aed6f977712d50595ea77b15301`,
which predates the substring change. All seven alternating pairs complete:

| Statistic | Vox | Brave lower bound |
| --- | ---: | ---: |
| Median instructions | 30,497,696,829 | 15,039,059,425 |

Independent auditing reproduces all fourteen full content and ownership
checks, verifies all native exits are zero, rechecks all 1,637 pinned files and
confirms that the memory guard adopted every browser root. All seven Vox
images differ by 120 pixels from the original reference; Brave pair 2 differs
by 64,177 pixels, while its other six captures are exact. References and
tolerances remain unchanged. The instruction gate also fails:
**319,696,388,710 > 134,571,742,605**. Driver, guard and controller exit 1.
No failed observation is excluded. The history now retains **1,292 cohort
attempts across 53 cohorts**, without attributing intervening build changes
to this candidate.

The completed production browser still lacks the new substring path, and the
shared production build is busy. A new-production eligibility/JSC diagnostic
and matched unprofiled cohort remain pending. The 10% target, reference
failures and BBC catalog entry remain open; historical rendering/script
limitations and prior broad failures are unchanged. Native startup, eleven
smoke checks within unchanged bounds and eight exact SVG checks pass on the
earlier completed `bafbc4c0…` bundle.

The local [V profile evidence](benchmark-results/bbc-v-profile-substring-2026-11-02.json)
and [compressed raw profile, cohorts and microbenchmark](benchmark-results/bbc-v-profile-substring-2026-11-02-raw.json.gz)
retain commands, function rows, source drift, input hashes, failed preparations,
exact counters, guards, host telemetry and audit results. Generated evidence
stays local under the repository's ignore policy.

## Executed substring path and intrinsic-context candidate (cohort 54)

The later completed production executable
`1c9c91f584d6bff71b8f92cc5b236f22e92cbbe0f795d9e8674307d3a96aa8a6`
contains the substring change. Separate enabled/control diagnostics confirm
that its new boundary scan executes only when enabled; both preserve full BBC
content, capture ownership and native exit zero. JavaScriptCore creates one
context and performs 1,936/1,951 evaluations. Both images retain the historical
120-pixel mismatch. These instrumented runs earn no instruction credit.

Cohort 54 retains seven alternating control/Vox/Brave triples. Candidate
instructions are 29,284,491,103; 31,384,726,604; 30,243,106,790;
30,018,310,875; 30,623,903,667; 31,646,854,418; 31,969,894,523.
The corresponding controls are 30,376,801,504; 30,561,902,689; 31,126,387,271;
31,077,720,216; 31,050,299,033; 30,055,138,801; 31,036,251,546.
Their medians are **30,623,903,667 versus 31,036,251,546**, a 1.3286%
point reduction, with four paired improvements and three regressions.
All fourteen Vox images have the same PNG hash and differ from the unchanged
reference by 120 pixels. Their complete content, native exits and exclusive
capture ownership pass independent auditing.

Brave pair 5 fails because a private helper is outside its resource coalition.
Its raw counter brackets and cleanup exit remain recorded; no replacement
trial or selected launch count is manufactured. The other six Brave lower
counts are 15,147,685,055; 15,170,928,414; 15,170,300,641; 15,209,275,762;
14,997,522,655; 15,086,195,807. Their partial median is 15,158,992,848, which
is explicitly **six complete trials**, not a seven-trial acceptance statistic.
Even the partial instruction comparison fails:
`319698945230 > 134977703895`. The guard adopts every recorded browser root,
reports no adoption errors, peaks at 1,492,549,632 bytes and completes in
107.1428 seconds. Driver, guard and controller exit 1. All 21 attempts remain
included, bringing the history to **1,313 cohort attempts across 54 cohorts**.
This invalid cohort earns no BBC saving or broad-check cadence reset.

The V profile also identifies repeated independent layouts inside intrinsic
probes. Commit `778ee82dc` tests a new cache confined to one document layout
pass. It keys closed flow/flex/grid contexts by mode, available space, root
sizes and constraints, and the complete containing-block size chain. Replay
rechecks text, tree order, computed-style identity/revision, image dimensions,
font generation and style environment. Lines, glyph runs, inline-end records
and descendant geometry are owned independently of the producer's retiring
scratch arena. Positioned/float, subgrid, table, generated, clamped and other
unsupported dependencies retain full layout. Each node keeps at most four
entries; closing the pass drops the cache.

Twenty focused cases pass enabled and disabled in default, no-GC and
preallocated modes: **120 executions, nine zero-exit jobs**. They compare
results and geometry against uncached probes after scratch retirement and
consumer mutation, and cover width/mode, text/style/tree/font/containing-height
changes and excluded dependencies. Three initial test preparations fail and
remain retained: one propagation-syntax error, duplicate indexes in a synthetic
mutation, then a missing containing block on its synthetic new child. These
are corrected before the passing checks. Control tooling `00c85d48d` isolates
`VOX_DISABLE_INDEPENDENT_MEASUREMENT_REUSE=1`; 63 BBC tests and the combined
212 browser-instruction tests pass. The initial malformed test insertion is
also retained in the failed tooling receipt.

The available completed browser initially lacks this context cache. A shared
production build is already running and supplies generated C with the new
path; no duplicate build is queued. Production eligibility, matched instruction
results and native conformance remain pending for this candidate. The target
and BBC catalog entry remain open, with earlier broad failures and rendering/
script limitations unchanged. See the local
[evidence](benchmark-results/bbc-intrinsic-context-2026-11-02.json) and raw
`Build/bbc-intrinsic-context-20261102/` receipts. Generated reports stay local
under the repository ignore policy.

## Rejected probe cache and reuse of completed contexts

The first pass-scoped probe cache reaches a stable completed production build,
`c8993aa08e74513dacc5fda3f384b9cd6eb2835eddc8f98cf315b4c39bd9c324`.
Fresh enabled/control BBC diagnostics both pass the original pixel reference,
full content, native exit and exclusive ownership. JavaScriptCore records one
context and 2,017/1,917 evaluations. **Neither run executes that cache's replay
path.** No instruction cohort is collected for an unused path, and no saving
is credited. The same pinned app passes headless startup, all eleven smoke
comparisons at unchanged bounds, and all eight required SVG comparisons
pixel-exactly. Executable/native identities are unchanged across those checks.
The earlier 120-pixel discrepancy has disappeared in this later shared build;
that restoration is not attributed to the unused cache.

A separate frozen-HTML C-O0 diagnostic, without resource replay or author-script
execution, also records no hits. Both arms retain 2,854 layout nodes, 902 lines
and the same scalar geometry checksum. These aggregates do not establish pixel
conformance or full-browser performance. The first standalone compile overlaps
a concurrent repository reset and lacks the candidate marker; it is retained
as an invalid candidate diagnostic. The subsequent marked build supplies the
reported standalone observations.

Commit `c2b6f290e` removes the probe-to-probe cache and instead lets intrinsic
probes read already completed ordinary retained contexts from their current
layout pass. The existing cache owns all descendant geometry and lines, so
this path creates no second snapshot cache. Pool closure releases its source
state reference. Replay requires matching mode, available space, root sizes,
constraints and definiteness, ancestor geometry, style/text/tree/image inputs,
font policy and actual current font metrics. The cached root's post-formatting
sizes/flags are retained explicitly. Rejection keeps the ordinary algorithm.
Twenty-six focused cases pass enabled and disabled in all three memory modes:
**156 executions, nine zero-exit jobs**. An initial key comparison fails because
measurement ancestors deliberately sever their geometry pointers; the corrected
key follows the logical node chain in either state. That failing run remains
retained.

The initial completed-context key is still too restrictive on the frozen HTML.
A separate read-only diagnostic in generated C observes **7,481 lookup calls
and 3,180 completed-context entries**. The first 32 expanded observations show
matching child inputs with differing ancestor min/max probe markers. These
are diagnostic counts, not retired instructions or an eligible-context total.
The generated source, inserted scalar logging, native link flags, executable,
commands and actual zero exits remain preserved. Its geometry aggregates stay
unchanged. No production browser or canonical repository tool is copied.

Commit `4d7edc800` compares ancestor dimensions and effective definiteness,
while retaining the child's own min/max constraints in its key. Ancestor probe
markers are not independently consumed by a closed child's formatting
algorithm. A marker that changes effective ancestor definiteness still rejects
replay. The dedicated case checks both outcomes against uncached geometry;
its first preparation incorrectly expected replay after changing a previously
definite axis and is retained as a failed check. Key comparison now walks the
saved chain without allocating a temporary replacement vector for each lookup.
All **27 focused cases pass enabled and disabled in default, no-GC and
preallocated modes: 162 executions and nine zero-exit jobs**. Selected-font
replacement rejects replay; unchanged actual faces may survive an unrelated
font-generation change. The standalone metadata-key revision positively
executes replay only when enabled, with the same geometry aggregates; that
binary predates the final allocation-free lookup and earns no browser credit.

Shared build receipts retain superseded successful compilations and failures
from concurrent checkout changes, a transient reset/rebase and conflicted
native files, then JavaScriptCore declarations corrected by the other session.
The original completed commits are retained in evidence alongside their rebased
identities (`132387c6a`, `0c10ec0f1`, `ac52c571e`). The recovered engine sources
match the passing checks byte-for-byte. The recovery preview is never applied;
no other session's native changes are overwritten. Latest completed bundles
supply applicable baseline evidence while the guarded shared build progresses.

The final candidate still needs production BBC eligibility, unchanged pixels,
matched unprofiled instruction results, and any broad verification triggered by
measured savings. There is no new accepted cohort or broad-check reset. The
history remains 54 cohorts/1,313 cohort attempts, and BBC is not added to the
catalog. The local [evidence](benchmark-results/bbc-intrinsic-context-2026-11-02.json)
links all raw diagnostics, native checks, source changes, failed preparations
and production receipts under `Build/bbc-intrinsic-context-20261102/`.

## Completed-context replay rejected after cohort 55

The completed production executable
`0bb14e2f940d1ee83a4a57f48179ab40fb3ecf71aa8b7331f199676792ab6974`
does execute completed-context replay after navigation starts and before PNG
encoding completes. The disabled control does not. Separate diagnostic launches
pass full content, unchanged pixels, native exit and exclusive ownership;
JavaScriptCore creates one context and records 1,980/1,986 evaluations. A native
sample is retained separately and supplies no unprofiled instruction credit.

Cohort 55 retains all seven alternating control/Vox/Brave triples, **21
attempts**. All 21 native exits, independently checked complete content audits
and original pixel references pass. One Vox trial fails capture ownership:
its native endpoint counter remains unselected, and the cohort is invalid.
All 1,638 pinned input files are independently rechecked before changing tools;
none changed. The memory guard adopts the browser roots without errors.

The raw seven-Vox median, including the unselected ownership failure solely as
a diagnostic, is **30,794,848,249 instructions**, against control
**30,548,193,331**: a **0.8074% regression**, with three paired improvements and
four regressions. The six selected Vox values have median 30,801,990,584.5;
this partial statistic cannot establish acceptance. Brave's seven lower-bound
median is **14,846,110,043**. Even the partial conservative gate fails:
`315396236710 > 133041026574`. Every raw value, failure and audit remains in
`matching-cohort55-audit.json` and `matching-matched-cohort/` under the same raw
evidence directory. No samples are retried or removed to pass.

The regressing engine experiment is removed in `75d4b6ec8`; both modified
common layout files match their pre-experiment versions byte-for-byte. The
22 retained focused cases pass in default, no-GC and preallocated modes:
**66 executions and six zero-exit compile/runtime jobs**. Its obsolete BBC
control is removed separately in `41e8675bf`; all **211 browser-instruction
tool tests pass** under the focused memory guard. These checks do not validate
a newer production executable. The shared build receipt identifies when the
restored source becomes available for native checks.

The history is now **55 cohorts/1,334 cohort attempts**. This experiment earns
no accepted instruction saving or broad-check reset. The target remains open
and BBC remains absent from `OPTIMIZED_SITES.md`. Earlier broad failures,
frozen replay scope and rendering/script limitations still apply. The local
[evidence](benchmark-results/bbc-intrinsic-context-2026-11-02.json) links the
phase witness, native sample, raw cohort, independent audits and restoration
receipts; generated evidence remains ignored.

## Definite-width contributions and current workflow profiles

`93c292a58` skips a content-width probe when a noncyclic definite preferred
width would immediately overwrite its result. The existing resolver still
converts border-box sizes and clamps negative content sizes. Intrinsic min/max
constraints still request their content measures; percentages, including
calculated percentages, keep the original path. `67fb1193e` adds an isolated
same-app control. Ten focused cases pass enabled and disabled in default,
no-GC and preallocated modes: **60 executions and nine zero-exit jobs**.
All **212 instruction-tool tests pass**. An initial test comparison using an
unsupported CSSPixels operator and an incorrectly named tooling test option
are retained with their failed receipts. Production eligibility and matched
unprofiled benefit remain unverified at this checkpoint.

Four separate C-O3 workflow diagnostics use a fresh instrumented executable
generated from the canonical restored source at `631a19687`, before that
definite-width change. No browser bundle or canonical tool is copied. Native
preprocessing is frozen; existing canonical native libraries, filter helper
and its matching snapshot are referenced directly. Source inputs match across
V generation and linker inputs match across native compilation. The original
preprocessing attempt incorrectly included multiple source inputs; the next
compile exposed a wrapper return-variable collision. Both failures and their
corrected zero-exit preparations remain retained.

All four fresh diagnostic processes exit zero, pass independent full BBC
content audits and match the unchanged original PNG exactly. Their runtime
identities remain unchanged. **All four fail exclusive capture ownership** and
their driver/guard exits are 1; these are diagnostics, not acceptance attempts
or selected instruction bounds. The process-counter scopes report no counter
errors. In the first run, styling uses 4,679,555,125 instructions across 14
updates; viewport layout uses 6,337,955,606 across 13 passes. The latter includes
nested measurements. Preparing/committing the DOM attachment uses 69,419,133 /
189,153,627. Script-engine call totals include native callbacks and cannot be
reported as isolated JavaScript execution costs. Inclusive scopes overlap and
must not be summed.

Read-only host-call diagnostics further separate those callbacks. The first
records 56 geometry reads totaling 5,025,978,026 process instructions, including
their style/layout work. A separate run divides the same 56 reads into 27
bounding rectangles (3,080,981,238), nine scroll widths (1,898,625,182), nine
scroll-left reads (889,765), nine offset widths (882,070), and two client widths
(193,191). These are instrumented observations from different launches, not
matched improvements. JavaScriptCore records one context and 1,925/1,948/1,994
evaluations in the three host-hook runs. The final hook retains author-call
backtraces for the rectangle and carousel reads. Reports immediately before
the PNG file write follow native encoding and precede semantic audit/teardown;
exit reports are labeled separately. Metadata inspection, process background
work and probe overhead remain included, and only the reporting thread's
host stack is covered.

The selected scope, frozen bytes, original references, historical RGB policy,
rendering/script limitations, prior broad failures and **55 cohorts/1,334
cohort attempts** remain unchanged. No diagnostic or standalone check earns
instruction savings or a broad-check reset. Raw commands, preprocessed C,
executable/native identities, guards, PNGs, failures, host telemetry and
independent audits are under `Build/bbc-workflow-profile-20261102-2300/`, linked
from the local [workflow evidence](benchmark-results/bbc-workflow-profile-2026-11-02.json).
The shared production build is already running; pending code validation uses
its next completed matching bundle without queuing a duplicate build.

## Closed SVG contexts, pending production comparison

`4e6156985` permits independent-context geometry snapshots to include closed
SVG shape trees. The supported elements are svg, g, path, rect, circle, ellipse,
line, polyline and polygon. Snapshots retain every qualified attribute and
namespace, DOM child identity/order, and the existing per-node style, font,
geometry and tree checks. Paths and transforms use the existing owned
UsedValues snapshots. Text, resource instances, foreign content, animation
elements and URL dependencies retain the complete path. Element, child,
attribute and byte limits bound snapshot work. Inline-flow reuse remains
unchanged. `df80b0354` adds the isolated comparison control; all **213
instruction-tool tests pass**.

The mutation checks expose a separate existing omission: CSS path data `d`
was not classified as affecting layout. It left committed path bounds stale
after an attribute or CSS edit, including with SVG reuse disabled. Commit
`b808b55d9` corrects the metadata and adds two direct geometry/paint regressions.
It follows the pinned upstream property's default layout classification; fill
remains a paint-only change. Standalone viewBox/transform checks supply an
unrelated geometry opportunity, as the browser replay owner normally does;
this does not claim complete standalone SVG mutation support.

All **29 combined focused cases pass enabled and disabled in default, no-GC
and preallocated modes: 174 executions and nine zero-exit compiler/runtime
jobs**. Coverage includes movement, unchanged grid identity, immutable old
paint, CSS geometry and size changes, attributes/namespaces, child reordering,
non-layout animation insertion, resource exclusions and bounded snapshots.
Preparatory API/signature, diagnostic formatting and budget-parameter compile
errors remain retained, along with the failing enabled/disabled path-data
checks. One preparation overlaps an unrelated optional-mask-bounds edit; that
compile failure and the later corrected source check remain separate.

The frozen server HTML contains 107 SVG roots: 105 use only path/svg elements,
and two also contain title. A separate standalone diagnostic positively
executes reuse during its first layout call, while the disabled control does
not. Both arms exit zero and retain **2,854 nodes, 902 lines, geometry checksum
110,113,314, and an identical paint dump** after a subsequent body-padding
change. The one-shot marker does not establish whether it executes again in
that second phase. This driver has no resource replay or author-script
execution, uses layout scale 2 and default-C/no-GC compilation, and cannot
establish full-browser pixel conformance or instruction savings. Its initial
summary inferred C-O0; the correction preserves that summary and records the
exact compiler command without assuming an undumped optimization level.

The full-browser diagnostic enables both the SVG and definite-width paths;
the same-app control disables both. It requires their markers after navigation
and before encoded capture, actual JavaScriptCore execution, complete content,
original pixels, ownership and normal exit. The prepared unprofiled cohort
retains seven alternating control/Vox/Brave triples under the adoption-aware
memory guard, using the canonical apps and tools. Native startup, smoke and
SVG checks are prepared for the matching completed bundle. Repeated shared
builds are superseded by concurrent input changes; the available completed
executable remains `0bb14e2f…` at this checkpoint and lacks both optimizations.
It cannot validate them. No duplicate production build or app/tool copy is
queued.

There is **no new accepted instruction cohort, broad-check reset or BBC
catalog entry**. The requested target remains open. All prior failing cohorts,
fixed references, rendering/script limits and broad failures remain retained.
The local [SVG evidence](benchmark-results/bbc-simple-svg-2026-11-02.json) links
the source proofs, focused checks, failed preparations, standalone diagnostics
and pending canonical runners under `Build/bbc-simple-svg-20261102/`.


## Fixed-point box edges, pending full-browser comparison (2026-11-03)

Commit `40ab612bd` resolves a box's padding, border and margin from one typed
style snapshot. It keeps each result in CSSPixels instead of dispatching twelve
individual properties and converting fixed point to double and back. Absolute
lengths retain the document rounding policy; percentages keep the same rounded
containing-block basis. Relative units and calculations retain their live font,
viewport and query-container context. No result or context is cached. Commit
`1ef435aee` adds an isolated same-binary control for the previous resolver.

All **12 CSS cases pass in both policies in default, no-GC and preallocated
modes: 72 case executions**. The four new cases cover fractional and saturated
absolute values, auto and negative margins, percentage bases, live relative
units/calculations, animation removal, style copies and both document rounding
policies. A separate 15-case layout selection runs in all six configurations:
84 executions pass and six fail. Every failure is the same existing trailing
collapsed-margin root-height check, **40 instead of 60**, with both resolvers.
This selection is not a whole-suite pass and does not reset broad cadence.
The instruction-tool selection passes all **237 tests**.

The first fixture preparation passed an optional pointer expression directly
as an argument; the generated code addressed option storage and crashed.
Explicit local parsed values correct the fixture. Both original crashes,
compile/debug receipts and a premature missing-binary launch remain retained.
The final focused runtime checks use separate 3 GiB guards after successful
12 GiB guarded compilations. The compiler paths and feature inputs are hashed
in the focused receipt.

A separate C-O3/preallocated microbenchmark compares 400,000 complete edge
resolutions per process across **seven alternating pairs**. Control median is
**481,519,372 instructions**; candidate median is **316,443,301**, a **34.2823%**
reduction. Every native/guard exit is zero, source hashes remain unchanged and
all checksums equal 690,435,400. These process deltas cover the loop and checksum
but exclude startup and style setup in both arms. The six scalar styles have
no page, scripts, resources, paint or PNG; this is **not BBC instruction credit**.

A C-O3/no-GC standalone frozen-HTML diagnostic separately exercises the width,
SVG and edge paths. Its logged witness enables all three markers. Ten quiet
fresh processes retain two trials per configuration: all three enabled, all
three disabled, and each enabled alone. All eleven processes exit zero and
retain 2,854 nodes, 902 lines, checksum 110,113,314 and the same paint-dump hash
`0b6eb34d7450e29a30f2e8d29ca9a07ff183bb30501146649e04b14e65e1635a`.
For all-enabled/all-disabled, first-layout medians are
2,858,301,537 / 2,891,863,491.5 instructions, and second-layout medians are
228,245,710 / 241,596,248.5. These layout-only process deltas have no author
scripts or resource replay, use layout scale 2, and do not establish browser
capture costs, PNG conformance or live-site gains.

A fifth full-browser workflow diagnostic groups C API call entries by their
captured function source. React scheduler callbacks dominate those entries;
their totals still include native callbacks, layout, background instructions
and instrumentation. Its native process exits zero, complete BBC content and
original pixels pass independently, and runtime identities stay unchanged.
Exclusive capture ownership fails again, so its driver/guard exit is 1 and
it supplies no selected instruction interval. Truncated descriptions, unrooted
function identities and one-time source inspection further limit attribution.

The next production diagnostic checks all three paths after navigation and
before encoded PNG, plus actual JSC execution, content, original pixels,
ownership and normal exit. Its control disables all three. The prepared
seven-triple unprofiled cohort retains the original launch-to-encoded-capture
protocol, historical RGB policy, fixed bytes/references and adoption-aware
memory guard. Startup, eleven smoke captures and eight SVG guards are prepared
for the same pinned bundle. No app bundle or repository tool is copied.

The latest completed production executable remains `0bb14e2f…` at this
checkpoint. Shared builds have encountered an edited shell script's parse
failure and subsequent source drift; current script syntax passes, and the
existing worker continues. Its next matching completed bundle is required;
the old bundle cannot validate these changes. The two earlier SVG readiness
observers timed out and retain their actual failures. No duplicate production
build is queued. **No new cohort, BBC catalog entry, instruction credit or
broad-check reset is claimed; the 10% target remains open.** Local
[edge-resolution evidence](benchmark-results/bbc-box-edges-2026-11-03.json)
links raw controls, all failures, process counters, commands, host telemetry,
source proofs and pending runners under `Build/bbc-box-edges-20261103/`.
The bridge probe is retained under `Build/bbc-bridge-calls-20261103/`.


The final 15-minute edge readiness observer also ends with exit 1 and no
matching bundle; its timeout is retained rather than retried into acceptance.
At the 00:54 local checkpoint, builds `003142-c60e729f`, `003723-c2c7eca2`,
`004258-953e2ca6` and `004854-39b3268c` all completed but were superseded for
changed inputs; `005352-a0c50202` was still running. The completed bundle's
actual SHA remains `0bb14e2f940d1ee83a4a57f48179ab40fb3ecf71aa8b7331f199676792ab6974`
and lacks the new edge path. Feature hashes remain equal to the focused pins.
The pending runner syntax, probe/diff binaries, available generated C and host
state are separately sealed in `ready-protocol-review.json`; canonical build
receipts and the actual observer exit are linked from `shared-build-blocker.json`
and the local edge evidence. No full-browser eligibility run or cohort starts
from the stale bundle. This is an unresolved production-publication blocker,
not a completed BBC optimization target.


## Verified frozen compiler inputs and cohort 56 (2026-11-03)

Commits `15fee1a2c` and `bf98ee40b` fix the shared production-publication blocker.
The macOS build finishes native/helper work, generates browser C and preprocesses
all translation units while the complete repository input digest remains equal
to the initial receipt. Generated link objects are sealed separately. Long C
optimization then consumes those verified preprocessed files, with original
language modes, C-O3 flags, runtime checks and the existing memory limit. Live
link libraries, framework stubs, resources, packaging code and entitlements are
rechecked before publication. Changed or incomplete input receipts reject the
build; a queued newer request survives rejection or publication. The old worker
hands off cooperatively after its current job. No running compiler is killed,
repository tool/source tree is copied, or source check bypassed. Later unrelated
checkout edits no longer change already sealed compiler inputs.

All **28 focused workflow cases pass**, including real Objective-C/C linking,
source/header/object edits after sealing, source drift before/during sealing,
changed libraries, library shadowing, packaging/resource changes, incomplete
receipts and worker/queue ownership. The broader tooling selection runs 310
cases: 300 pass; ten unchanged Linux compiler-selection fixtures fail because
they omit the existing supervisor flag and their fake Python returns before
compiler selection. Linux implementation and fixture files are unchanged. The
initial temporary-path alias and missing fixture-head failures remain retained.
The local [build evidence](benchmark-results/bbc-frozen-build-2026-11-03.json)
links the guards and production input audit.

The first successful frozen-input production build is
`Build/production-build/receipts/20261103-011139-5e6ed988`:
executable SHA256 **`1bcbbb5cca048906caf2151070018fb7ec0618b5af140b465700ba31a9cd1d75`**.
Compiler/outer guard and fresh headless smoke exit zero. Source digests match
through preprocessing; the later repository state is recorded separately.
An independent post-publication audit verifies all **130 retained compiler
inputs and 53 live inputs**, mapping staging assets to their published paths.
The build guard peaks at 6,839,779,328 bytes. This workflow change earns no BBC
instruction credit and does not change the measurement scope.

Separate candidate/control diagnostics on that bundle both pass complete BBC
content, original pixels, capture ownership and normal native/driver exits.
Actual JavaScriptCore execution records one context and 1,961 / 1,900 evaluations.
The candidate positively executes the definite-width, simple-SVG and bulk-edge
paths after navigation and before encoded capture; the same-binary control
disables them and reports none of their markers. Diagnostic probes are absent
from every unprofiled cohort attempt. Both arms include the shared JavaScript
startup policy and native snapshot changes; no isolated credit is assigned to
those changes here.

Cohort **56** retains all **21 attempts in seven alternating triples**, bringing
the history to **56 cohorts / 1,355 cohort attempts**. All seven Vox captures,
six control captures and six Brave captures match their original references
exactly. All twenty completed captures have full content and native exit zero.
Control pair 2 fails initial private-helper coalition ownership before capture,
with no selected count and cleanup status 15. Brave pair 5 exits normally and
passes content/ownership but differs by **64,177 pixels** in one photo region.
These failures remain in the cohort; there are no retries or exclusions.
All 1,639 pinned files rehash unchanged at the independent audit, and every
launched root is adopted by the memory guard without errors.

The complete seven Vox counts have median **29,966,443,591**. Seven recorded
Brave lower counts, including the failed pixel attempt, have median
**14,983,833,874**. The six available controls have median **30,528,521,255**.
For the six matched control/candidate pairs only, medians are
30,528,521,255 / 29,813,081,522.5: an observed reduction of **715,439,732.5**,
with four improving and two regressing pairs. This partial diagnostic does not
establish accepted optimization credit. The numerical 10% gate also fails:
`304964539640 > 133396656228`, highest-Vox/lowest-Brave ratio **2.0575334753**.
Benchmark, guard and controller exit 1. The guard peaks at 1,480,261,632 bytes
over 103.324202667 seconds; host conditions and exact raw counts remain retained.

The partial observed reduction exceeds the 5,000,000-instruction verification
cadence, so the broad layout selection is rerun. **479 cases execute in each
GC mode: 476 pass and three baseline checks fail in each**. They are the prior
text-control 13.5-versus-13 and toggle 16-versus-15 checks, plus the trailing
collapsed-margin root-height 40-versus-60 check already reproduced with both
edge resolvers. Owned source inputs remain unchanged and every selected case
is entered. This is not a full pass or cadence reset. On the pinned measured
bundle, startup, all eleven screenshot smoke cases and all eight SVG guards
pass, with unchanged executable/native-library identities before/after.

The build blocker is resolved. **The BBC 10% target is still unmet, and BBC is
not added to the catalog.** The original capture scope, frozen responses,
author-script/rendering limitations, historical RGB policy and original pixel
references remain unchanged. Cohort 56, independent audits, native/broad
checks and all failure receipts are linked from the local
[edge evidence](benchmark-results/bbc-box-edges-2026-11-03.json).


## Rejected longhand-cache capacity experiment (2026-11-03)

A temporary experiment raises the per-style-batch reuse-cache limit from 256
to 512, retaining the existing eligibility and typed-input mutation checks.
A separate diagnostic marks only an actual restore of an entry admitted beyond
256. Two new cases verify the bound, late-entry results against the ordinary
computation and the outer batch lifetime. All 33 combined cases pass enabled
and disabled in default, no-GC and preallocated modes: **198 executions**.
A separate logger check positively reports an extended-entry restore with the
larger limit and none with the 256-entry control.

The frozen HTML standalone witness does not execute that path. Its four quiet
candidate/control trials retain the same geometry and identical paint dump,
without instruction credit. More decisively, both fresh full BBC diagnostics
pass content, original pixels, ownership and native/driver exit zero, with
actual JavaScriptCore execution (one context, 1,975 / 2,008 evaluations).
Neither capture restores an entry admitted beyond 256. Their executable
contains the new diagnostic, and the independently exercised logger works;
there is no evidence that this proposed fast path benefits BBC. The eligibility
controller correctly exits 1 rather than attributing noise to the unused path.

The experiment is removed before committing engine changes. The original
`css/computed_longhand_reuse.v` is byte-identical to HEAD, both temporary files
are removed, and **31 original cases pass in all three GC modes: 93 executions**.
The patch, source hashes, actual diagnostics, logger controls, counters and all
runtime/compile receipts remain linked from the local
[capacity evidence](benchmark-results/bbc-longhand-capacity-2026-11-03.json)
under `Build/bbc-longhand-capacity-20261103/`. No matched cohort, instruction
credit, catalog entry or broad-check reset is claimed. History remains
56 cohorts / 1,355 cohort attempts. A later completed production bundle is
still required to validate the source restoration in the installed browser.


## Retained grid/flex trees: cohort 57 (2026-11-03)

The 10% target remains **unmet**. Seven alternating control/Vox/Brave triples
retain all **21 attempts**. Vox's launch-through-encoded-PNG median is
**30,237,763,354** instructions; the same executable with retained block
grid/flex trees disabled has median **30,838,133,429**. The observed difference
is **600,370,075 (1.9468%)**, with five paired improvements and two regressions.
This is a diagnostic median, not accepted optimization credit. Brave has only
six usable selected intervals, with diagnostic median **15,072,361,335.5**.
Its seventh attempt fails the private-helper coalition ownership audit after
capturing an exact PNG and complete content; no selected count or normal
kernel-exit receipt is recovered, and cleanup exits zero. It is retained
without retry or exclusion. History now contains **57 cohorts / 1,376 attempts**.

Even the available-count diagnostic gate fails:
`10 × 30,640,643,820 = 306,406,438,200 > 9 × 14,870,623,965 = 133,835,615,685`.
The highest-Vox/lowest-Brave ratio is **2.0604813821**. BBC remains absent from
`OPTIMIZED_SITES.md`. Exact raw selected intervals, failure records, host loads,
commands, identities and checks are retained in the
[tracked cohort ledger](performance/bbc-formatting-trees-20261103.json); full
counters, coalition scans, PNGs and reports are in
`Build/bbc-formatting-trees-20261103/formatting-matched-cohort/`.

Engine commit `b9f657f12` preserves unchanged text-only block grid/flex typed
subtrees across unrelated DOM tree mutations, including their text and
measurement caches. Geometry still reruns in a fresh layout state. It keeps
style/revision/DOM-order/parent/item-role guards, and excludes subgrids,
replaced content, SVG, generated content and controls. Anonymous text items,
repeated sibling mutations, role changes, sizing and paint-lifetime behavior
are covered by focused tests. All **31 cases × two policies × three memory
modes = 186 executions** pass. Tool commit `f8893f8cc` supplies the isolated
same-binary control; all **238 instruction-tool tests** pass.

The reused production build is
`20261103-015930-28e58436`, executable SHA-256
`f9fffcce6951aa3702654b97e75918d584c9054bec504f6b43d00b0fb665efbc`.
Separate candidate/control diagnostics both pass original pixels, full
readiness/content, ownership and native exit checks. JavaScriptCore records
one context and 1,957 / 2,056 evaluations. The candidate records the new path
after navigation and before PNG encoding; the control does not. The rejected
longhand-capacity marker is absent from this build. No diagnostic logging or
JSC probe is enabled in the unprofiled cohort. All **1,639 pinned files** are
independently rehashed unchanged. The memory guard adopts every trial root,
reports no adoption error, and peaks at **1,565,278,208 bytes**.

All **21 document PNGs** match the unchanged per-engine references and all
21 complete content audits pass. The failed Brave trial remains invalid
because of ownership. Twenty completed trials have normal native exit zero.
The unchanged cross-browser difference is **2,448,723 / 3,145,728 pixels**;
reference stability does not establish rendering parity. Scope, original
script policy, HTTPS replay bytes, private caches, viewport, scale and two
seconds settling remain unchanged. Host load is retained for every arm.

The pinned production browser also passes headless startup, all 11 native
smoke screenshots and eight SVG screenshots. The required broader batch
executes **483 cases in each of default and no-GC modes**: **480 pass and three
preexisting cases fail** in each mode (the two Chromium control-baseline
cases and the trailing collapsed-margin case retained from cohort 56).
Owned source hashes remain unchanged. This is not a full broad pass and does
not reset the verification cadence. The standalone script-free BBC mutation
probe has no eligible tree hit and earns no credit; its five geometry/paint
dumps remain identical. A separate native sampling attempt exits zero but
produces no call stacks, so it is inconclusive. These results establish
neither the requested live-site target nor scrolling performance.


## Original ancestor hashes: cohort 58 (2026-11-03)

The target remains **unmet**, with **58 cohorts / 1,397 attempts** retained.
Commit `2f2f17b77` records scalar ancestor-selector hashes on push and removes
those original hashes on pop, avoiding a second attribute read/hash pass.
It handles non-LIFO seeded-ancestor removal, duplicate visits, saturation and
reset, reuses bounded-to-active-depth buffers, and keeps their document
ownership across scratch scopes. It also balances the filter correctly if
attributes change while a visit is active. All **17 focused cases × two
policies × three memory modes = 102 executions** pass. An initial alias-type
compile failure and the test that caught buffer copy-on-write growth are
retained; both are corrected before the commit.

Seven alternating unprofiled **microbenchmark** pairs traverse the frozen
BBC DOM 20 times, preserving checksum **64,980**. Process-delta medians are
**112,206,970 candidate / 166,992,334 control**, a **32.8071%** reduction in
this narrow operation. The standalone C-O3/no-GC workload has no CSS cascade,
scripts, resources, browser startup, layout or PNG and earns **no BBC
instruction credit**. Its diagnostic witness is separate from timed trials.

Separate full-browser diagnostics pass original pixels, complete content,
ownership and native exit zero in both arms. They witness one JavaScriptCore
context with **1,922 / 2,045 evaluations**, and the saved-hash path executes
after navigation and before PNG only in the candidate. The selected
completed production receipt is `20261103-022243-2475302f`, executable SHA-256
`6acb86324bbd5a08af6c62a9693a484f4a5b87accf8fd9941ad1d1d8b637703f`.
All 239 instruction-tool tests pass. Headless startup and all 11 native
smoke plus eight SVG screenshots pass on that pinned browser.

The full **seven alternating control/Vox/Brave triples** retain all
21 attempts. Control1, Brave4 and Vox7 fail private-helper ownership checks
and have no selected count or normal kernel-exit receipt; cleanup statuses
are 15 / 0 / 15. Brave2 completes normally but differs **368,241 pixels**
from its unchanged reference. All 18 captured documents pass complete
content audits and native exit zero; 17 PNGs are exact. No attempt is retried
or excluded. Available six-sample diagnostic medians are **30,650,953,450
Vox / 30,528,853,274.5 control / 15,152,715,132 Brave**.

Only five pairs have both selected Vox/control intervals. Their candidate
and control medians are **30,851,039,698 / 30,696,684,108**, a diagnostic
**154,355,590-instruction regression**, with two gains and three regressions.
The available-count conservative ratio is **2.0674350834**;
`310,101,418,880 > 134,993,973,564` fails the 10% integer gate. No BBC saving,
broad-cadence reset or catalog entry is credited. Previous broad baseline
failures remain unresolved.

All **1,639 pinned files** rehash unchanged, and every trial root is adopted
without guard errors. Peak sampled browser-tree RSS is **1,746,681,856 bytes**.
The scope, fixture, scripts, viewport, caches and original references remain
unchanged; host telemetry and all failed attempts are preserved in the
[tracked ledger](performance/bbc-ancestor-visits-20261103.json) and
`Build/bbc-ancestor-visits-20261103/`.

Commit `c6ab1abe6` now preserves observed process commands even when ownership
fails. Brave4's receipt identifies a concurrent browser using the distinct
`brave-reference-xicj64uk` private profile, plus its GPU/network helpers, in
the global-app assertion. This explains that failure's extra PIDs without
retroactively validating it or relaxing counter ownership. Frozen-page and
JavaScript limitations above continue to apply.


## Rejected early-viewport experiment: valid cohort 59 (2026-11-03)

**The 10% target remains unmet.** This cohort has all **seven complete
alternating control/Vox/Brave triples**, with original per-engine PNGs, full
content, exclusive ownership and normal native exit zero in **all 21 attempts**.
All **1,639 pinned input files** rehash unchanged. Every root is adopted by
the unchanged memory guard without errors. No attempt is retried or excluded.
History now retains **59 cohorts / 1,418 attempts**.

The candidate median is **30,223,856,904** instructions, against control
**29,922,237,319** and Brave **15,061,869,449**. The candidate **regresses by
301,619,585 instructions (1.0080%)**, with two improving and five regressing
matched pairs. The conservative ratio is **2.0812862367**, and the integer
gate fails: **311,494,026,220 > 134,697,774,222**. Driver and guard exit one
reflect the failed numeric gate, rather than an invalid trial. The result
supplies no optimization credit and no BBC homepage instruction-table entry.
Exact intervals, commands, host load, identities and audits are in the
[tracked ledger](performance/bbc-viewport-style-20261103.json) and
`Build/bbc-viewport-style-20261103/viewport-matched-cohort/`.

The experiment (`7a746d5a4`, tool `a5eb2449c`) installed the requested viewport
before native scale-selection style queries. Separate diagnostics confirm
that the original first query recomputes 2,493 elements at **800×600**, while
the candidate recomputes 2,534 at the requested **1024×768**. They both pass
reference pixels, full content and ownership, and witness JavaScriptCore
execution (one context; 1,945 / 1,979 evaluations). Query and path probes are
absent in the unprofiled cohort. The pinned production receipt is
`20261103-023924-9e1a549f`, executable SHA-256
`eb372f4d5ddf52e30963791fcccb16b88e15cc069fc6abbefed8946782e5dc6c`.
The original page bytes, script policy, clock shim, viewport, scale, settlement,
caches, RGB compatibility and PNG references remain unchanged.

The earlier style query is an internal workflow change; the complete
measurement shows a regression. Commit **`166a0a8b4` removes the experiment**,
restoring all four existing implementation files byte-for-byte to their
pre-experiment revisions and deleting its helper/tests. **`2a0ad2f02`** removes
the unused benchmark control. Fresh restoration checks pass all **17 cases
in default, no-GC and production-preallocated modes (51 executions)**; all
239 remaining instruction-tool tests pass. A fresh later bundle, receipt
`20261103-030003-83304384`, passes headless startup and eleven smoke/eight SVG
checks with the experiment absent. Its executable is
`107814245c9defc216e452388949a272894fd5a1b84ef4b8e53531ec7fcdb12f`;
runtime identities remain unchanged throughout those checks.
No broad verification checkpoint or cadence reset is claimed.

### Corrected preallocated test configuration

The first preallocated main-test run used raw current V, whose unbounded
`v_realloc` copy crashes during PNG `realloc(nil,n)` in the initial-resource
test (exit 139). This was a **test-harness configuration error**. Production
already uses the repository's staged bounded allocator and arena-safe closure
runtime through `tools/prepare_prealloc_runtime.py`; it was unaffected.

Corrected checks reuse that exact immutable runtime/compiler view, its
module path and compiler working directory, retaining the 10 GiB compiler
limit and 12/3 GiB build/runtime guards. All **31 retained-formatting-tree
cases, 17 ancestor-hash cases and 20 viewport cases** pass under both policies
(**136 preallocated executions**). The viewport cases also pass default and
no-GC modes under both policies, for **120 valid executions** before removal.
The raw failed configuration and all corrected commands, runtime hashes,
logs and guard exits are preserved under
`Build/bbc-viewport-style-20261103/production-prealloc-v1/`. This corrects
the preallocated-runtime coverage of cohorts 57 and 58 without changing any
measured browser interval or earning performance credit.


## Rejected ordinary grid-placement borrowing: cohort 60 (2026-11-03)

**The 10% target remains unmet.** All seven alternating control/Vox/Brave
triples are retained without retries or exclusions, bringing history to
**60 cohorts / 1,439 attempts**. Vox4 and Brave1/3 fail the private-helper
ownership assertion and have no selected launch count. Their cleanup exits
are 15, 0 and 0 respectively. Eighteen attempts have selected counters; all
nineteen completed document captures pass full content and original PNGs.
The partial medians are **29,811,654,721.5 Vox (six)**,
**29,740,784,365 control (seven)** and **15,051,486,755 Brave (five)**.
Six matched control/candidate pairs regress by **189,233,679.5** instructions,
with two improvements and four regressions. Even the partial conservative
gate fails: **316,950,647,640 > 134,850,910,950**, ratio **2.1153404220**.
This invalid cohort earns no BBC saving or broad-check cadence reset.

Experiment `727447547` borrows the ordinary grid placement list for track
sizing, retaining the collector for subgrid projection. Separate full-browser
diagnostics witness the new path only in the candidate, after navigation and
before PNG encoding. Both pass native exit zero, content, original pixels and
exclusive ownership; JavaScriptCore creates one context and executes
1,938 / 1,951 evaluations. The selected cohort receipt is
`20261103-031356-b4de7787`, executable SHA-256
`2f0771f27b0993071f274965a240eded0393e899c482fd89b00cdee84454be2f`.
All fixture bytes, scripts, viewport/scale, settling, caches, RGB compatibility,
references and measurement endpoints stay unchanged.

The driver verifies pinned inputs after every trial and reports ownership
failure rather than identity drift. A later shared production publication
replaces the executable after cohort completion and before the independent
audit; 1,638 other input files still rehash unchanged. The superseded
executable cannot now be independently rehashed, and no bundle is copied.
This later replacement is distinguished from drift during a trial. Headless,
eleven smoke and eight SVG checks pass on the later candidate bundle
`20261103-031832-1710879f` (`903ed05b…`), not the cohort executable.

The static C-O3/no-GC two-layout probe preserves all geometry and its paint
dump but gives no meaningful total saving. It omits scripts, resources,
browser startup and PNG, and supplies no BBC credit. Experiment checks pass
14 cases under both policies in all three memory modes (**84 executions**).
With no reliable instruction benefit, `599b530` removes the engine change and
`db83d41` removes its comparison switch. Restoration passes eleven retained
cases in default, no-GC and the correct production-preallocated runtime
(**33 executions**), plus all **239 instruction-tool tests**. The initial
unittest import-path preparation failure is retained separately. Native
validation of the restored grid default awaits a containing completed bundle.

Exact raw intervals, commands, host telemetry, guard exits, diagnostics,
standalone results and identity qualifications are preserved in the
[tracked ledger](performance/bbc-grid-placement-20261103.json) and
`Build/bbc-grid-placement-20261103/`. BBC remains outside the homepage
instruction table. Its historical rendering/scripting limitations and earlier
broad failures still apply. Console diagnostics in cohorts 59 and 60 contain
the known `dotcom-bootstrap.js` CORS failure and no reported React hydration
error; this alone does not establish full React conformance.


## Retained flow trees across no-op restyles: cohort 61 (2026-11-03)

**The 10% target remains unmet.** All seven alternating control/Vox/Brave
triples are retained, bringing history to **61 cohorts / 1,460 attempts**.
All 21 native exits, complete content and exclusive ownership checks pass,
and all 1,639 pinned input files independently rehash unchanged. Every
original attempt also retains its actual post-trial hashes and timestamp;
`7ce073234` adds those success receipts without changing either endpoint.
No attempt is retried or excluded.

| Statistic | Vox candidate | Vox control | Brave lower bound |
| --- | ---: | ---: | ---: |
| Median launch-to-PNG instructions | 29,472,562,200 | 29,918,100,073 | 15,135,775,457 |

All fourteen Vox/control PNGs match their original reference. Their observed
median reduction is **445,537,873 instructions (1.4892%)**, with five improving
and two regressing matched pairs. Brave3 and Brave4 differ by **304,064** and
**64,177** pixels. Those failures invalidate acceptance, and even the raw
conservative instruction gate fails: **304,986,195,690 > 135,073,104,777**,
ratio **2.0321408660**. No accepted Brave advantage or BBC instruction-table
entry is claimed. The unchanged fixture, scripts, clock, private cache,
viewport/scale, settlement, RGB compatibility and capture scope remain in
force. Exact vectors, brackets, commands and host telemetry are in the
[tracked ledger](performance/bbc-flow-styles-20261103.json) and
`Build/bbc-flow-styles-20261103/flow-styles-matched-cohort/`.

Engine commit **`09dd7a7d4`** retains closed flow/grid/flex subtrees after a
no-op style recomputation replaces their DOM style object. It compares all
raw property inputs and flags, allowing newly allocated equal typed scalar
values while keeping identity checks for resource graphs. The font cascade,
selected font, generation, viewport, root metrics, subject, resolved cache
provenance and current color environment must match. Animated/unknown styles,
non-unit density projections, font/context changes and existing excluded
subtrees retain the complete builder. No new geometry cache is added. Control
**`a3c2e4921`** restores the prior style-identity requirement.

Separate production diagnostics witness actual subtree reuse after navigation
and before PNG encoding only in the candidate. Both pass content, original
pixels, native exit zero and ownership; JavaScriptCore creates one context
and executes **1,956 / 1,990 evaluations**. The cohort executable is
`1c463f8633d63c464346dbc2ce497017bb9a0a80c3f4b9ab452fe8f0edb47b65`,
receipt **`20261103-040243-ba54e3f3`**. The probes are absent in the unprofiled
cohort. The known BBC bootstrap CORS and rendering limitations still apply.

All **28 focused cases** pass enabled and disabled in default, no-GC and
production-bounded-preallocated modes (**168 executions**); all **240
instruction-tool tests** pass. A final C-O3/no-GC standalone frozen-HTML
probe witnesses reuse, preserves **2,855 nodes / 902 lines / extent 55,212,771**
and the identical paint-dump hash. Across two alternating pairs, second-layout
medians are **1,206,174,389.5 candidate / 1,519,807,941 control**, a
**313,633,551.5** instruction reduction. It excludes scripts, resources,
browser startup, window setup and PNG and supplies no BBC credit. Earlier
failed strict-identity and test-compilation preparations, plus the predecessor
probe, remain retained separately.

The broad run enters **486 cases in each of default/no-GC modes**, with
**483 passing and the same three known baseline failures** in each. All owned
feature inputs stay unchanged. This is not a full pass or cadence reset.
Fresh headless, eleven smoke and eight SVG checks initially all exit zero,
but a shared publication changes the executable and Skia library before the
identity check finishes; that attempt is rejected. A fresh validation on the
later completed **`20261103-040720-a4b16a6c`** bundle
(`ac089f6e9ee05ca73fad9393a5bf7b5cf4f2a5f676cb280da0763b113a7bde59`)
passes all those checks with unchanged runtime identities. It contains the
same feature and confirms that the earlier viewport/grid-placement experiments
are absent; it is distinguished from the cohort executable.


## Rejected deferred CSS resolution sharing (2026-11-03)

**The target remains unmet; history stays at 61 cohorts / 1,460 attempts.**
The R12 prototype reused an immutable resolved layout cache only when a no-op
style replacement was actually consumed and all original inputs still matched.
It retained fresh raw/mutation storage, rejected changed font/context/animation
inputs, and did not form chains of unused predecessor styles.

A separate production-compiler `v -profile -profile-no-inline` diagnostic
confirms **4,850 control / 4,570 candidate** full property resolutions, with
1,695 candidate reuse checks. Its instrumented timings supply no performance
credit. The final unprofiled C-O3/no-GC frozen-HTML probe retains two alternating
pairs: second-layout medians are **1,205,417,606.5 control /
1,205,328,499.5 candidate**, saving only **89,107** instructions. First layout
regresses by **2,574,527**. An earlier eager prototype also regressed. All
probes preserve 2,855 nodes, 902 lines, extent 55,212,771 and the original
paint-dump hash. This standalone scope excludes scripts, resources, browser
startup, window setup and PNG; it earns no BBC instruction credit.

All 32 focused cases pass both policies in default, no-GC and production-bounded
preallocated modes (**192 executions**). Successful final checks explicitly
use the pinned production compiler after the current compiler rejected an
unrelated concurrent sum-reference expression. Preparation failures, including
a test-only inline optional-argument lowering crash, are retained. The entire
prototype is removed; **84 restoration executions** pass across those three
memory modes, and its source hooks are absent. No native bundle restoration
claim is made because shared publication could contain transient experiment
code. No acceptance cohort, broad cadence reset or catalog entry results.
Exact counts, compiler identities, commands, profiles, rejected source and
checks are retained in the [tracked ledger](performance/bbc-noop-geometry-20261103.json)
and `Build/bbc-noop-geometry-20261103/`.


## Rejected image-containing flow trees: cohort 62 (2026-11-03)

**The target remains unmet.** Seven alternating control/Vox/Brave triples
bring history to **62 cohorts / 1,481 attempts**. All 21 native exits, complete
content and exclusive ownership audits pass. All 1,637 pinned files independently
rehash unchanged, and every attempt retains its successful post-trial input
receipt. No attempt, first-launch outlier or regression is excluded.

| Statistic | Vox candidate | Vox control | Brave lower bound |
| --- | ---: | ---: | ---: |
| Median launch-to-PNG instructions | 30,362,759,138 | 29,508,136,091 | 15,099,500,362 |

The candidate **regresses by 854,623,047 instructions (2.8962%)**, with three
improving and four regressing matched pairs. All fourteen Vox/control captures
match their unchanged reference. Brave4 differs by **64,177 pixels**, invalidating
acceptance; the raw conservative gate also fails: **318,773,530,540 >
135,353,319,102**, ratio **2.1196094739**. The exact counts, brackets, all attempts,
commands, host telemetry and adoption records remain in the
[tracked ledger](performance/bbc-flow-images-20261103.json) and
`Build/bbc-flow-images-20261103/flow-images-matched-cohort/`. The pinned
executable is `dc6b9b950efc257a654f9ee4fabaa11ca80c8256c8b89da22e254f591c74cede`,
receipt **20261103-053636-6b35402a**. Guard/driver exit one reflects the failed
acceptance checks; peak browser-inclusive sampled RSS is 1,442,512,896 bytes.

The prototype retained HTML image branches only while their source, natural
size and constructor metadata matched. It rejected SVG/resource replacements,
data/file images and other replaced content, and checked unavailable HTTP
images through the original SVG loader/MIME path. Geometry and containing blocks
still reran, including absolute-positioned placeholder images. Commit
**9969a278d** and its isolated control **b58c436f9** are removed by **a077833aa**
and **bd69501f7** after this browser regression.

The separate typed **DisplayStyleValue** comparison **4b9950bdb** remains:
blockification allocates equal display records, which can be compared by their
complete enum fields without relaxing resource identity. Its focused tests pass;
no isolated BBC instruction reduction is attributed to that change.

The final C-O3/no-GC standalone probe has an actual selected-subtree witness and
preserves 2,855 nodes, 902 lines, extent 55,212,771 and the unchanged paint dump.
Across two alternating pairs, second-layout medians are **1,174,548,382.5 control /
1,152,315,459.5 candidate**, saving **22,232,923** instructions, while first layout
regresses by **6,951,355.5**. It excludes scripts, resources, startup, window setup
and PNG and supplies no BBC credit. Earlier unused-path probes and all diagnostic
preparations are retained.

The initial completed build **20261103-052152-d626bb42** produces the identical
216,162-pixel italic-text mismatch in candidate, image-disabled and strict
style-identity controls. Those diagnostics are rejected. A separate font-boundary
probe initially breaks the adblock helper through an unresolved Skia symbol,
producing navigation-error pages and zero author contexts; both attempts remain.
Its weak-import revision succeeds on a later bundle, observes normal flags with
no synthetic slant, and matches the original pixels with or without clearing the
slant bit. No cause or rendering correction is attributed to these probes.
Final candidate/control production diagnostics on the cohort build pass content,
pixels, native exit and ownership, with the new path only in the candidate
between navigation and capture. JavaScriptCore executes **1,916 / 1,897**
evaluations in one context. All instrumentation is absent from the cohort.

All **27 layout cases** pass both policies in three memory modes (**162
executions**), with **27 additional CSS executions** and **241 tool tests**.
The final broad run enters **494 cases in each default/no-GC mode**, passing
**491** with the same three baseline failures in each. This is not a full pass
or cadence reset. Headless, eleven smoke and eight SVG checks initially all exit
zero but cross a shared publication and are rejected as stable-bundle evidence.
Their fresh rerun passes on unchanged executable/native-library identities.
After removal, **57 layout restoration executions** and **240 tool tests** pass.
A native rollback claim awaits a completed bundle containing the removal.

Low disk space required lossless compression of 109 completed diagnostic C/binary
artifacts from the R11/R12 directories, saving 1,901,550,265 bytes. Every archive
round-trips to its recorded original hash; the manifest is
`Build/bbc-flow-images-20261103/compressed-completed-artifacts.json`. Raw
measurements, logs, PNGs and durable ledgers remain unchanged. BBC is not added
to the homepage instruction table; the frozen workload and known limitations
remain unchanged.


## Pseudo candidate batching, first version: cohorts 63–64 (2026-11-03)

**The target remains unmet; no BBC improvement is accepted.** Cohort63 stops
when shared publication replaces the executable, worker and code signature
during Vox3. It retains all **eight attempts**, including that rejected trial,
and both complete triples. All eight captures pass content, original pixels,
normal exit and ownership; seven retain successful post-trial identity receipts,
and the eighth records the changed inputs. A separate erroneous CLI invocation
exits two before any browser starts and is retained as preparation, with zero
browser attempts. A new cohort is pinned to the newly completed bundle rather
than combining changed-build samples.

Cohort64 completes all **seven alternating triples / 21 attempts**, bringing
history to **64 cohorts / 1,510 browser attempts**. All 21 native exits, content,
exclusive ownership and post-trial identity receipts pass. All 1,637 input files
independently rehash unchanged. The original Vox/control pixels pass in all
fourteen attempts; Brave2 and Brave4 fail their original references.

| Statistic | Vox candidate | Vox control | Brave lower bound |
| --- | ---: | ---: | ---: |
| Median launch-to-PNG instructions | 29,151,808,791 | 29,188,738,481 | 15,057,693,466 |

The marginal median is lower by **36,929,690 (0.1265%)**, but only three matched
pairs improve and four regress. The paired median regresses by **205,354,095**,
and the paired mean also regresses. Variation is larger than the marginal
difference; this supplies no full-browser optimization credit. The conservative
Brave gate fails **306,772,026,460 > 133,900,574,202**, ratio **2.0619390578**,
and the two Brave pixel failures independently invalidate acceptance. The
[tracked ledger](performance/bbc-pseudo-candidates-20261103.json) preserves
all exact vectors, brackets, failed preparations, identities, raw commands and
host/adoption telemetry under `Build/bbc-pseudo-candidates-20261103/`. No sample
is retried or excluded to improve these statistics.

Engine **63efb717f**, with control **9427fbbf3**, builds one scalar candidate
union per element across consecutive rejected pseudo queries. A positive query
expires it before cascade or font work can run callbacks. It retains originating
and dedicated bucket semantics, including origins, layers, namespaces and shadow
scopes. The first implementation still builds a complete union when the first
query can return true cheaply; an adaptive early-exit follow-up is in progress.
This first-version evidence must not be attributed to that later implementation.

A separate `v -profile -profile-no-inline` C-O1 diagnostic sees 20,040 selected
queries in both arms. The control performs **59,096** direct RuleCache queries;
the candidate builds **16,506** unions. Its original bucket-predicate calls drop
from **107,100 to 60,522**, with **29,677** mask-bucket scans. These scope-limited
counts and instrumented timings are diagnostic only. The C-O3/no-GC standalone
frozen-HTML test has an actual reuse witness, unchanged 2,855 nodes / 902 lines /
extent 55,212,771 and the original paint dump. Two alternating pairs save
**10,099,704.5** first-layout and **13,020,538** second-layout median instructions.
It excludes author scripts, replayed resources, startup, native window and PNG
and earns no BBC credit.

Successful production diagnostics use **20261103-061731-b799d512**, executable
`3168441b4104efbbfd9dfdddafddaf91137b531b01f05e291387ca2c387b8954`,
with complete content, exact pixels, normal exit and ownership. The actual reuse
marker appears only in the candidate between navigation and encoded PNG; JSC
executes **2,067 / 1,986** evaluations in one context. Cohort64 uses **20261103-062721-16f243e9**, executable
`82859cf536e9944f307152e3ee4c62e930fb4a28651b5e057e524d3714127c8c`,
after the cohort63 publication; it is distinguished from the diagnostic build. No diagnostic probe is loaded in either unprofiled cohort.

All **18 focused cases** pass both policies in three memory modes (**108
executions**); **241 tool tests** pass. The broad run enters **490 cases per
default/no-GC mode**, with **487 passing and the same three baseline failures**
in each, with unchanged owned inputs. It is not a full pass or cadence reset.
Headless, eleven smoke and eight SVG checks all exit zero, but shared publication
changes runtime hashes during validation; that stable-bundle claim is rejected.
R13's native rollback validation remains pending. BBC remains outside the
homepage instruction table, with the same workload and limitations.

### Adaptive pseudo batching rejected (2026-11-03)

The follow-up `bd5a2a7a3` preserves positive-query early exits and shares a
common candidate mask only after a complete rejection. All 114 focused case
executions pass across both policies and three memory modes. The separate
requested `v -profile` diagnostic confirms the selected path; its 20,040 queries
use 43,127 bucket-iterator advances and only 80 original bucket-predicate calls,
versus 107,100 predicates in the control. Instrumented times earn no credit.
Two alternating unprofiled standalone pairs save **19,857,726** instructions
across first/second layout medians, with unchanged geometry and paint dumps.
Those script-free layout deltas exclude browser startup, resource replay and
PNG capture and establish no BBC browser gain.

All three subsequent cohorts retain the original launch-through-encoded-PNG
protocol. Cohort 65 stops after three attempted browsers when a shared bundle
publication changes pinned inputs. Cohort 66 launches all 21 browsers, but disk
exhaustion interrupts the final Brave capture and final guard/controller
receipts. Its missing exits remain unknown. The six completed triples and the
seventh Vox/control results remain available; no sample is excluded or repaired.
Completed diagnostic C/test artifacts were losslessly compressed with hash
manifests; raw counters, logs and PNGs remain intact.

Cohort 67 retains all 21 result receipts and unchanged original Vox/control
pixels. Its descriptive medians are **29,256,270,093 control** and
**29,376,953,822 candidate**, an observed increase of **120,683,729**. Three
matched pairs improve and four regress; the paired median regresses by
256,334,180. Brave pair 1 differs by 304,064 pixels, and pair 5 fails private
helper coalition ownership before a selected interval is available. The six
recorded Brave intervals have median 15,064,801,199.5; this is an invalid-cohort
statistic. The numeric gate also fails:
**311,735,280,420 > 134,857,329,507**, ratio **2.0804338437**. Neither this
cohort nor the retained interrupted cohorts establishes optimization credit.
The cumulative history is **67 cohorts / 1,555 browser attempts**.

Because neither batching variant establishes a BBC improvement, `f6944f9b5`
removes the engine experiment and `e641e1fef` removes its benchmark control.
All 42 restoration case executions and 241 instruction-tool tests pass. Broad
verification before removal enters all 486 selected cases in both memory modes,
with 483 passes and the same three known failures per mode; it is not a full
pass or a cadence reset. Two pinned candidate bundles separately pass headless
startup, eleven smoke and eight SVG checks with unchanged runtime identities.
Those checks also confirm the earlier R13 flow-image experiment is absent;
they validate the batching candidate before removal, while native validation of
the batching removal needs a later completed bundle. The **10% goal remains
open**, with no BBC homepage catalog entry. The
[durable ledger](performance/bbc-pseudo-candidates-adaptive-20261103.json)
retains exact counts, all failures, profiles, ownership/identity receipts,
commands, host telemetry, compression manifests and local evidence paths.

### Available image-request sources (2026-11-03)

`8b10299ff` reads an available image request's current URL before parsing
`srcset`, whose fallback the old constructor/relayout immediately overwrote.
There is no retained selection cache. All **96 focused executions** pass across
both policies and three memory modes, covering live replacements, request
availability, empty URLs, source fallbacks, constructor/relayout dimensions,
namespace guards and retained image painting. The benchmark control's 242 tool
tests pass. Separate original-origin diagnostics confirm this path before PNG,
original content/pixels, ownership, normal exits and actual JavaScriptCore
execution (1,903 candidate / 1,926 control evaluations).

Cohort 68 retains seven alternating control/Vox/Brave triples. Its observed
medians are **29,400,231,885 control**, **28,974,054,499 Vox** and
**15,094,259,216 Brave**. The Vox median is **426,177,386 lower (1.4496%)**;
five matched pairs improve and two regress, with paired median reduction
409,680,327. These are observed results with substantial variation. All 14
Vox/control PNGs are exact, and all content, ownership, adoption, identity and
normal-exit checks pass. Brave pair 7 differs by 64,177 pixels, invalidating
acceptance. The numeric gate also fails:
**296,509,379,560 > 135,657,192,798**, ratio **1.9671529102**.

The pinned executable is `d5414c4a59f0537b663d2a8530890315d4d4e5777115dd61a58bc325577111c8`
(receipt `20261103-072109-1e55b60e`). It contains R14 batching and the broader
exact-length prototype in both arms; this comparison isolates only image source
selection. It cannot validate their later removal/narrowing. Headless startup,
eleven smoke and eight SVG checks pass with unchanged executable/library
identities. Broad verification following this observed reduction remains
pending, with no cadence reset. The image-source change is retained; the
**10% BBC target remains open**, without a catalog entry. History reaches
**68 cohorts / 1,576 browser attempts**. The
[durable ledger](performance/bbc-image-layout-source-20261103.json) retains exact
counts, every regression and failure, full guard/identity/ownership receipts,
commands and local evidence. No isolated rendering, live-site or FPS gain is
claimed.

A later source-proof audit tightens the generated-C extractor to match only
unindented typed function definitions; the earlier expression could select a
call site. Rechecking the actual R14 union/adaptive functions and image-source
helper confirms the same function bodies (allowing only diagnostic string
symbol renumbering). Original proof files remain retained, with the corrected
hashes linked from both durable ledgers. No counts, endpoints, references or
performance credit change.

### Zero lengths and direct cascade reads (2026-11-03)

`ff990dbc8` skips the conversion/rounding context only for zero CSS pixel
lengths; nonzero, relative, nonfinite and saturated inputs retain the original
path. All 108 focused executions pass across both policies and three memory
modes. A broader exact-length prototype was discarded; its retained results
are not evidence for this narrower implementation. Two alternating standalone
control/candidate pairs save 10,608,172.5 instructions across the first/second
layout medians, with identical geometry and paint dumps. These script-free
layout deltas exclude browser startup, resource replay and PNG capture and
earn no BBC browser credit. See the [zero-length ledger](performance/bbc-exact-layout-lengths-20261103.json).

`0818d915e` reads retained typed cascade tags directly and preserves the original
unresolved, invalid and untyped-value paths. All 138 focused executions pass.
Preparation failures remain recorded, including an existing compiler bug that
also crashes the original control: the final composed fixture binds two
optional pointer arguments to locals, preserving the original cases and
assertions without modifying the canonical tests. All 243 instruction-tool
tests pass. The requested separate `v -profile` run records 30,989 cascade-list
calls and 235,321 declaration resolutions in each arm. Within that validated
scope, direct reads eliminate 235,323 typed-wrapper and 705,963 generic-wrapper
conversion calls. Profile timings earn no credit. Two unprofiled standalone
pairs save 62,345,738 instructions across layout medians; geometry and paint
dumps are unchanged. The generated-C proof checks actual typed function
definitions, rather than call sites.

Fresh original-origin diagnostics confirm both fast paths before encoded PNG,
original content/pixels, ownership, normal exits and actual JavaScriptCore
execution. Cohort 69 retains all 17 attempts and fails identity validation when
a shared publication replaces the executable. Cohort 70 completes seven
alternating control/Vox/Brave triples with **all 21 original PNG references
exact**, successful content, ownership, memory adoption, identity and normal
exit checks. Its medians are **28,835,768,721 control**, **29,172,047,727 Vox**
and **15,053,897,964 Brave**. The candidate median regresses by **336,279,006**;
four matched pairs improve and three regress, with paired median reduction
343,110,129. This mixed result establishes no isolated BBC improvement for
either change. The valid cohort fails the target:
**301,938,868,110 > 134,026,592,814**, ratio **2.0275452475**.

Broad verification enters all **490 selected cases per default/no-GC mode**,
with **487 passing and the same three known failures** per mode. Owned inputs
remain unchanged. This also supplies the pending broad check following the
image-source reduction, but is not a full pass or cadence reset. Two pinned
bundles pass headless startup, eleven smoke and eight SVG checks, with unchanged
runtime identities and both removed image-tree/pseudo-batching experiments
absent. This validates the earlier rollbacks on later completed bundles.

Native statistical and copy probes are separate diagnostics with a longer
eight-second settle period. The main-thread copy probe records 9,972,830 copies
of at least 256 bytes (3,870,634,236 bytes), including work through exit, and
motivated the cascade change. Its interposition overhead and endpoint prevent
instruction credit. Signal samples are biased around system calls and do not
establish CPU percentages. The [cascade ledger](performance/bbc-cascade-value-borrow-20261103.json)
retains exact counts, all preparation/interruption/regression attempts,
profiles, commands, guard exits, ownership, identities and local evidence.
History reaches **70 cohorts / 1,614 browser attempts**. The **10% target
remains open**, without a BBC homepage catalog entry, live-site, rendering-time
or scrolling-FPS claim.

### Selection-cache experiment removed (2026-11-03)

Extending the longhand cache to selection styles passes 216 focused executions
and 244 tool tests, but the separate frozen-HTML witness records no actual
selection-cache hit. Scanning all archived responses finds no `::selection`
rules. The experiment and its control are removed without a feature commit or
performance credit. All five standalone attempts, including their unchanged
geometry/paint and an erroneous post-run assertion, remain recorded in the
[rejected-experiment ledger](performance/bbc-selection-longhand-reuse-20261103.json).

A current-production checkpoint diagnostic preserves original content and
pixels, ownership and normal exits. Its corrected parser retains labels with
spaces, including detailed layout subphases omitted by the initial parser.
The [raw diagnostic ledger](performance/bbc-phase-instructions-20261103.json)
retains both extractions. Checkpoint gaps include interleaved callbacks,
asynchronous work and probe overhead; they are leads for investigation, rather
than exclusive function instruction costs or optimization credit.

### Keyword-length shortcut rejected (2026-11-03)

`2300d4ac0` avoids copying typed keyword wrappers before numeric length
rejection. All 108 focused executions and 244 tool tests pass. Separate
`v -profile` diagnostics confirm the selected scope, with 79,912 resolver
calls per arm and no generic-wrapper conversions in the candidate within that
scope. Two standalone layout pairs save 5,512,747 instructions across medians,
with identical geometry and paint dumps; this is no BBC browser credit.

Fresh production diagnostics confirm the actual path before encoded PNG,
original pixels/content, ownership and actual JavaScriptCore execution.
Cohort 71 retains all 21 launches. Observed medians are **29,136,371,921
control**, **29,668,120,108 candidate**, and **15,305,088,035 Brave**. Five
matched pairs regress and two improve; both the difference of medians and
paired median regress by **531,748,187**. Brave pairs 3 and 5 differ by
304,064 pixels, invalidating acceptance. The numeric gate also fails:
**302,149,303,840 > 135,435,582,306**, ratio **2.0078502918**.

Because no BBC gain is established, `ba7e391f0` removes the shortcut and
`a4bfdeede` removes its control. The retained rounding/cache restoration cases
pass in both policies and all three memory modes (84 executions); 243 restored
tool tests pass. Headless startup, eleven smoke and eight SVG checks pass with
stable identities on the candidate bundle before removal; native rollback
validation requires a later completed bundle. No positive BBC reduction is
credited toward the broad cadence, whose earlier three known failures remain.
The [durable ledger](performance/bbc-keyword-length-resolution-20261103.json)
retains every count, failure, profile, explicit preprocessor-normalization proof,
command and identity/ownership/guard receipt. History reaches **71 cohorts /
1,635 browser attempts**. The **10% goal remains open**, without a BBC homepage
catalog entry.

### Retained scalar invalidation comparisons (2026-11-03)

`5fc8829e0` compares complete retained scalar payloads during style invalidation,
preserving NaN non-reflexivity, inactive Display fields, live mutations and the
existing composite/untyped fallback. All **162 focused executions** and **244
tool tests** pass. A separate `v -profile` diagnostic confirms fewer wrapper
and deep-comparison calls within the selected scope. Two unprofiled standalone
pairs save **21,643,484.5 instructions** across first/second layout medians,
with unchanged geometry and paint. This diagnostic changes body color during
the second update and retains the then-present keyword shortcut in both arms;
it is not the frozen browser acceptance workload and earns no BBC credit.

Fresh original-origin diagnostics confirm this path before encoded PNG,
original content/pixels, ownership and actual JavaScriptCore execution.
Cohort 72 retains four launches and fails executable identity when a shared
publication replaces the bundle. Cohort 73 completes seven alternating
control/Vox/Brave triples with **all 21 original PNGs exact** and successful
content, ownership, adoption, identity and normal-exit checks. Its observed
medians are **29,640,606,074 control**, **28,994,053,751 Vox**, and
**15,082,070,722 Brave**. The difference of medians is **646,552,323 lower**;
four matched pairs improve and three regress, with paired median reduction
726,040,284. Large variation and regressions remain: these observations do not
establish that the full median difference derives from this path. The valid
cohort still fails the target:
**299,732,467,880 > 134,768,464,452**, ratio **2.0016494377**.

Broad verification enters all **490 cases per default/no-GC mode**, with **487
passes and the same three known failures** per mode, and unchanged owned
inputs. It is not a full pass or cadence reset. The pinned later bundle passes
headless startup, eleven smoke and eight SVG checks with stable identities.
That build also removes the rejected keyword shortcut, validating its rollback.
The generated-C comparison explicitly normalizes preprocessing of booleans,
null and diagnostic string symbols; it does not claim raw byte equality.
The [durable ledger](performance/bbc-borrowed-invalidation-values-20261103.json)
retains all results and interrupted/preparation attempts. History reaches
**73 cohorts / 1,660 browser attempts**. The **10% target remains open**,
without a BBC homepage catalog entry or live-site/rendering-time/FPS claim.

The separate broader [layout-scope profile](performance/bbc-layout-scope-profile-20261103.json)
records 5,064 function rows on frozen HTML with identical geometry/paint.
Its C-O1 instrumentation disproportionately charges small adapter calls, and
recursive inclusive times overlap. These call patterns guide investigation;
they are not unprofiled instruction savings or CPU percentages.

### Specified positioned-image geometry removed (2026-11-03)

`583d9c5cb` preserves specified positioned-image geometry when the first bitmap
arrives, without requiring a previous natural ratio. All 96 focused executions
and 245 tool tests pass, including full-rebuild paint comparisons, replacement
ownership, author ratios, percentage bases, intrinsic constraints and pending
styles. Preparation failures remain recorded: a synthetic bitmap lacked the
retained-replay flag, and a later fixture checked layout flags before flushing
styles. The corrected selection retains the relevant inputs and assertions.

The completed production bundle contains the code, but both original-origin
diagnostic arms show **no actual fast-path hit**, despite exact original pixels,
complete content, ownership, normal exits and JavaScriptCore execution. Two
additional observer captures also show no hit. The script-based style extension
is ignored by Vox's native audit and supplies no style evidence; the later
native layout observer retains actual image classes and width/height snapshots.
The precise cause of ineligibility remains unproved. The controller stops before
launching an acceptance cohort, so history stays **73 cohorts / 1,660 browser
attempts**, and no instruction reduction is attributed to an unused path.

`44f6e03c8` removes the engine experiment and `f1c018d66` removes its control.
All 33 focused rollback checks and 244 restored tool tests pass; native rollback
validation awaits a later completed bundle. Shared production failures during
this experiment retain their receipts: missing ECDSA dispatch entries were
corrected by the concurrent loading work, followed by an input-drift rejection.
A separate link probe succeeds with the corrected dispatch and fails when its
seven ECDSA mappings are deliberately undefined. No foreign implementation was
changed here. The [durable ledger](performance/bbc-positioned-image-specified-size-20261103.json)
retains every diagnostic, preparation failure, command and exit. The **10% BBC
goal remains open**, without a homepage catalog entry.


### Parent longhand hash hints (2026-11-03)

`a3a76bc8a` reuses inherited-parent bucket hashes within the existing style
batch, guarded by parent identity, graph-token identity and mutation revision.
Every restoration still checks current and retained original payloads. Direct
mutable-box changes cannot authorize a stale restore; an untyped direct change
also prevents publication. The hint table is bounded to 1,024 parents and
retires at the outer batch boundary. All **252 focused executions** and **222
selected instruction-tool tests** pass.

Separate `v -profile` runs observe 4,065 inherited-hash calls in the control
versus 2,981 in the candidate, and 560,517 versus 466,209 value-hash calls,
within 5,124 key queries in each arm. Two unprofiled standalone pairs reduce
first/second layout medians by **12,022,769.5 instructions** in total, with
identical geometry and paint. These frozen-HTML diagnostics exclude scripts,
resource loading, native window setup and PNG capture and earn no BBC credit.
Fresh original-origin browser diagnostics confirm an actual hint hit before
capture only in the candidate, complete original content/pixels, ownership,
normal exits and JavaScriptCore execution in both arms.

Cohort 74 retains all seven alternating control/Vox/Brave triples and all 21
original PNGs are exact. Control and candidate medians are **29,014,217,889**
and **29,284,096,731**: the candidate median regresses **269,878,842**, despite
four pairwise wins and three regressions. Brave trials 5, 6 and 7 fail helper
ownership; their absent instruction bounds are not inferred. The four observed
Brave lower bounds have median 15,176,889,092.5. Acceptance is invalid and the
available numeric gate also fails: **304,887,305,890 > 135,064,777,491**.
The hint remains a small guarded implementation improvement with no established
BBC browser reduction. No new BBC savings are credited toward broad cadence;
the earlier broad batch still has its three known failures and no reset.

The cohort's completed bundle passes fresh headless startup, eleven smoke and
eight SVG checks with stable identities. It also lacks the retired specified
positioned-image marker, supplying that experiment's pending native rollback
check. The generated-C proof explicitly records preprocessor and checked-array
accessor symbol spelling differences; it makes no raw-byte equality claim.
The [durable ledger](performance/bbc-parent-longhand-hash-20261103.json) retains
counts, receipts, diagnostics, profiles and native checks. History is **74
cohorts / 1,681 browser attempts**. The **10% target remains open**, without a
BBC homepage catalog entry.

Two separate [thread diagnostics](performance/bbc-thread-cpu-diagnostics-20261103.json)
retain original pixels/content and pin executable/native inputs. Cumulative
thread CPU observations place most observed work on one thread; the second
probe explicitly authenticates the main thread and records CPU-delta-weighted
frame-pointer stacks before PNG. Geometry queries within script event callbacks
and repeated layout/style paths are investigation leads. Sampling can miss
short-lived threads, an interval-end stack can differ from the work in that
interval, and inclusive stacks overlap. Probe overhead and unresolved native/JIT
frames prevent CPU percentages, exclusive function costs or instruction credit.


### Initial viewport ordering and missing historical inputs (2026-11-03)

`d2ee07c63` installs the actual initial CSS viewport before device-layout
eligibility queries computed display styles. Previously those queries could
compute the document at its default 800×600 viewport, then discard that work
after setting the actual size. At 2× page zoom without a media-query match
change, the old order can even retain default-viewport style provenance until
another restyle. The matched control `79d1b09b4` preserves that old order.

All **42 focused executions** pass: three new cases plus four existing device
layout cases, both ordering policies and all three memory modes. All **223
selected instruction-tool tests** pass. The pinned production bundle contains
the helper and its caller, confirmed by anchored generated-C inspection. Fresh
headless startup and all eight original SVG guards pass with stable executable
and native-library identities. Nine smoke comparisons pass initially; two diff
compilations fail on unavailable SDK headers. Their already captured expected
and actual PNGs are byte-identical and pass resumed comparisons with a separately
verified canonical diff binary. This is an eleven-case composite validation;
the initial smoke controller's actual exit remains 1.

A separate diagnostic on the recovered original 642,096-byte HTML records
**5,059 → 2,550 style computations**, eliminating **2,509 duplicate computations**.
Both arms have 2,550 styled elements and identical signatures over all stored
longhand `css_text` values plus inherited/important flags. This excludes author
scripts, resource replay, native window setup and PNG capture, and earns **no
BBC instruction credit**. Its V-generated profile instrumentation has the
intended scope disabled because the first selector omitted the language-level
`main__` prefix; only explicit style counters/signatures are used. Corrected
profile attempts retain an SDK-header compile failure and a later C-generation
failure in concurrent scalar-font work. Missing final receipts remain unknown,
not successful profile exits. The earlier completed parent-hash `v -profile`
results remain historical evidence.

Concurrent cleanup removed the original sealed **595-response BBC homepage
archive**, both fixed reference PNGs, the historical HN pixel-diff binary and
completed BBC benchmark/profile directories. This task did not remove them.
Committed ledgers preserve exact raw instruction counts and the independent
checks completed before cleanup, but missing linked Build artifacts are no
longer available for reinspection. A hash search recovers **108 of 590 distinct
response bodies**, including the exact original HTML; the complete manifest and
remaining bodies are unavailable, and no local APFS snapshots were found.
The retained diagnostic PNG has the exact SHA of all fourteen independently
verified Vox/control captures in cohort 74. That certificate does not restore
the original reference bytes or the Brave reference.

A [committed compressed recovery archive](performance/raw/bbc-surviving-style-diagnostic-20261103.tar.gz)
preserves the surviving raw diagnostic, image, identities and 96 cached bodies.
The separately reconstructed diff tool agrees with a retained older binary on
known exact and one-pixel fixtures; this does not replace missing BBC references.
The [viewport ledger](performance/bbc-initial-resource-viewport-20261103.json)
records focused/native checks, preparations, diagnostics and recovery hashes.
Its [committed raw evidence](performance/raw/bbc-initial-resource-viewport-20261103.tar.gz)
retains the actual logs, commands, guards, focused fixtures and native PNGs, with
all archived files authenticated by SHA-256 after a round trip.
No cohort 75 has launched: history remains **74 cohorts / 1,681 attempts** and
the **10% target remains open**, without a BBC homepage catalog entry. Continuing
the same acceptance workload requires restoring its sealed archive and fixed
references; a fresh BBC acquisition would need an explicitly documented new
control/reference baseline and no historical optimization credit.


### Runtime-selected viewport V profile (2026-11-03)

A follow-up uses the existing `v -profile - -profile-no-inline` diagnostic
binary and recovered original HTML. LLDB verifies entry to the viewport/style
root, enables the generated profiler state with memory readback, steps out of
that root, then disables profiling before signature construction. The executable
and native inputs remain unchanged. This makes the scope explicit at runtime;
it does not rewrite the earlier incorrect compile-time selector as a success.

The root executes once in each fresh arm. Property computations fall from
**5,176 to 2,616**, style recomputations from **5,059 to 2,550**, and matching-rule
collections from **22,492 to 11,384**. Both native processes and memory guards
exit zero, and the final stored-value/inheritance/importance signature remains
identical across all 2,550 styled elements. The initial debugger attempt stops
during process exec and refuses to enable profiling outside the selected root;
that failure is retained. An analysis correction reads root profiler row names
with their `main__` prefixes; the successful raw runs are not repeated.

Debugger stops and profiling overhead prevent timing or instruction credit.
This diagnostic excludes resource replay, author scripts, native window setup
and PNG capture. It supplies **no BBC acceptance cohort or catalog claim**.
See the [profile ledger](performance/bbc-viewport-debugger-profile-20261103.json)
and [authenticated raw evidence](performance/raw/bbc-viewport-debugger-profile-20261103.tar.gz).
The original sealed replay and fixed pixel references are still missing; the
10% instruction target remains open.


### Preserve exact inputs before launch (2026-11-03)

The BBC runner now accepts an optional preservation destination:

```sh
--preserve-inputs docs/performance/raw/bbc-inputs-MANIFEST_SHA.tar.gz
```

Before launching a browser, this saves the original sealed replay manifest,
every referenced response body and each supplied reference PNG, preserving
encoded bytes exactly. It reads back and verifies every member, then checks
source and archive identities again when pinning the cohort. A matching existing
archive is verified and reused; another session's file is never overwritten.
Missing/corrupt bodies, changed references, source mutation, extra archive members
and links fail preservation. The destination must be outside both `Build/` and
the trial output directory so build cleanup cannot remove the preserved inputs.
The preservation receipt and archive identity are included in `inputs.json`.
This setup runs outside both browsers' instruction endpoints.

All **11 preservation tests**, **224 selected instruction-tool tests** and **seven
sealed-replay tests** pass (242 cases). The retained first test selection has one
path-alias fixture failure: `/var` and `/private/var` need the same canonical
receipt path. A real invocation against the deleted original fixture exits 1
before launching a browser or creating trial/export output. It does not invent
a replacement workload or increment the cohort history. See the
[tooling ledger](performance/bbc-input-preservation-20261103.json) and
[authenticated raw results](performance/raw/bbc-input-preservation-20261103.tar.gz).
The original archive/reference files remain missing, the dataset choice remains
unresolved and the **10% BBC instruction target stays open**.


### Fresh frozen homepage protocol (2026-11-03)

Acquisition records the original HTTPS response bodies through a fresh live
Brave process, with original author scripts enabled. Complete semantic checks
pass. Eight transport timeouts in the additional resource acquisition are
retained; a separately recorded stage obtains those bodies. A subsequent stage
adds the consent frame and its authored resources before reference selection.
The complete original archive contains 609 responses and 35,282,023 body bytes.
Its 652,229-byte homepage has SHA-256
`3b15b815c5f7f2bd42bd02d742253b16134605355a04df706a5fd6316795eb90`.

The frozen replay inserts the same Date shim before author scripts in both
engines, at epoch **1793697943543 ms**. Original response bytes remain preserved;
monotonic timers and Math.random remain unchanged. The resulting document SHA
is `ecda950d0837c3efe51b75ed08fadd526a6453c3cdcff68361e861cf468d0585`.
Both engines use original origins, a sealed local HTTPS replay with no live
forwarding, original author scripts, empty private profiles/caches, a native
1024×768 CSS-pixel viewport at scale 2, visible-image decode and two seconds of
settling. OS filesystem/shader caches remain warm. Unmapped random analytics,
browser background endpoints and privacy categories/metrics requests are denied;
this is a frozen-page workflow rather than a live-site instruction claim.

Counters cover exclusive coalition creation through encoded document PNG
availability, including startup and native window/target setup. Vox ends before
PNG file write; Brave includes CDP delivery. Semantic audits and teardown follow
the endpoint. Owned exited tasks and explicitly permitted owned system services
are counted; GPU execution and services outside those coalitions are excluded.
Both cohorts use the adoption-aware default 12 GiB memory guard and preserve
actual browser/benchmark/guard exits, host load and identities. Each trial
verifies all pinned inputs again. Shared production changes between cohorts
receive no optimization credit.

All new-workload reference PNGs remain fixed after selection. Per-engine
stability is distinct from cross-browser equality: **2,602,001 / 3,145,728 pixels
(82.7154%)** differ between engines. Every source headline and photograph URL is
checked; known Vox layout/DOM differences and unavailable local Arial fallback
faces remain. No masks, tolerance adjustments or reference replacements earn
instruction credit.

A separate interposer verifies successful JavaScriptCore evaluations whose
hashes exactly match **72 archived external author scripts**, including BBC
framework/application chunks. Its PNG remains exact. This establishes actual
page-code execution; it does not establish complete scripting or DOM parity.
The copy diagnostic's attempted PNG-end hook did not fire, so its counts also
include audit/teardown work and supply only leads, with no timing or instruction
credit. The raw source, commands, logs and initial overflow-limited attempt are
retained. The subsequent retained-scalar length change has focused checks and a
separate V profile; production BBC acceptance is still pending.


### Retained scalar layout lengths (2026-11-03)

The new path reads absolute-length and percentage payloads directly after the
ordinary animated/important-property lookup, preserving both rounding policies,
percentage-basis quantization and the original relative/calculated/untyped
fallback. It retains no value across calls. The [implementation and focused
checks](performance/bbc-borrowed-layout-lengths-20261103.json) are committed, with
an isolated copying control for subsequent matched trials.

All **120 focused executions** pass: 20 cases, two arms, three memory modes.
All **248 instruction-tool tests** pass. The corrected scoped `v -profile`
run enters its root once per arm; 140 public length resolutions use 280 copied
value conversions in the control versus 140 in the candidate, with the latter
140 belonging to the unchanged semantic oracle. Generated C confirms direct
scalar reads. This is diagnostic call evidence, not production timing or BBC
instruction credit. Initial missing-CoreGraphics harness links and an implicit
embed_file profile-import failure remain recorded separately.

The observed 111,082,315-instruction marginal-median point in cohort 76 exceeds
the 5,000,000 broad-check cadence, despite its mixed pairs and lack of robust
speedup credit. A fresh broad batch enters all **490 selected cases per memory
mode**; **487 pass and three previously recorded tests fail** in both default
and no-GC modes. Current failures are text-input baseline 13.5 versus 13,
radio baseline 16 versus 15, and trailing collapsed margin height 40 versus 60.
Selected test and owned implementation hashes remain unchanged. The actual
failing exits are preserved; this supplies **no full pass or cadence reset**.

A refined copy diagnostic on the earlier completed bundle verifies its stop at
encoded PNG, reports zero table overflow and validates the array-push call site
before parent attribution. Its fixed pixels remain exact. Rule-candidate
collection is a further lead; copy counts do not measure instruction cost.
The previous unbounded-end diagnostics remain retained with their limitations.

Production validation remains blocked: the latest completed bundle lacks the
new path. Several shared builds fail on concurrent raster-layout changes or
changed preprocessing inputs. Build `20261103-130858-726a288c` is terminated by
the unchanged **12 GiB** memory guard at **12,904,431,616 bytes observed RSS**
(actual compiler child signal -9; build exit 125). A bounded ten-minute watch
exits 2 without launching another browser. **Cohort 77 is prepared but has not
launched**, so history stays at 76 cohorts / 1,723 attempts. No instruction
saving is attributed to the new path and no BBC catalog entry is added.
See the [focused/profile/broad/build ledger](performance/bbc-borrowed-layout-lengths-20261103.json)
and [authenticated raw receipts](performance/raw/bbc-borrowed-layout-lengths-20261103.tar.gz).


## Whole-browser V profile and scalar-length rollback (2026-11-03)

The shared production build recovered within its unchanged memory guard. Fresh
control/candidate scalar-length diagnostics both pass full content, normal
exits and the fixed Vox pixels, but neither exercises the new fast path. An
independent encoded-PNG-bounded copy probe identifies the legacy conversion's
264-byte value-copy site and samples **317,360 values, all Keyword** (tag 0).
The scalar experiment handles absolute lengths and percentages, so these
queries remain ineligible. The earlier build-blocked ledger above is historical;
the native eligibility failure is the reason to remove the experiment and its
benchmark control (commits `626dfebe2` and `1fd2b0c09`). All 15 existing length
cases pass in default GC, no GC and bounded preallocation: **45 executions**.
All **247 remaining instruction-tool tests** pass. No BBC gain is attributed.

A real whole-browser **`v -profile - -profile-no-inline`** diagnostic now also
completes the original-script frozen homepage, rather than only a microprobe.
The generated C proves that current-V double-underscore entry symbols enable
profiling in `install_loaded_page`, `draw` and `poll_javascript_tasks`. Its
standalone diagnostic executable links the canonical native libraries; no app
bundle or repository tool is copied. The profile has 9,589 function rows and
passes unchanged Vox pixels, all 91 headlines, 125 image elements and the full
content audit. A separate JavaScriptCore source hook verifies **72 exact unique
archived external author scripts**, 79 nonempty-URL evaluations total, with no
duplicate URL execution. The scalar success-report function is absent.

The profile records 31,085 uncached inline-formatting calls, 15,408 grid-layout
calls, 299,434 box-model-edge resolutions and 1,173,764 stylesheet-invalidation
subtree visits inside the selected roots. These are optimization leads, not
instruction credit. This instrumented C-O1 run includes timer overhead and
waits, can interleave counters across threads, and selected-root work can
continue after PNG capture. Instrumented self/inclusive times do not establish
exclusive CPU costs. The copy probes separately stop at encoded PNG.

All profile, diagnostic and cohort commands, actual guard/driver/native exits,
identity records, logs, PNGs, fixed-reference comparisons and raw counters are
retained in the linked ledger and archive. The previous broad batch remains
487/490 per memory mode, with the same three recorded failures; there is no
full-pass or cadence reset. BBC remains outside the optimized catalog.


## Pending pruning and fixed rendering policy (2026-11-03)

The whole-browser profile leads to a smaller stylesheet-invalidation search:
an already wholly dirty subtree needs no additional primary or pseudo-element
marking before the normal invalidation drain. Trailing universal combinators
retain traversal because they can affect siblings or table columns outside the
subtree. Commits `d9fd1df79` / `f88a9fbf0` implement the path and its matched
control. All **48 focused cases × two arms × three memory modes = 288
executions** pass. The first test fixture bypassed the DOM invalidation drain;
its three failed candidate jobs remain retained. The corrected fixture uses
`Document.update_style()` with a browsing context and keeps the original color
and invalidation assertions.

Fresh canonical production proves the pruning path executes on BBC before
encoded PNG, and both arms pass full content and normal native exits. However,
both produce the same PNG that differs from the established reference by
**45,346 pixels**. Cohort 78 is held. A normalized comparison of generated C
traces this to separate Retina correctness work (`ae71352ba`, later
`178c506e9`), which snaps HTML paint and rounds inline font metrics on the
presenting device grid. Image pixels and audit rectangles stay unchanged;
some text moves by one physical pixel. Disabling the new preload work or
identical-input cache does not restore the old reference. These are diagnostic
observations, not optimization credit. One attempted density switch did not
exist; that result is retained and supplies no density-path evidence.

For continued frozen-page comparisons, **`--retain-logical-paint-snapping`**
explicitly retains the original logical-grid paint and inline font metrics in
**both Vox arms**. The original references remain unchanged. Document DPR,
1024×768 viewport, native capture scale 2, selected fonts and author scripts
stay fixed. Default Vox rendering continues to use the presenting device grid.
Compatibility commits `103715a68`, `f70238e2f` and `dbbd95ab4` earn no instruction
credit. Any later result using this option must disclose that rendering policy;
it cannot establish a result for the new default Retina path. All **36 current
focused executions** pass: default/archived layout 5/2 cases and font metrics
4/1 cases, across three memory modes. Original device-grid cases run only in
their declared default arm; their assertions remain unchanged.

A second candidate normalizes the unused stored numeric height in closed,
text-only inline measurement when height is indefinite. It retains width,
availability, constraints, definiteness, font/style and input-ownership checks.
Commits `57010b2cd` / `9b20023fa` pass **six cases × two arms × three memory
modes = 36 executions**. It still requires a separate production BBC
eligibility witness before any matched cohort or attribution. The latest full
instruction-tool selection passes **263 tests**; earlier 248/261-test selections
and their actual exits are retained.

The JavaScript evaluation follow-up rejects another speculative lead:
1,993 internal evaluations before PNG consume only 21,504,380 recorded
own-thread CPU nanoseconds in total. API durations include synchronous host
callbacks and can overlap during reentry, so this is not exclusive engine CPU
or an instruction estimate. No evaluation-cache optimization is attributed.

See the [pruning/policy/key ledger](performance/bbc-pruning-policy-checks-20261103.json)
and [authenticated raw checks and diagnostics](performance/raw/bbc-pruning-policy-checks-20261103.tar.gz).
At this checkpoint, cohort 77 remains the latest instruction result and the
10% target is unmet. Native checks and cohorts 78/79 await a completed canonical
bundle with their required code and fixed rendering policy. No catalog entry,
robust instruction saving, full broad pass or cadence reset is claimed.


## Pruning rejection and current-V allocator repair (2026-11-03)

The pending pruning experiment above completed as cohort 78 with all 21 trials
valid, but regressed. Engine rollback `ed7c15257` and tool rollback `628b9f2b1`
remove it; the original failed fixture, rendering diagnostics, watch timeouts
and a prelaunch wrapper error remain preserved. No cohort was repeated to seek
a favorable sample. The exact counter intervals and all integer arithmetic are
recomputed from launch counters in the linked ledger.

Current V replaced its private per-thread preallocation cache with a locked
process-wide pool, removing a field mirrored by the platform adapter. This
blocked production and preallocation checks. Commit `a2baaa98a` follows the
current emitted C pool layout, derives capacity from its array addresses, and
holds the allocator's own atomic lock while retiring detached pages. Existing
block/scope ABI guards and memory limits remain. Eleven focused test functions
pass across default, no-GC and bounded-preallocation processes, including four
concurrent refill workers and preservation of live bytes. Retirement-specific
assertions execute in preallocation mode. All 45 rollback cases then pass in
all three memory modes. Earlier compiler failures remain retained.

A shared-index mistake included nine already-staged Performance API paths from
another session in that allocator commit. That work and linear history are
preserved. The allocator checks do not validate that separate feature; subsequent
commits select explicit paths with `git commit --only`. The linked ledger names
the affected paths. BBC remains outside the catalog, with no full broad pass
or cadence reset.


## Indefinite-height key cohort and broad checks (2026-11-03)

The pending key experiment completes as cohort 79 on pinned production
`928ebab161db15b7268b7ad984ef61a0da283e03599fcb889754dcf6d739667d`.
Fresh diagnostic launches pass the original Vox pixels and full content. The
candidate reuses text measurements across differing stored indefinite heights;
control retains those heights in its key and does not report this path.
A separately hashed JavaScriptCore source hook verifies 72 unique external
archived author scripts, each executed once with exact original bytes and no
reported exception, in each arm. This establishes the selected execution path,
not full BBC scripting/DOM parity. Instrumentation supplies no instruction credit.

All 21 unprofiled cohort attempts are valid and retained, but the target and
conservative matched-control gates fail. The 41.4M marginal median point
reduction exceeds the broad-check cadence, despite variation preventing robust
credit. All 490 selected cases enter in both default GC and no-GC modes;
487 pass and the same three names fail in each mode: text-control baseline,
radio-control baseline and trailing collapsed margin. Inputs are unchanged;
compiler, runtime and guard exits are retained. No full pass or cadence reset
is claimed. The test selection includes current code rather than reusing an
older compiled binary. The implementation remains, without a BBC saving claim.

The next experiment permits unchanged flex/grid item paint projections to use
the existing ordinary-box cache, adding both item roles to its key. All five
focused cases pass in both arms across default, no-GC and bounded-preallocation
modes (30 executions). Their complete payload oracle now compares immutable
cold paint snapshots by value, preserving borrowed-owner identity checks; the
old helper's decoration-pointer failures in both arms remain retained.
Commits `1f1873a05`, `5ce75b50b` and `1ba6251c3` contain the helper repair,
implementation and matched benchmark control. All 264 instruction-tool tests
pass. Native eligibility and unchanged pixels still need a completed production
bundle before cohort 80 can launch. No catalog entry is added.


## Flex/grid paint cohort and registry follow-up (2026-11-03)

The pending paint experiment completes as cohort 80 on production
`8cce637a6dbdaf684d997c8fdf47a6eade837a9d0edbb31c95a1e3222e821434`.
Separate fresh diagnostic launches show candidate-only reuse of unchanged
flex/grid item paint before encoded PNG. Both arms retain exact original pixels,
full content and 72 unique external author-script executions through JavaScriptCore,
each matching archived bytes with no reported exception. All 21 unprofiled
captures pass the complete acceptance audits; the instruction gates still fail.
The marginal median reduction is variable and receives no robust credit.

The repeated broad selection enters all 490 cases in both default and no-GC
modes, with 487 passes and the same three failures in each. Every selected
input hash is unchanged. This supplies no full pass or cadence reset. All
focused checks, the earlier decoration-pointer oracle failures, actual guards,
commands, PNGs, counters and native exits are retained in the paint ledger.

A longer native process sample requests 15 seconds and ends with the observed
browser lifetime, about 7.7 seconds after attachment. Its content and original
pixels pass. It includes waits, host contention and post-PNG work; neither its
stack weights nor requested duration establish instructions or exclusive CPU
time. It identifies repeated DOM/registry walks in tab-loading state checks.

Commits `42611f35b` / `6ea9375e9` use the same registry as container discovery
to prove that a document has no owned navigable containers before walking its
DOM. A detached same-document container deliberately falls back to the full
walk. Live ownership reads preserve registration, removal, adoption, tree order,
nested documents and shadow trees without a new cache invalidation scheme.
Five focused cases pass in both arms across all three memory modes (30
executions), and all 266 instruction-tool tests pass. The first shadow fixture
used a non-HTML namespace and failed before traversal in both arms; it is
retained, and the corrected fixture explicitly creates HTML elements.
Production BBC eligibility and cohort 81 remain pending; no registry saving or
BBC catalog entry is claimed.


## Registry cohort and main-thread profile correction (2026-11-03)

The pending registry experiment completes as cohort 81 on production
`6638f91b535e23667fcccd363a01067e334d109827c104d804c51cf2f05d574a`.
Separate fresh diagnostics witness the registry-negative proof for BBC only in
the candidate, before encoded PNG. Both arms keep original pixels and full
content; the independently hashed JavaScriptCore hook verifies 72 exact unique
external author scripts per arm, each executed once without a reported exception.
All 21 unprofiled trials pass their audits. The target and conservative matched
control gates still fail, so no robust instruction saving is attributed.

All 490 broad cases enter in both default and no-GC modes after the 149.1M
marginal median point reduction, with the same three failures in each. Selected
input hashes remain unchanged. The 30 focused registry executions, earlier
namespace-fixture failures and initial compile errors remain retained. Their
exact test sources are recovered and verified against each run's recorded SHA256.
There is no full broad pass or cadence reset.

The next diagnostic isolates the V profiler's scope-enable gate by thread.
Current V already makes its measured-child-time accumulator thread-local, but
its shared scope gate can admit background calls while a main-thread root runs.
The diagnostic changes only that generated C flag to thread-local, initially
false, and selects `main__main` after V's startup reset. It continues to use V's
elapsed timers, including waits and work after PNG; it cannot establish exclusive
CPU times or instruction gains. The first compile used the earlier production
recipe's incompatible staged allocator and failed before launch. It is retained;
the corrected build uses the latest completed production recipe. Its page run
and profile analysis are pending. BBC remains outside the catalog.


## Covered stylesheet invalidation and cohort 95 (2026-11-05)

A pending full document cascade can cover a primary stylesheet invalidation
walk. The shortcut retains pseudo-element anchor and trailing-universal walks,
falls back during an active computed-property batch, and requests a render
wakeup before returning. Its 360 final focused executions pass across three
memory modes and both arms, including effective cascade, pseudo-elements and
paint-revision checks. All 281 instruction-tool tests pass. The separate
`v -profile` and verified production sample remain diagnostic evidence only;
see the [coarse profile](performance/bbc-coarse-profile-20261104.json) and
[production sample](performance/bbc-current-production-sample-20261104.json).

Fresh native launches on executable `809de706` show the stylesheet shortcut
before encoded PNG only in the candidate. Both arms retain the original
pixels, complete content and 72 exact external author-script executions through
JavaScriptCore, with actual native images pinned. An experimental styled-inline
cache passed 225 focused executions but showed no BBC reuse marker. It was
removed in `d5de340eb`, followed by 126 passing focused executions. The pinned
cohort bundle still contains that extension equally in both arms; it cannot
validate the later source revert. An initial joint validator therefore fails
its inline eligibility requirement; the subsequent CSS-only validator passes.
A supplemental metadata label accidentally tested the CSS marker for inline
eligibility. Independent audits correct that label while preserving all raw
logs and primary validation gates.

Cohort 95 completes all seven alternating control/Vox/Brave triples with all
21 capture audits passing. Medians are **27,755,844,086 control**,
**27,718,688,336 Vox**, and **17,493,927,793 Brave lower bound**. The
37,155,750-instruction median point reduction is variable: four matched pairs
improve and three regress, and highest-candidate/lowest-control is 1.08564.
No robust saving is attributed. The strict target fails:
`288761570520 > 156545800641`, ratio **1.66012**. Driver and memory guard exit
1 because that target fails; every browser exits normally.

The unchanged protocol measures exclusive coalition creation through encoded
document PNG, including startup and native window/target setup. Vox ends
before file writing; Brave includes CDP delivery. Audits and teardown follow
the endpoint. The frozen 609-response replay retains original author scripts,
1024×768 CSS viewport, scale 2, two-second readiness/decode settling and fresh
private profiles/caches; OS filesystem/shader caches remain. Exited-task
aggregates and allowed owned services are counted, GPU/outside work excluded.
Exact per-engine references do not establish cross-browser equality: the
82.7154% cross-engine pixel difference and incomplete DOM/script support,
performance.measure gap, local Arial fallback and paint_decoded=false remain.
There is no live-site, rendering-time or scrolling claim.

The 37.2M point triggers broader verification despite its variation. Both GC
modes enter all 514 selected cases, with 511 passes and the same three known
baseline failures each. Inputs remain unchanged; no full pass or cadence
reset is claimed. History now contains **95 attempted cohorts / 2,085
acceptance browser attempts**; diagnostic/runtime preflights remain separate.
BBC homepage stays outside `OPTIMIZED_SITES.md`. See the
[focused ledger](performance/bbc-covered-inline-focus-20261105.json),
[cohort and exact counts](performance/bbc-covered-cohort95-20261105.json), and
[broader checks](performance/bbc-covered-broad-20261105.json). Earlier
[cohort 93](performance/bbc-relative-cohort93-20261104.json) and
[cohort 94](performance/bbc-svg-cohort94-20261104.json) remain retained.


## Final-flex measurement reuse and image trees (2026-11-05)

Final flex layout can now consume a result already owned by the same layout
pass. Exact keys preserve sizes, constraints, edges, immediate containing-block
bases, parent identity and item roles. A guarded extension ignores distant
ancestor heights only when the entire closed subtree proves them unused. Normal
flex baseline clearing and descendant copy-on-write remain intact. The first
exact-key version passes 207 focused executions but has no BBC hit. The
height-independent extension passes 216 executions and has candidate-only
pre-PNG native hits on builds `e6f36b36` and `1bf1abc8`. Each native arm keeps
original pixels, complete content and 72 exact external author scripts through
JavaScriptCore, with loaded native images pinned.

Unchanged branches containing decoded raster images can also keep their tree
structure while geometry runs in a fresh state. Every cached validation checks
the live provider kind. SVG, unavailable, generated, positioned and CSS
replacement images retain the complete builder path. Its 168 final executions
pass across three memory modes and both arms, including source/natural-size
changes, retained old pixels and full-builder oracles. Earlier inactive-document
and unchanged-source fixture failures remain retained. The image-tree marker
appears only in the candidate on `aa370dd4`; it is absent on `e6f36b36`, so no
current isolated image-tree saving is attributed. All 283 instruction-tool
tests pass. Three pinned production epochs pass the pixel-exact SVG source-switch
reftest. The earlier styled-inline rollback is also validated on fresh
production `2e38a436`.

Cohort 96 is invalidated by shared bundle publication after two captures. Both
individual captures pass their normal-exit, original-pixel and content audits;
the partial comparison earns no acceptance or robust performance credit. An
earlier image comparison identity preflight and a later storage preflight each
launch no acceptance browser. They are retained separately. The footprint-based
1,111,573,390-byte disk planning gate remains unchanged; only authenticated
archived generated sources, completed test binaries and finished private
profiles/caches are pruned to regain room.

Cohort 97 completes seven alternating control/Vox/Brave triples on pinned
`1bf1abc8`. All 14 Vox/control captures are exact. Brave pair 2 differs by
171,581 pixels (maximum channel error 23), invalidating acceptance under the
unchanged exact-reference requirement. All 21 browsers exit normally, content
audits pass, ownership passes and identities stay pinned. Observed medians,
including the failed capture, are **27,785,884,359 control**,
**27,334,629,037 Vox**, and **17,413,804,570 Brave lower bound**. The 451,255,322
median point difference (1.624%) has five improvements and two regressions;
highest-candidate/lowest-control is 1.04061, so no robust saving is claimed.
The strict target also fails: `278820577560 > 155650476906`, ratio **1.61219**.

Both broader GC modes then enter all 521 selected cases: 518 pass and the same
three known baseline failures remain. All seven new cases pass, checked input
hashes are unchanged, and no full pass or cadence reset is claimed. History is
**97 attempted cohorts / 2,108 acceptance browser attempts**, with runtime
preflights and native diagnostics separate. The latest wholly valid comparison
remains cohort 95, which also fails the target. BBC homepage stays outside
`OPTIMIZED_SITES.md`.

These are the same frozen original-origin 609-response, original-script,
1024×768 CSS, scale-2 workload and launch-through-encoded-PNG boundary. Fresh
private profiles/caches, retained OS caches, two-second readiness/decode settling,
exclusive coalition ownership and all prior capture limits remain. Cross-browser
pixel differences and incomplete DOM/script, performance.measure, local Arial
fallback and paint_decoded=false limitations remain; this is no live-site,
isolated rendering-time or scrolling claim. See the
[focused exact-flex record](performance/bbc-committed-flex-focus-20261105.json),
[all new evidence and exact counts](performance/bbc-flex-image-progress-20261105.json),
and [521-case broader checks](performance/bbc-flex-image-broad-20261105.json).


## Pending image tree comparison and fresh profile (2026-11-05)

The pending/absolute image-tree extension (`5c5ed9a46`) passes 279 focused
executions across three memory modes and three arms; all 284 instruction-tool
tests pass. Fresh native diagnostics verify candidate-only use before PNG,
original pixels/content and all 72 external author scripts through JavaScriptCore.
The original SVG source-switch guard is exact. The separate coarse V profile
also passes these audits and retains 21 timing scopes; its 21,113 uncached grid
and 41,327 uncached inline calls motivate further investigation. Instrumented
timings earn no instruction credit.

Cohort 98 is invalid after 17 successful captures because the shared bundle
changes; every attempted capture and identity-failure receipt is retained.
Cohort 99 completes seven alternating control/Vox/Brave triples on `f104d01e`.
All 21 browsers exit normally and pass original pixel/content checks; coalition
ownership and pinned input identities pass. Observed medians are **27,872,984,258
control**, **27,409,880,676 Vox**, and **17,431,401,660 Brave lower bound**.
The 463,103,582-instruction median point difference (1.6615%) has four paired
improvements and three regressions. Highest-candidate/lowest-control is 1.06565,
so no robust saving is credited. The strict target fails:
`279792063960 > 156061905759`, ratio **1.61354**. Driver and guard exit 1 for
the failed gate; this is a complete valid failing comparison.

Both broader GC modes enter all 524 selected cases: 521 pass and the same
three known baseline failures remain (root percentage height, text-control
baseline and radio baseline). Checked inputs are unchanged. There is no
full-suite pass or cadence reset. History is **99 attempted cohorts / 2,146
acceptance browser attempts**, with diagnostics and preflights separate.

The original frozen 609-response replay, author scripts, 1024×768 CSS viewport,
scale 2, private profiles/caches, two-second readiness/decode settling and
exclusive-coalition launch-through-encoded-PNG scope remain unchanged. Vox
ends before PNG writing; Brave includes CDP delivery; semantic audits and
teardown follow. OS caches are retained, exited work and allowed owned services
are counted, and GPU/outside services are excluded. The 82.7154% cross-engine
pixel difference and prior DOM/script, performance.measure, local Arial fallback
and paint_decoded limitations remain. There is no live-site, isolated rendering
or scrolling claim. BBC remains outside `OPTIMIZED_SITES.md`. See the
[focused evidence](performance/bbc-pending-image-focus-20261105.json),
[fresh profile](performance/bbc-coarse-profile-20261105.json), and
[cohorts, exact counts and broader checks](performance/bbc-pending-image-cohort99-20261105.json).


## Within-pass pending/absolute image measurements (2026-11-05)

The closed grid/flex measurement collector now admits pending HTML images and
absolute raster images whose containing blocks remain inside the captured
subtree (`135e81868`). Across-pass block retention keeps its existing rules.
Every replay validates live request identity/state/URL, selected source
attributes, provider kind/natural size, and cached ImageBox source, natural
size, auto size and resolution. SVG, broken images, CSS replacements, fixed
images and external containing blocks keep the full algorithm. Static positions
are retained; final absolute positioning still runs.

All 279 focused executions pass: 31 cases in three memory modes and three arms,
with test calls verified in generated main disassembly. Cases compare complete
uncached geometry before and after final absolute layout, scratch retirement,
committed replay, copy-on-write, pending/decode/failure/SVG transitions and
source/natural-size changes. All 321 instruction-tool tests pass. Fresh native
candidate/control launches on production `e4705bb1` pass original pixels/content,
72 exact external scripts and pinned native-image checks. Only the candidate
reports this new path before PNG. The SVG source-switch guard is pixel-exact.

Cohort 100 completes all seven alternating control/Vox/Brave triples on that
pinned executable. Every one of the 21 captures passes original pixels,
content, ownership and normal-exit checks; all input identities stay fixed.
Observed medians are **27,515,470,670 control**, **27,580,572,082 Vox**, and
**17,600,211,619 Brave lower bound**. The candidate shows a **65,101,412
instruction median regression** (0.237%), with two paired improvements and
five regressions. Highest-candidate/lowest-control is 1.06980. No instruction
saving is credited. The strict target fails:
`285468483720 > 156712274379`, ratio **1.63945**. Driver and memory guard exit
1 for this failed gate; every browser exits normally.

The unchanged exclusive-coalition launch-through-encoded-document-PNG scope
includes startup/window/target setup, with Vox before file writing and Brave
including CDP delivery. Semantic audits/teardown follow the endpoint. The
original 609-response original-script replay, 1024×768 CSS viewport, scale 2,
readiness/decode plus two-second settling, private profiles/caches and retained
OS caches are unchanged. Historical paint/SVG policies are held equal in both
Vox arms without optimization credit. Exited aggregates/allowed owned services
are included; GPU/outside work is excluded. The 82.7154% cross-engine pixel
difference and previous DOM/script/font limitations remain. No live-site,
isolated rendering-time or scrolling result is claimed.

No additional positive median reduction triggers broader checks. The prior
524-case batch remains 521 passes/three known failures in each GC mode, with
no full-pass claim or cadence reset. History is **100 attempted cohorts /
2,167 acceptance browser attempts**. BBC homepage remains outside
`OPTIMIZED_SITES.md`. [Focused, native and complete cohort evidence](performance/bbc-image-measurement-cohort100-20261105.json)
retains every attempt and its raw counts.


## Cache and callback attribution diagnostics (2026-11-05)

Three standalone C-O0 probes use the sealed generated C for `e4705bb1`, with
thread-local counters sampled immediately before the encoded PNG marker.
They pass original pixels/content, all 72 exact external author scripts and
unchanged actual native-image identities. These instrumented processes are
separate from acceptance; elapsed timing and counter frequencies earn no
performance credit. Native link inputs are pinned before and after compilation.
An initial probe compile rejects C struct comparisons; the corrected probe
uses CSSPixels raw values. A subsequent wrapper rejects reuse of an existing
exclusive guard report. Both failures remain recorded, followed by successful
compilation under unique guard names; the initial source is reconstructed and
hash-verified from the retained final source.

The first probe records 21,521 grid entries and 17,348 flex entries. Grid has
1,348 cache hits and 11,415 committed misses; flex has 2,882 hits and 8,013
committed misses. Thousands of key mismatches have equal widths but different
stored root/containing heights. These counts motivate a dependency audit;
they do not authorize dropping height-sensitive keys.

A second probe attributes 14,944 engine-helper calls through nine distinct
return sites. All nine preceding call instructions are checked against the
pinned executable after independently verifying the inferred image slide.
The largest caller is `Runtime.call_javascript_function` (12,428 calls),
while native function metadata accounts for only 378 and native forwarding
for 52. The third probe traces all 118 outer return sites, verifies their
preceding call instructions and records 12,438 generic callback invocations.
The largest groups are generic WebIDL callbacks (4,463), microtask enqueue
(2,922), and microtask delivery (2,927). Receivers include 4,845 objects and
7,593 undefined values, so an object-receiver-only shortcut would miss most
calls. The proposed captured-Function.call path preserves undefined/primitive
receivers while avoiding the C-created JavaScript argument array.

These are diagnostic observations on an older, explicitly pinned production
source, not validation of the new callback implementation or a target result.
The valid failing cohort 100 and its unchanged strict gate remain current.
[Raw probes, input hashes, disassembly and audit records](performance/bbc-cache-callback-probes-20261105.json)
are preserved independently of `Build/`.


## Captured Function.call callback path (2026-11-05)

`a3824ecec` invokes callable engine objects through a protected
`Function.prototype.call` captured before author mutation. The target is the
builtin's object receiver; the original callback receiver is its first
argument. This keeps strict undefined/primitive receivers and sloppy receiver
conversion without a C-created JavaScript argument array. Noncallables retain
the original captured Reflect.apply path, and caught native forwarding stays
unchanged. Realm preparation/cleanup and actual exception values remain intact.
Argument packing is confined to the existing JSC ABI adapter, with eight typed
native stack slots and a checked heap fallback for larger calls.

The final **120 focused executions pass**: 20 unique cases in both arms and
all three memory modes. Generated main disassembly verifies every test call.
Cases cover strict/sloppy receivers, 0–100 arguments, symbols/cycles/views,
author-mutated intrinsics, bound functions/proxies/classes, original thrown
values, reentry, Promise FIFO, WebIDL callback realm state and retained roots.
All 322 then-selected instruction-tool tests pass. The isolated control is
`7d94db9b8`.

An initial V-buffer version passes the same 120 executions, but its generated
C boxes the supposedly local argument buffer. The final ABI refinement removes
that allocation. Its first three candidate batches fail the inspector test's
ordinary-call positive control: the old test probe observes only the former
ABI wrapper. Extending the observer to the new entry point, without changing
any assertion, restores both the positive ordinary-call control and zero
intermediate exceptions for caught forwarding in every final batch. All failed
runs, source variants and probe changes are retained.

Native BBC eligibility, original-reference checks and unprofiled instruction
measurement remain pending. The latest completed production `2983f4d0` lacks
the final helper; the shared build's sealed generated C contains it and is
still compiling under host contention. No duplicate production build is queued.
An older executable earns no validation for this feature. Cohort 100 remains
the latest complete comparison and fails the target. There is no new broad
trigger, instruction credit, catalog entry or completion claim. See the
[focused results and retained failures](performance/bbc-native-callback-focus-20261105.json).


## Callback rollback and unused measurement heights (2026-11-05)

Cohort 101 tests the captured-Function.call experiment on production `8a1e86fa`.
Separate fresh native launches pass the original pixels/content, 72 external
script execution checks and actual native-image pins; only the candidate emits
the callback marker before PNG. The SVG source-switch guard is exact. All 21
acceptance attempts are retained, but pair 7 control is rejected before capture
by the coalition ownership audit and pair 7 Brave differs by 171,581 pixels.
The raw ownership scan records another session's HN screenshot Vox process and
helper, both gone during identity lookup. That uncertainty remains a rejection;
it does not justify weakening ownership or retroactively accepting the trial.

The six complete control/candidate pairs have medians 27,669,811,064.5 control
and 28,559,023,141.5 candidate, a negative point difference of 889,212,077.
All seven observed candidate/Brave medians are 28,360,337,963 and 17,582,118,355.
These are diagnostic counts from an invalid cohort. No saving or causal
regression is attributed under host contention. `de5d186f9` removes the callback
experiment and retains its five new semantic cases. The restored implementation
passes all 60 focused executions (20 cases in three memory modes), with actual
test calls verified in main disassembly. Its source rollback still awaits a
production executable containing it; the completed bundles used below predate
that rollback.

`fff39c3d6` permits closed grid/flex measurement reuse across unused stored
numeric heights only when the existing complete subtree proof excludes every
external-height consumer. Definite root heights and immediate containing-block
definiteness remain keyed, together with widths, constraints, edges and node
identities. All 315 focused executions pass: 35 cases in three arms and three
memory modes, with scratch retirement, owned geometry, copy-on-write, committed
replay, dependent-subtree rejections and complete uncached geometry oracles.
All 323 then-selected tooling tests pass; `2d1592da0` supplies the isolated
height control.

Fresh native candidate/control captures on production `2f50a29e` pass the
original pixel/content/72-script/native-image audits and the SVG source-switch
guard. Only the candidate emits the unused-height marker before PNG. This
bundle includes the callback experiment equally in both arms: it isolates the
height comparison and provides no validation of the callback rollback.

Cohort 102 completes all 21 captures with stable identities, normal browser
exits, complete content, and exact pixels/ownership for every Vox arm. Brave
pairs 4 and 5 differ by 224,973 and 53,392 pixels, so acceptance is invalid.
Observed medians are **28,910,002,538 control**, **28,880,421,922 Vox**, and
**17,496,430,647 Brave lower bound**. The **29,580,616** median point reduction
(0.102%) has two paired improvements and five regressions; highest candidate /
lowest control is **1.13755**. It earns no robust saving. The strict target also
fails: `303024301730 > 156361532166`, ratio **1.74417**.

That positive point difference triggers the broader regression batch. All
**532 unique cases** execute in both default and no-GC modes, with **529 passes
and the same three baseline failures** per mode (root percentage height,
text-control baseline and radio baseline). All eight added image/height cases
pass. Checked inputs remain unchanged. There is no full-suite pass or cadence
reset. No own compiler jobs run during cohort 102; independent host contention
and raw host records remain disclosed.

A separate Brave diagnostic forces hover, then clears it. Forced hover does
not reproduce cohort 101's failed PNG; clearing hover still leaves 441 pixels
with maximum channel error 1 against the original reference. This experiment
is inconclusive about the mismatch's cause. References, tolerances and capture
policy are unchanged; every failed acceptance attempt stays recorded.

The unchanged frozen 609-response original-origin replay, original author
scripts, 1024×768 CSS viewport, scale 2, private profiles/caches, retained OS
caches, readiness/decode and two-second settle policy remain in force. Counts
cover exclusive coalition creation through encoded document PNG availability,
including startup/window/target setup; Vox stops before file writing, Brave
includes CDP delivery, and semantic audits/teardown follow the endpoint.
Exited aggregates/allowed owned services are included; GPU/outside work is
excluded. The 82.7154% cross-engine pixel difference and documented DOM/script,
local-font and decoded-paint limitations remain. No live-page, scrolling or
isolated rendering-time claim is made.

History is **102 attempted cohorts / 2,209 acceptance browser attempts**.
BBC homepage remains outside `OPTIMIZED_SITES.md`, and the 10% task remains
open. [Exact counts, all failed attempts, focused/native/broad checks and the
inconclusive hover diagnostic](performance/bbc-callback-heights-cohorts101-102-20261105.json)
are preserved in a verified durable archive.


## Within-pass grid item placement (2026-11-05)

`573bf714f` retains grid item placement in the layout pass's existing measurement
pool. It validates the complete expanded column/row line definitions, subgrid
axes, immediate child identity/order, styles and anonymous-text membership.
A hit repeats the grid-item marking performed by `ordered_grid_items()` and
returns a separate writable placement vector. The pool owns both name-array
levels, their strings and the saved result; release clears the cache. Track
sizing and descendant layout still execute normally. This differs from the
rejected cohort 60 experiment, which borrowed a placement list for track sizing.

All **516 focused executions** pass: **86 cases**, candidate/control and three
memory modes. Actual test calls and unchanged checked sources are verified.
The cases include complete uncached geometry comparisons, scratch retirement,
caller mutation of line names and result arrays, style/order/position/tree
changes, whitespace becoming an item, named/implicit/negative lines, dense
row/column flow, auto-repeat counts and both subgrid axes. All **324 instruction
tool tests** pass; `f72134e36` isolates the placement control. The first compile
rejects two intentional mutable test aliases without `unsafe`; no case runs.
Those annotations and the anonymous-text fixture are corrected before every
passing run. The explicitly stopped redundant compilation remains recorded.

BBC eligibility and instruction measurement remain pending. Completed
production `2f50a29e` and the current build's sealed C both lack this path.
The shared build is already running; no duplicate production build is queued.
Neither old executable nor focused tests establish BBC instruction savings.
The 10% target stays open and BBC homepage remains outside the catalog.
[Focused checks, source hashes, retained compile failures and pending native
preflight](performance/bbc-grid-placement-focus-20261105.json) are archived.


## Resolved placement setters and callback restoration (2026-11-05)

Review finds that typed `MutableComputedValues` setters can replace placement
inputs without advancing the raw property graph revision. `f044b69f2` adds
explicit saved flow, order, resolved row/column positions and auto-position
flags to placement validation. Automatic positions and explicit first-line
positions can have equal numeric rectangles but different cursor behavior, so
both forms are checked. Child subgrid spans are resolved against the same saved
expanded line definitions. The new regression asserts an unchanged raw revision
through order, axis, flow and subgrid mutations, and compares with full placement.

All **522 focused executions** pass: **87 cases** in both arms and all three
memory modes, with unchanged checked inputs and every test call verified.
This supersedes the earlier 516-case-execution implementation check. The
placement native preflight now also requires these typed-input witnesses in
the sealed generated source. The prospective broader inventory has 537 cases;
it is prepared, not claimed executed. Placement performance remains pending.

A separate fresh launch validates the callback restoration on completed
production `557eb0c8` / receipt `20261105-073513-bf3e7f1e`. Sealed-source checks
confirm the original argument-array helper and absence of the Function.call
experiment and its ABI helper. The document PNG is SHA-256-identical to the
original reference, complete content matches, all 72 original external scripts
execute successfully before PNG, every actual native image is pinned, identities
remain unchanged, and native/driver/memory-guard exits are zero. This diagnostic
runs with the JSC witness and earns no instruction credit.

The reference-only driver does not populate `row.pixels_exact`; an initial
auditor therefore records null. The corrected auditor compares the same
already captured PNG independently and verifies the reference, actual PNG and
diff tool hashes, without another browser launch. Both auditor records remain.
This bundle predates grid placement reuse and cannot validate that change.
No acceptance cohort has been added: history stays 102 / 2,209, the 10% target
remains unmet, and BBC homepage stays outside the catalog.
[Setter regression and restored native evidence](performance/bbc-grid-placement-typed-and-callback-restored-20261105.json)
are preserved with a verified archive.


## Measurement rejection classifier (2026-11-05)

A separate C-O0/bounded-prealloc diagnostic instruments the closed-input
collector in sealed production `557eb0c8`, dumping thread-local counts before
encoded PNG. It passes original pixels, complete content, 72 exact external
scripts, native exit zero, unchanged inputs and actual loaded-image pins.
Compiler/runtime guards exit zero after the corrected probe. It predates grid
placement reuse and supplies no acceptance, instruction or timing credit.

The reject branch records 3,366 visits. Positioned rejections comprise 2,549
absolute and 32 fixed visits, with zero relative visits and zero all-auto or
absolute-zero relative-inset opportunities. Position-related visits include
1,057 image boxes and 514 block containers, with zero SVG boxes. These are
nonexclusive repeated visits, not unique elements. Widening the relative-inset
rule has no observed opportunity in this run.

All 640 rejected list-item visits have no marker. This motivates a narrow
measurement-only extension, still requiring every other closed-subtree guard
and live marker validation. It does not prove that those visits would pass all
remaining predicates or that the extension runs in production. The initial
probe compile uses an enum macro already expanded in the sealed preprocessed
C; the corrected literal is verified against that source's exact helper.
The failed compile, source-proof preparation mismatch, corrected source and
successful run are retained in the [rejection evidence](performance/bbc-measurement-rejections-20261105.json).
The 10% target and catalog status are unchanged.


## Placement cohort 103 and experiment restoration (2026-11-05)

Production `dd2957bc9df4` contains the placement cache and typed-setter guard.
Fresh candidate/control launches pass the original PNG, complete content,
72 external author-script and actual native-image audits. Placement reuse fires
before encoded PNG only in the candidate. Headless startup and the SVG
source-switch reftest also pass. These diagnostics establish eligibility and
correctness, not instruction savings.

Cohort 103 completes all seven alternating triples and retains all 21 attempts.
Every browser exits normally, content and endpoint ownership pass, and the
driver's input checks remain stable throughout. Brave pairs 2 and 6 each
differ by 53,392 pixels, invalidating acceptance. Their observation status is
1 because of that pixel audit; their actual native exit is 0. An early progress
claim that the first ten captures all passed missed pair 2 and was corrected.
Neither failed observation is excluded or replaced.

Observed launch-to-PNG medians are **27,649,940,404 Vox**, **27,445,014,213
control**, and **17,736,153,639 Brave lower bound**. Placement reuse regresses
the median by **204,926,191 instructions** (0.747%); two paired improvements
and five regressions give no robust saving. Highest Vox / lowest control is
**1.12758**. The strict Brave gate fails:
`290434170750 > 158257200780`, ratio **1.65168**. A subsequent shared bundle
publication prevents rehashing that executable now; the completed driver checks,
all raw per-row receipts, and its sealed C remain preserved.

`2242b6692` removes the provisional placement cache and its cache-specific tests.
Restored formatter/state bytes match the earlier implementation. The separate
markerless-list measurement experiment (`6930ae8be`) passes **342 focused
executions** after its fixture establishes a retained document heap owner.
Its fresh production candidate/control captures retain exact original pixels,
complete content, all 72 scripts and pinned native images, but neither arm
reports markerless reuse before PNG. It earns no performance credit and runs no
instruction cohort. `683a4fb69` removes that extension and its three new cases.
Restored shared collectors match their earlier bytes; existing measurement and
unused-height behavior remains.

Placement restoration passes **342 executions** (38 cases × three arms × three
memory modes). Restoration of both experiments passes **315 executions**
(35 × three × three), with unchanged checked inputs and actual test calls
verified. The first markerless compile's missing mode argument, the premature
preallocation fixture's two signal-139 runs and assertion failure, and the
later disk-space failures before focused/native checks all remain recorded.
The corrected owned-fixture checks pass before either restoration is committed.

Storage recovery deletes only 133 generated artifacts with verified durable
copies: completed private profiles/caches, reproducible test executables and
generated C. Three archive manifests and their members are read back and
hashed before deletion. It frees 1,413,427,841 logical bytes; browser bundles,
shared receipts, fixtures, raw counts and PNGs remain in place.

This supersedes the placement/markerless pending status above. No positive
cohort-103 reduction triggers another broad batch. The last broad batch remains
532 unique cases per memory mode: 529 passes and the same three baseline
failures, without a full-suite pass or cadence reset. Prepared 537/535-case
inventories are retained as unexecuted plans. History is **103 measured cohorts
/ 2,230 acceptance browser attempts**. The unchanged workload, launch-to-PNG
scope and rendering limitations described above still apply. BBC homepage
remains outside `OPTIMIZED_SITES.md`; the 10% target remains open.
[Exact counts, all attempts, focused/native checks, restoration proofs and
storage receipts](performance/bbc-placement-cohort103-and-restorations-20261105.json)
are preserved in a fully verified archive.


## Original pixel regression and comparison 104 preflight (2026-11-05)

The proposed aggregate grid/flex/inline-cache comparison 104 runs **no measured
pairs**. The driver's mandatory runtime discovery rejects an original-reference
pixel mismatch before its first triple. Its guard/controller status is 1;
the discovery browser's actual native exit is 0. The prospective diagnostic
comparison is not a completed cohort and adds no acceptance attempts.

Production `fc1b35e2a33b`, then the newer `68cec4406133` containing both experiment
removals, produce identical PNGs with the legacy measurement caches on and off.
Both policies differ from the immutable original Vox reference at exactly
**(398,1061)**: red **59 → 58**, with green 68, blue 78 and alpha 255 unchanged.
Complete content, all 72 original external scripts, actual loaded-image pins,
input identities and native exits pass. The SVG source-switch guards remain
exact. Neither reference nor tolerance is changed, masked or bypassed.

A fresh C-O0 compilation of the exact newer sealed source reproduces the same
one-pixel mismatch. A fresh C-O0 compilation of the earlier `e9b0f545f8f7` source
still matches the original PNG. Most named rendering functions match after
resolving generated string constants; initial namespace-limited and anonymous-
name classifiers remain investigative records, not proofs of whole-program
equivalence. The native include comparison finds only the added writing-tools
header; previously existing native files and linked libraries are unchanged.

The decisive control changes **only** `chromium_border_has_diagonal_path` in the
newer sealed source to its exact earlier body. That fresh C-O0 launch restores
the original PNG exactly, with complete content, 72 exact external scripts,
actual loaded-image pins and unchanged inputs. The corrected default in
`c2deb6773` recognizes omitted and zero-radius border arcs as analytic. Its
different tile-wide MSAA decision also changes an image sample inside the same
tile. This explains the observed mismatch without attributing an instruction
saving or changing the original workload.

An explicit historical border-sampling option is being validated so both Vox
arms can retain the references' original raster policy. The current default
remains intact. Production validation of that option is still pending; the
standalone C-O0 control is diagnostic evidence only. The 326 instruction-tool
tests pass for the common-arm option (`7cb843063`). No launch counts from the
JSC-witness or C-O0 diagnostics earn optimization credit.

History stays **103 measured cohorts / 2,230 acceptance browser attempts**,
plus comparison 104's rejected runtime-discovery preflight. The 10% target
remains open, and BBC homepage stays outside the catalog.
[Every failed capture, exact single-helper control, source/input hashes,
commands and actual exits](performance/bbc-pixel-msaa-attribution-20261105.json)
are preserved in a verified durable archive.

`0804e5699` completes the explicit historical border-sampling implementation.
All **90 focused executions** pass (30 cases in default, no-GC and bounded
preallocation modes), with actual test calls and unchanged checked inputs
verified. Tests cover ordinary lines, curved/omitted/zero-radius arcs and live
border geometry under both policy choices. The first matrix is retained as
invalid after a diagnostic-marker edit during compilation; the complete final
matrix is rerun against fixed inputs. The new option has zero optimization
credit. The latest completed `68cec4406133` predates it, and the shared build
remains busy; a preflight launches no browser. Original-reference native
validation remains pending. [Focused evidence and tested sources](performance/bbc-archived-border-msaa-focus-20261105.json)
are archived with full member readback checks.

Production `49a4b05fe332` subsequently validates that historical option in fresh
native launches: both legacy-cache policies produce PNGs SHA-256-identical to
the original reference, complete content and all 72 external scripts pass,
actual loaded images are pinned, and identities/native/driver/guard exits pass.
Both arms report the historical border policy before PNG. Frame-task layout
coalescing is explicitly disabled equally in these captures; this does not
validate that pending optimization or its later focus guard.

This is a **parallel C / 33-unit** production build, unlike the preceding
single-unit cohorts. No cross-mode difference receives optimization credit.
`042c69193` lets the instruction driver preserve its matching unique published
receipt, C-mode metadata, equal complete before/after build-input fingerprints
and staged compiler identity. These receipts supply **no sealed generated C**;
the manifest records that limitation instead of treating them as frozen C.
`7cb12acb0` additionally rejects metadata changed after its initial read. All
**330 instruction-tool tests** pass. Original references, exact-match checks,
ownership gates and instruction endpoints remain intact.

The initial parent auditor's `coalescing_present=false` label meant disabled
eligibility in this policy-only run, not absence of compiled code. Its initial
records and corrected labels are retained; correction verifies the same
already captured PNG hashes and launches no new browser. History remains
103 / 2,230 plus comparison 104's rejected preflight. The target remains unmet.
[Native captures, parallel provenance, tooling checks and label correction](performance/bbc-parallel-provenance-and-border-native-20261105.json)
are durably archived and verified.


## Frame-task layout coalescing and cohort 105 (2026-11-05)

`17841f527` lets dirty JavaScript synchronization inside an existing frame keep
scale and cosmetic filters current, then leave unqueried geometry to the normal
final frame update. Later DOM geometry/paint queries still flush synchronously.
Initial layout, tree-only mode, changed zoom, pending autofocus and focused
elements retain the full synchronous shell path. The focused mutation pair
commits geometry once instead of twice when no query intervenes.

All **30 executions of the five new cases** pass in candidate/control arms and
default/no-GC/preallocation modes. The full focused matrix executes 228 cases:
216 pass, and each of its six runtime runs has the same two existing internal
paint-width assertions expecting 30/20 while device-pixel widths are 60/40.
Assertions remain unchanged. All test calls and committed input hashes are
verified. The autofocus test initially exposes a real candidate-only dirty
layout after completion; the final guard preserves the original shell path.
Earlier direct-evaluation/storage assumptions and the later input fixture's
omitted UA padding/border are retained failures. The final input fixture uses
explicit border-box sizing. The evidence-auditor path correction and its
successful committed-source verification are recorded separately.

Fresh production `f2762ca3223b` / build HEAD `17841f527` passes original pixels,
complete content, all 72 original external author scripts, loaded-image pins,
identities and normal native exits in both arms. Coalescing fires before PNG
only in the candidate. The SVG source-switch reftest is exact in both arms and
across policies. This parallel build has no sealed generated C. Every checked
source matches its build HEAD and final focused inputs with a clean status for
those files; its complete before/after production input fingerprints match.
Later unrelated repository inputs differ. The earlier stricter whole-current-
checkout preflights launch no browser and remain preserved. No sealed-C identity
claim is made from the parallel receipts.

Cohort **105** completes all seven alternating triples with **all 21 capture
audits passing**, unchanged identities and valid endpoint ownership. Launch-to-
PNG medians are **27,734,177,885 Vox**, **28,019,708,756 control**, and
**17,636,922,428 Brave lower bound**. The point reduction is **285,530,871**
instructions (1.019%), with four improvements and three regressions. Highest
candidate / lowest control is **1.04611**; no robust saving is credited. The
strict Brave gate fails: `284838899410 > 156552895746`, conservative ratio
**1.63750**. No prior single-unit versus this parallel-build difference receives
optimization credit.

The positive point difference triggers the broader batch: **600 unique cases
in each memory mode**, comprising 532 layout cases and 68 main cases. Each mode
has **595 passes and the same five baseline failures** (three layout cases plus
the two main cases above). Both main arms agree. Including repeated control
checks, 1,336 case executions produce 1,322 passes and 14 baseline failures.
Every case call is verified and checked inputs remain unchanged. There is no
full-suite pass or cadence reset. The 330 instruction-tool tests pass.

The fixed 609-response replay, author-script policy, viewport/scale, private
profiles/caches, retained OS caches, readiness/decode and two-second settlement
are unchanged. Both Vox arms retain the original logical paint snapping,
CSS-SVG coordinates and degenerate-border tile MSAA. Scope remains exclusive
coalition creation through encoded PNG, including startup/window/target setup;
Vox stops before file writing, Brave includes CDP delivery, and audits/teardown
follow the endpoint. Exited aggregates/allowed services are included and
GPU/outside work excluded. Cross-engine pixels still differ by 82.7154%, with
the existing DOM/script/local-font/decoded-paint limitations; this establishes
no live-page, isolated rendering-time or scrolling result.

History now has **104 measured cohorts / 2,251 acceptance browser attempts**:
last measured ID 105, with ID 104 retained as a preflight-only comparison.
BBC homepage remains outside `OPTIMIZED_SITES.md`, and the 10% task remains
open. [All cohort attempts, focused/broad/native checks, actual exits, source
proofs and retained failures](performance/bbc-frame-coalescing-cohort105-20261105.json)
are archived with verified member hashes.


## Production sample and grid-policy diagnostic (2026-11-05)

The fresh CPU sample on cohort 105's pinned `f2762ca3223b` verifies the root PID
and start ticks, executable UUID/load range and all 11,711 resolved Vox frames.
Original pixels/content, 72 exact external author-script witnesses, loaded-image
pins and native/driver/guard exits pass. It shows repeated intrinsic layout,
retained-input collection and DOM attachment; recursive inclusive counts overlap
and idle workers dominate all-thread totals. Requested 1 ms sampling does not
prove that cadence. These are investigative leads, with no instruction saving
or acceptance credit. [Sample and verified raw evidence](performance/bbc-coalescing-production-sample-20261105.json).

A separate instrumented one-trial-per-arm diagnostic checks the existing
persistent-grid policy on newer **single-unit** production `c81e92dfd288`. Both
original pixel/content audits, 72 external script witnesses, pinned native images,
final ownership checks and normal exits pass. Grid reuse fires before PNG only
in the default candidate. Observed counts are 27,447,793,609 default and
27,291,032,111 with grid retention disabled: a 156,761,498 point regression. One
trial per arm, diagnostic instrumentation, high host load and independent browser
activity leave cache value unresolved; no saving or cross-C-mode attribution is
made. All attempts remain recorded. [Policy diagnostic and raw evidence](performance/bbc-retained-grid-policy-diagnostic-20261105.json).

Acceptance history stays at 104 measured cohorts / 2,251 browser attempts. The
last valid seven-triple cohort remains 105, the strict 10% target still fails,
and BBC homepage remains outside the catalog.


## Cached cosmetic token surveys (2026-11-05)

`af9b7abd0` stores the browser's sorted light-DOM ID/class tokens until either
the document tree or attribute version changes. Procedural selectors still run,
filter CSS is recomputed for toggles and live URLs, and mutations between primed
and final styles are observed. Independent bounded storage survives temporary
callers; navigation and tab disposal clear the cache. `9aca40cd8` supplies the
isolated disabled control without changing the shared rendering policies.

All **30 executions of five new cases** pass in both arms and three memory
modes. The complete cosmetic/lifecycle batch runs 44 cases per arm/mode: 264
executions, 258 passes and six occurrences of the same existing internal
paint-width assertion in both arms. Assertions are unchanged; this is no full
suite pass. All **331 instruction-tool tests** pass. Initial harness import and
Option-unwrap errors, ambient-proxy failures and preallocation crashes in an
unrelated GPU-image fixture remain retained. The final focused batch excludes
that network-fixture file, uses empty profiles and clears ambient proxies; no
complete execution is claimed for the earlier aborted batch.

The completed production bundle checked at this stage predates the cache and a
shared build is already running. BBC workload eligibility, native correctness
and matched instruction effect remain pending. This change receives no
performance credit yet; the 10% target remains open and the homepage stays
outside the catalog. [Focused checks, failures, source hashes and archive](performance/bbc-adblock-token-focus-20261105.json).


## Adblock token cache cohort 106 and broad checks (2026-11-05)

Fresh single-unit production `58129def664e` contains the cache. Both native arms
pass original pixels/content, all 72 exact external author-script witnesses,
loaded-image pins, endpoint ownership and normal exits. Token reuse fires
before PNG only in the candidate. The SVG source-switch guard remains exact
in both arms and across policies. Its sealed generated C and dirty build
provenance are retained; the final unchanged feature code is committed as
`af9b7abd0`. No cross-C-mode difference from parallel cohort 105 receives credit.

Cohort **106** completes all seven alternating triples: **all 21 audits pass**
with unchanged identities. Launch-to-PNG medians are **27,233,969,558 Vox**,
**28,259,580,188 control**, and **17,438,679,519 Brave lower bound**. The point
reduction is **1,025,610,630 (3.629%)**, with five improvements and two
regressions. Highest candidate / lowest control is **1.08964**, so no robust
saving is credited. The strict 10% gate fails: `288620237310 > 155541965742`,
conservative Vox/Brave ratio **1.67002**. Driver/guard exit 1 reflects the failed
target; every actual browser exits 0.

The broader batch executes **606 unique cases per memory mode**: 532 layout
and 74 main. Each mode has 601 passes and the same five baseline failures,
with matching main candidate/control results. Including repeated controls,
1,360 executions yield 1,346 passes and 14 baseline failures. All calls and
checked inputs are verified. No full-suite pass or cadence reset is claimed.
A local postprocessing error initially read the raw navigation diagnostic
field; that calculation is retained explicitly as invalid for acceptance. The
corrected audit uses the launch field matching the predeclared protocol and
canonical driver logs/summary. No measurement boundary, workload, reference,
retry or sample inclusion changes.

Scope remains exclusive coalition creation through encoded PNG, including
startup/window/target setup, readiness and two-second settlement. Vox stops
before file writing; Brave includes CDP delivery; semantic audits/teardown are
after the endpoint. Exited aggregates and allowed owned services are included,
GPU/outside work excluded. The fixed 609-response original-origin replay,
original scripts, 1024×768 CSS viewport at scale 2, fresh private profiles and
caches, retained OS caches, original per-engine references and three historical
rendering policies remain unchanged. Cross-engine pixels still differ by
82.7154%, with the recorded DOM/script/font/decoded-paint limitations. No live,
isolated rendering-time or scrolling result is established.

History is now **105 measured cohorts / 2,272 acceptance browser attempts**,
last measured ID 106; ID 104 remains preflight-only. The target stays open and
BBC homepage remains outside the catalog. [Complete measurements and broad/native evidence](performance/bbc-adblock-token-cohort106-20261105.json).

A separate fresh instrumented trace on that same executable passes original
pixels/content, 72 scripts, native-image identity and normal exits. Before PNG,
its final cumulative style causes show 5,148 full-cascade and 6,877 ordinary dirty
elements, plus 1,043 font refreshes and eight fallbacks. The capped source tracer
shows two class changes and no existing-styled-element data/ARIA mutations; it
cannot count all invalidations or precascade edits. This does not establish
workload eligibility for relaxing data/ARIA invalidation. [Trace and raw evidence](performance/bbc-post-cache-style-trace-20261105.json).


## Closed automatic-row grid height candidate (2026-11-05)

`f8836c069` extends the row-sizing scalar height seed to nested grids with
implicit automatic rows, fixed inline size and unconstrained block size. The
existing closed-subtree and unused-height proofs exclude percentage-dependent
geometry and specialized contexts; flex, replaced and SVG descendants retain
full intrinsic probes. `0d6dd95ef` adds an isolated comparison control.

All **126 focused executions** pass, including **30 executions of five new
cases** across both arms and three memory modes. Sixteen geometry/glyph digests
per arm and mode agree exactly. Checks cover row spans, nested grids, wrapped
text, widths, both font policies, rejected dependencies/constraints, producer
scratch retirement and live edits. The initial fixture's nested Option argument
generated a pointer-to-pointer; both arms abort there. The corrected named local
and retained initial generated C document that fixture repair. All **332
instruction-tool tests** pass. [Focused evidence](performance/bbc-auto-grid-height-focus-20261105.json)
is archived with member hashes verified.

Native BBC eligibility and matched instruction effect remain pending at this
checkpoint. No performance credit is assigned. Cohort 106 remains the last
verified acceptance comparison, the target remains unmet and the homepage stays
outside the catalog.


## Automatic-grid height cohort 107 (2026-11-05)

Parallel 33-unit production `31a7d6dc0c41`, build HEAD `0d6dd95ef`, matches every
checked focused source hash. Both fresh native arms pass original pixels and
content, all 72 exact external author-script witnesses, loaded-image pins,
ownership and normal exits. The new height seed fires before PNG only in the
candidate. The SVG source-switch guard is exact in both arms and across
policies. Parallel receipts retain unchanged complete generation fingerprints
and compiler metadata; no sealed generated C is claimed.

Cohort **107** completes all seven alternating triples with **all 21 audits
passing** and unchanged identities. Launch-to-PNG medians are **27,568,511,392
Vox**, **27,334,456,203 control**, and **17,540,883,525 Brave lower bound**. The
seed shows a **234,055,189 median regression (0.856%)**, with one paired
improvement and six regressions. Highest candidate / lowest control is
**1.07574**; no saving is credited. The strict target fails:
`286606990260 > 157090086387`, conservative Vox/Brave ratio **1.64203**.
Driver/guard exit 1 reflects that failed target; all actual browsers exit 0.
The prospective 611-case inventory is retained but has no positive point-saving
trigger and is not run.

The existing canonical bundle read lease holds publication through the short
SVG/cohort check and releases afterward; hashes remain checked throughout.
This coordination changes no endpoint or workload and earns no instruction
credit. Scope stays exclusive coalition creation through encoded PNG, including
startup/window/target setup, readiness and two-second settlement; Vox stops
before file writing and Brave includes CDP delivery. Audits/teardown follow the
endpoint, exited aggregates/allowed services are included, and GPU execution
and outside work are excluded. Frozen replay, scripts, viewport/scale, private
profiles/caches, retained OS caches, original references and historical rendering
policies remain unchanged. Cross-engine pixel/DOM/script/font/paint limitations
remain; no live-page or isolated rendering/scrolling claim is made.

History reaches **106 measured cohorts / 2,293 acceptance browser attempts**,
last ID 107, with ID 104 still preflight-only. BBC homepage stays outside the
catalog and the 10% task remains open. [All measured/native/SVG attempts and receipts](performance/bbc-auto-grid-height-cohort107-20261105.json).

A later fresh sample uses completed parallel production `d0eac328379f`. PID,
start ticks, dyld UUID, executable address ranges, original pixels/content, all
72 external author scripts, native-image pins and normal exits pass. Grid-seed
eligibility frames appear, but recursive inclusive samples cannot isolate their
instruction cost or establish a saving. Code inspection identifies avoidable
input collection before resource/flex rejection; its reordered follow-up is
under focused validation. [Sample and verified raw evidence](performance/bbc-auto-grid-height-production-sample-20261105.json).


## Early grid-proof rejection and cohort 108 (2026-11-05)

`7bc6e052d` rejects flex, replaced and SVG descendants before collecting
retained grid inputs. This preserves the previous admission proof. All **126
focused executions** pass across both arms and three memory modes, including
30 executions of the five new grid cases and 16 exact geometry/glyph digest
comparisons per arm and mode. [Focused checks and verified archive](performance/bbc-grid-height-early-rejection-focus-20261105.json).

Parallel 33-unit production `142853c75081` contains the checked source and passes
both original native captures, all 72 exact external author-script witnesses,
loaded-image pins, ownership and normal exits. Height seeding fires only in the
candidate before PNG; the SVG source-switch guard stays exact in both arms.
Parallel provenance preserves complete generation fingerprints and metadata,
without a sealed generated-C claim.

Cohort **108 is invalid**. All 21 attempts remain: Brave pairs 1 and 4 fail their
unchanged pixel references, and Vox pair 2 has a private helper outside its
exclusive coalition before a usable count or PNG. That failed launch has a
recorded controlled-cleanup kernel status of 15; the other 20 browsers exit
normally with status 0. Eighteen capture audits pass. The missing count is not
zero, and no full seven-triple medians, conservative acceptance ratio or saving
are credited. Six observed complete Vox/control pairs show a **543,760,580.5**
partial diagnostic median difference, with five improvements and one regression;
these observations cannot establish acceptance.

That positive partial observation conservatively triggers the broad checks.
Each memory mode exercises **611 unique cases: 606 passes and the same five
baseline failures** (three layout and two main cases). Repeated main controls
bring the actual total to 1,370 executions, 1,356 passes and 14 known failures.
All new grid cases pass and checked inputs stay unchanged. No full-suite pass
or cadence reset is claimed.

The pinned bundle lease releases after SVG/cohort checks; input hashes remain
checked throughout. Scope remains exclusive coalition creation through encoded
PNG, including fresh startup/window/target setup, readiness and two-second
settlement. Vox stops before file writing; Brave includes CDP delivery; audits
and teardown follow. Exited aggregates and allowed owned services are included,
GPU execution and outside work excluded. Frozen 609-response original-origin
replay, original scripts, 1024×768 CSS at scale 2, fresh private profiles/caches,
retained OS caches, original references and three historical rendering policies
remain unchanged. Cross-engine pixels still differ by 82.7154%, with the
recorded DOM/script/font/decoded-paint limitations; no live-page, isolated
rendering or scrolling claim is made.

History reaches **107 measured cohorts / 2,314 acceptance browser attempts**,
last ID 108; ID 104 remains preflight-only. The last valid full capture cohort,
107, still fails the target. BBC homepage remains outside the catalog.
[Every attempt, native checks and broad evidence](performance/bbc-grid-height-early-rejection-cohort108-20261105.json).


## Grid-seed cohort 109 and frame diagnostic (2026-11-05)

A newer completed parallel 33-unit build, `fcbdb3e693fa`, matches the checked
early-rejection sources. Both fresh native arms pass original pixels/content,
all 72 exact external author-script witnesses, loaded-image pins, ownership and
normal exits; the grid-height marker remains candidate-only. Four SVG captures
and all three comparisons are exact.

All **21 attempts** in cohort **109** remain. Brave pair 6 fails its unchanged
pixel reference, invalidating acceptance; 20 capture audits pass and all 21
actual browser exits are 0. Observed launch medians are **27,501,979,540 Vox**,
**27,330,420,056 control** and **17,500,230,358 Brave lower bound**. The grid seed
shows a **171,559,484 median regression (0.628%)**, with one paired improvement
and six regressions. Highest Vox / lowest control is **1.06840**. The observed
strict inequality also fails, `283883589910 > 157009872330` (ratio **1.62726**),
and the failed audit independently prevents acceptance. No saving is credited
and there is no new positive-point broad trigger. An initial local auditor
expected fields absent from an invalid summary; that failed postprocessing is
retained, and the corrected calculation uses unchanged raw launch intervals.

Separate frame-checkpoint diagnostics on `6bcb6ad70a1e` and `fcbdb3e693fa` pass
the original native audits in both arms. Ordered chains before PNG place about
0.84–0.86B root-process instructions between context readiness and document
replay completion, versus 22.44–25.86B between complete frames. Those intervals
include concurrent root threads, callbacks/preparation and checkpoint overhead;
they do not isolate function costs or provide acceptance counts. No diagnostic
instrumentation is enabled in the cohort.

The publication read lease releases after the cohort, with identities checked
throughout. The exclusive-coalition creation-to-encoded-PNG endpoint, startup
and window setup, original frozen replay/scripts/references, 1024×768 CSS at
scale 2, readiness plus two-second settlement, fresh private profiles/caches,
retained OS caches and common historical rendering policies remain unchanged.
Vox stops before file writing, Brave includes CDP delivery, audits/teardown
follow, exited aggregates/allowed services are included and GPU/outside work is
excluded. Existing cross-engine pixel/DOM/script/font/paint limitations remain;
no live-page, isolated rendering or scrolling claim is made.

History is **108 measured cohorts / 2,335 acceptance browser attempts**, last
ID 109; ID 104 remains preflight-only. The target remains open and BBC homepage
stays outside the catalog. [Complete attempts, receipts and frame diagnostics](performance/bbc-grid-height-cohort109-frame-parts-20261105.json).


## Intrinsic grid block-measurement reuse (2026-11-05)

`3576100c0` admits closed definite-width intrinsic block-size probes to the
existing owned grid measurement cache. Entries keep their layout mode, so an
intrinsic result cannot replace normal root track publication. Replay preserves
root track metadata and restores only the automatic height that the intrinsic
algorithm writes. Existing subtree/resource/font/style validation and cache
limits remain. `4459da977` adds the isolated same-binary control.

All **192 focused executions** pass: 32 cases in both arms across default,
no-GC and preallocation modes, including 24 executions of four new cases.
Unpooled uncached oracles check scalar/glyph geometry after scratch retirement,
copy-on-write, root track preservation, normal/intrinsic separation, widths,
font policies, text/font/environment changes and rejection of positioned,
floating and subgrid effects. Actual native test calls and unchanged checked
inputs are verified. The initial fixture's invalid font-policy enum is corrected
to `libweb`; its three compile failures remain retained. All **333 instruction
tool tests** pass. [Focused evidence and verified archive](performance/bbc-intrinsic-grid-measurement-focus-20261105.json).

Native BBC eligibility and matched instruction effect remain pending at this
checkpoint. No optimization credit or catalog entry is assigned; the 10% task
remains open.


## Intrinsic-grid no-hit rollback / preflight 110 (2026-11-05)

Completed parallel production `e05f01a6c418` contains the checked intrinsic-grid
extension. Both native captures pass original pixels/content, all 72 exact
external author scripts, native-image pins, ownership and normal exits, but
**neither arm reports the new reuse path before PNG**. Eligibility therefore
fails, and no acceptance browsers launch for ID 110. No instruction saving is
credited. The lease helper releases in its exception cleanup; a separately
recorded nonblocking exclusive-lock probe confirms subsequent availability.

`6c9e9df` removes the provisional implementation, four new cases and control,
while preserving their commits and evidence. All **168 remaining focused
executions** (28 cases × both arms × three memory modes) pass, and all **332
instruction-tool tests** pass after removal. This is a rollback check, with no
claim of a performance gain. [Native attempts, rollback checks and archive](performance/bbc-intrinsic-grid-no-hit-rollback-20261105.json).

History stays **108 measured cohorts / 2,335 acceptance browser attempts**;
IDs 104 and 110 are preflight-only. The original workload, references and scope
remain unchanged. The target is open and BBC homepage remains outside the
catalog.


## Definite positioned-image repaint candidate (2026-11-05)

`14e4a4501` permits an out-of-flow raster image with two independently resolved
specified dimensions to refresh its retained paint input after first decode or
a changed natural aspect ratio. Percentage dimensions require definite committed
containing-block bases; intrinsic constraints, SVG/broken providers and pending
style-driven geometry changes retain their existing layout paths. Old paint
commands keep their original URLs and pixels. `d7d84f1dc` adds the isolated
same-binary comparison control.

All **108 focused executions** pass: 18 cases in both arms across default,
no-GC and preallocation modes, including **24 executions of four new cases**.
Checks compare display lists with a full tree rebuild, exercise five object-fit
policies, first decode, changed ratios, old-pixel ownership, constraints,
indefinite bases, SVG/broken transitions and attribute-selector changes.
An additional 18-case default run with the older ratio optimization disabled
passes. Initial candidate runs caught a source-URL guard that still rejected
proved source replacements; those three failures and passing controls remain
retained alongside the correction. All **333 instruction-tool tests** pass.
[Focused checks and verified raw archive](performance/bbc-positioned-definite-image-focus-20261105.json).

Native BBC eligibility and the unprofiled matched effect are pending. The latest
completed bundle lacks this change and a shared build is already running. No
optimization credit or catalog entry is assigned; the 10% task remains open.


## Definite-image production validation pending (2026-11-05)

The canonical published `e05f01a6c418` predates `14e4a4501`. After confirming the
shared build guard was idle and no available bundle contained the required
code, one canonical supervised build was requested. Receipts
`20261105-154221-ff9df610` and `20261105-155115-01ebe610` both compile and smoke
successfully (exit 0), but publication rejects each because its complete build
input fingerprint changes. Neither supplies native validation for the candidate.
The next shared worker remains active; no duplicate build is requested while
its guard is busy.

The bounded 15-minute completed-build watcher expires without a qualifying
bundle. **No acceptance browser launches for reserved ID 111**, and history
stays at 108 measured cohorts / 2,335 attempts. Fresh native eligibility and
original-reference checks, the SVG source-switch guard, seven alternating
triples and a conditional 615-case broad inventory are prepared under
`Build/bbc-positioned-definite-image-20261105-1530`. All candidate code, control
and focused evidence are committed. Native and matched instruction credit remain
pending; the 10% target is unmet and BBC homepage remains outside the catalog.
[Build receipts, identities and pending-validation checkpoint](performance/bbc-definite-image-production-pending-20261105.json).


## Fresh detailed V profile and object-receiver candidate (2026-11-05)

A fresh \`v -profile - -profile-no-inline -profile-fns main__main\` diagnostic
passes the original exact PNG and complete content audit, all 72 exact external
author-script witnesses before PNG, loaded-image pinning and normal exits.
Current canonical sources remain unchanged during generation and sealing.
The bounded preallocation/C-O0 diagnostic retains 46 prospectively selected
generated V timers and a main-thread TLS scope gate; the original generated C,
transformed C, frozen inputs, selection proof and raw output are preserved.
Forty-five scopes execute. V omits the zero-call
\`complete_script_inserted_images\` scope from its printed rows; an initial
postprocessor incorrectly required it and its failure remains retained.

| Selected scope | Calls | Selected self elapsed |
| --- | ---: | ---: |
| Engine function calls | 15,113 | 2,138.668 ms |
| Uncached inline layout | 41,216 | 1,592.068 ms |
| Uncached grid layout | 20,029 | 1,185.895 ms |
| CSS rule matching | 75,332 | 1,064.593 ms |
| Frame drawing | 175 | 1,012.588 ms |

These are instrumented elapsed times, including unselected callees/native waits
and possible post-PNG work. Recursive inclusive intervals overlap. Recorded
host load is high, and main's outer timer remains unfinished at exit; these
figures establish neither CPU instruction shares nor a production speedup.
The call wrapper's own argument preparation is only 9.418 ms across 12,598
calls, so its parent engine time cannot be attributed to argument arrays.
Native function metadata is negligible: 378 calls / 0.620 ms selected self.
There are 24,173 intrinsic width probes versus 2,154 height probes; cache input
validation and key construction are much smaller than uncached layout.

[Profile, toolchain, scope qualifications and verified raw evidence](performance/bbc-v-profile-detailed-20261105.json)
retain both successful generation/compile/capture guards and all raw timings.
A supplemental archive preserves two compiler inputs omitted by the primary
packaging filter; together the archives cover every unique sealed input hash.
Actual capture tool identities come from the before/after manifests; a separate
toolchain observation taken later is explicitly distinguished. The native
library lease releases after capture. No profile instruction credit is assigned.

The earlier captured-\`Function.call\` experiment remains rolled back.
\`411e0574a\` instead invokes JSC's existing typed call ABI for verified callable
targets with object receivers. Primitive receivers and noncallable targets retain their
existing captured-\`Reflect.apply\` behavior; HTML realm preparation, actual
exceptions and Promise ordering stay covered. \`8c5ddafec\` supplies the isolated
comparison control.

All **126 focused executions** pass: 21 cases in both arms across three memory
modes, including six executions of the new proxy/boxed-receiver case. The
checks retain strict/sloppy receiver identity, argument counts 0–100, poisoned
call/apply properties, proxies, bound functions, exceptions, reentry, Promise
FIFO, WebIDL realm state and inspector-forwarding behavior. Every actual test
call and unchanged checked input is verified. All **334 instruction-tool
tests** pass. [Focused evidence](performance/bbc-object-receiver-call-focus-20261105.json).
Native eligibility and matched instructions remain pending at this checkpoint;
the 10% goal and BBC homepage catalog entry remain open.


## Object-receiver cohort 112 / image preflight 111 (2026-11-05)

Completed parallel 33-unit production `1e77ee4556ed` contains the checked
object-call candidate. Both fresh native captures pass original pixels/content,
all 72 exact external author-script witnesses, loaded-image pins, ownership and
normal exits. Only the candidate reports the direct object-call marker before
PNG. All four SVG source-switch captures and all three comparisons are exact.
Parallel receipts preserve unchanged complete generation fingerprints and
compiler/runtime metadata; no sealed generated-C claim is made.

Cohort **112** retains all **21 attempts**. Brave pair 3 fails its unchanged
pixel reference, invalidating acceptance; 20 capture audits pass and all 21
actual browser exits are 0. Observed launch-to-PNG medians are **27,606,264,572
Vox**, **28,140,792,412 control**, and **17,478,656,250 Brave lower bound**.
The matched point difference is **534,527,840 (1.899%)**, with five improvements
and two regressions. Highest Vox / lowest control is **1.08253**, so no robust
saving is credited. The strict target also fails:
`282713136490 > 156262101750`, observed conservative Vox/Brave ratio **1.62830**.
No failed attempt is retried, removed or combined with another build.

The positive point triggers broader verification despite the invalid cohort.
Each memory mode exercises **615 unique broad cases: 610 passes and the same
five baseline failures** (three layout, two main). Repeated main controls yield
1,378 fresh executions, 1,364 passes and 14 baseline failures. The 21 callback
cases from focused default/no-GC runs carry forward only after all checked
source hashes still match, adding 84 passing executions. The verified union is
636 unique cases per mode (631 passes / five known failures), or 1,462 actual
executions including carried checks: 1,448 passes / 14 known failures.
Preallocation remains separate focused coverage. No full-suite pass or cadence
reset is claimed.

The same completed bundle also validates the pending definite-image candidate's
original pixels/content/scripts/native images/ownership/exits in both arms, but
neither arm reports that path before PNG. ID **111 remains preflight-only** with
zero acceptance browser launches and no image-path instruction credit. Its
native attempts and lease cleanup are preserved with this cohort.

The canonical read lease releases after SVG/cohort checks; input hashes remain
checked throughout. Scope stays exclusive coalition creation through encoded
document PNG, including fresh startup/window/target setup, readiness and two
seconds of settlement. Vox stops before file writing; Brave includes CDP
delivery; audits and teardown follow. Exited aggregates and allowed owned
services are included, GPU execution and outside work excluded. Frozen
609-response original-origin replay, original author scripts, 1024×768 CSS at
scale 2, private profiles/caches, retained OS caches, original per-engine
references and the three common historical rendering policies remain unchanged.
Cross-engine pixels still differ by 82.7154%, with recorded DOM/script/font/paint
limitations. No live-page, isolated rendering or scrolling result is established.

History is **109 measured cohorts / 2,356 acceptance browser attempts**, last
ID 112; IDs 104, 110 and 111 are preflight-only. The 10% target remains open and
BBC homepage stays outside the catalog.
[Every attempt, native/SVG proofs, image no-hit check and regression evidence](performance/bbc-object-receiver-call-cohort112-20261105.json).

## Retained intrinsic text-width checks (2026-11-05)

The separate detailed `v -profile` diagnostic records 24,173 intrinsic width
probes across 16 layout passes. Those instrumented elapsed scopes guide this
experiment; they provide no instruction savings or acceptance totals.

`31050fb5a` retains scalar widths for closed horizontal intrinsic text contexts
across disposable probes. Dirty flags and ordinary intrinsic-cache invalidation
remain active. `913e038d5` additionally checks resolved viewport, scale and root
font contexts that can change without a raw CSS revision. Text, tree membership,
style revisions, measurement inputs and actual font cascades must still match.
Document-owned cloned inputs survive released scratch and measurement pools;
four entries bound each container's retained history. `680644503` supplies the
isolated control.

A same-count child replacement exposed an existing validator reading a detached
text node's inherited style before checking its parent. `5bd6e1e03` reverses
those checks and includes a regression for the within-pass line cache too.
The final **102 focused executions** pass: 17 cases in both arms across all three
memory modes, including 42 executions of seven new cases. All **335 instruction
tool tests** pass. Original fixture failures and the detached-child crash remain
retained with the superseded checks. Native BBC eligibility and an unprofiled
matched cohort remain pending; the 10% target and homepage catalog entry stay open.
[Focused evidence and verified raw archive](performance/bbc-retained-intrinsic-width-focus-20261105.json).

Preflight **113** launched only two separate native diagnostics. Both retain
exact original pixels/content, all 72 external scripts, pinned runtime images,
ownership and normal native exits. Neither reports scalar-width reuse before
PNG. Review of the recorded launch environments found two inherited common
diagnostic flags disabling grid placement and markerless reuse; the initial
protocol prose calling other layout reuse default was incorrect. This no-hit
result therefore does **not** establish default acceptance ineligibility.

The provisional cache and its control are removed in `17e01e5`; the detached
input validator fix `5bd6e1e03` remains. All **66 rollback executions** and
**334 instruction-tool tests** pass. No acceptance browser launched, no
instruction credit is assigned, and no failed attempt is retried or excluded.
History remains **109 measured cohorts / 2,356 acceptance browser attempts**,
last measured ID 112; ID 113 is also preflight-only. A fresh expanded
`v -profile` diagnostic is pending. The 10% target and catalog entry stay open.
[Native no-hit qualification, retained attempts and rollback checks](performance/bbc-intrinsic-width-preflight113-20261105.json).

## Expanded `v -profile` diagnostic (2026-11-05)

A fresh diagnostic selects 5,514 V profiler scopes before execution: generated
main/DOM/CSS/layout/browser-JS bodies of at least 2,200 characters plus the prior
coarse scopes still present. Of these, 2,949 execute. Thread-local main-entry
profiling excludes global initialization and background-thread rows. Complete
source inputs remain unchanged through generation; sealed compiler inputs and
runtime images are verified. Generation, C compilation and capture guards exit
0, with peaks of 6.56, 2.12 and 1.50 GB respectively. Original pixels/content and
all 72 exact external author-script witnesses pass before PNG.

The run records 2,993,967 simple-selector checks, 1,222,999 attribute matches and
1,952,787 candidate-rule additions. These counts motivate checking attribute
name buckets that admit rules for unrelated values. Selected self elapsed is
209.440 ms for simple-selector checks, 112.388 ms for bucket candidate traversal
and 90.314 ms for attribute namespace matching. Instrumentation, unselected
callees/native work, waits and recorded host contention remain included;
recursive inclusive scopes overlap. Neither these times nor comparisons with
the earlier instrumentation establish instruction shares or an optimization.
The profile precedes and cannot validate the exact-value index experiment.
[Expanded profile and complete verified sealed-input archive](performance/bbc-v-profile-expanded-20261105.json).

## Exact attribute-value index: focused checks (2026-11-05)

`24b996c79` indexes required, case-sensitive exact attribute values in the
selector's subject compound. It keeps class/ID priority and the existing paths
for case-folded values, namespace-dependent names, other operators and indirect
`:is()`/`:not()` arguments. Every candidate still runs the complete selector.
Lookup reads current attribute values; ordinary, direct and pseudo-candidate
iterators and `:has()` mutation scans include the new buckets. `4cc1e8921`
provides the isolated comparison control.

All **366 final focused executions** pass: 61 cases in both arms across all
three memory modes, including 36 executions of six new cases. Checks compare
with complete selector matching and cover live `Attr` replacement, empty values,
case/namespace boundaries, pseudo-elements, ancestor conditions, cascade, scope,
quirks and `:has()` invalidation. All **335 instruction-tool tests** pass.
Initial composed-fixture compile errors and the first oracle's missing ancestor
filter/pseudo-target setup remain retained; both arms failed those assumptions.
The corrected oracle and final matrices pass. BBC native eligibility and matched
instruction measurements remain pending; no performance or catalog credit is
assigned from focused tests or the preceding profile.
[Focused checks and retained raw attempts](performance/bbc-exact-attribute-bucket-focus-20261105.json).


## Exact attribute cohort 114 and rollback (2026-11-05)

Seven complete alternating triples retain all 21 successful capture audits and
normal native exits, with unchanged executable/library/fixture/reference/tool
identities. The observed medians are 27,939,302,206 Vox, 27,604,828,574 control
and 18,387,244,433 Brave lower-bound instructions. The exact-value index has
three paired improvements and four regressions: median point regression
334,473,632 (1.212%), with highest Vox / lowest control 1.09602. The strict
Brave target fails `288354550670 > 158331016152`, ratio 1.63909. No saving is
credited; the negative point does not trigger a new broad check or reset its
cadence. The candidate and control are removed in `5871c29` after all 330
rollback executions (55 cases, both arms, three memory modes) and 334 tooling
tests pass. The detached-child validator fix remains.

The correct native diagnostic verifies candidate-only exact-index use before
PNG, all original pixel/content audits, 72 exact external author scripts,
loaded images, ownership and actual exits. Four SVG source-switch captures and
all three comparisons are exact. Its candidate has no extra disable flags;
only the new index is disabled in control. An earlier wrapper misspelled the
diagnostic flag with plural `BUCKETS`, making its marker absence inconclusive.
Those two captures and an equally misconfigured one-arm operator trace are
retained. The corrected trace logs 5,765 candidate and 5,993 control attribute/tag
bucket construction events, largely prefix/substring selectors; these are
repeated construction logs, not unique selectors or instruction savings.

A shared helper edit first stopped the source-identity preflight before browser
launch. Both entire source variants independently pass 366 focused executions.
The completed bundle's whole checked build-HEAD source set matches the original
matrix; current sources match the later matrix. The proof chooses a complete
matrix, with no per-file mixing or claim that the bundle contains later edits.
Parallel generation/compiler/runtime receipts remain pinned; no sealed-C claim
is made. A reused audit report filename stopped postprocessing once; its guard
failure is retained and uniquely named postprocessing then audits the existing
captures. No acceptance capture is retried, excluded or combined across builds.

The canonical read lease releases after the cohort. Scope remains exclusive
coalition creation through encoded document PNG, including fresh startup/window
and target setup, readiness and two-second settlement. Vox stops before file
writing, Brave includes CDP delivery; audits and teardown follow. Exited
aggregates and allowed owned services are included, GPU execution/outside work
excluded. The fixed 609-response original-origin replay, original scripts,
1024×768 CSS viewport/scale 2, private profiles/caches, retained OS caches,
original per-engine references and three historical rendering policies are
unchanged. Cross-browser pixels still differ by 82.7154%; recorded DOM/script,
font and paint limitations remain. This is no live-page, isolated rendering or
scrolling result. The homepage stays outside the catalog.
[Every capture, preflight failure, source proof and rollback check](performance/bbc-exact-attribute-cohort114-20261105.json).
