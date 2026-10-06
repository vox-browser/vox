# Native HTML media buffered snapshots

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature: `5f567830e882b6c6385902a09b04cf17a33a8ac0`.

HTML audio/video wrappers now expose buffered through the media model attached
to their actual DOM element. The native getter validates the receiver before
replaying pending document changes and wraps each returned snapshot through
[TimeRanges](NATIVE_TIME_RANGES_OWNER.md). It does not derive ranges from the
compact script state. Append/removal leave earlier snapshots unchanged; the
[removal cache prerequisite](MEDIA_REMOVAL_RANGES_OWNER.md) refreshes the model
before queued updateend callbacks.

Parser-created elements retain their original DOM owner. Script-created
media are materialized once and reused during insertion replay. Ordinary
elements and SVG namesakes are not branded. Startup captures the private
binding helper, so author replacement does not redirect later creation.
Prototype and TimeRanges wrapping likewise use stored native records instead
of replacement public constructors. Receiver Proxy traps are not invoked;
original replay exceptions retain their actual JavaScript value.

The native buffered getter has the IDL readonly, enumerable/configurable
flags and native name/length metadata. HTMLMediaElement becomes a partial
interface constructor with illegal invocation/construction and all nine
pinned constants on the constructor and prototype. Existing compact element
operations remain. Its prototype currently inherits EventTarget directly;
the complete HTMLElement/HTMLAudioElement/HTMLVideoElement hierarchy and leaf
string tags are not implemented by this slice.

## Checks

Four host cases cover getter metadata/constants and brand-before-replay rules;
actual playback hooks and static snapshots; original replay exceptions;
and independent Runtime maps plus closed-owner cleanup. Two root cases cover
actual sourceopen/updateend append/removal and created-audio DOM identity,
with ordinary/SVG receiver rejection. The byte fixture exercises translated
VP9-track range records, not complete codec or playback execution.

| Run | Result | Seconds |
| --- | --- | ---: |
| baseline | Original missing-interface/getter assertion fails at runtime | 33.535 |
| focused | Duplicate platform method, zero runtime in both files | 2.409 |
| focused-corrected | Host helper fails compilation; both page cases fail at runtime | 38.468 |
| focused-final | Four host cases and two page cases PASS | 126.947 |
| default | 8/8 files PASS | 446.262 |
| gc-none | 8/8 files PASS | 417.893 |

The first platform stub lacked its conditional guard. The next host fixture
used Option propagation inside a Result-returning helper. Those compiler
failures are retained separately from the executed missing-getter baseline
and page failures for stale removal ranges and duplicated created media.
Before the host cases execute, playback-hook fixture expectations are aligned
with pinned TimeRanges.add_range(), which appends supplied ranges.

Final eight-file commands use `/Users/alex/code/v/v -old-compiler
-enable-globals`, `VJOBS=2`, with `-gc none` for the second mode. They include
the two new files, native TimeRanges, the previous SourceBuffer snapshot page,
image decode, the 66-case main regression and the two removal neighbors.
Paired manifests retain identical unchanged 4,865-file snapshots, eight
selected Source references and two compiler executables. Unrelated formatting
in the two prerequisite implementation files is subsequently restored with
literal/token checks and separately passing two-file checks in both modes;
all other implementation/test file bytes match these native sweeps.

## Frozen production proof

The signed `5f567830` bundle builds with `./build_ladybird.sh` using the
production compatibility compiler, `-enable-globals -prod -gc none`, Skia,
FFmpeg and Rust YUV bridges. Build duration is 1,132.909 seconds. Ad-hoc
signature verification and `--headless-smoke` pass. The public append/remove
media-range page matches all 480,000 pixels with explicit zero tolerances.

The first SVG comparison phase captures both pages successfully but its
direct fallback-compiler invocation selects an incompatible vinix V library
path. All comparator compilations fail before computing differences. This
failed phase is retained with its seven executed command records. A separate
comparison-only continuation uses a repository-private wrapper that invokes
`/Users/alex/code/v/v -old-compiler`. It verifies all 13 retained SVG image
pairs with explicit zero tolerances; no browser recapture is needed. The same
binary then passes all 11 default smoke cases. Eight are pixel-exact;
inline-node (13 pixels, maximum channel error 1), text-decorations (1,341,
maximum 2), and canvas-text (1,994, maximum 8) pass their existing per-case
bounds. No tolerance changes are made.

The SVG set covers same-size image replacement, HTML/SVG ID collisions,
script-added stops, moveBefore ordering, animation end values, href/offset/
transform changes, pattern changes, hidden-server inherited styles and
non-server fallback. Both production phases retain unchanged 4,865-file
snapshots and 25 selected Source references; they share this unchanged binary
SHA256:
`9a1c3e90217883176b16decfe571f13a979297c5489784343161d551aa3f7586`.

The original production manifest SHA256 is
`39e4828efe1552e891f48f106e00474f0565d4341984d859d197b739a9dd9559`;
the successful comparison continuation SHA256 is
`0c6cd6233162bcf0aa4b2215ff0ced09db129b72a4ba8c64b3ae345b73c87137`.
Retained fixtures, screenshots, diff heatmaps and logs are under
`Build/audit-fixes/native-media-buffered-production/`.

The consolidated `Build/audit-fixes/native-media-buffered-evidence.json` has SHA256
`7182f3d93289dc8eafc78948622ad23de5b73ff0164252925948a17af8c71f36`. It records manifest/log hashes, retained failure
representations, compiler/reference checks, feature file hashes, formatting
restoration and the subsequent frozen production runs. Manifests and logs
use the `Build/audit-fixes/native-media-buffered-<mode>` prefix.

The subsequent [native media state slice](NATIVE_MEDIA_ELEMENT_STATE_OWNER.md)
adds readonly scalar getters and replaces the compact HTML-media readyState
shadow. It preserves this buffered transport and verifies its own snapshot.

## Remaining scope

Played and seekable stay separate: existing V histories/ranges differ from
the pinned Source FIXMEs and duration-derived seekable result. Foreign realm
borrowing, DedicatedWorker startup, complete element prototypes and native
media operations/events, multi-buffer playback aggregation, WrapperWorlds,
IPC and physical weak/strong collector equivalence remain open. Wrapper/native
maps retain records for their Runtime lifetime. The browser still uses
JavaScriptCore; no new Wasm or LibJS sweep is claimed.

The refreshed 78-owner module inventory is 432,292 implementation / 153,795
test V LOC; browser/root support is excluded and these counts do not measure
parity. The audit stays 32 fixed / 25 partial / 9 open.
