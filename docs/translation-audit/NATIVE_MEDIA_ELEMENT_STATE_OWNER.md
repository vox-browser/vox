# Native HTML media state ownership

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `a699f872d2466a824efd0ea830b9bd021c1cc1a2`.

The Window binding now exposes `currentSrc`, `networkState`, `readyState`,
`seeking`, `duration`, `paused`, and `ended` through the actual DOM audio/video
HTMLMediaElement model. Previously these scalar attributes were absent from
the native prototype, while the compact page supplied its own snapshot-based
readyState. HTML media wrappers now inherit the native getter; the legacy
non-media readyState property is preserved separately.

## Source and owner boundary

| Attribute | Pinned Source result | Native transport |
| --- | --- | --- |
| currentSrc | HTMLMediaElement.h current_src member getter | Serialized URL string |
| networkState | HTMLMediaElement.h network_state enum getter | Number, 0 through 3 |
| readyState | HTMLMediaElement.h ready_state enum getter | Number, 0 through 4 |
| seeking | HTMLMediaElement.h seeking flag getter | Boolean |
| duration | HTMLMediaElement.cpp duration returns m_duration | Raw Number, including NaN, Infinity and negative zero |
| paused | HTMLMediaElement.h paused flag getter | Boolean |
| ended | HTMLMediaElement.cpp ended returns cached m_ended | Boolean |

The generated attributes.py contract supplies native getter name/length,
enumerable/configurable accessors and no setter. The host reuses the actual
media wrapper map and captured prototype. Brand checks precede document
replay and author Proxy traps. A valid read replays pending DOM changes and
then reads its owning media model, preserving original JavaScript abrupt
completions. Primitive states bypass the compact JSON snapshot.

The shared buffered getter continues returning native TimeRanges snapshots.
No media state-machine implementation changes are included. A created audio
wrapper retains one native DOM owner through insertion replay. An existing
decoded video frame keeps its actual HAVE_CURRENT_DATA state and dimensions.

## Checks

Three host cases cover readonly/native metadata and invalid receivers before
replay; completed resource callbacks plus live fields, independent audio,
NaN, Infinity, finite fractional duration and negative zero; and original
replay exceptions. Two page cases cover actual MediaSource attachment via a
currentSrc read, queued sourceopen/updateend initialization/append/removal,
finite and infinite duration changes, decoded frames and created audio.
The VP9-track bytes exercise translated range records, not full decoding.

| Run | Result | Seconds |
| --- | --- | ---: |
| baseline | 2 files fail at runtime on missing getters | 138.882 |
| focused | 2 files pass, 4 initial cases | 139.886 |
| default | 9/9 files pass, including all 5 final cases | 457.719 |
| gc-none | 9/9 files pass, including all 5 final cases | 447.172 |

The decoded-frame/created-audio case is added after the focused run and is
included in both final batches. Commands use `/Users/alex/code/v/v
-old-compiler -enable-globals`, `VJOBS=2`, with `-gc none` in the second
mode. The nine files include both new files, existing native buffered host/page
and SourceBuffer TimeRanges page, HTML media resource and seek/timeupdate,
the 66-case main regression and SourceBuffer task ownership.

Both final modes retain an identical unchanged 4,869-file snapshot, nine
selected Source files and two compiler executables. The baseline keeps its
private five-file representation separately. New test files pass formatting
verification and the scoped diff passes whitespace checks.

## Native production proof

`./build_ladybird.sh` passes with the production compatibility compiler,
`-enable-globals -prod -gc none`, Skia, FFmpeg and Rust YUV bridges in
613.856 seconds. Ad-hoc signature verification and `--headless-smoke` pass.
The public media-state callback page matches all 480,000 viewport pixels
with explicit zero tolerances.

All 13 pinned SVG pairs have zero differing pixels and zero maximum channel
error. They cover same-size image replacement, SVG/HTML ID collisions,
script-added/moved/animated gradient stops, gradient href/offset/transform
mutations, pattern attributes/transforms, hidden inherited paint-server styles
and URL fallback after non-paint-server lookup. The same signed binary passes
all 11 default screenshot smoke cases with existing tolerances. Eight are
pixel-exact; inline-node (13 pixels, maximum error 1), text-decorations (1,341,
maximum 2), and canvas-text (1,994, maximum 8) retain their previous residuals.
No screenshot tolerances change.

Production verifies the same uncommitted 4,869-file snapshot as the final GC
batches, before the feature commit is created. Both production snapshots retain
identical content, 26 selected Source references and two compiler hashes.
The five implementation/test file hashes subsequently match the feature commit
exactly. Documentation and inventory-table changes follow separately.
Comparisons use the stable compatibility wrapper retained from the preceding
batch, avoiding its recorded direct-fallback V library-path failure.

Signed binary SHA256:
`969ffdeb94587840110fff4f1e8295e19040977b67a46282bf83448b460ab7f8`.
Production manifest SHA256:
`105baa22a6d380d883c63881cecda581aaf592ea61a483ed21f7e546a221aa83`.


## Evidence and remaining scope

The consolidated `Build/audit-fixes/native-media-state-evidence.json` has
SHA256 `38c914519c262cc45f5b95ad783b1e69e89087ec8c1b2fc4196ba43819e0b058`.
It validates manifest/log/artifact hashes, preserved baseline files, Source
references, compilers, feature commit bytes, signed binary and module inventory.
The manifests and logs use the `Build/audit-fixes/native-media-state-<mode>`
prefix; production artifacts are under `Build/audit-fixes/native-media-state-production/`.

Default manifest SHA256:
`c2d73691a1996863299309ca1217ebaf6d41d64012ab3ea31c482ff7619e652f`.
GC-none manifest SHA256:
`5ea038ce324ddf2451ae4ac8004e3c4256a24fd0a554dd8945a30ee025e55c84`.

Implementation: [native media host](../../browserjs/media_element_host_darwin.c.v)
and [page bootstrap](../../main.v).
Focused tests: [host states](../../browserjs/media_element_state_host_test.v)
and [page owners](../../media/element_state_owner_test.v).
Existing [buffered owner evidence](NATIVE_MEDIA_ELEMENT_BUFFERED_OWNER.md)
records the preceding range and DOM-identity prerequisites.


The getters expose the existing V model's state. At this verification snapshot,
V recomputed cached ended synchronously. The subsequent
[step-1 owner slice](MEDIA_ENDED_STEP_ONE_OWNER.md) repairs that timing and the
ready-state trigger, while retaining the existing V duration/position predicate.
The Source automatic unbounded resource FIXME, complete decoder/manager
aggregation, native media operations and event delivery, played/seekable
differences, full HTMLElement/audio/video
prototype hierarchy, foreign realms, WrapperWorlds, IPC and physical collector
ownership remain separate. The browser still uses JavaScriptCore. No new
LibJS or Wasm sweep is claimed.

At that snapshot, all 2,179 files in the preceding 78-owner module inventory
retained their hashes:
432,292 implementation / 153,795 test V LOC. Browser/root code is excluded.
Physical counts do not measure parity; the ledger remains 32 fixed / 25 partial
/ 9 open.
