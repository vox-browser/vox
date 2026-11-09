# Document session ownership

`BrowserApp` is the shell for one tab. Its `DocumentSessionRef` points to the
current heap-allocated `DocumentSession`, and its `NavigationController` owns
history and pending navigation work that outlive individual documents.
The application sources still compile as `module main`; this is an ownership
boundary, not a new engine module or a public embedding API.

## Owners

| Owner | State and responsibility |
| --- | --- |
| `BrowserApp` | Window/context, chrome, tab/process coordination, the tab's `Page`, viewport, preferences, capture settings, frame reentrancy, renderer scratch and reusable texture caches |
| `NavigationController` | History entries/index, back/forward cache, scroll restoration, navigation result generations, pending fetch/preload/native navigation and per-install preload responses |
| `DocumentSession` | Document, realm, child-document host, image/script loaders, media players, document metadata, scroll/zoom, completion queue, retained response map, request scope and resource-discovery state, adopted geometry and recording leases |
| `BrowserMediaOwner` | Document-bound playback players, media callbacks and repaint revision accounting; embedded in a session or owned directly by a hosted document |
| `BackForwardCachedPage` | History-response identity and one session pointer |

The pointer embed preserves existing field access while callers migrate to
narrower interfaces. It does not copy document fields into `BrowserApp`.
New document-owned fields belong in `DocumentSession`; cache insertion and
restoration never enumerate those fields. Replay scratch that borrows
`PaintCommand` payloads also belongs to the session. Hosted documents share the
narrow media service without constructing a `BrowserApp`; closing that service
leaves child-document and realm retirement to their existing owner.

## Lifecycle

`new_document_session()` creates an owner in persistent storage, even when
navigation starts inside an outgoing document's allocation scope.
`activate(document)` attaches the prepared document. Parser runtime and media
callbacks capture this owner, so a delayed callback cannot install a runtime or
player on whichever page the shell happens to display later.

`suspend()` records the navigable and page-showing state, dispatches the existing
HTML suspension lifecycle, clears an already-consumed script navigation, and
unbinds this session's LibJS VM. The document keeps its realm, loaders, queued
tasks and computed layout. The session releases its adopted replay views; a
later restore records the retained layout for the current viewport. Cache
eligibility excludes live media, child documents and pending background requests.

Restoration publishes the incoming session pointer before `resume(navigable)`
reactivates the document and dispatches `pageshow`. The incoming VM is bound
before that dispatch. Publishing or rolling back an owner also synchronizes the
tab-owned PageClient zoom, even when the session already holds that zoom.
If an outgoing `pagehide` handler invalidates the cached
candidate, navigation restores the outgoing owner and falls back to the normal
stored-response reconstruction path.

`retire()` is the shared exit operation for uncached replacement, cache eviction
and tab closure. It marks the owner retired before invoking callbacks, cancels
its loaders, retires media callbacks, closes children, the realm and native
players, releases replay views, destroys/finalizes the document and drops its
native storage lease. Reentrant or repeated retirement returns immediately. DOM owns layout-publisher
retirement; the session does not retain a raw layout handle across navigable
deactivation. An independently retained scene can continue to hold document
payload storage until its final consumer releases it. Whole-owner reset runs
in persistent storage, without allocating a replacement response queue.

Cache capacity and memory limits are enforced after the new document takes
over the navigable. This prevents memory pressure from retiring an outgoing
owner while activation still needs its browsing context.

## Resource completion ownership

Each session owns its background result channel, retained resource map and
request scope. Pending background requests block cache admission under the
current resource policy. Replacement pages cannot consume an outgoing page's
completions or apply its styles and images.

Retirement cancels and releases the session's request scope. Scoped producers
can suppress their completion and wake from a full result queue after
cancellation, so retirement must not wait for a fixed number of replies from
those producers. Their worker-held references keep the scope valid until work
finishes. Legacy unscoped producers still transfer their outstanding count and
channel to a finite drain that holds no document or shell reference.

Navigation fetch and preload scopes belong to the navigation owner and are
cancelled on traversal and tab closure. Resource cache decisions continue to
use the shared policy introduced by the resource-service integration.

## History reconstruction

The navigation owner returns a typed `HistoryTraversal` containing the target
index and response used on a live-session cache miss. This preserves the
existing stored-markup reconstruction policy and retains URL, content type,
response headers and status together. A cache miss therefore restores response
CSP and referrer policy before parsing the saved markup. Same-document fragment
entries preserve that metadata too. Cache identity includes the response
metadata and excludes scroll position; a changed policy cannot restore an old
live session. Browser chrome does not construct the fallback response.
Traversal also invalidates queued navigation fetches, including a request
queued before the first window frame.

## Validation

`document/session_test.v` covers owner identity across back/forward navigation,
document-local request cancellation, retirement of a full legacy reply queue, lifecycle
callback ownership, reentrant retirement, cache eviction, retained storage and
independent hosted-media cleanup. A macOS-specific case checks that closed
native media hooks cannot reopen a player.
`navigation/controller_test.v` covers history-response selection, response-policy
reconstruction and pending navigation invalidation. Existing back/forward,
repeated-eviction and replacement-before-styles tests preserve the prior event,
realm, arena and layout contracts.

The Linux workflow runs these focused cases with Boehm and with the staged
production `prealloc` runtime. Released arenas are poisoned in that gate.
After preparing Linux dependencies, run the same native test runner locally:

```sh
VOX_ARENA_POISON=1 python3 tools/run_memory_bounded.py \
  --lock Build/session-tests.lock --report Build/session-tests.json -- \
  python3 tools/test_linux_native.py --gc prealloc \
    document/session_test.v navigation/controller_test.v \
    navigation/back_forward_cache_test.v navigation/blob_url_cache_lifetime_test.v \
    navigation/retire_before_styles_test.v browserapp/browser_zoom_test.v
```
