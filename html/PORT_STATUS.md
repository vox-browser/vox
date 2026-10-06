# HTML V translation status

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/HTML`

Translation workspace: `~/code/vox2/html`
Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`
Historical mapping inventory: 2026-09-08
Selected Source owner slices reviewed: 2026-10-06

The historical inventory below found candidate V mappings for 261 HTML source
files. Its file/symbol/LOC counts and 107-file test result describe that earlier
inventory, not current logic, generated-binding or browser parity. The current
audit and fix evidence is in `docs/translation-audit/`; mapping a source name or
a runtime hook does not establish that its complete logic was translated.

## Native volume and mute property owner

Native volume/muted accessors use the actual audio/video DOM model, validate
the receiver before restricted-double or boolean conversion and replay, preserve
original exceptions and expose genuine IndexSizeError with Source's exact
message. Successful writes keep the existing effective-volume and queued
volumechange owner behavior. Implementation and seven focused cases: `c2e279e5`.

[Native volume/mute evidence](../docs/translation-audit/NATIVE_MEDIA_VOLUME_PROPERTY_OWNER.md)
retains the unchanged runtime baseline, all 14 affected files in each GC mode,
the 66-case main regression, signed production startup, two exact public
viewports, 13 exact SVG pairs and all 11 smoke cases within unchanged bounds.
Autoplay-policy pause, muted-style invalidation, actual playback-manager/pipeline
delivery, other operations, complete media/MSE, realms and physical GC remain open.

## Native playback-rate property owner

Native defaultPlaybackRate/playbackRate accessors now use the actual audio/video
DOM model, check the receiver before restricted-double conversion and document
replay, preserve original thrown values and throw genuine NotSupportedError
DOMExceptions. Successful writes enter the existing queued rate setters;
signed zero and live task values survive the native boundary.
Implementation and six focused cases: `1ac087a6`.

[Native rate evidence](../docs/translation-audit/NATIVE_MEDIA_RATE_PROPERTY_OWNER.md)
retains the corrected runtime baseline and intermediate compile diagnostics,
all 11 affected files in each GC mode, the 66-case main regression, signed
production startup, two exact public rate viewports, 13 exact SVG pairs and all
11 smoke cases within unchanged bounds. Actual manager/clock/pipeline delivery,
other media operations, complete media/MSE, realms and physical GC remain open.

## Media rate setters and load caller

Rate changes queue ratechange through the owning media task. Current-rate
validation accepts finite values from 0 to 64; immediate assignment preserves
signed zero even when equality suppresses an event. Explicit/automatic load
resets through that setter, canceling old owner tasks and propagating invalid
defaults before resource selection. Separate implementation/test commits are
`96a8c005` and `9dbdb6f5`.

[Rate/load evidence](../docs/translation-audit/MEDIA_RATE_TASK_LOAD_OWNER.md)
retains both runtime baselines, ten new cases, all 23 selected files in each GC
mode and the 66-case main regression. The frozen signed production build,
assertion-independent DOM/model probe, existing duration-task viewport and all
11 smoke cases pass. Native rate properties are added by the subsequent slice
above. Actual manager/clock/pipeline delivery, full load/media/MSE, realms and
physical GC remain open.

## Duration and volume event tasks

Known-duration changes queue durationchange while duration/end-seek updates
and cache scheduling remain immediate. Changed volume or muted values queue volumechange
while effective-volume hooks update immediately. Both use the actual media
task/document owner, load cancellation and active-document delivery guard.
Separate implementation/test commits are `3c654b6b` and
`214de36b`.

[Property-task evidence](../docs/translation-audit/MEDIA_PROPERTY_TASK_OWNER.md)
retains baseline and full-disk diagnostics, eight new cases, all 20 selected
files in each GC mode, the 66-case main regression and the unchanged snapshot.
The signed production build passes startup; its public MediaSource task-timing
viewport is pixel-exact and all 11 smoke cases pass within existing bounds.
The subsequent native volume/mute slice above exposes the properties.
Autoplay-policy pause, muted-style invalidation, other native operations,
other events, complete playback/MSE, realms and physical GC remain open.

## Media completion task and DOM event owner

Associated media now use the actual audio/video DOM EventTarget. Native
wrappers, model handlers and ancestor capture listeners share one target,
including after adoption. End-of-playback completion queues one media task;
timeupdate sees the step-1 cache refresh, and the live pause/promise decision
runs after its listeners before ended. Loading cancels only that owner's task,
and inactive-document delivery follows the existing task guard.
Implementation/tests are separate commits `2e994235` and `33ffe100`.

[Completion evidence](../docs/translation-audit/MEDIA_END_TASK_DOM_OWNER.md)
retains all baseline/fixture diagnostics, eight final cases and 14/14 files in
each GC mode, including the 66-case main regression. The same frozen production
snapshot builds, signs, passes startup, matches the public state/event-owner
viewport exactly and passes all 11 smoke cases within their existing bounds.
Source manager Ended state, native play promises, ordinary compact listener
routing, other event scheduling, full operations, realms and physical GC remain
separate. These selected fixes do not establish full HTML parity.

## Media ended cache boundary

Media ended recomputation now uses the actual main-loop step-1 callback queue.
Position/duration changes preserve the old cache through microtasks; the next
boundary reads the live owner, including ready-state transitions, reload and
recorded loop state. Paused processing preserves pending callbacks and task
generation, while unpause schedules their automatic native resume.
The event-loop prerequisite and media implementation/tests are separate commits
`82f30d6f` and `1e6de269`.

[Step-1 evidence](../docs/translation-audit/MEDIA_ENDED_STEP_ONE_OWNER.md)
records the executed model/native/paused baseline failures, nine final cases,
all 16 affected files in each GC mode across frozen batches and a focused
rendering-fixture correction, the 66-case main regression, signed
production startup, an exact media-state viewport and all 11 smoke cases within
existing bounds. Source's PlaybackManager Ended predicate after consumed media
remains unimplemented: V retains its existing duration/position predicate.
Full event delivery, native operations, playback, nested pause/spin behavior,
prototype hierarchy, realms and physical GC remain separate.

## Native media state owner

Native readonly currentSrc, networkState, readyState, seeking, duration, paused
and ended getters now read the actual DOM audio/video media owner. HTML media
wrappers inherit readyState instead of shadowing it with the compact snapshot.
Brand checks precede replay; primitive values preserve NaN, Infinity and negative
zero. Existing decoded frames and created audio retain their actual DOM owners.
Implementation and five focused cases are committed as `a699f872`.

[State-owner evidence](../docs/translation-audit/NATIVE_MEDIA_ELEMENT_STATE_OWNER.md)
records 9/9 affected files in each GC mode, the 66-case main regression, signed
production startup, an exact media-state viewport, 13 exact SVG pairs and all
11 smoke cases within existing bounds. The getters expose the existing V model.
The subsequent [step-1 owner slice](../docs/translation-audit/MEDIA_ENDED_STEP_ONE_OWNER.md)
repairs cached ended timing. Native media operations/events, complete playback,
full prototype hierarchy, foreign realms and physical GC remain separate.
These slices do not establish full HTML parity.

## Native media buffered owner

The native Window bridge exposes HTMLMediaElement.buffered through the actual
DOM audio/video media model, with readonly getter metadata, native receiver
checks before document replay, and fresh TimeRanges snapshots. Created media
retain one DOM owner through insertion replay. The removal cache prerequisite
refreshes ranges before ready-state evaluation and updateend without entering
the append progress path. Implementation/tests are committed separately as
`cc9b1e78` and `5f567830`.

[Removal evidence](../docs/translation-audit/MEDIA_REMOVAL_RANGES_OWNER.md) and
[native buffered evidence](../docs/translation-audit/NATIVE_MEDIA_ELEMENT_BUFFERED_OWNER.md)
record both GC modes, the 66-case main regression, frozen signed production
startup, exact media/SVG viewports and all 11 smoke cases within their existing
bounds. The compact element prototype hierarchy, native played/seekable,
complete playback aggregation/codec execution, foreign realms and physical
GC ownership remain open. These slices do not establish full HTML parity.

## Historical unmapped-file inventory

| Remaining upstream module | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC |
| --- | ---: | ---: | ---: |
| None | 0 | 0 | 0 |

## Historical source-file inventory

LOC is physical line count (`wc -l`), including comments and blank lines. V
implementation and test columns are disjoint. Shared support added to `dom` is
not included in the V counts below, so these figures describe the `html` module
itself.

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Status |
| --- | ---: | ---: | --- |
| `HTML/` top level | 218 | 57,313 | Mapped |
| `HTML/Canvas` | 7 | 1,101 | Mapped |
| `HTML/CrossOrigin` | 2 | 358 | Mapped |
| `HTML/CustomElements` | 5 | 587 | Mapped |
| `HTML/EventLoop` | 3 | 1,017 | Mapped |
| `HTML/Parser` | 7 | 9,635 | Mapped |
| `HTML/Scripting` | 18 | 3,217 | Mapped |
| `HTML/SyntaxHighlighter` | 1 | 206 | Mapped |
| **Total** | **261** | **73,434** | **Mapped** |

The translated module contains 147 implementation files (56,368 LOC) and 107
test files (11,937 LOC), containing 545 V test functions. Several V files
consolidate tightly coupled C++ classes, while parser and state-machine code is
split by responsibility; file and test counts are therefore not expected to
match one-to-one with the upstream layout.

The historical symbol audit inventories 3,985 upstream implementations from both `.cpp`
and inline header definitions. That run reported zero unmatched entries:
3,313 direct candidate matches, 53 reviewed consolidated matches, 317 GC or
binding-runtime hooks, 229 language constructors/destructors, 62 namespace
template specializations, nine language template traits, and two language
operators. It also inventories 1,067 upstream HTML/WPT test inputs so changes to
the upstream corpus remain visible even though those JavaScript/browser tests
do not map one-to-one to V test functions.

## Historical module verification

Recorded inventory/module verification:

```text
$ python3 tools/html_translation_audit.py
upstream .cpp files: 261
upstream methods: 3985
unmatched methods by class:

$ /Users/alex/code/v/v -enable-globals test html
Summary for all V _test.v files: 107 passed, 107 total.
```

Focused coverage includes the HTML tokenizer/tree builder, foreign and fragment
parsing, custom elements, forms and selected-content, media, canvas and
offscreen canvas, navigation/session history and same-document updates,
browsing contexts and cross-origin access, event loop and messaging, classic
and module-script fetching, workers and scripting environments, structured
serialization, rendering-thread command ordering, and syntax highlighting.

History-step application is event-driven: document population, synchronous
navigation queue jumps, changing-document updates, and non-changing history
object updates advance through explicit continuation phases. Traversal queue
entries receive a settlement signal, child navigables become ready only after
their queued creation bookkeeping, and `Document.open()` cancels pending and
ongoing navigation without spinning the event loop. A child navigable whose
active document was cleared during destruction remains a load-event blocker
until its replacement document is activated.

The rendering update now executes the source content-visibility and
ResizeObserver fixed-point loop. It determines proximity for the filtered
`content-visibility:auto` paintable cache, repeats after an initially relevant
element, gathers and broadcasts resize observations until stable, then resumes
pending transitions and intersection observations.

Viewport resizing now crosses the active BackingStoreManager boundary. A
resize restarts its single-shot shrink timer, allocates a DPR-scaled store with
the source's temporary cushion, and publishes the new front/back IDs to the
PageClient and rendering-thread queues. The timer callback later reallocates at
the exact viewport size.

Responsive image source selection now delegates `sizes` to CSS's translated
component-value, media-condition, calculation, and viewport-length algorithms.
Picture-source media matching uses the same `MediaQuery.evaluate()` path, and
rendered `auto` sizes use the translated replaced-element default sizing
algorithm rather than a trailing-`px` parser and fixed numeric fallback.

Video frame handoff now feeds the media element's external-content source used
by `VideoPaintable`, while poster, current/first-frame, and transparent-black
selection stays in `HTMLVideoElementModel::current_representation()`. The
`videoWidth` and `videoHeight` accessors now also return zero in `HAVE_NOTHING`,
matching the current C++ guard instead of exposing stored decoder dimensions
too early.

The four `HTMLElement` CSSOM offset accessors now consume the translated
`PaintableBox` united border/padding geometry. Inline principal boxes split by
a block descendant retain their full continuation chain, so the offsets include
the intervening block and trailing inline fragment instead of reporting only
the first fragment.

`HTMLInputElement` checkedness, dirty checkedness, and indeterminate state now
live on the DOM element, matching C++, rather than being copied into a second
HTML model. `set_checked()` performs only the single-control transition and
style/repaint invalidation; binding and radio-group algorithms own exclusivity,
walk the current DOM root, and compare form owners instead of scanning a
process-global list of previously created models. Changing `disabled` on a
form-associated element now explicitly repaints it, and changing a fieldset's
disabled state repaints every form-associated descendant whose live enabledness
can change.

File and color picker requests now cross the DOM `Page` bridge belonging to the
input's own document. The optional per-model hook remains available to
standalone HTML tests and hosts without an attached page.

X-Frame-Options `sameorigin` validation now walks logical parent navigables and
reads their active-document origins through the remote-safe Navigable boundary.
It no longer depends on dereferencing locally hosted container documents.
Navigable containers also query their content navigable for session-history
readiness and load-event delay state; both the full navigation model and the
compact embedded-content model implement that boundary.
Navigable initialization keeps the logical DOM Navigable parent separate from
the optional local HTML model parent. Local roots under a remote parent remain
children for history/readiness decisions without downcasting that parent, and
inherit page-local debug state only when a local parent model exists.
The delaying-load-events flag remains owned by the navigable when its container
document is remote. Local container documents are scheduled to recheck parser
completion whenever that flag changes.

## Port boundary

The algorithms, state transitions, validation, error paths, and observable
ordering from LibWeb/HTML are translated. Operations owned by external runtime
subsystems—such as executing JavaScript bytecode, performing a platform fetch,
rasterizing through a native painter, IPC transport, or presenting a window—are
exposed as typed host hooks. Tests use deterministic hosts to verify the HTML
side of those boundaries. This keeps the module executable and testable without
pretending that the C++ LibJS, LibGfx, network, or embedder runtimes are V code.

## Conventions

- DOM-backed element algorithms use `html_<element>_<member>` functions over the
  corresponding `dom.HTML*Element` type.
- Stateful or host-bound objects use `*Model` types and explicit typed hooks.
- HTML event subclasses live in `dom/html_events.v` when dispatch identity must
  be shared with the DOM module.
- Translation implementation, tests, and status documentation live only in
  `~/code/vox2`; the Ladybird checkout remains the upstream reference.


## Actual drag FileAPI producer boundary

`DragDataStoreItem` now owns raw UTF16 type/text/name slots with copied file
bytes and checks stale compatibility views. `data_transfer_fileapi.v` maps
pinned DataTransfer::files, DataTransferItem::get_as_file and the add(File)
branch to genuine FileList/File/Blob records. Results are fresh Source owners,
respect protected/disabled/removed gates, preserve raw file names, and use
Source File MIME processing/default-clock options while retaining upstream
other-field TODOs. Older FormDataFile snapshot entry points remain compatibility
APIs. The native adapter accepts actual typed implementations and the actual
Runtime's FileAPI owners; it does not manufacture a public DataTransfer receiver.

Current producer/File/raw-slot neighbors pass **5/5** both modes; native
DataTransfer/input neighbors pass **2/2** both modes. Source mapping, native AK
byte-decoder proof and exact focused log names are in
[`READ_LOOP_BLOB_SOURCE.md`](../docs/translation-audit/READ_LOOP_BLOB_SOURCE.md).
Public DataTransfer/Item/List and HTMLInputElement wrappers, complete overload
dispatch, foreign-world/native Worker ownership, and BodyInit source/stream
records remain open. These finite results do not establish complete HTML parity.

Actual node-document MediaSource URL selection now authorizes the copied
entry through genuine relevant settings (`a0f60763`). Settings creation URL
and the Window's logical navigable select self-fetch; authorization failure
and Blob tags reach remote fetching. Authorized MediaSource tags resolve and
attach the real live store object. [Caller evidence](../docs/translation-audit/BLOB_URL_MEDIA_ACTUAL_DOCUMENT.md)
records the original missing-fetch-hook failure and **2/2 default plus 5/5
GC-none** combined caller/neighbor files, including main. Standalone Legacy
consumers, remote media transport and complete native bindings/GC ownership
retain separate scope.
