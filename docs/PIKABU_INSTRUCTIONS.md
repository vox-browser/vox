# Pikabu retired-instruction benchmark

The benchmark in `tools/pikabu_browser_instructions.py` compares native Vox and
Brave with full Manifest V2 uBlock Origin on a frozen Pikabu document. Author
JavaScript stays enabled. This is an offline rendering workload; it does not
establish complete browser functionality or live-site parity. A row whose
content gate fails remains a diagnostic and cannot establish the requested
Brave instruction target.

## Inputs and profiles

The original address is `https://pikabu.ru/`, with a 1024 by 656 document
viewport. The main response retains its Windows-1251 content type. Both engines
receive the same archived body bytes. Resources require a body, recorded
response headers, and an identical final URL; final-body-only redirect entries
are not replayed. Missing responses and non-GET requests fail closed.

The native cache's legacy format does not store HTTP status. The replay therefore
normalizes admitted responses to status 200. Cached bodies are already decoded,
so wire `Content-Encoding`, `Transfer-Encoding`, and `Content-Length` are removed
and length is recomputed. Other recorded headers, including repeated fields,
are preserved. This policy is recorded in each result; it is not an assertion
that every archived status is known.

The cache template must remain immutable between runs. Generate a new template
from a populated native cache, with the main page copied from the archived
response that also supplies its headers:

```sh
python3 - <<'PY'
import hashlib, json, pathlib, shutil, sys
sys.path.insert(0, 'tools')
from pikabu_browser_instructions import clone_file, fingerprint_tree
source = pathlib.Path.home() / '.cache/ladybird-v'
target = pathlib.Path('Build/pikabu-instructions-cache-example')
target.mkdir()  # Refuse to overwrite an existing template.
for category in ('pages', 'resources'):
    shutil.copytree(source / category, target / category, copy_function=clone_file)
key = hashlib.sha256(b'https://pikabu.ru/').hexdigest()
body = target / 'resources' / key
headers = json.loads(body.with_name(key + '.headers.json').read_text())
assert body.with_name(key + '.url').read_text() == 'https://pikabu.ru/'
page = target / 'pages' / key
page.unlink(missing_ok=True)
page.write_bytes(body.read_bytes())
page.with_name(key + '.content-type').write_text(next(
    h['value'] for h in headers if h['name'].lower() == 'content-type'))
manifest = fingerprint_tree(target)
target.with_suffix('.manifest.json').write_text(json.dumps(manifest, indent=2))
print(manifest['sha256'])
PY
```

Missing allowed GET resources must be collected before the measured series and
the manifest regenerated. Preserve the actual request's `Origin` and `Referer`
when capturing cross-origin fonts or XHR responses. Fetching fonts without
`Origin: https://pikabu.ru` produced bodies with no allow-origin header and caused
Brave to reject otherwise valid WOFF2 files. Do not invent a wildcard CORS header
to conceal this. A changed template starts a new series; earlier rows retain
their original fingerprints.

For the native font-cache handoff, write `RESOURCE_KEY.status` only from an
actual recorded HTTP receipt whose body hash still matches the cached bytes.
Legacy entries without status metadata remain ineligible for that handoff.
Do not migrate them by assuming status 200. The frozen diagnostic archive with
origin-correct headers and known-status receipts is
`Build/pikabu-instructions-cache-final`, fingerprint
`16d194b736f9123b26b0b9f5311514dd6904ef72a5024d1be7f8a31109157ebe`.
Its per-file manifest and status-receipt provenance are retained alongside it
under `Build/pikabu-instructions-cache-final-{manifest,status-provenance}.json`.

Brave uses a dedicated prepared profile, never the user's personal profile.
Preparation verifies full uBO's MV2 manifest/version against
`adblock/lists/manifest.json`, verifies each list hash, installs the repository's
exact ten lists including `RUS-0`, disables auto-update and Brave Shields, and
saves compiled filtering state. Preparation happens outside measured runs.
Graceful browser shutdown waits for profile database writes. Every measured run
starts with a new copy of this prepared profile and verifies its list settings;
the profile template, extension tree and list manifest are fingerprinted.

```sh
python3 tools/pikabu_browser_instructions.py --engine prepare-profile \
  --binary '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser' \
  --extension '/path/to/full-uBlock-Origin-1.75.0' \
  --profile Build/pikabu-instructions-brave-profile \
  --output Build/pikabu-instructions-brave-profile
```

## Runs and boundaries

Build the process-local native network guard once. It changes no system DNS,
proxy, hosts, trust or firewall settings. It denies external DNS/connect calls,
allows loopback for local browser services, and is fingerprinted in each native
result. Proxy environment variables are cleared. Brave disables proxies, denies
DNS fallback, and services page requests through the frozen CDP replay.

```sh
clang -dynamiclib -O2 -Wall -Wextra -Werror \
  tools/pikabu_instruction_network_deny.c \
  -o Build/pikabu-instructions-network-deny.dylib
codesign --force --sign - Build/pikabu-instructions-network-deny.dylib

python3 tools/pikabu_browser_instructions.py --engine vox \
  --binary Build/v/Vox.app/Contents/MacOS/Vox \
  --cache Build/pikabu-instructions-cache \
  --output Build/pikabu-instructions-vox-1

python3 tools/pikabu_browser_instructions.py --engine brave \
  --binary '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser' \
  --extension '/path/to/full-uBlock-Origin-1.75.0' \
  --profile Build/pikabu-instructions-brave-profile \
  --cache Build/pikabu-instructions-cache \
  --output Build/pikabu-instructions-brave-1
```

`--scratch-dir PATH` places disposable cache/profile copies on another volume.
Use separate prefixes per run. Alternate control/candidate and Vox/Brave order
in repeated series. Pin each measured executable and its non-system runtime
libraries; do not rebuild an executable in place during a series.

Retired CPU instructions come from macOS
`proc_pid_rusage(RUSAGE_INFO_V4).ri_instructions`, through
`tools/process_instruction_counts.py`. Counts include observed process threads
and charged kernel execution. GPU execution and external services such as
WindowServer are excluded. Elapsed time is a watchdog and a secondary observation,
not an instruction estimate.

Vox's total ends at process exit after native document capture and includes the
capture audit, image encoding and teardown. The final root sample is read while
the process is an unreaped zombie. Native first-paint scopes are retained as
separate overlapping diagnostics; they must not be compared to Brave's completed
capture or added together.

Brave's total includes browser startup, ordinary extension startup, renderers,
GPU and utility helpers through the last complete process-tree sampling pass
before the first CDP screenshot response. It excludes later content auditing and
shutdown. The result also records a separate navigation-to-capture delta after
the prepared extension becomes ready. Polling can miss short-lived children or
a final child sample, so the aggregate is explicitly an observed-descendant
lower bound. Counting only Brave's main PID is not a valid comparison.

The total endpoints are asymmetric: Vox includes teardown while Brave stops at
capture. A lower Vox total would be conservative with respect to that extra
native work, but only after content and rendering checks pass. Navigation-only
and whole-startup counts remain separate; neither can be substituted for the
other to cross the target.

## Content checks and current limitations

The shared gate requires the original URL, correct viewport, completed document,
nonempty story titles, real story elements, substantial content, settled fonts,
and a decoded visible story image. The generic native observer is opt-in through
`VOX_CAPTURE_AUDIT_PATH` and `VOX_CAPTURE_AUDIT_CONFIG`; it records retained DOM
text/counts/attributes/rectangles, existing image-model state and actual native
paint image-cache dimensions, current font-set status and JavaScript diagnostics.
Existing font-face entries also retain family/style/weight, load status, parsed
typeface presence, source path and declared sources. Native acceptance requires
the real retained normal Roboto 400, 500 and 700 faces to be loaded with parsed
typefaces and nonempty source paths; an unrelated fallback face cannot satisfy
that gate.
It does not materialize image/font state, force a new layout, or run author
script. Its snapshot occurs when capture is scheduled and is included in native
process-exit totals.

A font set that is absent or unmaterialized is unknown, not loaded. Conversely,
`document.fonts.status == 'loaded'` can include failed faces. Inspect the saved
Brave font audit, loading failures and used font checks before accepting font
comparability. Confirm story counts, first title, visible image source/dimensions
and both viewport captures independently; a loading screen or missing content
cannot earn an instruction win.

The initial frozen samples expose native JavaScript API gaps, including missing
`self` in page bundles, and native capture before `readyState=complete` and font
settlement. These rows are diagnostic. Offline analytics POSTs, a missing
anti-abuse endpoint and an archived Vk API redirect remain disclosed misses.
The request audit records each replay/failure rather than silently using live
network data. Completed offline captures now pass the shared content and font
checks; complete live-site functionality remains unproven.

## Completed-capture results

The following single-run checkpoints use the final immutable archive above.
They are development measurements, not a repeated-series win over Brave.
Counts are whole launch through the capture boundary described above.

| Checkpoint | Retired instructions | Content/font gate |
| --- | ---: | --- |
| Brave, full uBO including RU list | 46,689,653,685 | Passed |
| Vox control v3 | 329,336,880,722 | Passed |
| Vox candidate v3 | 358,818,177,133 | Passed; regression |
| Vox candidate v4 | 168,170,289,723 | Failed: document still interactive |
| Vox candidate v6 | 127,377,534,003 | Passed |
| Vox candidate v7 | 111,444,549,769 | Passed |
| Vox candidate v8b | 89,140,646,198 | Passed |
| Vox candidate v9 | 88,695,567,269 | Passed |
| Vox candidate v10 | 91,187,097,317 | Passed; regression |
| Vox candidate v11 | 106,101,297,297 | Passed; regression |
| Vox candidate v12 | 83,818,061,906 | Passed |
| Vox candidate v13 | 69,618,119,569 | Failed: extra body scrollbar |
| Vox candidate v14 | 78,965,962,830 | Passed |
| Vox candidate v15 | 48,894,785,438 | Passed |
| Vox candidate v16 | 63,190,658,751 | Passed; regression |
| Vox candidate v17 | 45,899,800,267 | Passed; single checkpoint only |
| Vox candidate v18 | 52,605,846,249 | Passed; regression |
| Vox candidate v19 | 57,276,228,995 | Passed; regression |

Candidate v6 uses executable SHA256
`cc105727ad0e7d08d12c94336ca6cd4d26e2c1318416dfddace23c626d1338c2`.
Its 1024 by 656 decoded pixels match the valid native v3 control exactly;
the same 15 stories, first title and decoded story image remain present.
Roboto 400, 500 and 700 have parsed typefaces, with new decoded font files
created during that launch. The uBO engine snapshot and all ten list files
are unchanged. Source, runtime, archive and observer fingerprints are retained
with the measurements under `Build/pikabu-instructions*`.

The valid control-to-v6 reduction is 201,959,346,719 instructions (61.32%).
Candidate v4 receives no savings credit because its document-completion check
failed. The capture scheduling predicate now waits for actual document
completion as well as font readiness. Candidate v5 was built with the older
predicate and was not measured.

Both v6 and v7 have completed the repository's broad regression batch: 135
selected CSS/SVG/layout/native cases in each GC mode, the 100 exact upstream
AST fixtures, production startup and 19 screenshot comparisons. Sixteen
screenshots are exact; three retain their existing sparse fuzzy bounds. All
19 v7 outputs are pixel-identical to v6. The native redraw case runs unchanged
in isolation, alongside the other 39 native cases, to avoid independently
confirmed queued-wake interference in the original v6 aggregate. The original
failed aggregate receipts remain preserved.

Candidate v7 uses executable SHA256
`25ddf4e9586f7f2695d1526a842edcc2eec85b77103bfceb11d098c14e2ef627`.
It saves another 15,932,984,234 instructions (12.51%) relative to v6, with
identical decoded pixels and the same completed-document and actual-Roboto
checks. Its authenticated broad summary and cadence reset are retained at
`Build/pikabu-instructions/broad-v7/{final-broad-summary,cadence-baseline-reset}.json`.
Candidate v8 was stopped before C compilation when review found incomplete
font-refresh guards. It has no measurement or savings credit. The corrected v8b
preserves all font-relative consumers while distinguishing size-relative units
from loaded-face metrics, and avoids recascading an unchanged adblock sheet.
Its executable SHA256 is
`e7f76e3d0ffebecbcfe9426016c97e19a8d6922a03efe45ba86e8b1febdc62f1`.
It saves 22,303,903,571 instructions (20.01%) relative to v7.

Candidate v9 shares immutable CSS gradient paint payloads and avoids allocating
optional layout flags for unchanged defaults. Its executable SHA256 is
`b9dbfede3c2702575d6d0c3784625aeb31053aad29870115d3177915687a3127`.
Its single checkpoint saves another 445,078,929 instructions (0.50%) relative
to v8b. Both v8b and v9 passed the same broad batch described above: 135 cases
per GC mode, 100 exact AST fixtures, production startup and all 19 screenshots.
Their outputs remain pixel-identical to v6 and v7. Authenticated summaries
and cadence resets are under `Build/pikabu-instructions/broad-v8b/` and
`Build/pikabu-instructions/broad-v9/`.

Candidate v10 adds compact cascade history storage and reuses freshly prepared
DOM layout wrappers within the same layout pass. Its executable SHA256 is
`464c81111cb048c1c36d4bdfb7909040a8f51be5cdf6b0ca0e0e6a6fd093adf4`.
The first completed checkpoint regresses 2.81% against v9. Two additional
matched pairs preserve the variance rather than establishing an improvement:

| Run order | v9 instructions | v10 instructions |
| --- | ---: | ---: |
| v9, then v10 | 92,048,685,106 | 91,919,067,499 |
| v10, then v9 | 91,703,081,177 | 104,651,408,533 |

Across all three observations of each build, medians are 91,703,081,177 for v9
and 91,919,067,499 for v10. All six captures pass the content/font gate and have
identical decoded pixels. A separate matched GC diagnostic records less
allocation for v10; it provides no primary instruction savings credit.
The comparison receipt is
`Build/pikabu-instructions/v9-v10-audit-phase-memory-comparison.json`.

Candidate v11 moves seldom-used computed layout values into an immutable,
lazily copied record. Its executable SHA256 is
`96dd767e119c6559ac0c77f3d4f87eae2fcf4c75e616cc55fde5dc84c02de1f6`.
The completed checkpoint regresses 19.62% against v9. A separate, controlled
cache ablation records 94,076,157,016 instructions without that cache versus
95,249,901,586 with it, with identical pixels and the same seven tree builds
and ten formatting passes. The cache lowers peak memory by 42.43 MB in that
pair, but neither this ablation nor allocation traces earn primary savings
credit. Receipts are retained under
`Build/pikabu-instructions/v11-cache-ablation-*`.

Candidate v12 keeps frequently updated content and marker values inline,
shares immutable SVG gradient/filter payloads, reuses live DOM layout mirrors,
and caches the exact layout-stabilization element count by tree version.
Its executable SHA256 is
`56934eaef478d45d732c89e635eebb4a1b9cba41c014721407e2844183ef16f7`,
built from frozen revision `67c853d6380cb1ab4c5b015d5a17046b4a9be584`.
The single checkpoint saves 4,877,505,363 instructions (5.50%) against v9.
The same 15 stories, exact first title, decoded image and actual parsed Roboto
faces pass, and decoded pixels remain identical to the native control.

Candidate v12 also passed the same broad batch: 135 cases per GC mode,
100 exact AST fixtures, production startup and all 19 screenshot comparisons.
Sixteen screenshots are exact and three retain their existing fuzzy bounds;
all 19 native outputs match v6 exactly. The authenticated summary and reset
are retained under `Build/pikabu-instructions/broad-v12/`.
Candidate v13 separates the viewport's layout overrides from authored element
styles, avoiding a full tree rebuild when the cascade restores body overflow.
It also shares UA selector caches across empty shadow scopes, reduces anonymous
style resolution, and removes redundant inline-position and glyph copies.
Its content, completion, image and actual-Roboto checks pass, but 4,736 pixels
differ from the native control: one extra body scrollbar at the right edge.
That row receives no savings credit and triggers no broad-baseline reset.
Its executable SHA256 is
`d9276f0b65a634693ccf249ce26fb9aa26826a321808e4130d2d4ee6ceec4556`.
The failed strict receipt remains preserved under
`Build/pikabu-instructions/candidate-v13-measure-watch-state.json`.

Candidate v14 fixes four paint helpers that still read authored overflow,
writing mode, direction or scrollbar width instead of the layout overrides.
The duplicate body scrollbar disappears while authored computed styles remain
intact. Its executable SHA256 is
`66eee3d64c6e90fc8e10d0c0c079d1a6e75bc2236abe329682546f036e9a8682`,
built from frozen revision `2205cbf096608395dc3e897ad609c9bab1786773`.
Its single completed checkpoint saves 4,852,099,076 instructions (5.79%)
against v12. All content, font, fresh font-file and exact native-pixel checks
pass with unchanged archive, lists, observer and endpoint.

Candidate v14 passed 135 cases in each GC mode, all 100 exact AST fixtures,
production startup and all 19 screenshot comparisons. Sixteen reference
comparisons are exact; three retain the same existing fuzzy bounds. All 34
native captures are fresh, and all 19 outputs match both v6 and v12 exactly.
The authenticated summary and reset are retained under
`Build/pikabu-instructions/broad-v14/`.
Candidate v15 installs CSS already primed by uBO before procedural selectors
flush styles, avoiding a second full-page style pass. It also replays adblock
mutations through keyed lookups, borrows counter-style descriptors and internal
normal font settings, reuses current unboxed styles for CSSOM reads, and reuses
bounded measurement chunks within one document layout. Its executable SHA256 is
`b77b4527d08e743a18b98290d629f25f931fe95181e2511da9f55eec4f02b196`,
built from frozen revision `aabcd7700989bf6ee269830041fca2a81df10231`.
The single checkpoint saves 30,071,177,392 instructions (38.08%) against v14.
All content, font, fresh font-file and exact native-pixel checks pass without
changing the archive, filters, observer, completion gate or production GC.
The frozen source preserves the independently committed video-poster feature;
this combined measurement does not isolate each change's contribution.

The archived-page style diagnostic records 3,903 recomputations instead of
7,806, with byte-identical final adblock CSS. That instrumented diagnostic and
the separate sampling runs receive no additional performance credit.

Candidate v15 passed the same 135 cases per GC mode, all 100 exact AST fixtures,
production startup and 19 screenshot comparisons (16 exact, three within the
unchanged fuzzy bounds). All 34 native captures are fresh; all 19 outputs match
v6 and v14 exactly. The interrupted final native no-GC check was preserved and
resumed; completed checks and captures were retained. The authenticated summary,
actual-zero finalizer receipt and reset are under
`Build/pikabu-instructions/broad-v15/`.
The broad-verification baseline is now 48,894,785,438 instructions, with zero
additional measured savings credited. Diagnostic profiles, isolated allocation
probes and failed content or pixel checks do not advance that baseline.

Candidate v16 adds conservative shared-style identity checks and a fast path
for non-combining Cyrillic graphemes, and preserves the independently committed
live video-dimension getters. Its executable SHA256 is
`0448d96df77877edd738eb70e6fa28636e784c9217da9bfec1754230864ad189`,
built from committed frozen revision
`fc35908f152ef66045819d1eb149cf0514d3f6ec`. The source was read from exact
Git objects; concurrent uncommitted JavaScriptCore host-file changes were
recorded and excluded. All content, font, fresh font-file and native-pixel
checks pass. The completed primary checkpoint nevertheless uses
14,295,873,313 more instructions than v15 and earns no savings credit, broad
batch or baseline reset.

A separate reverse-order diagnostic pair records 47,886,531,355 instructions
for v16 and 47,257,583,987 for v15, with identical native pixels and all gates
passing. The 1.33% regression in that pair is much smaller than the primary
regression; the original row remains preserved. This diagnostic investigates
run variation and earns no primary performance credit. Its receipt is
`Build/pikabu-instructions/v16-v15-matched-pair-diagnostic.json`.

Candidate v17 reserves inline-item capacity from retained text chunks and emits
general grapheme boundaries directly, preserving the exact V13 tables and rule
ordering while removing temporary cluster strings. Its executable SHA256 is
`67f5206079ae7c00526d93b3c5f80e9c9ca8b3d4f471883eb9aa7c04c6aaf3b7`.
The isolated committed source revision is
`c5ca0dce5aa374730586fce1f26cf6174f5e31b5`; its two feature snapshots retain
the exact tested blobs from canonical commits `ebeac4b8` and `17270386`.
Concurrent OpenSSL changes, documentation and uncommitted host-file changes
remain preserved in the canonical checkout and are excluded from this build.

The valid single checkpoint saves 2,994,985,171 instructions (6.13%) against
v15. It passes completion, all 15 stories, title, decoded image, loaded Roboto,
fresh font-file and exact native-pixel gates. The same broad batch passed:
135 cases in each GC mode, 100 exact AST fixtures, production startup and all
19 screenshot comparisons (16 exact, three within unchanged fuzzy bounds).
All 34 native captures are fresh and all 19 native outputs match v6 and v15
exactly. The summary and reset are under
`Build/pikabu-instructions/broad-v17/`; the new broad baseline is
45,899,800,267 instructions with zero additional savings credited.

The required five alternating fresh Vox/Brave pairs did **not** confirm a win.
All ten rows pass their content/font/image gates, and all five Vox captures
retain identical native pixels and fresh font files. Vox's median is
48,646,816,544 instructions versus Brave's 47,141,548,806: Vox uses 3.19% more,
with two pair wins out of five. Every row is preserved under
`Build/pikabu-instructions-candidate-v17-final*`, including the Vox runs at
59,182,518,815 and 55,595,049,138 instructions. The source, filters, archive,
endpoint and runtime fingerprints stay pinned. The target remains unachieved;
these repeated observations do not advance the broad-baseline savings carry.

Candidate v18 adds the standalone U+2060 fast path and replaces encoded
grapheme-property ranges with static numeric intervals. The focused selections
pass 49 and 48 cases respectively in each GC mode, including complete Unicode
property comparisons for the numeric intervals. Canonical commits `813985a1`
and `68fcaf57` retain their focused tests. The isolated source revision is
`a38652e3d878fe48c4d005d36b04b42365fbe6f3`, and its production executable
SHA256 is `340cade672b955ea26a69804c5701729a56bfa839349d2336021f3b05a0281f6`.

The primary checkpoint passes every completion, content, font, fresh font-file
and native-pixel gate, but uses 52,605,846,249 instructions: 6,706,045,982 more
than the v17 broad baseline. The broad supervisor terminates without running
suites or removing the held helper guards. The baseline stays 45,899,800,267,
with zero additional savings credited.

A separate fixed five-pair variation check also fails the target. Vox's median
is 49,116,308,193 versus Brave's 48,430,875,718, or 1.42% more instructions,
with two wins out of five. All ten completed rows pass their content/font/image
checks; all five native captures retain the exact control pixels and fresh
font files. Every row is preserved under
`Build/pikabu-instructions-candidate-v18-variation*`, authenticated by the
completed-cohort verification and actual-zero supervisor receipts. Neither
this variation check nor the isolated shaping microbenchmarks earn a broad
baseline reset. The faster-than-Brave target remains unachieved, and this
isolated candidate has not replaced the canonical app bundle.

### Candidate v19: regressing primary and lower variation median

Candidate v19 contains two separately committed ownership changes. Cold glyph
producers transfer their fresh vectors into the retained glyph run while public
constructors keep copying caller-owned input. Commit `22bebff7` passed 41 focused
cases in each GC mode on its recorded canonical base, including exact original
producer comparisons and ownership after collection. Image paint geometry moves
into an optional shared payload, reducing the common command from 1,928 to
1,608 bytes. Commit `75966fb5` passed 108 focused cases per GC mode: 88 unchanged
layout cases carried from the tested slice and 20 freshly run native cases on
the merged source with the independent video changes. Its 42 microbenchmark rows
retain exact comparisons of all 108 logical fields and SVG output. These focused
checks and microbenchmarks assign no separate per-page savings to either feature.
The evidence is retained in
`Build/pikabu-instructions-{cold-glyph-transfer,paint-image-payload}-checks.json`.

The measured source is the complete canonical committed revision
`75966fb5f5ca6373b629fc08d336efd41d28a9f5`, with 5,866 files, including the
concurrent Linux, JavaScriptCore, OpenSSL and native-video work. Its signed
production build and headless startup passed. The executable SHA256 is
`4ca1de86cb08026400f47a8f809db29ace021a5659443973628c72c5f34958c7`.
The primary checkpoint passes completion, content, fonts, fresh font files and
exact native pixels, but uses 57,276,228,995 instructions: 11,376,428,728 more
than the v17 broad baseline, a 24.79% regression. The broad supervisor exits
successfully at its insufficient-savings gate without launching suites or
removing the four held helper guards. The baseline remains 45,899,800,267,
with no new broad credit or reset.

A separate fixed five-pair variation check records:

| Pair | Vox instructions | Brave instructions |
| --- | ---: | ---: |
| 1 | 43,755,407,015 | 47,751,929,604 |
| 2 | 43,459,303,543 | 47,393,137,227 |
| 3 | 46,469,235,529 | 47,086,909,064 |
| 4 | 53,763,857,469 | 46,942,611,331 |
| 5 | 47,202,920,471 | 47,174,279,634 |

Vox's median is 46,469,235,529 instructions versus Brave's 47,174,279,634,
or 1.49% fewer, with three pair wins out of five. Median paired savings are
617,673,535 instructions. This series meets its recorded median criterion;
the two lost pairs and the regressing primary remain part of the evidence.
All ten completed rows pass content, font and image checks. All five native
captures retain exact control pixels and three freshly decoded Roboto font
files per launch. The actual-zero measurement, verifier and supervisor receipts
are retained with every row under
`Build/pikabu-instructions-candidate-v19-variation*` and
`Build/pikabu-instructions/candidate-v19-variation-cohort-attempt1/`.

The result applies to the archived server-rendered Pikabu document with author
JavaScript enabled and the same fail-closed resource replay. It does not establish
live-site or complete JavaScript functionality parity. The asymmetric native
process-exit and Brave observed-tree capture endpoints remain unchanged. The
variation result does not replace the primary checkpoint or earn a broad reset;
repeatability and broad validation of this complete composition remain open.

### Candidate v20: narrow primary median margin, no broad reset

Candidate v20 combines four separately committed changes. The host last-label
scan (`75780f20`) removes split allocations; 17 URL test files containing
89 functions pass per GC mode. The ASCII ACE-label scan (`9cf93a69`) removes
per-label splitting and lowercase allocation inside the existing nonstrict
ASCII IDNA branch; 94 cases and 443,077 assertions pass per GC mode. Valid
empty inline chunks (`15c67b10`) distinguish an empty cached result from an
absent or stale cache; the original focused runs pass 43 cases and 34,383
assertions per GC mode. SVG path paint data (`bde1e411`) moves 18 immutable
fields into a shared optional payload, reducing the common command from
1,608 to 1,280 bytes. Its fresh focused checks total 159 cases and 173,552
assertions per GC mode across three separate child runs: 134 layout, 23 native
and two integration cases. The respective optimized micro series retain
30, 42, 48 and 48 rows, with no per-feature page savings credited. Source,
focused dependency scopes, ownership checks and micro regressions remain in
the [four-component policy](../Build/pikabu-instructions/candidate-v20-components-policy.json)
and its linked root reviews.

The full committed source is
`bde1e411783f66f45e024920aeced01be49ee065`, containing 5,874 authenticated Git
files with exact blobs, modes and membership and no source overrides or
fallback. The [manifest](../Build/pikabu-instructions/candidate-v20-source-manifest.json)
and [authentication](../Build/pikabu-instructions/candidate-v20-source-auth.json)
retain the complete concurrent committed work. The normal Boehm/O2 production
build, signing checks and headless startup pass with actual-zero exits. The
executable SHA256 is
`b2ebd624744a1e9cca763e6f4454ebbeb52175dc75c92cc7fd63908213120bca`.
The [completed helper receipt](../Build/pikabu-instructions-candidate-v20-check.state.json)
binds that executable, its six-file signed bundle and 30-file non-system runtime
closure, archive, prepared Brave profile, full MV2 uBO/list snapshot, driver
and instruction counter to the series.

The [primary plan](../Build/pikabu-instructions/candidate-v20-primary-aggregation-plan.json)
was fixed before source freeze, build and measurement. Five fresh alternating
Vox/Brave pairs replace the earlier single primary followed by a separate
variation cohort. The order is Vox1/Brave1, Brave2/Vox2, Vox3/Brave3,
Brave4/Vox4 and Vox5/Brave5. All ten valid rows are required; invalid rows abort
without credit, and rows cannot be dropped, replaced or stopped for performance.
The primary is the median of all five completed native lifetime totals;
Brave's median and median paired savings are reported separately.

| Pair | Vox instructions | Brave instructions |
| --- | ---: | ---: |
| 1 | 55,315,486,868 | 48,084,882,379 |
| 2 | 58,969,044,694 | 47,248,636,486 |
| 3 | 45,151,975,245 | 46,954,350,808 |
| 4 | 45,032,095,512 | 47,713,891,695 |
| 5 | 47,202,746,972 | 47,207,324,731 |

Vox's median is 47,202,746,972 instructions versus Brave's 47,248,636,486,
or 0.09712% fewer, with three pair wins. Median paired savings are 4,577,759
instructions. This satisfies the prespecified observed-median criterion,
but the small margin and native range of 45.032 to 58.969 billion instructions
do not establish a repeatable speed advantage or complete the optimization goal.
A [separate opt97 experiment overlapped part of this series](../Build/pikabu-instructions/c20-foreign-opt97-overlap-read-only-receipt-attempt1.json),
including its early rows and later validation work. Timing alone does not
establish a cause for any row's count. All ten rows remain included, with no
subset or replacement series used to improve the result.

All ten completed rows pass content, font and image checks, retaining the same
15 stories, first title, completed document and decoded visible story image.
All five native captures have exact control pixels, actual retained Roboto
400/500/700 faces and three newly decoded TTF files created during each launch.
The [completed-cohort verification](../Build/pikabu-instructions-candidate-v20-check.completed-cohort-verification.json)
retains every result hash and all five pairs. Build, smoke, measurement, verifier
and both supervisors finish with actual-zero exits, recorded in the
[build/measurement terminal receipt](../Build/pikabu-instructions/candidate-v20-build-measure-attempt2/actual-exit.json)
and [pipeline exit](../Build/pikabu-instructions/candidate-v20-pipeline-attempt1/actual-exit.json).
The [initial rejected launch](../Build/pikabu-instructions/candidate-v20-root-launch-attempt1-failure.json)
remains preserved: an authorization-key mismatch failed before any build or
measurement child started; its actual exit code was not collected.

The native median exceeds the fixed C17 broad baseline of 45,899,800,267 by
1,302,946,705 instructions. Comparing C20's five-launch median with C17's
existing single-launch point uses asymmetric sampling, as disclosed before
measurement. The signed 5,000,000-saving gate fails. The broad pipeline exits
successfully at `terminal-insufficient-valid-primary-saving-no-broad`; no broad
suite or broad screenshot captures ran, none of the four helper holds is removed,
and no cadence reset or app installation is credited. C17 remains the established
broad baseline with zero new savings credited.

The [freeze-time test disclosure](../Build/pikabu-instructions/candidate-v20-excluded-test-repair-disclosure.json)
records a separate uncommitted empty-cache fixture repair that was excluded
from C20's exact committed tree. Its post-invalidation check incorrectly required
font pointer identity even though rebuilding can create equivalent native font
owners. The repair compares resolved face, settings and metrics after
invalidation while retaining pointer checks for valid caches. It subsequently
committed as `2c57d7a7`, outside the measured source. The original focused results
retain their exact provenance; C20 receives no validation credit for that later
test repair and makes no claim that all current tests pass.

This remains an archived server-rendered Pikabu workload with author JavaScript
enabled and fail-closed replay. It does not establish live-site or complete
JavaScript functionality parity. Vox's process-exit total includes audit, capture
encoding and teardown; Brave's observed descendant-tree lower bound stops at
its first CDP capture response. These asymmetric endpoints remain unchanged.

Focused checks:

```sh
python3 -m unittest discover -s tools -p pikabu_browser_instructions_test.py -v
v -old-compiler -enable-globals test capture/audit_test.v
v -old-compiler -enable-globals -gc none test capture/audit_test.v
```

Broad regressions follow the repository's instruction-optimization cadence:
after cumulative measured savings of 5,000,000 instructions on the same workload
and endpoint, with the baseline and accumulated saving recorded. Failed content
gates do not establish a Brave parity claim.
