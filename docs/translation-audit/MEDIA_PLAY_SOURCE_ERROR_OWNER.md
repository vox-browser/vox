# Unsupported media play rejection

Permitted V `HTMLMediaElement.play()` requests with `MEDIA_ERR_SRC_NOT_SUPPORTED`
now reject with a fresh typed `NotSupportedError` carrying the current
`MediaError.message`. The prior fixed diagnostic string is removed from this
public caller. Implementation and four new focused cases: `aa9a5e27`.
Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

## Source behavior and promise boundaries

HTML/HTMLMediaElement.cpp:614–639 checks playback permission first, then rejects
code SrcNotSupported using a new NotSupportedError and m_error->message(). Only
requests that pass both checks append their promise and enter internal play.
HTML/MediaError.h defines code 4 and exposes the immutable message; the V record
retains its existing string representation. The new rejection uses the existing
WebIDL DOMException record/value ABI, with exception code 9. Every rejected
request receives a distinct exception record.

Rejection preserves the MediaError owner, prior pending requests, paused/poster/
can-autoplay state and resource/task state. It does not fetch, start the manager
or queue play events. Permission denial continues to produce NotAllowedError
before this unsupported-source check. Aborted, network and decode error codes
continue through the existing permitted play steps.

The native case enters the actual V play caller and converts its rejection
through the existing DOMException bridge. It verifies native class, code,
message and stable wrapper identity. It does not create a native JavaScript
play() promise. Source-selection failure Results, captured source-failure
promise batches and ended rejection retain their separate legacy adapters.
MediaError's V string slot is unchanged; valid Unicode and embedded NUL are
covered without claiming arbitrary raw UTF16 MediaError parity.

## Regression results

Three new model cases use actual DOM audio/video owners. They check fresh typed
records with empty, ordinary, Unicode, NUL and line-break messages, preserve an
earlier pending promise, reach the actual failing resource-selection caller
without retrying it, and keep other error codes on their existing play path.
The native Page case reaches handle_media_source_failure for both owners and
checks the exact Unicode/NUL message, distinct per-request records, stable
native wrappers, trusted owner error events and balanced execution contexts.
Rejected calls add no play or playing events. The existing permission-precedence
case now checks the typed unsupported exception and its original message.

The unchanged parent 0ff8444a compiles both new files and fails two independent
model typed-value assertions plus the native typed-value assertion. The
non-source-error control passes. The same new test bytes then pass with the
implementation. The focused three-file batch includes all four new cases and
the four existing permission cases. Both complete selected runs pass 15/15
files on unchanged `aa9a5e27` code and tests, including the 66-case main
regression, load/failure, play/pause, permission, volume-policy and native callers.

| Run | Manifest under Build/audit-fixes | SHA256 |
| --- | --- | --- |
| Two model assertions and native typed-value assertion fail | `media-play-source-error-baseline-manifest.json` | `b46978abf484885a92cd273e52ad814a4e83d4cff15995a2da35ef47e048c5a9` |
| 3/3 files pass, including permission precedence | `media-play-source-error-focused-manifest.json` | `cb8e5fdaa1fe3a06b4d01f9999ee078af76373fae1cf7a46b7cf97d2d942dca5` |
| 15/15 files pass with default GC | `media-play-source-error-default-manifest.json` | `16863b643875690fe6e78bb56908c00517d5fb51b3bce1eaa48e378b2482549e` |
| 15/15 files pass with GC disabled | `media-play-source-error-gc-none-manifest.json` | `e496376e7ba3e92ba409df1e1dbf25a3b9d8feb22df16395160c0e5e72c7e5b4` |
| 12 steps pass, including 11 smoke cases | `media-play-source-error-production-manifest.json` | `815cfa400da23178f34cb1eafc5c45a489b52ccc7ad5a800b7a72391e537882f` |

The ordinary probe builds with -prod -gc none and keeps its require checks
active. It uses actual DOM audio/video owners, the actual source-failure caller,
typed/fresh model rejections, native exception identity and exact Unicode/NUL
messages. The signed native bundle passes startup, both pixel-exact prior load
viewports and all 11 canonical smoke cases with their existing tolerances.
Binary SHA256:
`9954df62829cac196b0e209e3483dcffcf9c3def37302d6759e8b31bfb3dc06b`.
It remains unchanged throughout production verification. Manifests retain inputs,
Source/toolchain hashes, logs, artifacts, any launch diagnostics and before/after
snapshots.

Consolidated evidence: `Build/audit-fixes/media-play-source-error-evidence.json`,
SHA256 `2380b97f5370aaec4238c8cb356fa3e0174c0937247a96a6f342017ca309ba4f`.
The preceding volume-policy evidence remains intact. The physical inventory
`Build/audit-fixes/source-current-module-loc-aa9a5e27.json` has SHA256
`166070c623211b8600db5300c89ed5219375d0e4045728c12117361ad8cca27c`.
Its 78 owners contain 432,812 implementation and 158,530 test V lines across
2,208 assigned files; HTML has 69,617 and 40,013.
Root/browser integration tests are excluded. LOC and source mappings do not
measure parity. The historical ledger remains **32 fixed / 25 partial / 9 open**.

Native JavaScript play promise bindings, remaining source-failure/ended promise
adapters, full resource/readiness/seek, enough-data autoplay, Permissions Policy,
physical manager/decoding and automatic weak ownership remain open. The browser
uses JavaScriptCore. Fetched media and failure delivery in these checks are
deterministic model inputs; physical decoding is a separate boundary.
