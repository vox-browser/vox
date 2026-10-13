# Ordinary native media event listeners

Parsed and script-created HTML audio/video compact wrappers now inherit the
installed EventTarget methods. After successful native media binding, the
generic own `addEventListener` stub is removed, so ordinary add/remove/dispatch
calls share the actual DOM owner's listener records. Implementation and six
new cases: `4ef8e6e501ad26c6d100845d23bb129b7f58593a`.
Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

## Owner routing and event behavior

The former own method wrote a separate compact `__listeners` table while native
media tasks dispatched through the DOM EventTarget. Ordinary listeners missed
real play, pause and readiness events, while inherited native removal could not
remove their compact registrations. The stub also ignored listener options and
could invoke late video `loadeddata` and `seeked` callbacks immediately with a
plain object, based on copied `readyState`.

Successful binding now leaves these media wrappers on the existing
HTMLMediaElement/EventTarget prototype path. Both registration and removal use
the installed native binding, which retains callback identity and routes
capture, once and listener-object handling through the actual DOM records.
Synthetic `dispatchEvent()` calls use that same list. Registering a listener
on an HTML video with an existing retained frame does not manufacture a historical
data or seek event.

`HTMLMediaElement.cpp` dispatches media events through the element's actual DOM
target. `DOM/EventTarget` and `DOM/EventDispatcher` supply listener identity,
capture/removal/once behavior, callback invocation and event lifetime. The
completed model and native bindings already expose this machinery; the compact
wrapper now reaches it through an ordinary `video.addEventListener(...)` call.
Queued events carry actual trusted Event records, live `this`, target and
currentTarget identity, and currentTarget clears after dispatch. Synthetic
events remain untrusted.

The existing native play Promise path is unchanged. Play/playing events precede
fulfillment, and waiting-audio pause events precede rejection of the captured
batch with one typed AbortError. Listeners registered before DOM insertion keep the script-created media
owner's actual DOM/EventTarget identity after insertion. Queued metadata, first-data
and canplay events likewise use the existing model transitions for both audio
and video; listener registration does not bypass their tasks.

Actual Page pointer release already dispatches DOM pointerup and click before
the compact replay helper. Ordinary media listeners now run in that existing
dispatch and are absent from the compact listener table, so replay does not
deliver a duplicate media click. `preventDefault()` on the trusted click reaches
the Page's `last_click_allowed` flag and the existing BrowserApp release gate.
The native callback's script mutation reaches the owning document through the
same replay/poll path. Image, object and SVG facade listeners retain their
existing compact click delivery.

The pointer regression enters actual `Page.handle_mousedown` and
`Page.handle_mouseup` with `InputTarget.from_node`, then invokes the real
BrowserApp compact replay helper. It verifies the translated Page route and
cancellation flag. It does not establish Cocoa/AppKit event transport, pointer
coordinate hit testing or general input parity. This slice adds no new pointer
or click dispatcher.

## Six focused cases and frozen evidence

Both new files use ordinary add/remove/dispatch calls throughout, without
bypassing the compact wrappers through `EventTarget.prototype.addEventListener.call(...)`.

| Test file / case | Covered behavior |
| --- | --- |
| `main_media_event_listener_owner_test.v`: parsed play | Ordinary video callbacks receive trusted play/playing before two real play Promises fulfill; the other audio owner remains silent; saved Event lifetime and actual target identity are preserved |
| Created audio | Registration before insertion follows the same DOM owner; timeupdate/play/waiting/timeupdate/pause precede two rejections sharing one typed AbortError |
| Queued readiness | Audio and video receive queued metadata, first-data and canplay in source order; registration and microtask checkpoints cannot deliver them early |
| Listener identity/options/dispatch | Duplicate callback registration is deduplicated; once invokes a listener object's handleEvent with that object as receiver; capture-sensitive removal and synthetic dispatch share one native list |
| Real-ready late registration | A retained 2x1 bitmap fixture with model readiness set to HAVE_CURRENT_DATA keeps late loadeddata/seeked registration silent; a later genuine load/readiness crossing queues exactly one trusted loadeddata |
| `main_media_event_listener_ui_owner_test.v`: Page pointer/replay | Actual Page release delivers one trusted pointerup/click sequence before compact replay; native click cancellation reaches the Page flag; callback mutation, window.event cleanup and image/object/SVG compact routing are preserved |

The unchanged baseline compiles both files and fails all six new functions at
the intended runtime assertions. There are no compiler failures or panics:
parsed playback and created-audio events are missing, readiness listeners miss
queued metadata, ordinary registration does not share the native dispatch
list, ready-video registration fabricates callbacks, and ordinary pointer
listeners miss trusted Page delivery. Both files then pass with the narrow main
fix and byte-identical tests. Both snapshots remain unchanged through their
respective runs.

The baseline and focused commands use the frozen V dispatcher with
`-old-compiler -enable-globals`, `VJOBS=2`, and both new file paths. The committed
19-file selected batch additionally covers the existing main regression,
native EventTarget and media hosts, play promises, Page/document events,
pause/load, and readiness model callers. Its GC-disabled command adds
`-gc none`. Both complete selected runs pass 19/19 files, including the
66-case main regression, on unchanged committed `4ef8e6e5` inputs. All four
runs retain 4,967 input hashes, with byte-identical new tests throughout; both
selected runs also retain identical complete snapshots. The source references,
compiler and native-archive hashes remain unchanged.

| Run | Result | Manifest under `Build/audit-fixes` | SHA256 |
| --- | --- | --- | --- |
| Unchanged parent baseline | Both files compile; all six cases fail at runtime; no panic | `native-media-listener-baseline-manifest.json` | `8a683e091b5df2484977d34fe731533d01a78d31d5135498dc4c8618311581a0` |
| Corrected focused run | Both files / all six cases pass with the same test bytes | `native-media-listener-focused-manifest.json` | `11c4d5d59c17199e3ddf56f85bc2a04d505863bd7b78436f4e898194e0998669` |
| Frozen selected default-GC run | `19/19 files pass` | `native-media-listener-default-manifest.json` | `c6a4e0d5f7b46421362e93ce543184e2e4c9a1312846c75a502942832ba1bb91` |
| Frozen selected GC-disabled run | `19/19 files pass` | `native-media-listener-gc-none-manifest.json` | `d8cb859c4cdcf3944f53eeb8dc3c3d0b3f1e7ace5a3d152bafafc67bae3390c2` |
| Production verification | `Signed build/probe/startup, 2 exact pages, 14 exact SVG pairs and 11/11 smoke cases pass` | `native-media-listener-production-validated/manifest.json` | `9019da6de14330bfc2c6de22f69a1799e3ee9e8b456c5c3e5a7ca757e572210d` |

The runtime baseline log has SHA256
`7229d924cc1c09ae6f63b7a0a4ed9d605653ac3c1e5f6f2e42e9a6f366afc670`;
the corrected focused log has SHA256
`5f5a60fda099d43fbc2c51ffb3c507c71aafe038b5dba537ae55beb85949d879`.
Manifests retain exact tracked/new-test bytes, selected upstream references,
compiler/native-archive hashes, commands and before/after comparisons.

The current V formatter accepts the final test bytes. The preserved older
formatter prefers two cosmetic line wraps in the five-case file. This
informational disagreement is retained on an ignored copy with its exact diff
and hashes under `native-media-listener-format-review/`. It is not a compiler
or runtime failure, and no test bytes were changed after the baseline.

The ordinary production probe compiles with `-prod -gc none` and executes
explicit `require_listener` checks. It embeds the exact `javascript_bootstrap()`
function extracted from frozen `main.v`, SHA256
`8ac3e597969bc69881ad78568ed5007a4717ff889ac5bc57e7f6263870618be8`.
The probe supplies actual parsed/created media owners and controlled model
transitions. The full Page pipeline is covered by the root tests and the signed
browser page captures; the standalone probe does not reproduce the whole
BrowserApp navigation loader.

The initial production precheck used the wrong Element setter in its fixture
(`set_attribute`), and stopped before any browser build or runtime check. The
corrected fixture uses `set_attribute_value` in the separate validated run.
The original attempt remains in `native-media-listener-production/`, with
manifest SHA256
`a5428c96d85419e884fb51a4d648756939b3e5281c6a82ac303cae53e0ea10d7`.
Its unchanged snapshot and failed precheck remain separate diagnostics.

The signed build, active probe, signature verification and startup all pass.

Both ordinary-listener pages are pixel-exact against the 800x600 green
reference: 480,000 pixels each, zero differing pixels and zero maximum channel
error. `ordinary-media-play` exercises parsed/created muted play, waiting,
pause and the shared typed rejection batch; `ordinary-media-dispatch` exercises
the same native list through synthetic dispatch and listener options, including
passive cancellation, AbortSignal removal and original getter exception values.
All 14 required SVG pairs are pixel-exact, including same-size image-source
switching and paint-server mutations.

All 11 configured screenshot smoke cases pass: eight exact, with the existing
fuzzy bounds retained for inline-node (13 differing pixels, maximum channel
error 1, MAE 0.0000 and RMSE 0.0026), text-decorations (1,341 / 2, MAE 0.0013
and RMSE 0.0419), and canvas-text (1,994 / 8, MAE 0.0038 and RMSE 0.0928).
No new browser launch reports appeared.

The completed manifest records all 13 steps and identical 4,967-file
before/after snapshots. The binary remains unchanged; all 99 current artifact
hashes verify and all 236 previous source-error/native-play evidence artifacts
retain their hashes. The original precheck's eight artifacts and verifier bytes
also remain unchanged. The final completion receipt retains the manifest and
flushed runner-log hashes:
`native-media-listener-production-validated/completion-receipt.json`, SHA256
`2c6a7638a0a54f685e53c61bf4c04a4c41633ae2a7aabf42684fa359f05c56cc`.

Production binary SHA256: `db0afb231b93d18cb281f2fc71c6bc4b1bcc64071b0f340c913f30ac7c9120e5`.
Consolidated evidence: `Build/audit-fixes/native-media-listener-evidence.json`, SHA256
`75028b97d12dfa3d4937d145ec36368222bbc10abc77f56388e69da31fc4e0b9`.

## Inventory and retained boundaries

Physical inventory: `Build/audit-fixes/source-current-module-loc-4ef8e6e5.json`,
SHA256 `64cd5fb2cfa150fe9505b5e07dc6f6251a8e2211fd7d0d9ce93481eaee33fcff`.
The counts remain unchanged: 78 owners and 2,209 assigned files, with 432,825
implementation and 158,801 test V LOC. HTML retains 69,630 implementation and
40,284 test lines. The implementation and both new test files are root browser
support, excluded under the established module convention. Physical LOC and
source mappings do not measure behavioral parity.

The pinned HTML media load step 4 is still FIXME: it does not immediately
settle promises already captured by media tasks that load subsequently cancels.
The existing captured-batch pending behavior remains. Ordinary listener routing
does not close this source limitation or replace synchronous V resource
selection with the full upstream asynchronous algorithm.

Complete resource/readiness/seek/MSE, enough-data autoplay, full Permissions
Policy, physical playback/decoding, foreign engine realms, arbitrary raw UTF16
MediaError storage and automatic weak ownership remain open. General compact
nonmedia EventTarget behavior, element handler-attribute parity and the full
HTMLElement/audio/video prototype hierarchy remain separate work. The browser
continues to use JavaScriptCore. The historical ledger stays **32 fixed / 25 partial / 9 open**.

Earlier native-play and listener-related evidence retains its original scope,
snapshots and hashes. This document records the subsequent ordinary listener
route; it does not rewrite older descriptions of that then-open boundary.
