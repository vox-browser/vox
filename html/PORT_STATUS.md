# HTML V translation status

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/HTML`

Translation workspace: `~/code/vox2/html`
Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`
Historical mapping inventory: 2026-09-08
Selected Source owner slices reviewed: 2026-10-13

The historical inventory below found candidate V mappings for 261 HTML source
files. Its file/symbol/LOC counts and 107-file test result describe that earlier
inventory, not current logic, generated-binding or browser parity. The current
audit and fix evidence is in `docs/translation-audit/`; mapping a source name or
a runtime hook does not establish that its complete logic was translated.

## Structured storage integer codec

`structured_leb128.v` uses vlib `encoding.leb128` in place of the handwritten
AK/LEB128 translation for structured storage, File timestamps and CryptoKey
metadata. The adapter preserves unsigned 16/32/64-bit and signed 32/64-bit
width limits, valid padded encodings, failure cursor positions and existing
`DataCloneError` messages. IPC continues to use its fixed-width format.
Encoded temporary arrays are freed after their bytes are copied into the
serialization record.

`structured_leb128_test.v` covers wire bytes, padding, terminal-byte limits,
truncation, sequential fields and IPC. The Linux CI allocator matrix also runs
the existing storage, FileAPI and CryptoKey codec tests against the full HTML
module.


## Native inherited UIEvent binding

Window-owned runtimes now expose the inherited UIEvent binding over
actual native records: constructor, view/detail/dynamic which and legacy
initUIEvent. Native accessors and initializer preserve IDL metadata, brands,
conversion order and dispatch-time no-op after argument conversion. Actual
Page media callbacks retain native identity, owning view, current-event state,
cancellation and DOM polling. Late Window attachment preserves the original
Event parent and actual global; known UI-family wrappers use a retained
prototype. Implementation and six cases: `d1b86d81`. Both parent files compile
and all six initial UIEvent guards fail there; later assertions remain
unexecuted. Final bytes pass focused and ordinary optimized tests, and 12/12
selected files pass in both GC modes. Signed startup, two exact synthetic
UIEvent pages and all 11 smoke cases pass (eight exact).

View mapping is explicitly owner-local; foreign WindowProxy wrappers are
unsupported. Trusted Page fixtures use explicit targets and platform values,
and expose existing record data rather than full input construction parity:
pressed compatibility moves retain the V mousedown detail and supplied button;
upstream normal mousemove supplies zero detail and primary. Concrete UI
subclass constructors/prototypes/fields, Page mousemove argument/coordinate
mapping, physical Cocoa input/hit testing/default actions, raw inline element
compilation, foreign realms and weak ownership remain open, along with full
media/physical playback and the pinned load captured-task FIXME.

[UIEvent evidence](../docs/translation-audit/NATIVE_UI_EVENT_OWNER.md).

## Native media movement handlers

Media onpointermove and onmousemove now share actual audio/video native
handler slots. Existing Page dispatch delivers pointermove then compatibility
mousemove. Pointermove false alone still permits mousemove; mousemove false
controls the canceled result, while zero permits it. Canceled pointerdown
suppresses compatibility moves until release, preserves click and restores
the next pair. Parsed/created owners keep identity/order, self-replacement,
null/reactivation, original thrown-object reporting and live DOM polling.
Implementation adds only two names; main/Page/dispatcher/bootstrap and click
receipts remain unchanged. Implementation and five cases: `e5ae9afb`. Both
parent files compile and all five functions stop at their initial descriptor
guards; later Page assertions run only after installation. Identical final
bytes pass focused/ordinary optimized tests, and 27/27 selected files pass
in both GC modes. Signed startup, two exact synthetic-Event pages and all
11 configured smoke cases pass (eight exact).

[Movement handler evidence](../docs/translation-audit/NATIVE_MEDIA_MOVEMENT_HANDLER_OWNER.md).

Trusted Page fixtures supply explicit native DOM targets; synthetic Event
pages provide separate browser binding coverage. The shared base Event
surface does not provide full MouseEvent/PointerEvent fields. Node-less
InputTarget logging remains a separate fallback. `Page.handle_mousemove()`
ignores button-mask/modifier arguments and does not install complete client
coordinates; these tests establish no field parity. Physical Cocoa transport/
hit testing, full prototypes, raw inline compilation, foreign realms, weak ownership and
full media/physical playback/load captured-task boundaries remain open.

## Native media auxiliary and double-click handlers

Media onauxclick and ondblclick now share actual audio/video native
handler slots. Primary dblclick follows click even when click is canceled;
its own cancellation does not change the primary activation result. Middle/
right auxclick uses exact false cancellation, while zero permits activation.
Parsed/created owners preserve identity, handler order, self-replacement and
exception reporting. Existing primary receipts suppress same-release raw
onclick installed by a throwing dblclick callback. Implementation adds only
two names to the selected handler list; main/Page/dispatcher/bootstrap remain
unchanged. Implementation and five cases: `5ba4d87c`. Parent baseline compiles
both files and fails all five initial descriptor guards, leaving later Page
assertions unexecuted there. Final bytes pass focused/ordinary optimized tests,
and 25/25 selected files pass in both GC modes. Signed startup, two exact
synthetic-Event pages and all 11 configured smoke cases pass (eight exact).

[Auxiliary handler evidence](../docs/translation-audit/NATIVE_MEDIA_AUXILIARY_HANDLER_OWNER.md).

Actual trusted Page fixtures supply explicit DOM targets/buttons/counts;
synthetic-Event pages supply separate browser binding coverage. Physical Cocoa
input/hit testing, platform double-click recognition, full input fields and
prototypes, raw inline compilation, foreign realms, weak ownership, full media/
physical playback and the pinned load captured-task FIXME remain open.

## Native media onclick and compact replay

Script-assigned media onclick now reaches the actual HTML audio/video
owner's native handler map. Callback identity, listener slot order, trusted
Page delivery and false cancellation use existing source algorithms. Private
Event/Page receipts are compact adapter bookkeeping: an already-processed
native handler cannot trigger stale raw replay after self-mutation. Replay
reads current DOM raw text after flushing compact mutations and uses a stable
bridge key; generic image/object/SVG paths remain intact. Raw fallback still
uses a plain compact Event and Function, leaving real inline compilation open.
Implementation and eight focused cases: `8c567b08`. The unchanged parent
baseline compiles the native/main files and fails six functions; the two Page
tests require new APIs and are unexecuted on that baseline. All eight cases
then pass, and 22/22 selected files pass in both GC modes. Signed startup,
the active optimized probe, two exact pages, 14 exact SVG pairs and all 11
configured smoke cases pass (eight exact).

[Click handler evidence](../docs/translation-audit/NATIVE_MEDIA_CLICK_HANDLER_OWNER.md).

Explicit-target Page fixtures do not establish Cocoa transport, hit testing
or complete input interfaces. Full prototype placement, other handler
attributes, foreign realms, weak ownership, full/physical media and the pinned
load captured-task FIXME remain separate work.

## Native media press/release handler attributes

Ordinary onpointerdown, onpointerup, onmousedown and onmouseup now use the
actual HTML audio/video owner's native handler map. Parsed and created media
preserve callback identity, replacement order and trusted Page press/release
delivery. False pointerdown suppresses compatibility mouse events until release
while click remains; clearing/replacing the handler restores the next press.
False mouseup does not block click. The existing compact replay adds no duplicate
delivery. Implementation and five new cases: `9ee0685b`. The final unchanged
parent baseline compiles both files and fails all five functions; identical
final tests then pass within 18/18 selected files in both GC modes. Signed
startup, the active ordinary production probe, two exact pages, 14 exact SVG
pairs and all 11 configured smoke cases pass (eight exact).

[Press/release evidence](../docs/translation-audit/NATIVE_MEDIA_POINTER_HANDLER_OWNER.md)
retains both native fixture corrections, initial/intermediate diagnostics and
final frozen snapshots. Page tests use explicit DOM targets; Cocoa transport,
hit testing, full PointerEvent/MouseEvent interfaces, raw inline compilation,
onclick, other input handler attributes and full prototype placement remain
open. The pinned load captured-task FIXME, full media/physical decoding,
foreign realms and weak ownership remain separate work.

## Native media event-handler attributes

Ordinary onplay, onpause, onloadeddata and 20 other media handler attributes
now use native descriptors backed by the actual DOM owner. Parsed and created
audio/video retain callback identity, listener slot ordering and queued event/
Promise order. The shared legacy conversion accepts any object by identity,
clears primitives, and silently skips noncallable objects before entering
callback contexts or reading handleEvent; the old Window assertion is corrected.
Implementation and ten new cases: `60ef4bb2`. The corrected unchanged baseline
compiles all three files and fails all ten cases; identical final tests then pass
within 24/24 selected files in both GC modes. Signed startup, the active ordinary
production probe, two exact viewports, 14 exact SVG pairs and all 11 smoke cases
pass.

[Media handler evidence](../docs/translation-audit/NATIVE_MEDIA_EVENT_HANDLER_OWNER.md)
retains initial fixture diagnostics and frozen snapshots. Raw element inline
compilation, onclick/general HTMLElement handlers, full prototype placement,
foreign realms and weak ownership remain open. The pinned load captured-task
FIXME, complete resource/readiness/seek/MSE and physical decoding remain open.

## Ordinary native media event listeners

Parsed and script-created audio/video compact wrappers now inherit native
EventTarget registration, removal and dispatch after successful media binding.
Ordinary listeners receive trusted queued play/pause/readiness events from the
actual DOM owner before the existing play-promise batch settles. Duplicate,
capture-sensitive removal, once and listener-object behavior use the same native
list. Late registration on a retained frame with manually set current-data
readiness no longer creates plain loadeddata/seeked callbacks.
Implementation and six new cases: `4ef8e6e5`. Both new files compile on the
unchanged parent and all six cases fail at runtime, then pass with identical
test bytes. Both frozen 19-file runs pass, including the 66-case main regression.
The signed build/startup, active ordinary production probe, two exact listener
viewports, 14 exact SVG pairs and all 11 configured smoke cases pass.

[Ordinary listener evidence](../docs/translation-audit/NATIVE_MEDIA_EVENT_LISTENER_OWNER.md)
records actual Page pointer/click delivery before compact replay, native
cancellation and generic image/object/SVG preservation. The Page fixture uses
explicit DOM targets; Cocoa/AppKit transport and coordinate hit testing remain
separate. General nonmedia EventTarget, handler attributes and full media
interfaces remain open. The pinned load captured-task FIXME and the other
resource/readiness/seek/MSE, physical playback and ownership boundaries below
remain unchanged.

## Native media play promise owner

Native JavaScript play returns a real Promise backed by the actual audio/video
DOM model's pending WebIDL capability. Parsed and created media inherit the
native operation; ordinary compact elements lose the fulfilled stub. Receiver
checks precede mutation replay, extra arguments are ignored, and binding errors
reject with the original reason. Waiting calls settle through the existing
captured playing/pause/load/ended batches. Resource selection and MediaSource
failure now reject with typed NotSupportedError, and ended uses AbortError;
batch rejection enters the current Document execution context.
Implementation and 17 new cases: `58fde80e`. All 24 selected files pass in both
GC modes, including the 66-case main regression. Signed production startup,
the ordinary native probe, two exact play viewports, 14 exact SVG pairs and all
11 configured screenshot smoke cases pass.

[Native play evidence](../docs/translation-audit/NATIVE_MEDIA_PLAY_PROMISE_OWNER.md)
retains the final three-file runtime baseline and unchanged verification
snapshots. Load's pinned FIXME for already-captured canceled-task batches remains
pending. Full resource/readiness/seek/MSE, enough-data autoplay, Permissions
Policy, physical decoding/manager, foreign engine realms and automatic
ownership remain open. Raw UTF16 MediaError storage remains a wider
representation boundary. Earlier sections retain their original
slice evidence; native play and the typed rejection sinks above are now connected.

## Unsupported media play rejection

Permitted V play rejects code SrcNotSupported with a fresh typed NotSupportedError
and its current MediaError message. Permission denial remains first; rejection
preserves prior pending requests and enters no fetch or internal play. Other
error codes retain the existing permitted path. Implementation and four new
cases: `aa9a5e27`. The focused three-file batch and all 15 selected files in each
GC mode pass, including main. Signed production startup, the ordinary probe,
two exact viewports and all 11 smoke cases pass.

[Unsupported play evidence](../docs/translation-audit/MEDIA_PLAY_SOURCE_ERROR_OWNER.md)
records the unchanged runtime baseline and exact message/identity checks.
Full resource/readiness/seek, physical manager/decoding and automatic ownership
remain open. MediaError's V string slot does not establish raw UTF16 parity.

## Volume-change playback policy owner

Volume/muted changes now queue volumechange, consult the actual owner's current
Document permission and run internal pause when denied before effective-volume
updates. Native setters reach this shared caller. Internal pause disables
can-autoplay without selecting an empty resource, commits state/manager pause
immediately and defers timeupdate/pause plus captured model promise rejection.
Page-wide mute changes retain their separate update-only path. Implementation
and six focused cases: `46701a87`; 21 selected files pass in each GC mode,
including the 66-case main regression. Signed production startup, an ordinary
production probe, two exact viewports and all 11 smoke cases pass.

[Volume-change policy evidence](../docs/translation-audit/MEDIA_VOLUME_POLICY_OWNER.md)
retains the corrected runtime baselines, fixture/compiler diagnostics and the
interrupted focused run. Enough-data autoplay, Permissions Policy, complete
resource/readiness/seek, physical decoding/manager and automatic ownership remain
open.

## Native getStartDate owner and timeline rounding

Native getStartDate returns fresh built-in Dates from the live audio/video DOM
model after replay. The copied video timestamp and generic compact method are
removed. The model rounds fractional milliseconds away from zero at the Source
UnixDateTime boundary, avoiding i64 overflow. Model/native commits: `7ea057ff` /
`5b86ed38`.

[Start date evidence](../docs/translation-audit/NATIVE_MEDIA_START_DATE_OWNER.md)
retains the initial fixture/compiler diagnostic, ten final runtime baseline
failures, both 2/2 focused batches and 23/23 affected files in each GC mode,
including the 66-case main regression. Signed production startup, an ordinary-
branch native DOM probe, two exact viewports, 13 exact SVG pairs and all 11 smoke
cases pass, with the final SVG launch-trap failure and bounded retry retained.
Source timestamps beyond the native Date range explicitly reject;
that engine boundary, foreign realms, physical manager/decoder, defaultMuted,
complete media/MSE and physical GC remain open.

## Native fastSeek owner and caller

Native fastSeek checks receiver, required arity and restricted-double conversion
before replay, then calls the actual DOM media model. The model clears the
poster before its HAVE_NOTHING return and selects approximate direction from
each live Source clock comparison before queuing seeking. Original exceptions,
default starts and adjusted clock commits survive. Model/native commits:
`a870b6b8` / `335564fd`.

[Fast seek evidence](../docs/translation-audit/NATIVE_MEDIA_FAST_SEEK_OWNER.md)
retains nine runtime baseline failures, 3/3 model and 4/4 native focused files,
20/20 affected files in each GC mode and the 66-case main regression. The signed
production bundle/startup, assertion-independent model probe, two exact public
viewports, 13 exact SVG pairs and all 11 smoke cases pass. Physical manager/clock/
decoder delivery, remaining seek/media/MSE algorithms, defaultMuted, complete
prototypes, realms and physical GC remain open.

## Native currentTime property owner

Native currentTime accessors use the actual HTML audio/video model, validate
the receiver before restricted-double conversion/replay and preserve original
exceptions. Reads use the real-loop generation cache; writes enter default
start or existing seek steps. The page's synthetic shadow is removed.
Implementation and seven focused cases: `16f4c31c`.

[Native time evidence](../docs/translation-audit/NATIVE_MEDIA_CURRENT_TIME_PROPERTY_OWNER.md)
retains fixture/stop diagnostics and the final runtime baseline, four focused
files, all 16 affected files across each GC mode and the 66-case main regression.
The initial no-GC compilation/disk failure and production linker I/O failure
remain recorded alongside the sequential retries.
Signed production startup, two exact public time viewports, 13 exact SVG pairs
and all 11 smoke cases pass. Physical manager/clock/decoder/pipeline delivery,
complete operations/media/MSE, realms and physical GC remain open.

## Media currentTime generation cache

The model getter prioritizes a nonzero default start and samples its existing
clock once per real main-thread generation. Seek, pause, metadata and load
commits stamp that generation; clock notifications preserve a same-turn sample.
Implementation and eight focused cases: `a160812b`.

[Generation/commit evidence](../docs/translation-audit/MEDIA_CURRENT_TIME_GENERATION_OWNER.md)
retains fixture diagnostics and the final eight-case runtime baseline,
six focused files, all 21 affected files in each GC mode and the 66-case main
regression. The signed production build, assertion-independent real-loop/DOM
probe, two exact adjacent volume viewports and all 11 smoke cases pass.
The later native time slice above exposes the property. Physical manager
clock/reset, other media algorithms, complete media/MSE, realms and physical GC
remain open.

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
Muted-style invalidation, actual playback-manager/pipeline
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
Source manager Ended state, other event scheduling, full operations, realms and
physical GC remain separate. These selected fixes do not establish full HTML
parity.

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

Local MessagePort transfer memory now preserves graph aliases and event-port
identity through the native JavaScript bridge (`0b34de6b2`). The owner keeps
scheduled deliveries queued until execution and moves them with a transferred
endpoint; a disabled in-transit endpoint keeps its peer live and supports moving
both channel ends. Receiving ports retain their actual native clone context,
including File/Blob exposure. The existing worker wire keeps buffer-transfer
behavior while active/nested worker-port transfers remain unsupported.
Sixteen HTML owner/messaging and eleven public integration checks pass in normal
GC and preallocated GC-none modes. Twenty-two original official Window/Worker
WPT variants pass 564/564 in both native Page modes; production verification is
tracked separately. Exact resizable-view metadata and full WebMessaging parity
remain open. See [WPT progress](../docs/WPT_CONFORMANCE_PROGRESS.md).

Production verification of that local-port change also passes all 564 assertions
in the same 22 original variants on a fresh matching executable, with harness
OK and strict exits 0; its build identity and evidence are in the linked report.
