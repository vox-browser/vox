# Native media getStartDate owner and timeline rounding

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Model rounding and three focused cases: `7ea057ff5425765b04798ff45390927c8a9e0a04`.
Native operation and seven focused cases: `5b86ed38cc6de1070c431209656ad968e977e28f`.

getStartDate now reads the actual audio/video DOM media timeline after replay
and returns a fresh built-in Date for each supported call. The compact bridge's copied
video timestamp and generic own method are removed. Unknown offsets return
fresh invalid Dates; later metadata and load reset are observed immediately,
while previously returned Dates retain their value.

## Source and engine boundaries

HTMLMediaElement.idl:54 declares a zero-argument operation returning an object.
HTMLMediaElement.cpp:570–577 reads the live optional timeline offset through
UnixDateTime::milliseconds_since_epoch(), then uses JS::Date::create in the
relevant realm. AK/Time.h:464 calls Duration::to_milliseconds(); its steps in
AK/Time.cpp:213–227 round fractional milliseconds away from zero. The V model
previously truncated its microsecond record. It now divides before applying the
signed remainder, avoiding overflow at either i64 limit. Two existing fractional
metadata expectations are corrected to the Source values. The V metadata record
and typed hook still carry microseconds; physical manager and finer-precision
metadata delivery remain separate.

operations.py:452 onward checks the actual receiver before the operation.
Native getStartDate has name getStartDate, length zero and writable, enumerable,
configurable prototype flags. Invalid receivers, ordinary/SVG elements and
unregistered Proxy wrappers reject without Proxy traps or replay. Extra arguments
are ignored without author coercion. Replay precedes the live model read;
original replay exceptions survive. The owner and EventTarget remain the actual
DOM audio/video element before and after insertion.

The macOS binding uses JSObjectMakeDate with one numeric argument, creating a
real Date with the intrinsic prototype even after author Date is replaced or
Date.prototype.getTime is overwritten. No author constructor or coercion is
called. The SDK JSObjectRef.h declaration describes built-in Date-constructor
behavior; signed Date-range limits and NaN are exercised through the native API.

JS::Date::create (Date.cpp:27–36) installs the raw Source double. JavaScriptCore's
constructor TimeClips outside ±8,640,000,000,000,000 milliseconds. This slice
explicitly rejects those unrepresentable Source values with the error
“Source media Date value cannot be installed exactly by JavaScriptCore”, matching
the repository's existing explicit native-clone Date boundary. That rejection
is a compatibility deviation, not upstream behavior or complete Date parity.
The model retains the raw rounded value; no timestamp is silently clipped.
Foreign realms, full prototype hierarchy, WrapperWorlds, IPC, physical GC,
defaultMuted, complete media/MSE and backend playback/decoder delivery remain
open. The browser still uses JavaScriptCore.

## Tests and frozen verification

Three actual-DOM model cases cover positive/negative fractional milliseconds,
exact milliseconds and positive zero, large exactly representable values and
both integer clock limits, fresh records, absent metadata and load reset.
Four native cases cover descriptors/receiver order, extra arguments, real Date
identity under author replacements, live positive/negative metadata, saved Date
values, load reset, original replay exceptions, sampling after replay, both Date
limits and explicit unsupported values. Three public page cases cover parsed
and created owners, insertion, nonmedia rejection, metadata arriving after the
initial compact snapshot and reset through the same model.

The first attempted baseline had two Option/Result propagation fixture errors;
its original files, log and manifest remain preserved separately. After correcting
the fixtures and Source-derived expectations, all ten final cases fail at runtime
on the unchanged old implementation. There are no compiler errors in that final
baseline, and final new test bytes match its retained private copies.
Focused model and native/page batches each pass 2/2 files.

| Run | Exit code | Seconds |
| --- | ---: | ---: |
| baseline | 1 | 45.553 |
| focused-model | 0 | 26.271 |
| focused-native | 0 | 49.073 |
| default | 0 | 641.865 |
| gc-none | 0 | 392.540 |

All 23 affected files pass with default GC and GC disabled on the same clean
committed `5b86ed38` snapshot. The frozen dispatcher uses
-old-compiler -enable-globals with VJOBS=2; the second batch adds -gc none.
The batch includes the 66-case main regression, existing media model/currentTime
and fastSeek tests, native rate/volume/state/range/event owners, MediaSource and
SourceBuffer, and public property/caller integration. All 4,905
tracked inputs, 18 Source references and both compiler hashes remain unchanged.
No whole HTML/LibJS/Wasm sweep is claimed.

## Production evidence

The same snapshot builds/signs the macOS bundle with -prod -gc none, verifies
its signature and passes --headless-smoke. A standalone production probe uses
ordinary failure branches independent of V assertions. Through an actual parsed
video/native wrapper it verifies descriptor, fresh invalid Dates, live metadata,
positive/negative Source rounding, built-in identity under author replacement,
explicit Date-range rejection and load reset.

Two public JavaScript pages use ordinary green/red conditions independent of
V assertions. Each is pixel-exact against its 800×600 reference (480,000 pixels,
zero tolerances), covering native descriptors, actual parsed/created audio/video,
Date identity, extra arguments, insertion and nonmedia checks. All 13 required
SVG mutation/image pairs are exact. All 11 smoke cases pass with the previous
bounds and residuals: eight exact; inline-node 13 differing pixels/max error 1,
text-decorations 1,341/2, canvas-text 1,994/8. Tolerances are unchanged.

The initial SVG batch passed 12 pairs, with one capture recovering through the
built-in launch retry. It then stopped after two Trace/BPT launch traps before
the final pair could be compared. The remaining pair was rerun, followed by the
previously unexecuted smoke set, on the same unchanged binary and tracked/Source
snapshot. The failed attempt, captures and logs remain preserved separately
from the successful retry; no pixel failure was discarded.

Production preserves 58 Source input/reference/font hashes,
the exact probe and pages, logs, screenshots and artifact hashes. The bundle
binary remains unchanged throughout capture.
Binary SHA256: `33745e641a0d9b8a39619c637161b08349c39246d424b04caff646ec0e6643b4`.
Initial production manifest SHA256: `4811824e57303ddbbbc50ee983b0f18872caebfd65fc039877112b89e2d6595e`.
Successful production retry manifest SHA256: `4573795591cfcb45979d2b26fa0760dbdecaae9c5530923f6904f48acdad4baf`.
Default manifest SHA256: `d993344efc6fbf529bd3930d5679fad0cbeba80402b897fe22519b2e3cc325bd`.
GC-none manifest SHA256: `731601f98ade1a2e75b92f9bf4f94a6cfc0c35db5b8cb4296ac07083f3f21316`.
Consolidated evidence: `Build/audit-fixes/native-media-start-date-evidence.json`.
SHA256: `44dcd0c5f43fe66a3f29e88172fa30cdea6535c95eecff2ad24f48bf996e1389`.
Runs use native-media-start-date-owner-frozen; production artifacts are under
Build/audit-fixes/native-media-start-date-owner-production/ and its separate
native-media-start-date-owner-production-retry/ directory.
The fixture diagnostic is retained under native-media-start-date-frozen-baseline.

## Inventory and remaining audit

The refreshed 78-owner inventory contains 432,351
implementation / 155,129 test V LOC across 2,190 owned
files. Only the HTML model and its existing test change within the prior owned
files; one HTML rounding test is added. Browser/root support remains excluded
by the established convention. All owned hashes match the frozen snapshot.
Inventory: `Build/audit-fixes/source-current-module-loc-5b86ed38.json`.
SHA256: `8de84b604fdab6724db26327f79c48774835474b44277781aab43544527bc2ff`.
Physical counts do not measure parity; the ledger stays 32 fixed / 25 partial /
9 open. This selected method/caller slice does not close the wider runtime or
ownership findings.

Implementation: [model](../../html/html_media_element.v),
[native binding](../../browserjs/media_element_host_darwin.c.v),
[compact bridge](../../main.v).
Tests: [rounding](../../html/media_start_date_rounding_test.v),
[native](../../browserjs/media_element_start_date_host_test.v),
[public page](../../media/main_media_start_date_owner_test.v).
