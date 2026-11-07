# Native media fastSeek owner and caller

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Model caller and three cases: `a870b6b88b49fcedd40a56e0e80eb348169e4cbe`.
Native operation and six cases: `335564fdc6aa262c49e143168622e05ffd0ea6af`.

The native fastSeek method now calls the actual audio/video DOM model.
The model always enters seek steps, clearing the poster before the
HAVE_NOTHING return while retaining the default playback start. Approximate
direction selection uses the live playback clock at each Source comparison,
before the seeking task is queued. The adjusted clock is then committed through
the existing currentTime generation cache.

## Source and ownership boundaries

HTMLMediaElement.idl:52 declares fastSeek(double time), returning undefined.
operations.py:452–488 checks the actual receiver before required arity and
argument conversion. arguments.py passes the parameter identifier to
to_idl_value.py:473–485, which applies ToNumber and rejects NaN and infinities.
ErrorTypes.h retains fastSeek() needs one argument and the restricted-double
message naming time. Missing arguments differ from explicit undefined.

The native function has name fastSeek and length one, with writable, enumerable
and configurable prototype flags. It checks its actual wrapper record without
running Proxy traps or author conversion on invalid receivers. The shared
restricted-double helper uses the captured unary-plus intrinsic; Symbol and
primitive/boxed BigInt reject, objects receive the number hint, and replacing
author Number does not replace conversion. Extra arguments are ignored.
Original conversion/replay exceptions survive, replay follows successful
conversion, and failure leaves the model unchanged. Successful calls return
undefined. Existing rate/volume/currentTime properties retain their conversion
and exception behavior through the shared helper.

HTMLMediaElement.cpp:539–543 unconditionally enters seek_element. Its first
steps clear the poster before the HAVE_NOTHING return. The selected direction
step compares the clamped target against current_playback_position() for each
comparison, rather than storing one sample or reading the compatibility field.
The Source backward branch reads once; forward/equal branches can read twice.
These comparisons precede the queued seeking task. The existing post-request
clock commit is retained. The tests distinguish a stale scalar zero from a live
clock nine, and also use changing comparison samples (-1, nine) to require
accurate mode rather than a cached decision. Loaded native calls cover backward,
forward, equal and duration/zero clamps, including a seven-second request whose
existing hook adjusts the committed clock to four.

The model's existing no-hook scalar clock/seek fallback remains a compatibility
deviation; Source returns zero without a PlaybackManager. Range selection,
duration conversion, real manager seek execution, decoder stable-state delivery,
complete media/MSE, play promises, defaultMuted, full prototypes, foreign realms,
WrapperWorlds, IPC and physical GC remain open. These selected method/caller
fixes do not establish complete fastSeek or whole-browser media parity.
The browser still uses JavaScriptCore. main.v is unchanged.

## Focused tests and executed checks

Three actual-DOM model cases cover poster/default start, live clock direction
and adjusted commit, separate comparison reads and seeking-task ordering.
Four native cases cover descriptors, brand/arity/conversion order, conversion
success/failure at HAVE_NOTHING, original exceptions and loaded model requests.
Two page cases use run_document_javascript: parsed and created audio/video
wrappers keep their actual model/event-target owner, preserve default starts
through fastSeek and insertion, and reject ordinary/SVG receivers before author
conversion. No independent page method or synthetic owner is introduced.

All nine cases fail at runtime on the unchanged old implementation. The third
model failure is reported from its clock callback, at the queued-task check;
the other eight are reported from their test functions. There are no compiler
errors, and exact private baseline copies are retained. Final test bytes match
that baseline. Model and native focused batches pass 3/3 and 4/4 files.

| Run | Exit code | Seconds |
| --- | ---: | ---: |
| baseline | 1 | 190.012 |
| focused-model | 0 | 130.065 |
| focused-native | 0 | 501.416 |
| default | 0 | 1108.709 |
| gc-none | 0 | 340.218 |

All 20 selected files pass with default GC and with GC disabled on the same
clean committed `335564fd` snapshot. The batches use the frozen dispatcher
with `-old-compiler -enable-globals`, VJOBS=2; the second adds `-gc none`.
They include the 66-case main regression, the new three files, existing full
media/seek/generation checks, native currentTime/rate/volume/state/range/event
owners, MediaSource/SourceBuffer and adjacent public property integration.
All 4,901 tracked inputs, 14 Source references and both compiler
hashes remain unchanged. No full HTML/LibJS/Wasm sweep is claimed.

## Production verification

The same frozen snapshot builds/signs the macOS bundle with
`-old-compiler -enable-globals -prod -gc none`; signature verification and
--headless-smoke pass. A separate production probe uses ordinary failure
branches independent of V assertions on an actual parsed video owner. It checks
poster/default start at HAVE_NOTHING, live backward/forward/equal mode selection
and the adjusted clock commit through the existing typed hook boundary.
It proves those model decisions, without proving physical backend seeking.

Two public JavaScript pages use ordinary green/red conditions independent of
V assertions. Each matches its 800×600 expected viewport exactly (480,000 pixels,
zero tolerances), exercising native descriptors, conversion/default start,
created-owner insertion, arity and nonmedia brand checks. All 13 SVG mutation/image
pairs are exact. All 11 smoke cases pass with unchanged bounds and residuals:
eight exact; inline-node 13 differing pixels/max error 1, text-decorations
1,341/2, canvas-text 1,994/8. No tolerance changes.

Production retains 54 Source input/reference/font hashes,
the exact standalone probe and generated pages, logs, screenshots and output
hashes. Its binary is unchanged through capture.
Binary SHA256: `c24591c95f481a7d2fa0efdcbda863b98b4da652d23587de00ae383beb9ca2fa`.
Production manifest SHA256: `87081d54b32addd915ca8d5631ed8d1474a18197df41f6d8098e3f495c4bf2af`.
Default manifest SHA256: `ae9438480dccfc6e8a4712cfaed6e29c5d17d2f5b6f93f394af5760b579e836a`.
GC-none manifest SHA256: `6e448d1d4b6e019374eda2e3139fe4238bcb969b519390ab8ae78c2c7f9fa349`.
Consolidated evidence: `Build/audit-fixes/native-media-fast-seek-evidence.json`.
SHA256: `24eedb495add4c8f149d9fcc9af6c2db5e40810cae91c205b940fdea1d8720f3`.
Private runs use native-media-fast-seek-frozen; production artifacts are under
Build/audit-fixes/native-media-fast-seek-production/.

## Inventory and implementation

The refreshed 78-owner inventory has 432,347
implementation / 155,053 test V LOC across 2,189 owned files.
Only the HTML model changes within the prior owned files; the new HTML caller
test is added. Browser/root implementation and tests remain excluded by the
existing convention. All owned hashes match this frozen snapshot.
Inventory: `Build/audit-fixes/source-current-module-loc-335564fd.json` (SHA256 `c75a784722328706f901dbb5d244b0e21a8f5fb046c7f6ea6ff2ec21086d0a46`).
Counts do not measure parity; the ledger stays 32 fixed / 25 partial / 9 open.

Implementation: [model caller](../../html/html_media_element.v),
[native operation](../../browserjs/media_element_host_darwin.c.v).
Tests: [model](../../html/media_fast_seek_caller_test.v),
[host](../../browserjs/media_element_fast_seek_host_test.v),
[public page](../../media/main_media_fast_seek_owner_test.v).
