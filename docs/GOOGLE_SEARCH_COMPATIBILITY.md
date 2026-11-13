# Google Search compatibility — 2026-11-12

The fixed browser returned the UTC clock card and search results in three
consecutive fresh-profile runs of `google.com` → type `utc time` → Enter.
Input went through native mouse/key events, with the default JavaScriptCore
backend, unchanged browser identity, empty profiles, and proxy overrides removed.
Each process exited cleanly after its native screenshot. The longer run kept the
results page open until a 55-second capture timer, completing after 61.8 seconds.

Fresh private Brave also returned results on this network with
`navigator.webdriver=false`. The earlier blanket network explanation was wrong.

## Changes

- `64ac33a2a`, `d0545216f`, `fd73e6172`: Navigator accessors and platform function
  source formatting use native callbacks. Native WebIDL exceptions use captured
  engine constructors, preserving their classes and identity without JavaScript
  factory frames. Invalid function-source receivers throw at one native boundary.
  Accessor names retain `get userAgent`, while JSC native source and stack frames
  use `userAgent`. Source snapshots ignore later author changes to function names;
  author function source remains intact. `navigator.languages` reuses its frozen
  array until the language preferences change.
- `02fd51fd6`: the initial iframe realm exists on the first `contentWindow` read.
  Previously that read returned a placeholder: reading `Function` created the
  realm, subsequent `contentWindow` and `document.defaultView` reads returned a
  different object, and `eval` was a wrapped function. The focused identity and
  native-function checks now pass.
- `5ca8ef30b`: runtime and binding records survive the temporary frame arena in
  which an iframe initializes. The regression fails before the fix and passes
  after releasing that arena and calling the retained native bindings.
- `6f3c529cf`, `7b1c5eff9`: registered Range identities survive their creation
  arena. Registry entries pointing into borrowed/inert document payloads retire
  with the final storage lease. Shared adoption keeps valid ranges receiving
  mutations until the destination retires. These fixes address storage crashes
  exposed while loading and closing real result pages.
- `a1ead31ea`: a missing object-literal brace in the PerformanceObserver bootstrap
  prevented page-script initialization after the upstream port. Its source failed
  syntax validation before the repair; the rendered startup regression is now
  pixel exact.
- `138b82146` anchors native headers to their source directories.
  `f4591cd1c` updates wheel diagnostics for the ported precise-wheel legacy units
  (42 pixels yields −126 legacy units). The signed-browser smoke path passes.

The earlier same-agent source fix `9d074571b` alone did not resolve search.
Google's server decision is opaque: these changes correct observed API and
lifetime defects, and the live runs validate the combined browsing workflow.

## Validation

The three acceptance runs used a pinned C build with production preallocation
(`-prealloc -gc none`, JSC, `vox_production`, C optimization `-O0`), launched as a
fresh native process each time. This is functional verification, not a production
performance comparison. Executable SHA-256:
`773ccd5eadd15833b2c59ad9232c343c09acbeccc626eb4830fc088508ee7b11`.

| Fresh profile | Result headings | Browser exit | Elapsed |
| --- | ---: | ---: | ---: |
| 1 | 8 | 0 | 25.3 s |
| 2 | 8 | 0 | 22.6 s |
| 3 | 10 | 0 | 61.8 s |

The screenshots show the UTC clock card. All three stayed at `/search`, and their
executable identities remained unchanged. No cookies or proof values were copied
from another browser. Earlier failing, challenged, and crashing attempts remain
in the local evidence; they are not included as successful final runs.

Focused function-source, native Navigator/exception, range-lifetime,
initial-frame, and runtime-arena checks pass. The native startup smoke passes.
SVG image-source switching, paint-server ID collisions, gradient-stop reordering,
and the PerformanceObserver startup reftest have zero differing pixels.

The broader wheel-routing suite still reports four fractional-scroll assertions:
3.75 is expected where 4 is observed, including combined element/viewport scroll
checks. Its native legacy-delta assertions now match the ported units. These
remaining scroll assertions are outside the Google Search fix; no scrolling
performance or broad-suite acceptance claim is made.

The managed shared production bundle was subsequently verified as well. Its
receipt is `20261112-132807-5c76223f`, C backend with literal V `-prod` in one C
unit. Executable SHA-256:
`7f74bcb7355130ccc4d2cc51e8f02e2e8baf2a902d32f16a2159d0fdc7a77069`.
A fresh native process repeated the homepage typing flow, returned 11 result
headings, reached `complete` readiness, rendered the UTC card, and exited 0 after
24.0 seconds. Its executable identity stayed unchanged. The receipt's parsed
source hashes match the bridge and lifetime fixes; the sealed generated C also
contains the runtime binding allocation scope and corrected smoke assertions.
The receipt precedes later comments and unrelated edits in `main.v`.

All fixes are committed on canonical `master`; their post-commit hooks request
the coalesced production build. The successfully validated bundle is already at
`Build/v/Vox.app`.

Sanitized local evidence is under
`docs/benchmark-results/google-search-resolved-20261112/`. It retains outcomes,
build/source identities, failure summaries, focused checks, and selected native
screenshots. Private profiles, cookies, check programs, temporary executables,
and probe sources are removed after validation.
