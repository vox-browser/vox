# Native media wheel event-handler attribute

Implementation: `0cd374b60b4ab27336f5e9e4ec0776caf0a04358`; actual immediate parent: `777c3cf9b399d940e8eb37270d3d0195569b7b9a`.
The compiled availability baseline is `a6e6adcfdfa033c5bbf9363abc15f14a396b40fc` and remains separately pinned.
Optimized/production validation uses `ea533888ed39102c55f0f526bdb4438edafa03ab` and
`Build/audit-fixes/native-media-wheel-handler-corrected-validation-source`; the wheel feature stays at its original pin.
Upstream reference: `963d46a829f3e1b79f44dba9d02afb70654300fa`. Verification date: 2026-10-14.

## Bounded implementation

Only wheel is added to the existing native media registry (40 names).
Native onwheel accessors brand before compact replay and use the generic callback route.
LegacyTreatNonObjectAsNull maps primitives to null without coercion and retains object
identity. Noncallable objects do not read handleEvent; callable proxies keep their call.
Replacement keeps listener order, null removes the slot, and reactivation appends it.
Ordinary handlers receive currentTarget as this and one actual event. Only boolean false
sets canceled, including when cancelable is false; preventDefault checks cancelable/passive.
Video/audio are ordinary non-passive targets. Raw content handlers remain uncompiled.

Parsed video and script-created audio belong to an actual translated Page. Trusted
embedding WheelEvent factory dispatch preserves fractional coordinates, modern/legacy
deltas and native target identity. Public redispatch uses the same wrapper and timestamp,
changes trust to false and retains wheel slots. Host probes verify relevant/incumbent
settings and VM contexts. Page scripting gates, original thrown values, later listeners,
DOM replay, self-replacement/removal and post-close dispatch keep their owner lifecycle.

## Actual completed verification

| Run | Completed result |
| --- | --- |
| Baseline | 2 files compile; 6 availability guards fail; later assertions uncredited |
| Focused | 4 files / 13 cases pass |
| Default / GC disabled | 8 files / 27 cases pass in each mode |
| Optimized | 2 new files / 6 cases pass with -prod -gc none at corrected validation `ea533888` |
| Production at `ea533888` | 10 internal stages pass; original child exits [0, 0, 1]; supplemental provenance actual exit zero |

Production pages wheel-handler-defaults and wheel-handler-dispatch use public untrusted
dispatch. They turn green only after native accessor, callback and actual WheelEvent
checks succeed. Screenshot smoke tolerances retain their own metrics; no claim makes
all eleven cases pixel-exact. Trusted embedding dispatch has separate V owner coverage.
The original optimized batch and production build fail to compile inherited CSS option
defaults; they receive no test-body, startup, screenshot or complete-run pass credit.
Their original sources/manifests/logs/actual exits remain sealed. A separate compatibility
commit removes exactly two '= none' defaults in css/css.v, preserving zero physical-line
delta and the intended Length defaults. Existing CSS semantic tests pass in both GC modes.
They run before that commit on the feature checkout with those exact corrected CSS bytes.
Fresh optimized and full production validation use the corrected pin above.
The wheel registry/tests are byte-identical to the original feature; no feature is rewritten.
The completed production's old provenance parser rejects a valid committed GC branch.
Its child exit one and logs remain preserved without full-supervisor pass credit.
A metadata-only supplemental proof exits zero and authenticates the same signed binary
and two exact pages/eleven smoke cases; no build, test or screenshot is repeated.

Consolidated evidence: `Build/audit-fixes/native-media-wheel-handler-evidence.json` (SHA256 `acfb1c20452ef429aadd8920df7b4e1e81438bca8e5859f1d1316ee6240bb4cc`).
Independent counter: `Build/audit-fixes/native-media-wheel-handler-inventory-current.json` (SHA256 `393db2d4bee0aeabeae05a4d6caf1c0785526ad70ea2065cdf7cc33ed26b3495`).
Successful manifests and actual receipts retain exact frozen source/compiler identities.
5,074 exact Git input files and 4,230 prior
artifacts remain authenticated, alongside 6 older private sources.
Owned cleanup: `Build/audit-fixes/native-media-wheel-handler-scratch-cleanup.json` (SHA256 `ae8457c0e2ccc99b47856060cefdfd10a0a4429ec8849c7ce78c5b0aac718d99`).

## Physical inventory and remaining work

All three feature paths are excluded browser/root support. Registry implementation
changes by zero physical lines; the two new tests contain 486 lines. Assigned
feature implementation/test/file deltas are all zero. At this code pin the counter
records 78 owners / 2,237 files, 433,369 implementation /
160,729 test V LOC. Earlier assigned CSS/Layout/DOM/Gfx work is reconciled
per commit/path/owner separately; it earns no additional feature or test credit here.
Later independent work outside this pin requires its own inventory. Historical
paragraphs, source-unit mapping labels and the 32 fixed / 25 partial / 9 open ledger stay.

Page wheel entry points still record routing metadata rather than DOM WheelEvents.
Physical Cocoa/Page production, default scrolling, blocking-wheel subtree/compositor
invalidation, complete HTMLElement handlers, weak wrappers and foreign realms remain
open. Existing native play() promises remain complete; the browser still uses
JavaScriptCore. This slice does not establish full LibJS or wheel-input parity.
