# Source read-loop and Blob owner prerequisites

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`
Reviewed: 2026-10-04
Assignment 7 private workspace: `Build/audit-fixes/worktrees/07-fetch-xhr`

`ReadableStreamDefaultReader.cpp:48-106,202-233` maps to
`streams/read_loop_request.v`. Its retained ReadLoopReadRequest owns the realm,
reader, accumulated bytes and success/failure callbacks. Each valid Uint8Array
chunk appends its witness byte span, then recurses through the same actual
request. Close moves the accumulated bytes to success; errors preserve their
original value. No default-reader Promise is allocated for each aggregation
chunk. The deprecated Blob-facing wrapper allocates one relevant-realm WebIDL
Promise, resolves an ArrayBuffer on success and rejects the original failure.

`ReadableStreamOperations.cpp:1202-1241` maps to the actual request entry point.
The source FIFO can now retain both default Promise-backed read requests and
the aggregation request. Public default reads and both controller pull paths
deliver chunk/close/error steps through that interface. A release-lock
TypeError is shared across pending requests, rather than being replaced by
separate strings. This slice is commit `4777144e` with its focused tests.

`ReadableStream.cpp:439-487` maps to `streams/byte_reading_support.v`. Full
byte-reading setup installs the relevant realm, initializes the source stream,
allocates its byte controller and performs the actual start/pull/cancel setup.
Start completion belongs to the realm's microtask queue. Optional pull/cancel
algorithms forward their pending Promises and original error values; absent
algorithms resolve undefined. Source `MUST` failures remain fatal V panic
boundaries. This slice is commit `5b6f84b1` with its focused tests.

Private verification logs under this assignment's `Build/audit-fixes/`:

- `source-read-loop-default.log`: **3/3 PASS** (aggregation, default read
  Promise ownership, native byte enqueue).
- `source-read-loop-gc-none.log`: **10/10 PASS**, adding default/byte readers,
  pending pipe/tee, tee reasons, source entry points and actual native
  ReadableStream host ownership.
- `source-byte-reading-default-final.log`: final setup test **PASS** after
  the preceding default run passed its read-loop neighbor.
- `source-byte-reading-gc-none.log`: **3/3 PASS** (setup, retained read loop,
  byte-reader neighbor).

Native Uint8Array slot/witness projection is a separate pending prerequisite;
unprojected opaque engine values are not accepted as typed Uint8Arrays. Blob's
actual FileReading task, TemporaryExecutionContext and relevant-realm
Promise/stream path still need translation. The synchronous standalone Blob
accessors and compact XHR facade do not establish those owner semantics.
Complete native Blob/File/FileList bindings and source host-object GC remain
open.
