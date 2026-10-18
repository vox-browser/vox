# Parallel resource-cache header decoding

2026-10-18. Implementation: `8d0bd2c5`. One completed fix toward the repository's
ten-fix regression cadence; no instruction savings or broad-suite credit claimed.

A search-load measurement panicked in the first concurrent cache reads, before
the document painted. All 2,977 header metadata files in the frozen cache were
valid JSON. The compatibility compiler's `x.json2` decoder publishes its static
struct-field array before populating it; another worker can index that empty
array. The original panic and failed measurement remain in
`Build/search-speed/pair-1.after.log`.

Cache header reads now use V's generated JSON decoder, which has no shared lazy
field initialization. The on-disk schema, header order, duplicate headers,
escaping, request filtering, and handling of corrupt entries are preserved.

Two focused cases pass with default GC and `-gc none`: 32 workers simultaneously
perform 64 decodes each and verify every header, and malformed/empty metadata
exercise the cache-miss boundary. They ran alongside the native search, image,
and form regressions in the frozen focused driver; both complete runs exited
zero. Receipts are `Build/search-speed/focused-final.{log,status}` and
`focused-none.{log,status}`. This report does not count the earlier failing
image-fixture runs as successful full runs.
