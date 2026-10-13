# Canonical MouseEvent-family related target

MouseEvent-family records now use the existing base Event related-target slot
for construction, typed accessors, legacy initialization, cloning and hover
dispatch. Previously a second MouseEvent field could retain the original
related target while the dispatcher retargeted or cleared only the base
field. The two getters could therefore disagree, and a constructor-supplied
related target could be invisible to dispatch suppression and retargeting.

Implementation: `dd0cc2d5642afaaffb615477ef59067432783282`.
Parent: 158f3759306143c6f59f075e74a64f39226a4029.
Upstream pin: 963d46a829f3e1b79f44dba9d02afb70654300fa.

## Source behavior and implementation scope

Upstream DOM/Event owns relatedTarget. MouseEvent construction and
initMouseEvent use that inherited state, and mouse-derived PointerEvent,
WheelEvent and DragEvent records inherit the same storage. DOM event dispatch
reads the related target when constructing its path, retargets it for each
invocation, and clears it together with target when the shadow-tree cleanup
rule applies. The pinned references include DOM/Event.{h,cpp},
UIEvents/MouseEvent.{h,cpp}, PointerEvent.h, WheelEvent.{h,cpp},
FocusEvent.cpp, HTML/DragEvent.{h,cpp} and DOM/Document.cpp.

Only dom/ui_events.v and dom/hover_event_dispatch.v change implementation:

- MouseEvent, PointerEvent and WheelEvent constructors install the supplied
  related target in Event.related_target_. The duplicate MouseEvent field is
  removed.
- MouseEvent.related_target() and related_target_mouse() read the canonical
  base state. Legacy init_mouse_event() updates it through set_related_target()
  after the existing dispatched guard.
- MouseEvent.clone(), create_from_mouse_event() and PointerEvent.clone()
  copy the current getter value, including a value changed by the base setter,
  retargeted during dispatch, or cleared by shadow cleanup.
- Hover construction writes the canonical base field once for each pointer
  or compatibility mouse event, rather than maintaining two copies.

DragEvent construction inherits this correction through its existing
MouseEvent creation path; html/drag_event.v is unchanged. FocusEvent already
uses the base field and remains a control for the established behavior.
The event dispatcher, Page algorithms, main compact bridge, browser binding
implementation and existing tests are unchanged.

No public JavaScript MouseEvent constructor, prototype or relatedTarget
getter is added. The owner tests install a private fixture observer that reads
the actual typed native getter and returns the existing cached EventTarget
wrapper. That observer is test support, not a shipped interface.

## Six focused cases

| File / case | Coverage |
| --- | --- |
| dom/mouse_event_related_target_test.v: constructor/base agreement | MouseEvent, PointerEvent and WheelEvent trusted and untrusted construction use the same related target as base Event; null defaults and unchanged FocusEvent control |
| Legacy initialization/current clones | Base setter changes, MouseEvent clone and timestamped copy, PointerEvent clone, legacy replacement/null, existing dispatch guard and preserved native identity/data |
| Shadow retargeting/cleanup | Real closed-shadow slot assignment delivers a light target through inner slot and outer listeners; related target changes from the shadow peer to its host by invocation; noncomposed shadow dispatch clears both typed and base getters |
| Suppression/trusted hover | A distinct shadow descendant retargeting to the dispatch target suppresses delivery; an original related target equal to target follows the source exception and may dispatch; actual Document hover pointerover/mouseover events agree on retargeted native state |
| browserjs/mouse_event_related_target_owner_test.v: owner listener | Actual Window/Document settings and ordinary native listeners exercise MouseEvent, PointerEvent, WheelEvent and inherited DragEvent, existing UIEvent wrapper identity/view/detail/trust/current event, and shadow-retargeted typed state |
| Nested owner dispatch/exception | Ordinary nested dispatch inside a shadow tree, original thrown-object reporting, later listener delivery, outer current-event restoration, canonical clear-target cleanup, cached wrappers and balanced script/callback contexts |

The DOM package cannot import HTML without a cycle, so the core constructor
matrix covers the three DOM families. The two browser owner cases include
actual HTML DragEvent records and exercise the inherited correction.

The unchanged-parent baseline compiles both files and fails real
related-target assertions in all six cases. This is a core-state regression
baseline, not a missing-interface guard. Assertions later in a case that
stops at its first failure are not executed on the parent. The complete
post-fix tests use the identical final test bytes.

Final core test SHA256: `99a3d6ccd7748ade02c299033ca8bf71ca416d07eb2c95ef5b721df94e6cd38e`.
Final owner test SHA256: `960ecfb5df287900771c10dbe99aec756960a77f72b48862c9c3860a1cbdc97b`.

## Immutable verification records

| Verification | Record | SHA256 | Outcome |
| --- | --- | --- | --- |
| Final parent baseline | `Build/audit-fixes/native-related-target-baseline-frozen-final-manifest.json` | `e63452a20134c912d1aa4c88edcd7c9b6ee2c47c88dd5f2563f7f4648835ad10` | Both files compile; six real runtime assertions fail on the unchanged parent |
| Final focused | `Build/audit-fixes/native-related-target-focused-complete-manifest.json` | `8c0680a0505db1020d63619aa1774700c36dd11fb4e61eb3a8c51a65519346ff` | Both files / six cases pass with final test bytes |
| Selected default GC | `Build/audit-fixes/native-related-target-default-manifest.json` | `42d31d93d37f9482703e4dec6c856937fedaabace0828dc416e70c5668498c90` | 12/12 files pass on the unchanged implementation commit |
| Selected GC disabled | `Build/audit-fixes/native-related-target-gc-none-manifest.json` | `754429fe182c4f2bc995dca1e84ac6189eebb0881d4623d7cc599ca9a404dde6` | 12/12 files pass with GC disabled |
| Ordinary optimized tests | `Build/audit-fixes/native-related-target-optimized-manifest.json` | `8b7cffe2d36c3ef732c8a672654981996171a6a2ceb026638fafdb2dbe576a69` | Both files / six cases pass with -prod -gc none |
| Signed production | Build/audit-fixes/native-related-target-production/manifest.json | `ee03005a410029084ef3b0134922cfa457e1a8c46160e8e689651bbbf629f899` | Five stages pass; signed startup and 11 smoke cases (eight exact) |

The frozen verifier selects twelve files for each full GC run.
The ordinary optimized run selects the two new files and six cases with
-prod -gc none. Final snapshots retain 4,992 input hashes,
38 selected source references and 145 production references.
The independent report verifies complete before/after snapshots,
the committed implementation/test bytes, exact commands and environments,
source references, compiler binaries, three archives, and preserved prior
artifacts. The selected cases retain earlier UIEvent, native event callback,
hover, legacy dispatch, Page pointer and compact media click/movement coverage.

The production verifier passes five stages: archive-cache-precheck,
build, codesign, startup and smoke-screenshots. It validates the signed
browser startup and all eleven configured smoke cases under their existing
comparison criteria. This slice adds no new browser pixel-check pages.
Actual related-target behavior is covered by the focused and ordinary
optimized native-record and owner-listener tests.

Production completion receipt SHA256: `880bbbbfa54a832638a0a6fa5b4fce3f0d8342ecc8a25181881dfacf06e1911d`.
Signed binary SHA256: `e0618b89ecb3f1da3d6d4f05a4f9df14bb545d159498d4bc681052d7b0b89b83`.
Smoke metrics and exact-case count: 11 pass, eight exactly; three retain their existing fuzzy tolerances. Per-case differing-pixel and maximum-channel-error values are retained in the independent report.
Verified current artifact count: 38.
Verified unchanged prior artifact count: 1225.
Consolidated evidence: `Build/audit-fixes/native-related-target-evidence.json`, SHA256
`7ba7b929b6c7b0ef1ab33ad1f828db8b5ee23f250cbde7ad35d175d7b4605e1d`.
Independent verification report: `Build/audit-fixes/native-related-target-verified-report.json`, SHA256
`946a318cc9937281717ca5fba6c48be85f38dd725579250899f3db2648d65892`.

Compiler scratch uses the separately owned RAM volume
/Volumes/Vox2RelatedTargetScratch; source, logs, snapshots and evidence
remain in the repository. Guarded cleanup verifies that image's identity
and retains every persistent current/prior artifact.
Cleanup outcome/receipt: Only the task-owned `/dev/disk6` RAM image is detached; persistent source and evidence remain intact. Receipt: `Build/audit-fixes/native-related-target-scratch-cleanup.json`;
SHA256 `e719ee37029cea66b5d5732ff174ac6e9454bf4daea02c97aa80b0e67e65a72e`.

## Retained diagnostics

An existing focused attempt passed the core file but failed browser fixture
callback checks. It supplies no complete six-case passing proof. Its cause,
scope, retained input bytes, logs and final resolution are preserved in
the diagnostic evidence.

Diagnostic outcome: The initial checker omitted the two shared-helper failure frames from its six-case count. A later focused run passed all core cases but reused the first native event export in subsequent owner iterations. Indexed private exports fix the fixture without changing runtime or dispatch algorithms. Separate diagnostic compile variants and labeled runtime logs remain preserved.
Diagnostic manifest/log records: `Build/audit-fixes/native-related-target-development-runs.json`, SHA256 `b8ac7086eaf221a22d8e1b066c67663847fdb58825534a641254f84b27c643a1`; all earlier manifests/logs and the isolated owner-probe artifact map are verified in the independent report.
Final-byte baseline/retry relation: Final core/owner bytes compile and fail all six real parent assertions, then pass both files/all six cases in focused, selected and ordinary optimized runs.

Historical evidence remains unchanged and retains its original scope.

## Assigned inventory and remaining boundaries

The recount preserves the same disjoint 78 owners and existing
UIEvents/Selection special assignment lists. The new 285-line core test is
assigned to DOM; the browser owner test remains excluded support.

| Owner | Implementation V LOC before → after | Test V LOC before → after |
| --- | --- | --- |
| DOM | 43,499 → 43,497 (-2) | 4,694 → 4,979 (+285) |
| UIEvents | 1,490 → 1,489 (-1) | 474 → 474 (unchanged) |

Verified total: 2,211 assigned files, 432,871 implementation V LOC and
159,242 test V LOC. The fresh snapshot recounts every actual assigned
file byte hash and physical newline. Hash changes occur only in the two
core implementation files and new DOM test. Other owner mappings, hashes
and counts remain intact.

Inventory: `Build/audit-fixes/source-current-module-loc-dd0cc2d5.json`, SHA256 `568534bda24ca5538af3196bacd984810907a7fd79a60c064135af6cb4478b51`.
Recount outcome: All 2,211 assigned files are recounted and match committed bytes; only DOM/UIEvents change, exactly as shown above.
The prior inventory is preserved at
Build/audit-fixes/source-current-module-loc-d1b86d81.json, SHA256
1d396d2178a0173ebe3f267c44e8a13bb7eac2ce5ce68cfdade2ad6ce2dfa265.
The current inventory reference is updated in a separate documentation
commit after final evidence is complete.

This core fix does not establish complete MouseEvent/PointerEvent/WheelEvent/
DragEvent JavaScript interfaces, full Page input-field construction parity,
physical Cocoa input or hit testing, raw inline element compilation, foreign
realm/view wrappers, or weak wrapper ownership. JavaScriptCore remains the
browser engine. Existing broader media/MSE/playback and pinned load
captured-task boundaries remain open.

The historical ledger remains 32 fixed / 25 partial / 9 open.
