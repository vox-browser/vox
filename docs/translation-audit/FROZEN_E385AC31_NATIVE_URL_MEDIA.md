# Frozen native URL and MediaSource verification at e385ac31

Snapshot `e385ac31659e02c680ac53d0505f475e846d05ca` against Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa` verifies the integrated native URL,
URLSearchParams, Blob/File object-URL and MediaSource slices. It includes the
queued-event identity and changed media src replay corrections. This refreshes
production evidence after the [f273f1ef bundle](FROZEN_F273F1EF_BLOB_URL_CONTINUATION.md),
which predates those native methods.

All five manifests retain identical before/after HEAD, clean tracked status,
SHA256 hashes for all **4,844 tracked files**, the upstream HEAD/status
and both compiler executable hashes. Native captures use the same signed
binary throughout. No implementation changes occur during verification.

## Commands and results

Package checks run `/Users/alex/code/v/v -old-compiler -enable-globals test
webassembly domurl`, with `VJOBS=2`; GC-none adds `-gc none`. Each command
passes all **114 Wasm files and five DOMURL files**. This is a current package
sweep, independently of the earlier focused native binding checks.

Production runs `V_BIN=/Users/alex/code/v/v ./build_ladybird.sh`, selecting
`-old-compiler -enable-globals -prod -gc none`. The bundle passes
`codesign --verify --deep --strict` and executable `--headless-smoke`.
Complete argv, environment, exits, timings and per-log hashes are retained
in the manifests below.

| Check | Result | Seconds |
| --- | --- | ---: |
| packages-default | 119/119 default GC | 275.086 |
| packages-gc-none | 119/119 GC-none | 306.950 |
| build | PASS | 228.944 |
| codesign | PASS | 0.022 |
| headless | PASS | 1.958 |
| targeted | 8/9 pixel-exact; exit 1 | 80.155 |
| smoke | 11/11 within configured tolerances | 91.286 |
| targeted-retry | 9/9 pixel-exact | 77.295 |
| feature-headless | PASS | 0.116 |
| feature-reference | PASS | 2.759 |
| feature-capture | PASS | 2.722 |
| feature-diff | Zero differing pixels; reporting mode | 2.685 |
| feature-strict-diff | PASS with explicit zero tolerances | 2.205 |

The first targeted run fails `gradient-stop-color-animation`: its 100×100
square retains the initial red-to-green gradient, with **10,000 differing
pixels**, maximum channel error **254**, MAE **0.9974** and RMSE **11.8888**.
The other eight cases are pixel-exact. Its manifest keeps `success=false` and
exit 1. A complete nine-case rerun uses the same inputs, default two-second
settle, scripts and binary in a new output directory; all nine are pixel-exact.
The original failure and PNGs remain intact. This retry does not establish a
cause or fix for the intermittent capture result.

Targeted cases cover same-size SVG image replacement, gradient removal, live
selection insertion, SVG/HTML paint-server ID collisions, gradient-stop
move/add/animation and pattern transform mutation. The standard eleven-case
smoke set passes on its first run. Eight smoke cases are pixel-exact; three
retain the same residuals as the preceding bundle:

| Case | Differing pixels | Maximum channel error | MAE | RMSE |
| --- | ---: | ---: | ---: | ---: |
| inline-node | 13 (0.0027%) | 1 | 0.0000 | 0.0026 |
| text-decorations | 1341 (0.2794%) | 2 | 0.0013 | 0.0419 |
| canvas-text | 1994 (0.4154%) | 8 | 0.0038 | 0.0928 |

## Public native page

Private fixture `Build/audit-fixes/source-native-media-source-e385ac31-feature/input.html`,
SHA256 `9121d5d3eac5f560dae35cd49263f185b6fca1a597de77d7109c9a9e100c0fa9`, uses an actual local-file
navigation and its genuine Document/Window settings. Absolute HTTPS strings
inside URL parsing checks do not substitute a fabricated settings origin.

Author JavaScript verifies live SameObject query writeback, URL parse/canParse
and webkitURL, literal leading query questions and preserved leading BOM,
Blob/File object-URL creation and revocation, MediaSource initial state and
statics, and BigInt rejection before duration state validation. Headless
startup explicitly checks the synchronous success log and absence of a
failure log; it does not claim queued media events ran headlessly.

The windowed fixture begins with a red viewport. It turns lime only after
actual queued sourceopen and sourceended callbacks verify the original
MediaSource target, currentTarget, callback receiver and trusted flag, duration
writeback, endOfStream state, and revocation without closing the attachment.
Native screenshot input/reference are captured through the canonical viewport
workflow at 800×600. All **480,000 pixels match exactly**. The initial diff
command reports metrics without a failing threshold; a separate command on the
same retained PNGs supplies explicit `0 0` bounds and passes. Both commands,
the fixture, PNGs and immutable binary hashes remain recorded.

This production page supplements the [focused actual-owner tests](NATIVE_MEDIA_SOURCE_OBJECT_OWNER.md).
It does not expose or certify the complete JavaScript HTMLMediaElement or
SourceBuffer API, physical wrapper GC, or general media playback.

## Evidence and boundaries

- Before record: `Build/audit-fixes/source-native-media-source-e385ac31-before.json`, SHA256 `422cc927f366e4bcd450dd227d9db03bb4b839a5a7f421f7ca8792915dc72a06`.
- Whole tracked-file map SHA256: `2082d3cac3e8054dfbfb79e0e6eb27132caae2a172ec5058eafdd6f31261b791`.
- Native binary SHA256: `1c194363ffd9cac5e83bd7c6325042df074c82e604262c26eb0f449a940c8274`.
- `Build/audit-fixes/source-native-media-source-e385ac31-packages-manifest.json`, SHA256 `bb37b039e986ec9d4f02f820024051e339d7db63634445fbabaa1caf805a21cd`.
- `Build/audit-fixes/source-native-media-source-e385ac31-native-manifest.json`, SHA256 `e37d0ebb2ff9f8fe78dd19448495031c32968daf2b43375cd1f92e71378208ec`.
- `Build/audit-fixes/source-native-media-source-e385ac31-targeted-retry-manifest.json`, SHA256 `f93dfbdbc4fc0675335a7e362947e23a0c25bee9eaec8b3771c9aa1e58eed6cd`.
- `Build/audit-fixes/source-native-media-source-e385ac31-feature-manifest.json`, SHA256 `59208454cefc5394acd87458c3c6a8d54db1b019f76ef99b97b3f1be12e5b14b`.
- `Build/audit-fixes/source-native-media-source-e385ac31-feature-strict-manifest.json`, SHA256 `a8f2e3f6172e7b9481b02cc829f66659b894642433d64c1ee63f6f2687ceba63`.

Retained helper scripts:

- `Build/audit-fixes/run_media_source_frozen_verification.py`, SHA256 `8944b1b702809b92c04b5c942ca2b81dee02855295b0eb25b1ef071a88373a86`.
- `Build/audit-fixes/run_media_source_targeted_retry.py`, SHA256 `91f4ad586720342a53bcbe1631bafe6a044fea353102246d677609e15332d172`.
- `Build/audit-fixes/verify_production_media_source_page.py`, SHA256 `027f0ecb16e33cba4a5670302a8588e3ffa1009a4524aba29dfffbdeb044b126`.
- `Build/audit-fixes/verify_production_media_source_page_strict.py`, SHA256 `2b78149b07699c2def98b2b2196a08cfc28defacec46260df5ea709109b8f075`.

Comparison PNG directories use the `source-native-media-source-e385ac31` prefix with
`-targeted`, `-targeted-retry`, `-smoke` and `-feature` suffixes. The
previously committed 78-owner inventory remains **432,272 implementation V
LOC / 153,433 test V LOC**; verification changes no module implementation or
tests, and physical counts do not measure parity.

The audit remains **32 fixed / 25 partial / 9 open**. Native buffer bindings,
Worker/foreign realm/world identity, Source event clock integration, physical
GC/IPC ownership, Wasm instantiation/interpreter/native compilation, and full
LibJS execution/builtins remain unfinished. Browser execution continues to use
JavaScriptCore. External libraries and the complete native toolchain are
outside this file/compiler freeze. No current whole MediaSourceExtensions,
LibJS or full-repository test sweep is claimed.
