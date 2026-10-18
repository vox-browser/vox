# CNN rendering and instruction comparison

The CNN target remains open. The accepted result requires seven fresh-process
pairs with **zero differing RGBA pixels** and `max(Vox) <= 0.85 * min(Brave)`.
The preliminary instruction counts do not meet that target and receive no
performance credit while their images differ.

The private workload was captured from `https://edition.cnn.com/`, reached by
CNN's redirect, on October 17, 2026. It retains the live DOM, removes executable
script elements, and keeps normal scripting policy for `noscript` parsing and
uBlock scriptlets. Both engines receive the original encoded resource bodies
and response headers. Missing archive entries fail offline. This is a frozen
rendering workload, not a live CNN JavaScript or interaction parity claim.

## Identical filtering

Brave uses full Manifest V2 uBlock Origin 1.75.0 in an isolated prepared profile,
with Brave Shields disabled, empty user filters, automatic list updates off,
and the same ten repository filter-list snapshots as Vox. The existing Brave
profile is unchanged.

The live capture audit matched all 268 request/header checks, including 24
blocked requests, with zero static-filter disagreements. Cosmetic CSS,
procedural filters and selected scriptlets also matched. A separate replay of
Vox's actual frozen-page traffic matched all 179 request/header checks over
124 distinct requests, including four blocked requests. The workload and raw
receipts are private under `Build/cnn-parity/`; the relevant receipts are
`capture-ubo.json` and `frozen-native-ubo.json`. These are observed-stream
results, not a claim of complete uBlock extension parity.

## Current diagnostic progress

The signed gradient-tile candidate has **2,918 differing pixels**, with a
maximum channel error of 88, against the unchanged Brave reference. Its single
diagnostic records **59,761,049,408 instructions**, while overlapping another
capture and a short GPU probe; it receives no performance credit. A fresh Brave
diagnostic remains pixel-exact and records 42,262,584,954 instructions, whose
15% threshold is approximately 35.923 billion. These are diagnostic runs, not
the required seven-pair cohort, and no CNN performance success is credited.

The implementation now skips unused fonts in collapsed whitespace contexts,
connects TCP before allocating TLS state, initializes DOM JSON through the
native engine API, and batches raw parser text without bypassing delimiters or
stream boundaries. Rendering fixes retain eligible gradient stops, normalize
invisible premultiplied RGB, snap SVG root paint origins, and round SVG
background containers independently of tile edges. Linear gradients preserve
Chromium's float endpoints, snap eligible default tile geometry before
resolving stops, and use root raster-tile coordinates for dithering. Remaining
fractional SVG
and image-sampling diagnostics keep their unchanged inputs and original Brave
references under `Tests/Browser/Brave/diagnostic/`.

Cold parallel filtering also exposed incomplete JSON metadata and interleaved
audit writes. Separate conversion and log locks preserve engine serialization
and complete request/header records. The latest actual native stream matches
full uBO across 173 checks, 118 distinct requests and four blocked requests,
with zero disagreements.

Validation of the isolated gradient-tile source passes a 24-file CSS/layout/HTML/
network selection in both default and no-GC builds, all 30 exact Brave
fixtures, eight exact SVG mutation guards, all 100 upstream AST comparisons,
signing and native startup. Earlier failed invocations are retained and receive
no wholesale pass credit. Browser JavaScript still runs on JavaScriptCore.
The test union carries 15 already-passing checks and adds 33 successful recovery
checks. Earlier disk-full and incorrectly configured compiler invocations are
retained without pass credit. The private receipts are
`gradient-tiles-broad-pinned-recovery/combined-results.json`,
`gradient-tiles-broad-images/results.json`, `gradient-tiles-svg-guards.log`,
`gradient-tiles-ast.log`, and
`production-gradient-tiles-instructions/pair-1.vox.{json,ubo.json}`. The current
side-by-side
image is saved to `Build/cnn-parity/cnn-brave-vox-progress.png`.

## Reproduction

Build the normal signed bundle with `sh build-prod-browser.sh`. Capture a new
workload using `tools/adblock/brave_parity.mjs --url https://edition.cnn.com/
--capture-dir NEW_DIRECTORY --output LIVE_RECEIPT.json` as described in
[the adblock workflow](ADBLOCK.md). Prepare a full-uBO profile with
`tools/pikabu_browser_instructions.py --engine prepare-profile`; the profile
preparation is independent of which page will later be visited.

With the frozen cache, prepared profile and live receipt in place:

```sh
clang -dynamiclib -O2 tools/pikabu_instruction_network_deny.c \
  -o Build/pikabu-instructions-network-deny.dylib
python3 tools/cnn_browser_instructions.py --mode compare \
  --cache Build/cnn-parity/capture/cache \
  --profile Build/cnn-parity/ubo-profile \
  --extension "$CNN_UBO_EXTENSION" \
  --expected Build/cnn-parity/reference-initial/pair-1.brave.png \
  --adblock-reference Build/cnn-parity/capture-ubo.json \
  --output Build/cnn-parity/new-comparison
```

Set `CNN_UBO_EXTENSION` to the installed full-uBO extension directory. The native
adblock checker and exact PNG diff executable must already be built; see the
adblock workflow and `tools/check_pixel_equality.py`. Output directories must
be new. `--mode vox` and `--mode brave` capture one diagnostic run each.

The comparison pins the native executable and colocated dylibs, Brave,
extension, prepared profile, filter assets, expected image, archive, offline
guard, checker, driver, audit sources and the resolved Boehm runtime. Each launch receives a fresh cache
or profile clone. The native capture must contain the loaded CNN display
fonts and decoded visible images. Each measured Vox request log is checked
against the full extension outside the counted interval. Collector environment
and dyld loader overrides are rejected for production comparisons.

Filter audits also receive a fresh copy of the pinned prepared profile through
`brave_parity.mjs --profile-template`. Process locks and the old debugging
endpoint are omitted. The audit reloads the identical list bytes and clears
user filters; it never launches against or writes to the prepared source.

Counts use macOS `proc_pid_rusage(RUSAGE_INFO_V4).ri_instructions`. Vox includes
the exact root's final unreaped counter and teardown. Brave includes the
observed descendant tree through the last complete sampler pass before the
first screenshot response; this is a polling lower bound. Brave audit and
shutdown work are excluded. GPU instructions, WindowServer and external
services are outside both CPU counters. A mismatched or incomplete capture
cannot pass the performance gate.
