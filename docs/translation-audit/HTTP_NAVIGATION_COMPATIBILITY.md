# HTTP error documents and browser request identity

Stack Overflow's redirect from `/` to `/questions` returned an HTTP 403
Cloudflare challenge during investigation on 2026-10-15. The response included
`cf-mitigated: challenge` and an HTML document titled `Just a moment...`.
Sending Chrome's user-agent and retaining cookies across the redirect with curl
still returned that challenge; a user-agent change alone did not establish site
compatibility. Chrome's existing profile/session was not inspected or reused.

`01c52643` preserves nonempty HTTP error documents in the native browser's
navigation path. Their markup reaches normal document parsing and scripting,
and the final redirect URL remains the document URL. Text error responses use
the existing escaped text representation. Empty error responses retain the
browser error page. HTTP error responses cannot replace a successful page in
the browser's disk cache. Subresource status checks remain independent.

`475d9ecc` replaces the compact HTTP adapter's `Ladybird V/0.1` user-agent with
the translated loader's browser identity. Before loader initialization, requests
use its default identity. Afterwards they use the configured identity and site
compatibility rules also used by `navigator.userAgent`, recalculated for every
redirect target. The native RequestServer/Fetch adapter is outside this change.

The new navigation tests and user-agent tests failed against the original
implementation and pass after the fixes. Eight focused cases across three test
files pass with:

```sh
v -old-compiler -enable-globals test main_http_navigation_test.v
v -old-compiler -enable-globals test browsernet/user_agent_test.v browsernet/http_test.v
```

The cases cover 403/404/429/503 HTML, plain-text and empty errors, redirects,
cache preservation and recovery, observed request user-agents, site-specific
redirect identity, and existing blocker enforcement.

`sh build-prod-browser.sh` rebuilt and ad-hoc signed `Build/v/Vox.app`.
Its `--headless-smoke` check passes. A local HTTP server redirects the signed
browser to an HTTP 403 document whose inline script updates its heading using
the final `location.pathname`; `--headless=layout-tree` confirms the resulting
text and the server observes the expected browser user-agent on both hops.
Logs are retained under `Build/http-navigation-validation/`.

A direct `browsernet.get()` probe still receives the live Stack Overflow
challenge with HTTP 403. The rebuilt browser capture
`Build/http-stackoverflow-window.png` confirms the final `/questions` address
and HTTP 403 status, but the document stays blank and the console reports
`ReferenceError: Can't find variable: btoa`. This is not a successful site load
or a completed Cloudflare solve. Additional browser API, challenge script,
and cookie/session integration work remains. Cloudflare documents
[limited support for custom browser engines](https://developers.cloudflare.com/cloudflare-challenges/reference/supported-browsers/).

These are two additional browser fixes beyond the recorded native-media batch;
this focused validation does not reset the broad-verification cadence or claim
complete Cloudflare, cookie, dynamic-script, or browser compatibility.
