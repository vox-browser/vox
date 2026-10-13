# Native wheel input routing

Implementation: `33ba13ac7abc680a45a85fb3cac708009c351fb8`; actual immediate parent: `31355243acc7f1305237c01730e37ef96406b9b2`.
Upstream reference: `963d46a829f3e1b79f44dba9d02afb70654300fa`. Verification date: 2026-10-13 UTC.

## Bounded implementation

The native browser mouse-scroll entry performs one real Page/DOM wheel dispatch
before default scrolling, retaining the existing 42-CSS-pixel scale and Shift swap.
At scale 1, committed paint-tree hits carry actual node/layout identity. Text targets,
disabled ancestors and stale layout are checked before the native WheelEvent.
Trusted fractional coordinates/deltas, modern/legacy fields and owner Window reach
registered native media/VDOM listeners. UA controls retarget to the external host.
Cancellation blocks inner-box and viewport scrolling. Callback DOM/style mutations
are committed even when canceled; accepted callbacks resolve fresh layout/hit state
before defaults. Nested wheel callbacks cannot replace the outer local delta.
Already-performed async defaults use noncancelable events and receive no second scroll.
Ordinary false returns set canceled; preventDefault still checks cancelability/passive.

## Actual verification

Both GC modes verify six selected files /23 functions: five unchanged test files
contribute 18 passing functions and the focused corrected Page fixture contributes 5.
The original Page fixture fails compilation because it calls the nonexistent
`Element.set_attribute()` method with a result operator. Its original batches,
logs and actual exits remain preserved without full-batch or failed test-body
credit. Replacing that call with the public `set_attribute_value()` setter changes
only the fixture; implementation and the five passing files stay exact.
There are eight new routing functions across the root and Page tests.

Production completes 4 stages with actual exit zero, including the signed native
build/startup, three deterministic software GG wheel injections and 11 screenshots.
The smoke split is 8 pixel-exact / 3 retained tolerance cases. This does not make all
screenshots exact or constitute physical OS-device/hardware injection. The startup
diagnostic exercises the same parsed Page/browser wheel entry, without a synthetic
generic-event fallback. Owner tests separately cover actual UA hits, wrapper identity,
fractional payload, cancellation before inner/viewport movement, canceled DOM updates,
Shift scaling, fresh native audio/overflow mutation, async cancelability, scripting
gates, original exceptions with listener continuation and runtime-close balance.

Consolidated evidence: `Build/audit-fixes/native-wheel-input-routing-evidence-v2.json` (SHA256 `eb245cd3b93fcebb2d69b1e786451b4cbea6fa3a7fa90e987d6c013672e9832a`).
Test selection and retained failure history: `Build/audit-fixes/native-wheel-input-routing-test-evidence.json` (SHA256 `2d304183e810f985728e2051cc74ba823474ff512f156a94ca8cbb2a8de7c49d`).
Production manifest/actual exit: `Build/audit-fixes/native-wheel-input-routing-production-v1/manifest.json` (SHA256 `a509cc1af19cf0ae17b35c6138ae0a458c8a357bc2937d9fbe5367d33c03cf56`); `Build/audit-fixes/native-wheel-input-routing-production-actual-exit.json` (SHA256 `01b6de474ecb6fd8758fdb6528758f6b0de53a7be037ed81798b42381115b0d8`).
Independent physical counter: `Build/audit-fixes/native-wheel-input-routing-inventory-current.json` (SHA256 `590ac39c939ef72b92c769b0c66f7fdaf09c2825e64ce6a64141dbaa39764557`).
Preserved prior records: `Build/audit-fixes/native-wheel-input-routing-prior.json` (SHA256 `841fdb1169cfc40dcb0bb26b23502b4e700a937acedcb26427be49b4b04d9476`) (4,541 records).
Owned cleanup: `Build/audit-fixes/native-wheel-input-routing-cleanup-actual-exit.json` (SHA256 `50fcd948bb56da47d6cb2fb7d8257956e8884b4e119dfe5b8bc3cbcfd6c3395b`).

## Inventory and remaining work

Three Page paths are assigned: +46 implementation / +327 test physical lines and
one file from the actual parent. Four root browser/support paths remain excluded.
At this pin, 78 owners / 2,238 files contain 433,415 implementation / 161,056 test V LOC.
Previous 0cd→parent CSS byte changes have zero LF delta; prior documentation commits
stay separately attributed. Old0cd inventory 393db, source-unit mapping labels and
the 32 fixed / 25 partial / 9 open ledger remain dated history; physical counts imply
no additional behavioral parity.

The compact generic Element facade still has its separate listener list. This slice
does not upgrade every HTMLElement listener/IDL attribute or raw content compiler.
Visual-viewport zoom, nested navigable wheel forwarding, snapped gesture selection,
compositor async orchestration and physical Cocoa/device automation remain open.
The browser continues to use JavaScriptCore; full LibJS/input parity is not claimed.
