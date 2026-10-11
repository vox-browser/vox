# Native media play promise owner

Native JavaScript `HTMLMediaElement.prototype.play()` now returns a real
JavaScriptCore Promise backed by the actual audio/video model's WebIDL promise
capability. Parsed and script-created media use their live DOM owner, and the
generic compact element's own immediately fulfilled `play()` stub is removed.
Implementation and 17 new focused cases: `58fde80e`.
Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

Complete media/resource/readiness/seek and MSE behavior, enough-data autoplay
timing, full Permissions Policy, ordinary compact media-listener routing,
physical playback/decoder/manager parity, foreign engine realms and automatic
weak ownership remain open. The browser continues to use JavaScriptCore.
This slice connects native promises to the translated state and task machinery;
its deterministic resource inputs do not certify physical decoding.

## Source behavior and owned capability

`HTML/HTMLMediaElement.idl` declares `Promise<undefined> play()`.
`HTMLMediaElement.cpp::play()` rejects denied requests with a fresh
`NotAllowedError`, then rejects `MEDIA_ERR_SRC_NOT_SUPPORTED` with a fresh
`NotSupportedError` containing the actual current `MediaError.message`.
Only permitted requests without that source error append their promise and
enter the existing internal play steps.

The public V convenience caller now creates one `webidl.Promise` per request
and exposes that exact capability through `dom.Promise.from_webidl()`. Its
context comes from the media owner's current Document settings and realm,
including after real DOM adoption. Without a Document or settings, the
standalone adapter retains an empty promise context. The same capability remains
in the pending list and is observed by both V and native JavaScript callers;
the bridge does not copy settlement state into a second model promise.

The native method validates its registered DOM receiver before mutation replay
and does not convert unused extra arguments. Brand failures become rejected
real Promises carrying an actual `TypeError`; they do not synchronously throw
or consult author Proxy traps. A replay exception likewise becomes a rejected
Promise with the original JavaScript value, before invoking model `play()`. Descriptor
flags are writable, enumerable and configurable; native name `play` and length
zero are retained. Author replacements of global `Promise` or `DOMException`
do not replace the captured intrinsic promise or exception construction path.

## Typed rejection sinks and task ordering

The native bridge wraps the same WebIDL capability and converts actual
DOMException records by identity. Besides the existing permission and immediate
unsupported-source gates, this slice corrects three legacy string sinks:

| Model path | Actual rejection |
| --- | --- |
| Exhausted resource selection | `NotSupportedError`, code 9, with the actual final `last_error` |
| Captured MediaSource failure batch | `NotSupportedError`, code 9, with the upstream fixed message `Media is not supported` |
| End-of-media pending batch | `AbortError`, code 20, with `Media playback has ended` |

The resource-selection Result error remains a separate synchronous adapter
boundary. Selection failure preserves the actual `MediaError` message; the
typed promise rejection does not replace that error record. MediaSource failure
fires its error event before rejecting its captured batch, and retains the
existing guard when a listener resets the error. Every batch uses one shared
DOMException record. Batch rejection now enters the current Document's temporary
execution context, matching the upstream Promise rejection-hook requirement.
Valid Unicode, embedded NUL and line breaks survive native conversion. The
existing V string slot still does not establish arbitrary raw UTF16 MediaError
parity.

Permitted low-readiness calls remain pending through queued `play` and `waiting`
events. A later readiness crossing captures those promises before listeners run,
queues first-data and canplay before playing, fires trusted `playing`, and then
fulfills only that captured batch with undefined. Already-playing calls retain
their separate queued resolution. A pause after playing has already captured
its batch does not cancel that earlier fulfillment.

Explicit pause commits paused state immediately; its task dispatches timeupdate
and pause before rejecting the captured waiting batch with one typed
`AbortError` (`Media playback was paused`). A pause listener's resumed play
request stays outside that earlier batch. Load immediately rejects the current
waiting batch with one typed `AbortError` (`Media playback was aborted`) while
its reset events remain queued. End-of-media rejection follows timeupdate and
pause and precedes ended. Temporary execution-context cleanup can run promise
jobs before the media task returns; event callbacks still observe the correct
pre-settlement state.

The pinned load algorithm's step 4 remains FIXME for promises already captured
by tasks canceled during load. Those canceled-task batches retain their existing
pending behavior. The new native binding does not resolve or reject them
speculatively. V resource selection remains synchronous and Result-returning;
complete upstream asynchronous selection is separate work.

When the owning JavaScript runtime closes with a waiting native request, later
model readiness may still fulfill its capability. The promise bridge checks the
closed runtime before conversion or engine reentry, and the already released
JavaScript roots remain released.

## Focused cases and frozen evidence

The three new files contain 17 cases:

| Test file | Cases | Covered behavior |
| --- | ---: | --- |
| `html/media_play_promise_owner_test.v` | 5 | Exact capability identity; current realm after adoption; standalone/no-settings fallback; typed selection, MediaSource and ended batches; owner-context job scheduling |
| `browserjs/media_element_play_host_test.v` | 10 | Native descriptor and brand order; ignored arguments; original replay value; permission precedence and fresh exact source messages; intrinsic construction; queued waiting fulfillment; pause/resumed and load batches; earlier queued-playing fulfillment after pause; runtime closure; native selection/ended failures |
| `main_media_play_promise_owner_test.v` | 2 | Parsed-page source replay and event-before-fulfillment ordering; created audio before/after insertion; actual DOM/EventTarget ownership; captured pause rejection; absent own/generic compact `play()` |

The integration tests use the actual native `EventTarget.prototype` listener
path. They do not certify the remaining ordinary compact listener routing.
The created-media case preserves the existing initial timeupdate caused by
poster clearing before play/waiting and the later pause task's timeupdate.

The final parent baseline compiles all three new files without compiler
failures and fails all three at runtime. The model's first two cases fail
because the earlier V caller has no WebIDL capability. Its third case panics
on the missing typed selection rejection, so the final two model cases are not
executed in that baseline. The native file exposes the missing method, and the
page cases expose the old compact fulfillment stub. This is a three-file
runtime baseline, without a claim that all 17 individual cases ran on the
parent. The initial baseline compilation diagnostic remains in the separate
`native-media-play-baseline.log` and `native-media-play-baseline-manifest.json`.

All 17 new cases then pass within both complete frozen 24-file selected runs
on unchanged committed `58fde80e` snapshots. These runs include the existing
66-case main regression and neighboring media/Promise callers. They use the
preserved V dispatcher with `-old-compiler -enable-globals`, `VJOBS=2`, and
`-gc none` for the second run. Before/after comparisons retain unchanged tracked
inputs, selected Source references and compiler hashes.

Individual focused checks preceded the frozen runs. Their diagnostics remain
separate: `native-media-play-focused-diagnostics/` retains the initial page
integration ordering failure, the diagnostic run and the corrected focused
integration pass. The corrected test observes the existing initial timeupdate
before play/waiting. There is no claimed separate frozen focused manifest.

| Run | Result | Manifest under `Build/audit-fixes` | SHA256 |
| --- | --- | --- | --- |
| Final parent runtime baseline | 3/3 files compile and fail at runtime | `native-media-play-baseline-final-manifest.json` | `c9e915d3dee9a7557c8bcf7ecd6b0b8dbbfe4150dda801797d614e90820795cb` |
| Selected default-GC run | 24/24 files pass | `native-media-play-default-manifest.json` | `e2f617d153c706e43abba9b0f872837ef37d39c26285d7478ec16af5b98a98c9` |
| Selected GC-disabled run | 24/24 files pass | `native-media-play-gc-none-manifest.json` | `110f44b44468c4158adbc080cc24e7e0fd00626ab2fca371281d9de36ff87ef9` |
| Signed production verification | Signed build/probe/startup; 2 exact play pages; 14 exact SVG pairs; 11/11 smoke cases pass | `native-media-play-production/manifest.json` | `895658242296742f526d04b0e028cd2cceb25f5fe88cd58127eed06a49862c6a` |

The production build, ordinary `-prod -gc none` native promise probe, ad-hoc
signature verification and startup pass. Both native-play pages are pixel-exact
against their 800x600 reference: 480,000 pixels each, zero differing pixels and
zero maximum channel error. All 14 SVG preservation pairs are also pixel-exact,
including same-size image-source switching and paint-server mutations. All 11
configured screenshot smoke cases pass: eight exact, with the existing fuzzy
bounds retained for inline-node (13 differing pixels, maximum channel error 1),
text-decorations (1,341 / 2), and canvas-text (1,994 / 8, MAE 0.0038 and RMSE
0.0928). No new browser launch reports appeared.

The production manifest records all 13 commands, logs, exact probe/pages,
Source inputs and captures. Its 4,964-file before/after snapshots are identical,
the built binary remains unchanged, all 104 artifact hashes verify, and all 81
previous source-error artifacts retain their hashes. The completion receipt
`native-media-play-production/completion-receipt.json` retains the final
manifest and flushed runner-log hashes; its SHA256 is
`5adaa335326ed73ada860cd45727555e5018630568858bd01b9faa6a482597ee`.
The interrupted pre-commit production attempt remains separately preserved in
`native-media-play-production/interrupted-before-implementation-commit/` and
is not counted as completed verification.

Production binary SHA256:
`efe7d68414c0179b776a1aacf565dd57d41d70c552bdd4f8ccd2353b339c4cab`.
Consolidated evidence: `Build/audit-fixes/native-media-play-evidence.json`, SHA256
`4b58d16d0aed341fb1d416bd029fa481254b8010c3c822b23d02d73bb339ce1b`.

## Inventory and retained audit history

Physical inventory: `Build/audit-fixes/source-current-module-loc-58fde80e.json`,
SHA256 `87f5275d06b35029406cead2eca001cb606389db9aa58958d6fbb3ff1b1c6f01`.
Its 78 owners contain `432,825` implementation and `158,801` test V lines across
`2,209` assigned files; HTML has `69,630` implementation and `40,284` test lines.
Browser/root integration code and tests follow the existing exclusion convention. LOC and
source mappings do not measure behavioral parity.

The historical ledger remains **32 fixed / 25 partial / 9 open**. Existing
evidence documents, manifests, logs and inventories retain their original
snapshots and hashes. In particular, the unsupported-play `aa9a5e27` evidence
still describes the earlier V caller and native exception conversion without a
native JavaScript play Promise. This new document records the subsequent
binding and typed-batch work without rewriting that historical claim.

Preserved prior consolidated evidence: `media-play-source-error-evidence.json`,
SHA256 `2380b97f5370aaec4238c8cb356fa3e0174c0937247a96a6f342017ca309ba4f`.
Preserved prior inventory: `source-current-module-loc-aa9a5e27.json`, SHA256
`166070c623211b8600db5300c89ed5219375d0e4045728c12117361ad8cca27c`.
Both prior artifact hashes still match. Production and consolidation record
the completed historical-evidence preservation checks.
