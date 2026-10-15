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
The broad-verification baseline is now 78,965,962,830 instructions, with zero
additional measured savings credited. Diagnostic profiles, isolated allocation
probes and failed content or pixel checks do not advance that baseline.

Vox remains above Brave's instruction count. A target claim still requires
at least five alternating fresh Vox/Brave runs with all gates passing, preserved
rows and unchanged input/runtime fingerprints.

Focused checks:

```sh
python3 -m unittest discover -s tools -p pikabu_browser_instructions_test.py -v
v -old-compiler -enable-globals test main_capture_audit_test.v
v -old-compiler -enable-globals -gc none test main_capture_audit_test.v
```

Broad regressions follow the repository's instruction-optimization cadence:
after cumulative measured savings of 5,000,000 instructions on the same workload
and endpoint, with the baseline and accumulated saving recorded. Failed content
gates do not establish a Brave parity claim.
