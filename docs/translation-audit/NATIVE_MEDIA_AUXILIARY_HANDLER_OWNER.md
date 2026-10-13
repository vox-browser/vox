# Native media auxiliary and double-click handlers

Script-assigned `onauxclick` and `ondblclick` now reach the actual HTML
audio/video owner's native event-handler map. Previously these assignments
created unrelated own properties on compact wrappers and missed native
dispatch. Implementation: `5ba4d87c9af7c3a0e847beebfa64d37bdfa8f989`; unchanged parent:
`4ec90a19275eff1eb435f32ce3d47e70d366c8c4`. Upstream pin:
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

The implementation adds two names to the existing selected media-handler
list, from 28 to 30 attributes. `DOM/EventHandler.idl` and
`HTML/GlobalEventHandlers.{h,cpp}` declare both attributes and delegate to the
actual EventTarget map. Existing native descriptors, receiver checks, callback
conversion, listener activation and replacement are reused. Main, Page,
dispatcher, primary-click receipts and the compact bootstrap are unchanged.

The enumerable/configurable accessors retain native names and lengths zero/one.
Invalid receivers fail before replay or Proxy traps. Functions keep identity;
replacement preserves the active listener position, null removes the slot and
reactivation appends it. Shared legacy conversion clears primitives and
retains noncallable objects without invoking `handleEvent`. Only the exact
boolean false cancels an event; zero does not.

## Actual Page delivery and cancellation

The ordinary integration tests enter actual Page press/release through explicit
DOM targets and supplied button/click-count values. Parsed video and created
audio retain trusted Event arguments, receiver and target/currentTarget
identity, owning Window current-event state and post-dispatch cleanup.

The existing `Page/EventHandler.cpp::fire_click_events` and its V translation
dispatch primary click before dblclick when the click count is two. Canceling
dblclick cancels that record while the primary click still permits activation.
Canceling the primary click still delivers dblclick, with activation blocked
by the primary result. Middle/right releases dispatch auxclick rather than
click/dblclick, including when the supplied count is two. Auxclick false blocks
activation; zero permits it. Ordinary non-nested auxiliary releases clear an
earlier primary replay receipt.

Self-replacement applies on the next event, null removes the handler and
reactivation takes a new slot. A throwing dblclick handler can install a new
raw onclick and mutate the DOM; later listeners still run and the original
exception identity is reported. The existing receipt preserves the already
processed outer primary click, so compact replay cannot execute that new raw
text on the same release. The next single click can use the preserved raw
fallback. These tests exercise existing source algorithms and adapter
bookkeeping; this slice adds no dispatch or receipt algorithm.

## Five cases and frozen verification

| Focused file / case | Coverage |
| --- | --- |
| `browserjs/media_element_auxiliary_handler_host_test.v`: descriptors/brands | Both attributes on audio/video; default null, native metadata, invalid receivers before replay/traps |
| Native owner/slot/legacy rules | Actual synthetic Event dispatch, callback identity/order, ordinary listener separation, false versus zero, null/reactivation and noncallable objects |
| `main_media_auxiliary_handler_owner_test.v`: primary/double independence | Trusted parsed/created delivery, both cancellation directions, stable handler position, DOM replay and no duplicate compact callback |
| Non-primary release | Middle/right auxclick only, exact false versus zero, native cancellation and clearing the earlier non-nested primary receipt |
| Self-mutation/throw | Aux replacement/null/reactivation; throwing dblclick retains reported exception and outer click receipt, later listeners/DOM mutation, same-release raw suppression and next-click fallback |

Both new files compile on the unchanged parent, and all five functions fail
at their initial missing-descriptor guards. That baseline establishes the
binding gap; it does not execute their later Page behavior assertions.
The same final test bytes pass all five focused cases after installation.
Native test SHA256: `0d39cfbcdd69068f761129c8ab5d39a8705fe5853f13bc7c493c218100d97ec3`.
Main test SHA256: `0e8aed0aeb9a385c5ba01f6156a7091bfbc47005fbe57d92809a8b84448bdb83`.

| Verification | Manifest under `Build/audit-fixes/` | SHA256 | Result |
| --- | --- | --- | --- |
| Parent baseline | `native-media-auxiliary-handler-baseline-manifest.json` | `61016a58d20e103b4fcf607f4bce43b27dcd5df10e745c4693904f5df8b9d7cb` | Two files compile; five descriptor guards fail at runtime |
| Focused retry | `native-media-auxiliary-handler-focused-retry-manifest.json` | `db1b29db21aad58f5149d68d9884dfebfe9c6f23c6d81dd863447aed2c6cc278` | Two files/five cases pass with final bytes |
| Selected default GC | `native-media-auxiliary-handler-default-manifest.json` | `29aa658f7e3b2627e498612075830a30d902293e53f90831a14497d45d857b1c` | 25/25 files pass on unchanged committed inputs |
| Selected GC disabled | `native-media-auxiliary-handler-gc-none-manifest.json` | `52e9ba46de342beb5a69cc6392db6842844ec99165f96a840099282b03963f21` | 25/25 files pass on unchanged committed inputs |
| Optimized ordinary tests | `native-media-auxiliary-handler-optimized-manifest.json` | `035abd5765b7ac014ada5128edb9138f2fdc493f5c1a7a08e4548b5b772ac8bf` | Both new files pass with `-prod -gc none`, including actual trusted Page fixtures |
| Signed production | `native-media-auxiliary-handler-production/manifest.json` | `f6f736716f725c15acfcfe1480da4dc7e20de02d6348cb15abcff9b10c56ba05` | Startup, two exact synthetic-Event pages and all 11 configured smoke cases pass |

The two full selected runs and optimized ordinary run retain the same complete
committed snapshot. The selected batch includes the prior 22 files and
Page interaction coverage, preserving earlier handler/listener/play behavior
and the existing 66-case main regression. Final runs keep 4,981 input
hashes and 25 selected source references unchanged.

An initial focused attempt could not create writable compiler scratch folders
during transient disk exhaustion. Test runtime was zero; no tests executed.
Manifest persistence also failed with errno 28, so no complete before/after
snapshot proof exists for that attempt. Its original log and separate
[disk diagnostic](../../Build/audit-fixes/native-media-auxiliary-handler-focused-disk-diagnostic.json) remain preserved, SHA256
`fbdc348523c10cc9047f195ce40aeb6bf189baaf85d535df1fd311d95f813b8d`. It receives no passing credit. The separate immutable
focused retry supplies the successful result above. The diagnostic's three
feature-file hashes match the final frozen implementation/test bytes.

The signed browser run passes 10 steps and both 800x600
pixel-exact pages. Those pages dispatch untrusted `Event` instances and verify
native descriptors/owner behavior in the real browser. Actual trusted Page
delivery is covered separately by the ordinary optimized tests with explicit
targets. All 11 configured screenshot smoke cases pass, eight exactly; the
other three retain their existing fuzzy tolerances. All 51 current artifacts
and 964 previous evidence artifacts verify.
Earlier screenshot and feature evidence retains its original bytes and scope.

Consolidated evidence: `Build/audit-fixes/native-media-auxiliary-handler-evidence.json`, SHA256 `55b95fa856b311d5bad0e32d8b14089bf3289afa54ecf79e89ea1af01c50b63d`.
Production binary SHA256: `a701dd96dc0ab3b809fffea948c46e3e3b46d0e3d94bd1ff19e7f651e8137f23`.

## Inventory and remaining boundaries

The fresh inventory `Build/audit-fixes/source-current-module-loc-5ba4d87c.json`, SHA256 `90982b16fe88bc53a2ad6f1a6f89d53950ef88a4e7250cc86ec5619997e7dadc`, verifies
all 78 owners and 2,210 assigned file hashes/physical newline counts unchanged
against the preceding `8c567b08` snapshot: 432,874 implementation and 158,957 test V
LOC. The changed native host and two focused files are root/browser support
excluded from this established inventory. The current inventory reference is
updated separately; its module table numbers do not change.

The partial media prototype exposes 30 selected handler attributes. Complete
HTMLElement/audio/video prototype placement, remaining handler attributes,
full MouseEvent/PointerEvent fields, raw inline element compilation, foreign
engine realms and weak ownership remain open. Explicit targets/counts do not
establish physical Cocoa transport, hit testing or platform double-click
recognition. Broader nested auxiliary receipt semantics are outside these
new cases. The browser still uses JavaScriptCore; full media/MSE/physical
playback and the pinned load captured-task FIXME remain separate work.
The ledger remains 32 fixed / 25 partial / 9 open.
