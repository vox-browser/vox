# Media currentTime generation cache and explicit commits

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and eight focused cases: `a160812bfd3f1aa276f782e5c3d50409be3b06b1`.

The model currentTime getter prioritizes a nonzero default playback start and
samples the existing playback clock once per actual main-thread event-loop
generation. Repeated reads and microtasks keep that sample stable. Explicit
seek, pause, metadata and load position commits stamp the same real generation.
This is a model prerequisite for native currentTime exposure.

## Source boundary

HTMLMediaElement.cpp:500–518 returns a nonzero default start regardless of
readiness, then compares the official-position tag with the main loop's task
generation before sampling current_playback_position(). HTMLMediaElement.h:
353–354 initializes both mutable cache fields to zero. The translated const
getter mutates only those heap-owned cache fields, matching Source's mutable
members. No synthetic loop, document, realm or generation is introduced.
EventLoop.cpp:144 increments the actual processing-turn counter; a standalone
microtask checkpoint leaves it unchanged.

The new current_playback_position query uses the already existing typed clock
hook. Its fallback preserves the existing compatibility model clock. Source
returns zero when no PlaybackManager exists; that fallback deviation remains
explicit. These checks do not establish a physical PlaybackManager clock,
decoder, duration clamp or audio/video pipeline.

HTMLMediaElement.cpp:553–557 stamps explicit official-position assignments.
Metadata's zero reset, load's conditional zero reset, pause of a playing model
(including while seeking) and seek's post-request clock sample now use that
setter. A seek hook that adjusts the requested target determines the committed
value. Clock notifications and compatibility advance_playback no longer eagerly
overwrite a cached official position. Existing load/pause scheduling,
notify_about_playing's queued snapshot, seek-mode/range selection and physical
manager reset remain separate incomplete algorithms.

## Focused cases and diagnostics

The eight cases cover nonzero default precedence after a readiness change,
zero default fallback without metadata, one sample per real turn with a
microtask checkpoint, clock notifications and compatibility advances in the
same turn, adjusted post-seek clock values, pause while seeking, explicit
metadata/load reset stamps and independent actual audio/video DOM owners from
a parsed navigation document. Existing play/rate/controls/video-paint fixtures
now advance the actual loop between clock movement and the later observation;
their expected positions, timeline percentage, timestamp and frame remain.

The initial fixture failed compilation because clock records and hook fields
were immutable. The first focused run identified a setup clock read from buffer
monitoring and a controls fixture still observing generation zero. Both
diagnostics are retained. The final fixture measures getter reads separately
from setup and performs an actual controls turn. All eight final cases fail at
runtime against the old committed model on an unchanged snapshot; its private
model/test copies are retained. The final focused six-file batch passes.
The production probe's initial private cleanup calls also failed its precheck;
they were removed from that standalone probe and the corrected precheck passes.

## Executed verification

| Run | Seconds |
| --- | ---: |
| baseline: expected failure | 68.323 |
| baseline-runtime: expected failure | 89.366 |
| baseline-final: expected failure | 74.143 |
| focused: expected failure | 271.676 |
| focused-final: pass | 248.037 |
| default: pass | 790.010 |
| gc-none: pass | 665.534 |

The frozen dispatcher at Build/audit-fixes/native-media-rate-toolchain/v uses
`-old-compiler -enable-globals`, VJOBS=2; the second affected batch adds
`-gc none`. All 21 affected files pass in each mode on the same clean committed
`a160812b` snapshot. This includes the 66-case main regression, duration,
end/seek/rate/load/adoption owners, native state/range/rate/volume neighbors,
MediaSource/SourceBuffer and typed video painting. All 4,894
tracked inputs, seven Source references and both compiler executable hashes
remain unchanged. This is an affected batch; no full HTML/LibJS/Wasm sweep is
claimed.

## Production verification

The same frozen snapshot builds and signs the macOS bundle with
`-old-compiler -enable-globals -prod -gc none` in 551.508 seconds.
Signature verification and --headless-smoke pass. A standalone production model
probe uses ordinary failure branches independent of removable V assertions.
It verifies Source's initial zero tag, real turn/microtask sampling, default
precedence, metadata/load reset stamps, explicit pause and separate active DOM
owners. The configured hook remaining after model load is an existing model
boundary; physical manager reset is not proven. Native currentTime is not yet
exposed or tested through JavaScript.

Two existing public volume/mute pages retain exact 800×600 output (480,000
pixels each, zero tolerances), protecting adjacent browser integration. All
11 smoke cases pass within unchanged bounds: eight are exact and the previous
residuals are identical (inline-node 13 differing pixels, maximum channel
error 1; text-decorations 1,341/2; canvas-text 1,994/8). No tolerance changes.
Production retains 36 Source inputs/references/font files,
the actual probe, generated pages, logs, screenshots and output hashes. The
bundle binary remains unchanged through every capture.

Binary SHA256: `41e2008fcdfa1164812e6a2bf0902b165cc55fc6b3fbbfd2426dae7f76d1f4c4`.
Production manifest SHA256: `9d126b7689da12d1ae9318c9280e3dc8d94daedd4a0b49b052607fa0a3af84e6`.
Default manifest SHA256: `db99f2923c0908e14ef624e815452f6824812d81fc7c8be12777cb51b93a5722`.
GC-none manifest SHA256: `408422409761f62eee9c3edb32289e20761bc3a7fd3789a74f5fbe44c601f374`.
Consolidated evidence: `Build/audit-fixes/media-position-generation-evidence.json`.
SHA256: `e25b963b6cc92bc6b85383c8daa8e137b8649c0801e05436e38fbb8a38db0304`.
Private runs use media-position-generation-frozen; production artifacts are
under Build/audit-fixes/media-position-generation-production/.

## Remaining scope and inventory

Native currentTime/defaultMuted and other operations, complete seek/play/pause/
load algorithms, physical manager/clock/pipeline delivery, muted policy/style
behavior, native play promises, ordinary compact listener routing, complete
media/MSE, task-source identity, prototypes, foreign realms, WrapperWorlds, IPC
and physical GC remain open. The browser still uses JavaScriptCore. The ledger
stays 32 fixed / 25 partial / 9 open.

Implementation: [media model](../../html/html_media_element.v).
Focused tests: [generation and owner cases](../../html/media_current_time_generation_owner_test.v).
The 78-owner physical inventory contains 432,348
implementation V LOC and 154,939 test V LOC across
2,188 owned files. One HTML test file is added; four existing
HTML/Layout fixtures advance real turns. Browser/root support is excluded.
Counts do not measure parity. Inventory: `Build/audit-fixes/source-current-module-loc-a160812b.json`.
SHA256: `89a753fd66fc95526e492563b9ee9cea133de847aea49b652bfb34c76871ab6c`.
