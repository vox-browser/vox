# Native search rendering lifetime and HTTP/2 admission

2026-10-18. This follows [navigation overhead](SEARCH_NAVIGATION_OVERHEAD.md).
The search-task batch after `17328490` now contains eight behavioral fixes:
the six previously recorded fixes, rendering-data release (7), and HTTP/2 I/O
admission (8). DOM-count profiling is tooling and does not increment that count.
No instruction-count reduction or broad-suite reset is claimed.

## Completed changes

`87ca86bc` releases the inactive document's opaque layout backend, viewport
scroll hook and cached display list. Clearing only the DOM's layout pointers
left those other owners holding the old renderer. After closing that document's
native script runtime, the browser clears resolved element and pseudo-element
styles, including closed shadow descendants, and per-document style-computation
scratch. The native history path reconstructs a document from saved markup.
The helper refuses a fully active document. A temporary computed-style getter
closure is also replaced by direct property reads.

Five focused cases, comprising the two timer cases, lifecycle case, and two
style-release cases, pass in both default-GC and no-GC builds. The collection
case watches both the DOM computed-style wrapper and its actual CSS backing
store through weak references from a worker thread. Both are collected after
replacement. These checks do not establish collection of the entire old
Document: the earlier incomplete registry-retirement investigation remains
uncredited. An independent flex-closure probe also passed on the unchanged
control; its proposed refactor was removed, with no behavioral credit.

`46149aae` adds `VOX_PROFILE_CLASS`. Immediately before reporting the first
document frame, it counts actual live DOM elements and elements with that class,
and prints the document URL's SHA-256. It emits neither the URL nor page text,
does not mutate the page, and is inactive without the environment variable.
Its focused case checks live class mutations, case sensitivity, and URL hashing.
This replaced an unreliable attempt to infer result counts from raw HTML.

`f8778e93` stages a narrowly patched V HTTP/2 pooled transport through the
existing HTTP compatibility overlay. An idle TLS reader used to reacquire the
I/O mutex while request writers waited. An admission mutex now lets a writer
queue before waiting for the current read to finish. All TLS operations remain
serialized; buffered data, timeouts, close handling and write-stall budgets are
unchanged. The V installation itself is untouched, and source-layout assertions
reject an unsupported upstream transport.

The deterministic admission test and three existing real HTTP/2/TLS cases pass
in both GC modes. The integration cases retain concurrent multiplexing, binary
and compressed response bytes, repeated headers, HTTP/1 fallback, redirects,
and certificate/hostname isolation. The checker compiles and explicitly executes
the test binaries; an earlier shell-pipe test-selection failure remains retained
without pass credit. This change removes observed writer starvation, but the
live fresh-search series below does not establish an overall latency win from
this individual fix.

## Live comparison

Both browsers use already-open native windows, direct networking, the same
temporary authenticated cookie jar, a 1024×768 viewport, JavaScript, ordinary
resource caches, and 25 actual search-result elements. Raster snapshot reuse is
disabled. One initial navigation is excluded; five subsequent pairs alternate
browser order, with two seconds between actions and an intervening blank page.
Native time runs from ordinary address submission through the first submitted
document frame. Brave time runs from CDP navigation through visible result
geometry, DOMContentLoaded, two animation frames, and an observed paint entry.
Native command delivery adds up to 50 ms. These are useful user-visible
endpoints, not identical internal engine milestones.

For uncached comparisons the native main-response cache is cleared between
samples, while resource caches remain. Its response-file timestamp must follow
submission. Brave must report HTTP 200 and a transferred main response. Neither
browser receives a changed query to manufacture a cache miss.

| Signed executable / workload | Vox median | Brave median | Vox pair wins |
| --- | ---: | ---: | ---: |
| Isolated final, ordinary warm cache | 409 ms | 712 ms | 5/5 |
| Isolated final, uncached main response | 1,356 ms | 654 ms | 0/5 |
| Canonical production, ordinary warm cache | 505 ms | 684 ms | 5/5 |
| Canonical production, uncached main response | 1,185 ms | 679 ms | 0/5 |

Warm searches beat Brave in these samples. Fresh-search parity remains open.
The canonical executable includes independently changing rendering work and
does not isolate the effects of this task's changes. The HTTP/2 patch should
not be credited with the cumulative improvement from the earlier fixes.

The before/after saved-search captures have exactly equal decoded pixels at
1024×768. The live `svg-image-source-switch-same-size` comparison is pixel-exact.
Both isolated and canonical production bundles pass signing and headless
startup checks. Broad packages and screenshot batches remain deferred under
the ten-fix cadence; the earlier mandatory full LibJS checks are recorded in
the preceding audit.

## Retained receipts

Private, ignored `Build/search-speed/` holds `style-shadow{,-none}.{log,status}`,
`content-profile-test.{log,status}`, `h2-fairness-corrected.{log,status}`,
`h2-verification{,-runner}.status`, `h2-progress.json`, `h2-binaries.json`, the
three `h2-*-comparison.json` series, `production-fresh-current-comparison.json`,
`final-style-pixels.json`, and `final-style-svg-guard.log`. Failed predecessor
runs and discarded investigation patches are retained separately. URLs,
queries, cookies and page bodies are excluded from this audit and Git.
