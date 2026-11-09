# Document session ownership

`BrowserApp` is the shell for one tab. Its `DocumentSessionRef` points to the
current heap-allocated `DocumentSession`, and its `NavigationController` owns
history and pending navigation work that outlive individual documents.
The application sources still compile as `module main`; this is an ownership
boundary, not a new engine module or a public embedding API.

## Owners

| Owner | State and responsibility |
| --- | --- |
| `BrowserApp` | Window/context, chrome, tab/process coordination, the tab's `Page`, viewport, preferences, capture settings, frame reentrancy, renderer scratch and reusable response/texture caches |
| `NavigationController` | History entries/index, back/forward cache, scroll restoration, navigation result generations, pending fetch/preload/native navigation and per-install preload responses |
| `DocumentSession` | Document, realm, child-document host, image/script loaders, media players, document metadata, scroll/zoom, completion queue and resource-discovery state, adopted geometry and recording leases |
| `BackForwardCachedPage` | History-entry identity and one session pointer |

The pointer embed preserves existing field access while callers migrate to
narrower interfaces. It does not copy document fields into `BrowserApp`.
New document-owned fields belong in `DocumentSession`; cache insertion and
restoration never enumerate those fields. Replay scratch that borrows
`PaintCommand` payloads also belongs to the session.

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
eligibility retains its existing exclusions for live media and child documents.

Restoration publishes the incoming session pointer before `resume(navigable)`
reactivates the document and dispatches `pageshow`. The incoming VM is bound
before that dispatch. If an outgoing `pagehide` handler invalidates the cached
candidate, navigation restores the outgoing owner and falls back to the normal
stored-response reconstruction path.

`retire()` is the shared exit operation for uncached replacement, cache eviction
and tab closure. It marks the owner retired before invoking callbacks, cancels
its loaders, closes children and the realm, closes media, releases replay views,
destroys/finalizes the document and drops its native storage lease. Reentrant
or repeated retirement returns immediately. DOM owns layout-publisher
retirement; the session does not retain a raw layout handle across navigable
deactivation. An independently retained scene can continue to hold document
payload storage until its final consumer releases it. Whole-owner reset runs
in persistent storage, without allocating a replacement response queue.

Cache capacity and memory limits are enforced after the new document takes
over the navigable. This prevents memory pressure from retiring an outgoing
owner while activation still needs its browsing context.

## Resource completion ownership

Each session has its own background result channel. Suspended pages buffer
their completions for resumption; replacement pages cannot consume them or
apply their styles/images. The existing response cache remains shared by the
tab, with its existing reuse policy.

Background image and stylesheet workers count their outstanding replies on
the owning session. Retirement transfers that finite count and channel to a
drain that holds no document or shell reference. Late producers can finish
even if the channel was full when the page retired. This does not abort those
network transports or change their cache policy; transport cancellation and
cache unification remain separate resource-service work.

## History reconstruction

The navigation owner returns a typed `HistoryTraversal` containing the target
index and response used on a live-session cache miss. This preserves the
existing URL/markup/content-type reconstruction policy. Browser chrome does
not construct the fallback response. Traversal also invalidates queued
navigation fetches, including a request queued before the first window frame.

## Validation

`document/session_test.v` covers owner identity across back/forward navigation,
document-local completion queues, retirement of a full reply queue, lifecycle
callback ownership, reentrant retirement, cache eviction and retained storage.
`navigation/controller_test.v` covers history-response selection and pending
navigation invalidation. Existing back/forward and replacement-before-styles
tests preserve the prior event, realm and layout contracts.

The Linux workflow runs these focused cases with Boehm and with the staged
production `prealloc` runtime. Released arenas are poisoned in that gate.
After preparing Linux dependencies, run the same native test runner locally:

```sh
VOX_ARENA_POISON=1 python3 tools/run_memory_bounded.py \
  --lock Build/session-tests.lock --report Build/session-tests.json -- \
  python3 tools/test_linux_native.py --gc prealloc \
    document/session_test.v navigation/controller_test.v \
    navigation/back_forward_cache_test.v navigation/retire_before_styles_test.v
```
