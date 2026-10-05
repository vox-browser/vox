# getParameter retained state and native query ownership

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/WebGL/WebGLRenderingContextImpl.cpp:929–1718` and
`WebGLContextProxyBase.h:44`, `WebGLContextProxyBase.cpp:168–176`.

The Source method begins with the proxy's empty `make_current()` method.
Retained bindings, browser pixel-store state, compressed formats and invalid
parameter branches return without a synchronous compositor query. Actual
numeric queries cross `send_sync_call`. The V adaptation previously selected
its native EGL driver before every branch, including those CPU-only returns.

Commit `c97ca4fb` removes that unconditional selection. Existing numeric/array
query branches still select their actual driver, and the direct sampler query
now selects it explicitly at its call site. Retained Source records and public
wrapper identity remain intact, including a deleted retained buffer and a
program whose native use was rejected.

The canonical GC-none check passes all four files: typed and public parameter
owner tests, the aggregate query-owner regression, and first-exposure current
program wrapper identity. It covers both WebGL versions, actual EGL viewport
selection, a genuine other-driver error, early extension/name failures,
public arity/coercion failures, retained bindings, and real numeric/sampler
queries. The updated aggregate expectations follow the reviewed CPU branches.

Command: `VJOBS=2 v -old-compiler -enable-globals -gc none test
webgl/native_parameter_owner_source_test.v
webgl/native_query_owner_selection_test.v
browserjs/canvas_webgl_parameter_owner_source_test.v
browserjs/canvas_webgl_current_program_record_test.v`.

Log: `Build/audit-fixes/continuation-webgl-parameter-owner-canonical-gc-none.log`.
Result: 4/4 files, 135.259 seconds. SHA256:
`a4bcf104ff94500ac10dfe5d7719d940914dffd24c20d25d9ab524da363b5955`.

This bounded review does not establish the Source proxy string-cache behavior,
every getParameter result or complete transport/realm/wrapper GC parity.
Earlier frozen package and native results do not cover this later commit.
