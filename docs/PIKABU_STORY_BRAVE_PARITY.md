# Pikabu story rendering against Brave

Target: https://pikabu.ru/story/otvet_na_post_novyie_blokirovki_youtube_ot_mts_vpn_zapret_14457095

The requested whole-page pixel parity is **not complete**. Comparisons below use
1024 × 768 document pixels at scale 1, excluding browser chrome. The retained
Brave DOM archive bundles assets to separate rendering errors from changing
votes, timestamps, advertisements, and network responses.

## Retained rendering checkpoint

The signed native build at `fc9239f4` has SHA-256
`3d88f22ce3ce5d389978c445850cb06956fcc330ce624dfe1ac59835b1c5d314`.
`Build/pikabu-story-updated.metadata.json` records startup and capture exits.
The guarded production run is `Build/pikabu-story-postmessage-core-job.json`.

- Shadow fixture: 0 differing pixels out of 786,432.
- Bundled story: 24,750 differing pixels (3.1471%), down from 30,595.
  268 pixels exceed three channel levels; maximum channel error is 51.
  Mean absolute error is approximately 0.0224 and RMSE approximately 0.3005.
- The title region and visible photograph are pixel-exact.
- Header, title, badge, text, and photograph rectangles match Brave. The story
  header begins at (101, 281); its content begins at (101, 428), and the image
  begins at (101, 679).
- Remaining retained differences include shadow/compositing rounding, the logo,
  and the cookie notice. No comparison tolerance was changed.

Images and audit files are `Build/pikabu-story-updated-{shadow,bundled,title,live}`;
reference images are `Build/pikabu-story-shadow-brave.png` and
`Build/pikabu-story-brave-bundled.png`. Pixel reports and amplified differences
are retained beside the captures.

## Live startup

The same live capture still reports missing IndexedDB, PerformanceObserver, and
WebSocket interfaces, plus a separate randomized script reference error.
The advertisement reservation and cookie notice do not initialize, moving the
story 200 pixels above the retained Brave layout. The archived page has no
JavaScript diagnostics; it cannot establish successful live initialization.

The IndexedDB binding at `106cb5bb` connects JavaScriptCore to the owning
Window's existing typed factory and database-access task source. It supplies
open/upgrade/delete coordination, real request and transaction event delivery,
store creation, transactions, and asynchronous get/put/add operations. Values
are cloned at call time and request errors can roll back transactions.

This is a bounded browser API slice, not full IndexedDB parity. The existing
catalog remains in memory. The binding does not expose cursor/index operations,
complete request event bubbling, quota, disk persistence, or arbitrary structured
clone graphs. Its current value adapter accepts finite trees of plain objects,
dense arrays, primitive values, dates, and ArrayBuffers; unsupported records fail
with DataCloneError rather than being stored as JSON.

Six new asynchronous core cases and ten existing store/transaction/factory cases
passed with normal GC. Five browser binding cases passed with normal GC and
with the production arena allocator (`-prealloc -gc none`). The guarded report
is `Build/pikabu-story-idb-core-job.json`; its sampled process-tree peak was
3,194,159,104 bytes and child exit was zero. A fresh production capture is pending.

The PerformanceObserver binding at `7d9d986a` connects each observer to its
owning Window's native performance timeline. It supports observation by type
or entry-type list, buffered entries, queued callback delivery, disconnect,
takeRecords, and sorted entry-list queries. Resource observers continue to
receive new entries when the primary resource timing buffer is full. The
callback runs through the owning document's task and script settings.

Five timeline, three entry-list, two native-global, four existing-global, and
four resource-timing cases passed. Three JavaScriptCore binding cases passed
with normal GC and again with `-prealloc -gc none`. Individual exit codes and
log paths are in `Build/pikabu-story-observer-stages.json`; the retained first
binding attempt failed before the successful retry. The later root paint-test
compile hit a mixed-vlib HTTP error; `3dd2d1cf` makes the chrome harness stage
the same compiler-compatible HTTP modules as production builds.

The observer exposes the base PerformanceEntry attributes. ResourceTiming's
additional attributes and a JavaScript performance global remain separate
work. These passing binding tests do not establish successful live Pikabu
startup; fresh production captures of the live URL and retained archive are
still queued under the shared build guard.
