# Native media volume and mute property owner

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and seven focused cases: `c2e279e54694b01d9eca1f1d59acf2ee63133ffa`.

Native volume and muted accessors now read and write the actual audio/video DOM
media model. They use the compact HTMLMediaElement prototype and existing model
setters, preserving immediate effective-volume hooks and deferred volumechange
delivery through the owning media task. JavaScript assignments no longer create
independent fields on these wrappers.

## Source boundary

HTMLMediaElement.idl declares volume as restricted double and muted as boolean.
The pinned attributes.py checks the receiver before conversion;
to_idl_value.py:343–348 uses ToBoolean, while :473–485 uses ToNumber and rejects
nonfinite values. The native adapter checks its actual owner record first.
Volume uses Runtime's captured unary-plus intrinsic, rejecting primitive and
boxed BigInt, Symbol, NaN and infinities while preserving author-thrown values.
Muted uses JSC's ToBoolean directly, without invoking author conversion hooks,
including on revoked proxies. Omitted setter arguments supply undefined.
Conversion precedes the transport's existing document replay.

HTMLMediaElement.cpp:655–681 rejects volume outside 0–1 inclusive with
IndexSizeError and its exact message. The model's prior message is corrected;
the adapter turns that selected model error into a genuine native DOMException,
including code 1 and the engine prototype. Author replacements of Number,
Boolean and DOMException do not alter conversion or exception construction.
Equal volume values preserve the stored signed zero and suppress another task.

The existing volume/muted task algorithm from
[property-task evidence](MEDIA_PROPERTY_TASK_OWNER.md) remains in place.
Source's autoplay-policy pause and muted-style invalidation are still absent.
The tested effective-volume hook is an existing model boundary; these changes
do not establish actual PlaybackManager, audio pipeline or decoder execution.

## Focused cases

Four native host cases verify descriptors, native accessor names/lengths,
receiver rejection before proxy traps/conversion/replay, finite conversion,
range exceptions with an actual native record, boolean truthiness, missing
arguments, author-global replacement and original conversion/replay exceptions.
The event case checks immediate hook values, no synchronous or microtask event,
live values at deferred dispatch, trusted target/currentTarget and Event branding,
unrelated-owner isolation, page mute independence and balanced realm/VM depths.

Two page cases use public properties through run_document_javascript. They
verify the actual model fields and task callbacks, plus a created audio element
written before insertion that keeps one DOM owner. Ordinary and SVG elements
reject the setter before author conversion. The compact listener stub remains;
page callbacks explicitly use EventTarget.prototype.addEventListener.call.
One additional model case verifies the exact range message without mutation or
queued tasks. All three baseline files fail at runtime on an unchanged snapshot;
there are no intermediate compile failures in this slice.

## Executed verification

| Run and result | Seconds |
| --- | ---: |
| Runtime baseline: 3/3 files fail | 326.385 |
| Focused: 4/4 pass | 258.939 |
| Frozen default: 14/14 pass | 1347.405 |
| Frozen GC-none: 14/14 pass | 1290.020 |

The frozen dispatcher at Build/audit-fixes/native-media-rate-toolchain/v uses
`-old-compiler -enable-globals`, VJOBS=2; the second batch adds `-gc none`.
All 14 affected files pass in each mode on the same clean committed `c2e279e5`
snapshot. This includes the 66-case main regression, previous native rate
properties, media state/ranges, volume/rate task owners, DOM event ownership
and MediaSource/SourceBuffer neighbors. All 4,892 tracked inputs,
12 Source references and both compiler executable hashes remain unchanged.
This is an affected-file batch, not a full HTML, LibJS or Wasm sweep.

## Production verification

The same frozen snapshot builds and signs the macOS bundle using
`-old-compiler -enable-globals -prod -gc none` in 1297.474 seconds.
Signature verification and --headless-smoke pass. Two public JavaScript pages
use ordinary conditions independent of V assertions: the first turns green only
after three trusted owner volume events see the final values, zero synchronous
or microtask events, both error categories and unrelated-owner isolation; the
second requires created-audio property and receiver checks. Each 800×600
viewport matches all 480,000 pixels exactly with zero tolerances.

All 13 SVG mutation/image pairs remain pixel-exact. All 11 smoke cases pass
within unchanged bounds; eight are exact, and the previous residuals remain
identical: inline-node 13 differing pixels (maximum channel error 1),
text-decorations 1,341 (2), canvas-text 1,994 (8). No tolerance changes.
Production retains 52 Source inputs/references/font files, generated pages,
logs, screenshots and output binary hashes. The binary remains unchanged
through all captures.

Binary SHA256: `7e08b036830a5247fed715bc2235e31179bb3b2c046a50108764c957273bb68b`.
Production manifest SHA256: `024290091b189478f751be80580816e42be84749427fb9af1acfab5dbe00e5bc`.
Default manifest SHA256: `2214e892d2ed3430068dabe479c2342466be5c552833cea1215ecd910bbee395`.
GC-none manifest SHA256: `171420284443f921952367dd511752e3168e3f5063ee56d8b4414856fe3f0c69`.
Consolidated evidence: `Build/audit-fixes/native-media-volume-evidence.json`.
SHA256: `029b4d0e1e55ef8532e6a5aaeb22cb2ae87f099f42b0e03fccee416dbab59a47`.
Private runs use native-media-volume-frozen; production artifacts are under
Build/audit-fixes/native-media-volume-production/.

## Remaining scope and inventory

Autoplay-policy pause, muted-style invalidation, real playback-manager/pipeline
delivery, native defaultMuted and other incomplete operations,
complete media/MSE algorithms, native play promises, ordinary compact listener
routing, unique task sources, complete prototypes, foreign realms,
WrapperWorlds, IPC and physical GC remain open. The browser uses JavaScriptCore.

At this snapshot the currentTime model still selected by readiness and lacked
Source's generation cache. The subsequent [generation/commit slice](MEDIA_CURRENT_TIME_GENERATION_OWNER.md)
adds nonzero default precedence and actual-loop sampling with explicit commit
stamps. The subsequent [native time accessor](NATIVE_MEDIA_CURRENT_TIME_PROPERTY_OWNER.md)
exposes the property; the physical manager clock remains open.

Implementation: [native media host](../../browserjs/media_element_host_darwin.c.v),
[volume model](../../html/html_media_element.v).
Tests: [native accessors](../../browserjs/media_element_volume_host_test.v),
[page owner](../../media/volume_property_owner_test.v),
[model tasks](../../html/media_volume_task_owner_test.v).

The 78-owner physical inventory remains 432,331 implementation V LOC and now
contains 154,733 test V LOC across 2,187 owned files. The one existing HTML test
gains 12 lines; the model message correction adds no physical line. Browser/root
support is excluded. All owned file hashes match the frozen snapshot.
Inventory: `Build/audit-fixes/source-current-module-loc-c2e279e5.json`.
SHA256: `568f0783d9097f9e8b5f0214e0110a9a53ac346353ae552f1c8a8af4026bb942`.
Counts do not measure parity; the ledger stays 32 fixed / 25 partial / 9 open.
