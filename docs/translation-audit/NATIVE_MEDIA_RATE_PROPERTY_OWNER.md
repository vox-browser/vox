# Native media playback-rate property owner

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and six focused cases: `1ac087a64845b021ca455b6a6d7052aab3a8dcf7`.

Native defaultPlaybackRate and playbackRate getters/setters now read and write
the actual audio/video DOM media model. They inherit from the existing compact
HTMLMediaElement prototype instead of creating independent JavaScript fields.
Successful writes use the previously verified queued model setters, so events
run as media tasks and observe the live rate values.

## Source boundary

HTMLMediaElement.idl declares both properties as restricted double. The pinned
Meta/Generators/libweb_bindings/attributes.py checks the receiver before value
conversion; to_idl_value.py:473–485 performs ToNumber, rejects NaN and infinities
with TypeError, and preserves finite values. The binding reuses Runtime's
captured unary-plus intrinsic, because JSC's C JSValueToNumber accepts BigInt.
Genuine ToNumber rejects primitive and boxed BigInt and preserves author-thrown
values. Conversion finishes before this transport's existing document replay.

HTMLMediaElement.cpp:2982–3022 assigns every converted default value without
an internal range check. The current-rate setter accepts finite 0–64 inclusive
and rejects unsupported rates with NotSupportedError. This adapter wraps that
selected model error in a genuine native WebIDL DOMException; its name, message,
code and engine prototype survive author replacement of global DOMException.
The native exception binding is installed before author code runs.

The model and load-reset implementation from
[rate/load evidence](MEDIA_RATE_TASK_LOAD_OWNER.md) remains unchanged. Actual
PlaybackManager rate/clock/pipeline propagation remains unimplemented. Native
property exposure does not prove physical playback speed or decoder execution.

## Cases and diagnostics

Four host cases verify accessor metadata and native function names/lengths,
receiver checks before Proxy traps/coercion/replay, string/null/boolean/object
conversion, nonfinite/Symbol/BigInt rejection, default values outside the current
rate range, the real NotSupportedError record, missing arguments,
original conversion/replay exceptions, live callbacks delivered as tasks, equal signed
zero and unrelated-owner isolation. Event target/currentTarget, trusted flags,
branding and balanced realm/VM depths use actual native records and callbacks.

Two page cases exercise public JavaScript writes through the compact browser,
including delayed events after a microtask checkpoint, range/conversion failures
and a created audio element inserted into the document. V checks that the
created wrapper keeps one DOM owner and the same actual rate fields. Non-HTML
media and ordinary elements reject before the proposed value is coerced.
The existing compact listener stub remains; page cases explicitly use
EventTarget.prototype.addEventListener.call for actual native delivery.

The first baseline attempt had an Option-propagation fixture error and observed
an external replacement of /Users/alex/code/v/v. Its log and differing compiler
hashes are retained as diagnostics, not a complete baseline proof. After the
fixture correction, all six cases fail at runtime on an unchanged snapshot.
The frozen dispatcher is byte-identical to that corrected run's primary
executable and selects the same stable V 0.5.2 compatibility compiler.

Two intermediate focused attempts caught a local variable name collision and
a rejected conditional argument-selection expression. Their compilation logs
are retained; they are not counted as passing tests. The final binding uses
the imperative argument-selection form from neighboring native adapters.
A page-extractor preflight also rejected an ambiguous raw-string pattern before
the build began; the anchored correction and failed helper bytes are retained.
The final evidence file separates the diagnostic JSON digest from the failed
helper digest. The initial metadata artifact and byte-identical consolidator
are retained as native-media-rate-evidence.json and
consolidate_native_media_rate_evidence_initial.py under Build/audit-fixes/.

## Executed verification

| Run and result | Seconds |
| --- | ---: |
| Corrected runtime baseline: 2/2 files fail | 258.791 |
| Focused: 3/3 pass | 357.790 |
| Frozen default: 11/11 pass | 944.224 |
| Frozen GC-none: 11/11 pass | 903.427 |

Final checks use the private frozen dispatcher at
Build/audit-fixes/native-media-rate-toolchain/v with
`-old-compiler -enable-globals`, VJOBS=2; the second affected batch adds
`-gc none`. All 11 affected files pass in each mode on the same clean committed
`1ac087a6` snapshot, including the 66-case main regression, state/range
bindings, DOM event owners, prior rate tasks and native MediaSource/SourceBuffer
neighbors. All 4,889 tracked inputs, ten Source references and
both compiler executable hashes remain unchanged. This is an affected-file
batch, not a full HTML, LibJS or Wasm sweep.

## Production verification

The same frozen snapshot builds and signs the macOS bundle with
`-old-compiler -enable-globals -prod -gc none` in 1064.405 seconds.
Signature verification and --headless-smoke pass. Two public JavaScript pages
are assertion-independent: the first turns green only after three trusted
owner rate events observe the final values, zero synchronous/microtask events,
range/conversion failures and unrelated-owner isolation; the second requires
the created audio property/brand checks. Each viewport matches all 480,000
pixels with zero tolerances. These pages exercise public native rate properties
and rendered task delivery, while the V page test verifies the underlying owner.

All 13 SVG mutation/image pairs remain pixel-exact. All 11 smoke screenshots
pass within unchanged bounds; eight are exact and the three previous residuals
remain identical: inline-node 13 differing pixels (maximum channel error 1),
text-decorations 1,341 (2), canvas-text 1,994 (8). No tolerance changes.
Production retains 50 Source inputs/references/font
files, frozen compilers, generated pages, logs/screenshots and output binary
hashes. The signed browser binary remains unchanged through the captures.

Binary SHA256: `8dd543d585aa941da13b99f7e2650314b38690f88eacfb112c5b947983e1dec7`.
Production manifest SHA256: `746e71e92543c94f848224731049b10e61222e9da65bd8275d7f49637b0e7db2`.
Default manifest SHA256: `c8ac7a42eda4360d384331a5fff0c85aaf07d16768bb915244ad94188a001fda`.
GC-none manifest SHA256: `3b90c8b5fae062f63d798d45a00d73827dc58b590f4ef38b77a30d8fbedfbaca`.
Consolidated evidence: `Build/audit-fixes/native-media-rate-evidence-final.json`.
SHA256: `31686443d9e4233c73d9812620a867daf0953bd5fe8b878a0f903fb093974c6e`.
Private manifests/logs use native-media-rate and native-media-rate-frozen;
production artifacts are under Build/audit-fixes/native-media-rate-production/.

## Remaining scope

The subsequent [volume/mute slice](NATIVE_MEDIA_VOLUME_PROPERTY_OWNER.md) adds
those two native properties with separate verification.

Actual PlaybackManager rate/clock/pipeline delivery, decoder Ended state,
native currentTime and other incomplete property operations,
complete load/media/MSE algorithms, autoplay policy, native play promises,
ordinary compact listeners, unique task sources, complete prototypes, foreign
realms, WrapperWorlds, IPC and physical GC remain open. The browser continues
to use JavaScriptCore.

Implementation: [native media host](../../browserjs/media_element_host_darwin.c.v).
Tests: [native rate accessors](../../browserjs/media_element_rate_host_test.v),
[public page owner](../../media/rate_property_owner_test.v).

No module-owned implementation or test file changed. The existing 78-owner
inventory remains 432,331 implementation / 154,721 test V LOC across 2,187 owned
files; this feature's browser/root support is excluded. All inventory file
hashes were checked against the frozen snapshot. Counts do not measure parity;
the ledger stays 32 fixed / 25 partial / 9 open.
