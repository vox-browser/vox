# Native getParameter Source string cache

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Source `WebGLContextProxyBase.cpp:393–408` checks its per-GL-enum owned string
cache before `send_sync_call` or loss handling. An uncached lost query returns
the empty string without installing a cache entry. Successful replies are
copied into the cache. `set_lost()` leaves that cache intact
(`WebGLContextProxyBase.h:39`), while `restore()` clears it
(`WebGLContextProxyBase.cpp:31–39`). The host encodes a null driver string as
one NUL byte rather than a transport failure (`HostWebGLContext.cpp:282–292`).

The standalone V proxy already implemented this cache. The actual native
getParameter path bypassed it: every standard string query selected its
driver and read GL directly, and the vendor/renderer helpers did the same.
After loss, make_current returned without switching away from another live
context, allowing an uncached query to read that other driver's real string.

Commit `b1b05829655f5d65f5289333e2a168137f8fd4b2` translates the same cache
lookup/loss/query/copy/store order into the existing direct-driver adapter.
Standard string queries and the unmasked debug aliases share entries keyed
by the underlying GL enum. Numeric/array queries retain their driver path.
The adapter retains cache entries on loss and clears them on restore. The
existing native C-string copy supplies owned V strings; no fabricated driver
metadata or new remote transport is introduced.

## Executed failures and passing checks

Before implementation, the first two new typed tests executed against
`2ec712c0`: a warm query selected Owner's `[1,2,3,4]` viewport instead of
leaving Other's `[9,10,11,12]` viewport current, and a cold lost query returned
a nonempty string instead of empty. Both are executed assertion failures.
The subsequent third typed case checks a genuine null/empty driver reply.

| Canonical run | Result | Seconds | Log SHA256 |
| --- | --- | ---: | --- |
| Original typed cache/loss regression, GC-none | 1 failing file, two assertion failures | 6.891 | `a9c527b47fdc101c2bf4e195d5e530181aee3c8699ad8ce63ef73a42eb388d7d` |
| Corrected typed/public plus four neighbors, GC-none | 6/6 files PASS | 90.115 | `ced56abc7b3525f8af2e3f77488e54f124ac379e3cb26b2977c2f042fa144043` |
| Corrected typed/public plus six neighbors, default GC | 8/8 files PASS | 129.481 | `0d00ce993bc77bc28841a127e4978f7c0aa5b2470041b356eb244a19a7bb64ef` |

Commands use `v -old-compiler -enable-globals test`, adding `-gc none` for
the GC-none rows. VJOBS is 1 for the original failure and 2 for final checks.
The new files are `webgl/native_parameter_string_cache_source_test.v` and
`browserjs/canvas_webgl_parameter_string_cache_source_test.v`. Both WebGL
versions exercise real EGL driver values and viewport selection, pending
native errors, shared standard/debug aliases, cold/lost output shapes and
restore-driven cache invalidation. The public test also verifies single
pname conversion and preservation of the original abrupt conversion value.
The empty driver-reply case verifies a cached empty value without a repeated
GL query. Existing proxy sync, context loss, debug-renderer and native query
tests pass in both modes; the earlier typed/public parameter-owner regressions
add default-GC coverage.

Logs are `Build/audit-fixes/source-parameter-string-cache-{original-gc-none,
canonical-gc-none,canonical-default}.log`. Exact argv, feature-file hashes,
Source pin and scope are in
`Build/audit-fixes/source-parameter-string-cache-manifest.json`, SHA256
`ed83f8beb6fe9ad6d955ad1260cd1855973b5edca07017d8f57dc43e4b27e1a1`.

These are focused checks after the [frozen 6f1df913 bundle/package proof](FROZEN_6F1DF913_CONTINUATION.md).
No new full WebGL sweep, production browser build or screenshot result is
claimed for this later feature. The direct EGL adaptation, native C-string
conversion, physical allocation/ownership, remote command/transport and
PrimitiveString/WrapperWorld/GC graph remain separate boundaries. Genuine
Blob-store settings and partition ownership are the next independent slice.
The audit ledger stays **32 fixed, 25 partial, 9 open**.
