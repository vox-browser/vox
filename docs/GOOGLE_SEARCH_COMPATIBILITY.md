# Google Search compatibility — 2026-11-12

The `google.com` → type `utc time` → Enter failure remains open. A fresh
private Brave window returns results on this machine. Do not attribute Vox's
challenge to the shared network based on the earlier automated comparison.

## Verified controls

- A native Brave incognito window returned 11 results. An isolated, fresh
  private CDP context also returned results with `navigator.webdriver=false`.
  Chromium's `--remote-debugging-port=0` enabled `webdriver` in the earlier
  failing control; that control did not represent the user's private window.
- Vox and Brave used the same observed public IP. Brave also returned results
  with Vox's User-Agent, platform string, and individual missing-plugin or
  missing-outer-dimension controls.
- For an identical fresh check page, submitting the browsers' resulting
  cookies through the same HTTP client returned a redirect to the challenge
  for Vox and search-result HTML for Brave. These are short-lived, isolated
  diagnostic sessions, not an acceptance test or a proposed cookie workaround.
- A fresh nonpersistent native WebKit view, using a Safari User-Agent, returned
  seven result headings and exited successfully. Changing Vox's identity alone
  in the completed controls did not resolve the failure.

## Completed fix

Commit `9d074571b` preserves platform-function source identity across same-agent
realms. A child realm's borrowed `Function.prototype.toString` now recognizes
platform functions installed in its parent, while preserving author source.
The registry uses weak keys in a DOM-free agent realm.

The two focused tests and native smoke check passed. SVG image-source switching,
paint-server ID collisions, and gradient-stop reordering remained pixel exact
using the existing pixel-diff executable. This fix **does not establish that
Google Search works**.

## Limits and remaining work

The check produces a result and Vox follows its redirect, but Google still
rejects the result. UA, clock, readiness and bridge-source controls have not
isolated a sufficient fix. An eager initial-iframe realm candidate was reverted;
its focused identity tests passed, but the child-document suite timed out and
Google still rejected its result.

A minimal JavaScriptCore harness initially appeared accepted after Brave had
used the same diagnostic session. A fresh first-use control was rejected;
the earlier observation cannot establish that the harness passes the check.
Modified/instrumented check programs likewise cannot establish live correctness.

The experimental V8 diagnostic exposed a separate cross-context security-token
restriction. Its temporary library changes were reverted; they are not a
production fix. The final pure Safari identity diagnostic failed to compile
because concurrent native rounded-image declarations disagreed about source
pointer constness. Those rendering changes were left untouched.

Local, ignored evidence is under
`docs/benchmark-results/google-private-window-20261112/`. It retains sanitized
summaries, selected screenshots, guard outcomes and compilation errors. Private
profiles, cookies, check programs, temporary executables and probe sources were
removed. No live-search acceptance claim is made.
