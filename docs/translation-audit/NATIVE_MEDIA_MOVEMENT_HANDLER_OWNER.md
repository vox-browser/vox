# Native media movement handlers

Script-assigned `onpointermove` and `onmousemove` now reach the actual HTML
audio/video owner's native handler map. Previously these assignments created
unrelated own properties on compact wrappers and missed native dispatch.
Implementation: `e5ae9afbb79e297d18e513807b876dc1a0ddf77b`; unchanged parent:
`d33c520df3bd076285f586544e43f165856cfab3`. Upstream pin:
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

The implementation adds two names to the selected media-handler list, from
30 to 32 attributes. `DOM/EventHandler.idl` declares `onmousemove`;
`UIEvents/PointerEventHandlers.idl` declares `onpointermove` in the partial
GlobalEventHandlers mixin. `HTML/GlobalEventHandlers.h` maps both names to the
actual EventTarget handler map. Existing native descriptors, receiver checks,
callback conversion, activation and replacement are reused. Main, Page,
dispatcher, primary-click receipts and compact bootstrap retain parent bytes.

Enumerable/configurable accessors retain native names and lengths zero/one.
Invalid receivers fail before replay or Proxy traps. Functions keep identity;
replacement preserves the active listener position, null removes it and
reactivation appends it. Shared legacy conversion clears primitives and keeps
noncallable objects without reading `handleEvent`. Only exact boolean false
cancels an event; zero does not.

## Trusted Page delivery and compatibility cancellation

Ordinary integration tests use explicit native DOM targets through existing
Page move entry points. Parsed video and audio created before insertion keep
owner identity, trusted Event arguments, receiver/target/currentTarget,
owning Window current-event state and post-dispatch cleanup.

`Page/EventHandler.cpp::dispatch_a_pointer_event_for_a_device_that_supports_hover`
and its V translation dispatch pointermove before compatibility mousemove.
Canceling pointermove alone still delivers mousemove. The compatibility
mousemove result controls whether the move returns handled or canceled.
The tests cover pointermove false with uncanceled mousemove, mousemove false,
and zero from both handlers.

Only canceled pointerdown sets the compatibility suppression flag. Moves
while that flag is set still deliver pointermove, omit mousemove and return
canceled because no compatibility default action runs. The suppression fixture
leaves those pointermove events uncanceled. Pointerup clears suppression;
click still arrives, and the next move delivers both
records again. Existing compact replay adds no second native callback.

Self-replacement takes effect on the next move. Null removes the slot and
reactivation appends it after existing ordinary listeners. A throwing
pointermove handler reports the original object while a later pointer
listener and compatibility mousemove still run. DOM polling applies callback
mutations. A following native click clears the move handler and remains a
single delivery through the existing compact replay adapter. This slice
changes no source dispatch or adapter algorithm.

## Five cases and frozen verification

| Focused file / case | Coverage |
| --- | --- |
| `browserjs/media_element_movement_handler_host_test.v`: descriptors/brands | Both attributes on both owners; default null, native metadata and invalid receivers before replay/traps |
| Native owner/slot/legacy rules | Synthetic Event and direct untrusted DOM dispatch, identity/order, ordinary listener separation, false versus zero, object/null and reactivation |
| `main_media_movement_handler_owner_test.v`: compatibility cancellation | Trusted parsed/created owners; pointer then mouse listener order, independent cancellation, cleanup and live DOM polling |
| Suppression through release | Canceled pointerdown omits compatibility moves until pointerup, preserves click, restores the next pair and avoids compact duplication |
| Self-mutation/throw | Replacement/null/reactivation, original thrown-object identity, later pointer listener and mouse delivery, DOM mutation and single native click |

Both new files compile on the unchanged parent. All five functions stop at
their initial missing-descriptor guards; their later Page assertions remain
unexecuted there. The identical final test bytes pass all five focused cases
after installation. Native test SHA256: `1d0b7cd08d2b40331a06c2de4579c1d69010dd57dc34f448833b92cfbe24cab7`.
Main test SHA256: `5f0569d07b759f9c2542cb83e424ee68c375d4be14c049f1053bdf2e9bd8f0e0`.

| Verification | Manifest under `Build/audit-fixes/` | SHA256 | Result |
| --- | --- | --- | --- |
| Parent baseline | `native-media-movement-handler-baseline-manifest.json` | `5ab7b6a0a603a1173c3a53e552bbaba6887bf4e72043daeed427a8063cc76e1b` | Both files compile; five initial descriptor guards fail at runtime |
| Focused final | `native-media-movement-handler-focused-final-manifest.json` | `122317f9d1af3ca376d2f303a4614cbfb6e0fec95cc99d3bfce82b99f38e5f69` | Both files/five cases pass with identical final bytes |
| Selected default GC | `native-media-movement-handler-default-manifest.json` | `0a25f694b462cca1f34860b63206dd9c86d3e431833415a6879d1653a156c172` | 27/27 files pass on unchanged committed inputs |
| Selected GC disabled | `native-media-movement-handler-gc-none-manifest.json` | `80b5ce8b0748420a6c665d85e7d95da1ba9784ba76f1b71a2b187b4395e360cc` | 27/27 files pass on unchanged committed inputs |
| Optimized ordinary tests | `native-media-movement-handler-optimized-manifest.json` | `c372cbf161b4706d3cccfbb0dff5e74adba294c17fd916acddeea9baaf65e8e6` | Both new files pass with `-prod -gc none`, including trusted Page fixtures |
| Signed production | `native-media-movement-handler-production/manifest.json` | `77fe08ecd91dae9ae78140de7d67bfb35b5a1473f5e491dc3baa8339fdab167d` | Startup, two exact synthetic-Event pages and all 11 configured smoke cases pass |

The two full selected runs and optimized ordinary run retain the same complete
committed snapshot. The selected batch adds both new files to the previous
25-file selection, preserving earlier media/listener/play and main/Page
regressions. Final runs keep 4,984 input hashes and 25
selected source references unchanged.

Transient ENOSPC interrupted preparation writes before validation. The
interrupted helper heredoc did not execute; the main draft write was retried
and no partial main test file was retained. No implementation change or test
execution occurred during those failed writes. The preserved
[preparation record](../../Build/audit-fixes/native-media-movement-handler-preparation.json), SHA256 `70acf8c415c6f2f293c002e74f3a49104b90c6d94c0d89d87bd588dcff43ef47`,
records that limited scope. Compiler runs use `VJOBS=1` and the dedicated
1 GiB RAM volume `/Volumes/Vox2MovementScratch` for `VTMP`/`TMPDIR`; source,
logs and snapshots remain in this repository. The record identifies the
scratch device and requires detachment after validation. After all tests,
build and captures, guarded cleanup verifies that RAM image's device/UUID,
checks preserved evidence and discards only its disposable scratch by
detaching the image. The [cleanup receipt](../../Build/audit-fixes/native-media-movement-handler-scratch-cleanup.json), SHA256
`67e79e7224b52efc725b0d0757ce95108a14270241a6e387e9a06b1a7260201c`, records successful detachment and retention of persistent
source/evidence. Existing evidence and unrelated files were preserved.
No new-slice test failure is attributed to disk exhaustion.

Signed production passes 10 stages and both 800x600
pixel-exact pages. Those pages dispatch untrusted `Event` instances and give
separate browser binding coverage. Actual trusted Page delivery is covered
by the ordinary optimized tests with explicit targets. All 11 configured
smoke cases pass, eight exactly; three retain their existing fuzzy tolerances.
All 51 current artifacts and 1,038 previous evidence artifacts verify.
Earlier evidence retains its bytes and scope.

Consolidated evidence: `Build/audit-fixes/native-media-movement-handler-evidence.json`, SHA256 `a128c77fe22cb36ba39c5a1f06112a32802fd015c8d052f4ec1896f8a3e2c122`.
Production binary SHA256: `35710c6f092416b78fe30ceb6a12dd050d65339255998e33e0d762a731fb62c6`.

## Inventory and remaining boundaries

The fresh inventory `Build/audit-fixes/source-current-module-loc-e5ae9afb.json`, SHA256 `16e41f1d3ac526bd0ed255fae0aeebb752d66421da4b1d587f69cde20f9a5c9c`, verifies
all 78 owners and 2,210 assigned hashes/physical newline counts unchanged
against the preceding `5ba4d87c` snapshot: 432,874 implementation and 158,957 test
V LOC. The native host and both focused files are excluded root/browser
support. The current inventory reference is updated separately; module
table numbers remain unchanged.

The JavaScript wrapper exposes the shared base Event surface, leaving full
MouseEvent/PointerEvent fields and interfaces open. The node-less InputTarget
fallback uses separate logging/cancellation flags; it does not establish real
DOM move behavior. Existing `Page.handle_mousemove()` ignores supplied
button-mask/modifier arguments and does not install complete client-coordinate
data. These tests assert no such field parity. Explicit targets do not establish
physical Cocoa transport, hit testing, capture/touch or full input default
actions. The partial media prototype now exposes 32 selected handlers;
complete HTMLElement/audio/video prototype placement, other attributes,
raw inline element compilation, foreign realms and weak ownership remain
open. JavaScriptCore remains the browser engine. Full media/MSE/physical
playback and the pinned load captured-task FIXME remain separate work.
The ledger remains 32 fixed / 25 partial / 9 open.
