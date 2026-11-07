# Native media currentTime property owner

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and seven focused cases: `16f4c31c2a9b479da163fcdeb97b3680292a31df`.

Native currentTime reads and writes now use the actual HTML audio/video model.
The compact page object's synthetic currentTime property is removed, so it
cannot shadow the native getter or keep an independent timeline value. Created
audio elements use one DOM owner before and after insertion; ordinary and SVG
elements no longer receive that synthetic accessor.

## Source boundary

HTMLMediaElement.idl:51 declares a writable restricted double. The pinned
attributes.py resolves the actual receiver before conversion and returns
undefined after the model setter. to_idl_value.py:473–485 applies ToNumber and
rejects NaN and both infinities. The native accessor reuses Runtime's captured
unary-plus intrinsic, preserving number-hint conversion, primitive/boxed BigInt
and Symbol rejection and original author exceptions. Missing setter arguments
supply undefined and fail finite validation. Replacing author Number does not
alter conversion. Receiver checking precedes conversion and the transport's
existing document replay; replay failure leaves the model unchanged.

HTMLMediaElement.cpp:500–535 delegates reads to the default/official-position
algorithm and writes either the default start at HAVE_NOTHING or an accurate
seek. The [generation/commit model slice](MEDIA_CURRENT_TIME_GENERATION_OWNER.md)
from `a160812b` already samples the existing clock once per real event-loop
generation and stamps explicit commits. The native getter now uses that model,
including during microtasks. A loaded model's setter enters the existing
seek caller, clamps its target and commits the clock value after the request;
the focused hook deliberately adjusts a requested seven seconds to four.

Setter callbacks return undefined. JavaScript assignment and chained assignment
still return their original right-hand value, including an author object whose
conversion runs separately for each media receiver. No extra model fields or
synthetic document, realm, clock or generation is introduced by this binding.
The existing no-hook model clock remains a compatibility deviation: Source's
absent PlaybackManager returns zero. Real manager/decoder/pipeline execution,
seek range/mode selection and complete media algorithms remain separate.

## Focused cases and diagnostics

Five host cases verify native descriptors/names/lengths, receiver failure before
proxy traps or conversion/replay, restricted-double success/failure, default
positions, author Number replacement, original conversion/replay exceptions,
chained assignment, actual turn/microtask clock sampling and independent owners.
The loaded caller case verifies accurate seek requests, post-request clock
adjustment, duration/zero clamps and cache refresh on the next actual turn.
Realm/VM depths are balanced after the native clock reads.

Two page cases use run_document_javascript and the public property. They verify
actual model fields and event-target identity, default positions, rejection of
nonfinite/BigInt/Symbol values, one created audio owner across insertion and
nonmedia brand failure without author conversion. The generic page shadow is
absent. Tests do not claim physical backend seeking or decoding.

The initial baseline reached both page failures but the host fixture failed
compilation because an Option was propagated through a Result helper. The
premature focused child run was stopped with exit -15 and its unchanged input
manifest retained. Explicit fixture errors correct that helper. All seven final
cases then fail at runtime in the two baseline files on an unchanged old
implementation snapshot. Both diagnostics and exact private baseline copies
are retained. The final four-file focused batch passes without fixture changes.

## Executed verification

| Run | Exit code | Seconds |
| --- | ---: | ---: |
| baseline | 1 | 67.745 |
| baseline-corrected | 1 | 62.622 |
| focused | -15 | 39.096 |
| focused-final | 0 | 93.724 |
| default | 0 | 632.035 |
| gc-none | 1 | 524.288 |
| gc-none-retry | 0 | 71.636 |

The frozen dispatcher at Build/audit-fixes/native-media-rate-toolchain/v uses
`-old-compiler -enable-globals`, VJOBS=2; the no-GC batch adds `-gc none`.
Default GC passes all 16 selected files. The initial no-GC batch passes 14;
media_seek_timeupdate_test.v cannot create its compiler output directory and
reports "No space left on device" before execution. MediaSource host is also listed as
failed without a retained per-file error. Both failed files pass on a sequential
VJOBS=1 no-GC retry. Together the runs cover all 16 files in each
mode on the same clean committed `16f4c31c` snapshot, without input changes.
This includes the 66-case main regression, native
state/range/rate/volume/event-target owners, the model generation and seek
checks, MediaSource/SourceBuffer and public rate/volume/range/state integration.
All 4,897 tracked inputs, 12 Source references and both compiler
executable hashes remain unchanged. No full HTML/LibJS/Wasm sweep is claimed.

## Production verification

The initial production build fails at linking with LLVM's "IO failure on
output stream: Bad file descriptor" during the low-disk episode. That log and
its unchanged input manifest remain as diagnostics; disk exhaustion is a
possible cause of the linker failure, not a confirmed compiler defect. Only
27 MB of disposable compiler output from the earlier canceled run is removed;
its logs and exact baseline copies remain. Verification retries are sequential.

The same frozen snapshot subsequently builds and signs the macOS bundle with
`-old-compiler -enable-globals -prod -gc none` in 232.632 seconds.
Signature verification and --headless-smoke pass. Two public JavaScript pages
use ordinary conditions independent of V assertions. Their green output
requires native descriptor/default-write/conversion/chaining behavior and
created-audio/receiver checks. Each 800×600 viewport matches all 480,000 pixels
exactly, with zero tolerances. These pages exercise the actual native interface;
generation and loaded seek hook coverage is in the affected native tests.

All 13 SVG mutation/image pairs are pixel-exact. All 11 smoke cases pass within
unchanged bounds: eight are exact, with identical prior residuals (inline-node
13 differing pixels, maximum channel error 1; text-decorations 1,341/2;
canvas-text 1,994/8). No tolerance changes. Production retains
52 Source inputs/references/font files, exact generated
pages, logs, screenshots and output hashes. The binary is unchanged through
every capture.

Binary SHA256: `275075871576e2508ffee7a25814f823385134083b2182a6136ae7f4c4db32ff`.
Production manifest SHA256: `a86524bf9119826a76abb2c8571a7a3f4533826bbdd9948b65ed13100ccf2ade`.
Default manifest SHA256: `76b3105f262b4cabbddeb542224bdfb6e70556cd118a3481f042d9c4f2b832cb`.
GC-none initial manifest SHA256: `e651e28567503574ffc92c758db2df34f169953df39ce20dd9f050820fd6d207`.
GC-none failed-file retry manifest SHA256: `db12c64ecf65137a821059f5da57e687d320586b99bf941dcf0a74b5aaf987ee`.
Consolidated evidence: `Build/audit-fixes/native-media-current-time-evidence.json`.
SHA256: `733407c09f48dad861e951fc0becea8e510c2bf8a00fcb14a3f742569cd2c459`.
Private runs use native-media-current-time-frozen; production artifacts are
under Build/audit-fixes/native-media-current-time-retry-production/; the failed
first build remains under native-media-current-time-production/.

## Remaining scope and inventory

The subsequent [fastSeek caller and binding slice](NATIVE_MEDIA_FAST_SEEK_OWNER.md)
adds the native method, poster entry and live-clock direction selection.

Physical manager/clock/decoder/pipeline delivery, complete seek/play/pause/load,
defaultMuted and other native operations, muted policy/style behavior,
native play promises, ordinary compact listeners, complete media/MSE, unique
task sources, full prototypes, foreign realms, WrapperWorlds, IPC and physical
GC remain open. The browser uses JavaScriptCore. These selected accessor and
model fixes do not establish whole-browser currentTime or HTML parity.

Implementation: [native accessors](../../browserjs/media_element_host_darwin.c.v),
[page bridge](../../main.v).
Tests: [native host](../../browserjs/media_element_current_time_host_test.v),
[public page owner](../../media/main_media_current_time_property_owner_test.v).

The 78-owner inventory stays at 432,348 implementation / 154,939 test V LOC
across 2,188 owned files. All owned hashes match this frozen snapshot; the two
new browser/root support tests and their implementation are excluded by the
existing ownership convention. The unchanged `a160812b` inventory remains
`Build/audit-fixes/source-current-module-loc-a160812b.json` (SHA256 `89a753fd66fc95526e492563b9ee9cea133de847aea49b652bfb34c76871ab6c`).
Counts do not measure parity; the ledger stays 32 fixed / 25 partial / 9 open.
