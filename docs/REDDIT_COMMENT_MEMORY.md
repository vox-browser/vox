# Old Reddit comment-page memory

The requested limit is **500,000,000 bytes** for
`https://old.reddit.com/r/UkraineRussiaReport/comments/1xls5ou/ua_pov_ukraine_hits_10_of_russias_oil_refining/`.
The whole-page limit remains **unverified**. The implemented collection
serialization reduction has passed focused checks; no updated production
browser measurement is claimed.

## Reproduction

Both direct access and the configured SOCKS route returned HTTP 403. The
native cache contained the actual requested thread, so the investigation
sealed its original HTML and resources with `tools/page_archive.py capture
--from-cache`, then replayed them through the existing HTTPS archive server.
Account-bearing HTML, screenshots and request logs remain private under
`Build/reddit-comment-memory-20261102/`.

Fresh processes used normal scripted browsing, a private profile/cache and
`VOX_TEST_WINDOW=1`. External `PhysicalTree` sampling recorded simultaneous
browser and observed-descendant physical footprints every 50 ms. Capture and
the DOM audit followed the primary observation interval. The first run had
an empty profile; the longer exploratory run copied history, bookmarks and
zoom into its private profile. Neither changed the user's saved files.

The executable was SHA-256
`f769e44dbef6c5c309654f532cadf36bc7d5288a4b99c9f4a03f40845649be49`.
Executable, native-library and filter-snapshot identities remained unchanged.
The browser and guard exited zero in both baseline observations.

| Baseline observation | Endpoint viewport | Observed peak | Final two-second median |
| --- | --- | ---: | ---: |
| Approximately 55 seconds | 1024 × 768 | 921,455,280 B | 409,454,488 B |
| Approximately 300 seconds | 1708 × 941 | 937,708,280 B | 522,913,760 B |

These different viewport/profile conditions are exploratory observations,
not a matched optimization comparison. Both endpoint audits retain the exact
URL/title, a complete, visible, fully active document, 49 comment containers
and two images. One existing compact-JavaScript diagnostic remains. The longer
trace grows by roughly 9 MB every 20 seconds after settling. An independent
mapping trace identifies repeated layout work during Reddit's timestamp refresh
and large temporary DOM collection serialization graphs. The source reduction
below does not establish that repeated layout allocation is bounded.

Physical footprint measures macOS charged process memory. It is distinct from
RSS and from the guard's aggregate RSS safety reading. Sampling can miss short
spikes and short-lived children; external system services are excluded. An
existing user's browser process was inspected read-only and showed a 2.2 GiB
historical peak, but it is not a controlled trial of this URL.

## Implemented reduction

Commit `27cc9c860` streams native collection replies one element at a time.
Temporary attribute maps, metadata objects and JSON encoder work retire after
their bytes enter the reply. Bridge-key maps, materialization flags, lazy
input/textarea/video models and the final reply keep their owning lifetime.
Tag collections, class collections, selector lists and full-state collection
snapshots share this implementation. General adapters preserve their ordinary
allocation behavior.

The 256-element control executes the previous array-of-maps implementation.
Both implementations produce byte-identical JSON:

| Retained allocation | Bytes |
| --- | ---: |
| Previous collection serialization | 6,058,179 |
| Streamed collection serialization | 740,934 |

This is an **87.77% reduction in the focused serialization allocation**, not
a percentage reduction in whole-browser RAM. All three focused cases pass in
prealloc, arena-poisoned prealloc and default Boehm modes. They cover exact JSON,
stable wrapper identities, live membership after mutations, class/selector
collection replies, control-model lifetimes and SVG namespaces. Explicit runtime
checks use separate 3 GiB guards. Early compiler setup and poisoned-lifetime
failures remain in the raw directory; the final runs select the staged runtime
and pass with actual test and guard exits zero.

## Remaining validation

The shared production build was already running and repeatedly superseded by
concurrent source changes. The post-commit request includes this fix; no second
production build was queued. `Build/v/Vox.app` still contains the baseline code
at the time of this report, so it cannot validate the new serialization path.

Once a completed canonical bundle includes the fix, repeat matching fresh-process
trials at the same viewport/profile conditions, including startup and at least
five minutes of idle timestamp updates. Record both peak and settled footprint;
do not turn the earlier 409 MB short-run observation into acceptance of this
change. Longer idle and interactive checks, updated native screenshot checks
and successful live-URL validation remain open. The 500 MB target stays open
until those measurements establish it.

The [durable receipt](benchmark-results/reddit-comment-memory-2026-11-02.json)
pins raw samples, audit/capture hashes, runtime identities, focused guards,
source hashes, exact byte values and pending work. `probe.py`, `compile.py`,
commands, logs, invalid diagnostic attempts and actual exits remain in the
private raw directory above.
