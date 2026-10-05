# WebGL2 maximum client wait timeout

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/WebGL/WebGLRenderingContextImpl.cpp:1708–1711`.
Within the WebGL2-only switch, Source returns numeric zero for
`MAX_CLIENT_WAIT_TIMEOUT_WEBGL` without a compositor query. The page cannot
wait on the compositor, and the host clamps clientWaitSync's timeout to zero.

The V constant existed, but getParameter fell through to INVALID_ENUM/null.
The genuine typed EGL regression reproduced that incorrect WebGL2 return
after the separately reviewed driver-selection correction. Original log:
`Build/audit-fixes/continuation-max-client-wait-original-gc-none.log`, SHA256
`0f1beab4c5ff2f683f09a309d3a591d436decac34307d98dab9b95ad1d6dec4f`.
This is an executed assertion failure, not a compilation failure.

Commit `477ea688` adds the Source zero-return branch and its typed/public tests.
WebGL1 preserves INVALID_ENUM/null. The typed regression keeps the other
driver's actual viewport and native error intact. The public regression checks
numeric zero, generated single pname conversion and abrupt Symbol conversion.

Command: `VJOBS=2 v -old-compiler -enable-globals -gc none test
webgl/max_client_wait_timeout_source_test.v
browserjs/canvas_webgl_max_client_wait_timeout_source_test.v`.
Result: 2/2 files pass in 109.419 seconds. Log:
`Build/audit-fixes/continuation-max-client-wait-canonical-gc-none.log`, SHA256
`a246da3f7cabf6e5f1800d228081579a343a3751fd8fca381d7cec4d17e2eb18`.

This completes the single constant-return branch. Source proxy string caching,
remaining parameter families, transport and realm/wrapper GC remain separate.
