# Native media drag/drop event-handler attributes

Verification date: 2026-10-14. Implementation: `a503c977b416922e7df145188d5ba3d06996f31f`.
Immediate parent and compiled availability baseline:
`dc5aa34dc545092463ed3893162711cd6c7e84fa`. Upstream source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

## Source behavior and compact native surface

DOM/EventHandler.idl declares ondrag, ondragend, ondragenter, ondragleave,
ondragover, ondragstart and ondrop as ordinary nullable EventHandler attributes.
EventHandlerNonNull uses LegacyTreatNonObjectAsNull. GlobalEventHandlers delegates
its accessors to the owning EventTarget handler slots. Generated getters/setters
are native functions named get/set plus the attribute name, with lengths zero/one
and enumerable/configurable descriptors. Actual receiver branding precedes callback
conversion, and this transport also brands before compact DOM replay.

The translated media host exposes this subset directly on its flattened
HTMLMediaElement.prototype, which already uses an EventTarget base. Upstream's
complete HTMLElement hierarchy and every GlobalEventHandlers consumer are not
implemented by this compact surface. This slice adds seven names to the existing
native handler registry; it does not introduce a second dispatch pipeline.

Primitive assignments, including undefined, strings, Symbols and BigInts, become
null without coercion. Object callbacks retain their exact identity and captured
incumbent settings without an assignment-time callable check. Invoking a
noncallable object returns without reading handleEvent or other author properties.
A callable Proxy retains its actual apply behavior without callback property gets.

A handler slot activates one listener. Callback replacement preserves that
listener's position, and repeated same-value assignment does not duplicate it.
Assigning null removes the slot listener; reactivation appends a new listener.
Ordinary handlers receive the actual currentTarget wrapper as this and one native
event argument. Only the actual boolean false result cancels the event; zero,
empty strings, null, undefined and false-looking objects do not undergo boolean
conversion. The pinned ordinary-handler algorithm sets the canceled flag directly
for actual false without a cancelable check. Thus even a noncancelable Event can
become defaultPrevented and make dispatchEvent return false through this handler
path; event.preventDefault() uses its separate cancelability gate.
Exceptions, window.event restoration and callback settings continue
to use the existing shared event machinery.

The fixtures use parsed video and script-created audio in an actual translated
Page. Native DragEvent factory dispatch reaches the owning DOM EventTarget, and
JavaScript redispatch retains the same wrapper, timestamp and native payload while
changing trust according to dispatchEvent. Host probes inspect the relevant and
incumbent settings, callback/script depths and active translated VM contexts.
The real Page scripting gate suppresses callbacks, then re-enabled dispatch
resumes them. Raw content-handler strings remain uncompiled by the unavailable
element compiler; IDL replacement retains the original HTML attribute bytes.
Runtime close clears actual native media host records, releases JS roots and
permits later V dispatch without entering a dead engine context.

DataTransfer/list/item wrappers retain their original native identity. Public
File additions snapshot the actual File slots and bytes. Subsequent getAsFile,
files and webkitGetAsEntry reads produce fresh File/FileList/Entry records, so the
fixtures distinguish input files from retained snapshots and later fresh reads.
Removing items or disassociating the store leaves retained snapshot metadata
intact. No author-visible File/Entry shim supplies these records.

Page's existing drag route records DragDispatch entries. Trusted events here
come from the existing V embedding factory and actual DOM dispatcher. The two
production pages use public dispatchEvent and correctly observe isTrusted=false.
This evidence does not establish a Cocoa drag producer, physical Page delivery,
automatic store transitions or default drop actions.

Source references include DOM/EventHandler.idl, HTML/GlobalEventHandlers.{h,cpp},
DOM/EventTarget.{h,cpp}, HTML/HTMLElement.idl, HTML/HTMLMediaElement.idl,
generated attribute/callback conversion paths, WebIDL callback abstractions,
HTML/DragEvent.{idl,cpp} and Page/DragAndDropEventHandler.cpp. The read-only
source review authenticates 14 upstream references
at the pinned clean checkout; selected run manifests authenticate their own exact
source inputs. Weak WrapperWorld and foreign WindowProxy/function-realm ownership
remain separate runtime work.

Upstream DataTransfer.setDragImage is a FIXME IDL operation without an implemented
C++ method. Its private diagnostic marker does not install a public JavaScript
property. It remains absent; no throwing public stub or drag-image behavior is
invented in this slice.

## Documentation base and preserved independent commits

Verification and the physical inventory remain pinned to `a503c977`. 3 later independently authored commits are preserved at documentation base `a79d432b`; their CSS/Layout sources and counts are outside this slice's verified source and inventory counter. A later inventory refresh must account for those separate changes under its own pin.

| Preserved foreign commit | Parent | Subject | Changed paths |
| --- | --- | --- | --- |
| `76c96ff3b9ca1013646898a7c0eb7573b6273321` | `a503c977b416922e7df145188d5ba3d06996f31f` | Own CSS tokenizer lookup tables in a scoped numeric arena | `css/parser_core.v`, `css/tokenizer_input_arena_test.v` |
| `ea0f3fd936d1eaa3a92cc78586afc2ed8644172c` | `76c96ff3b9ca1013646898a7c0eb7573b6273321` | Reuse font length metrics on the owning computed style | `css/computed_interpolation.v`, `css/computed_length.v`, `css/computed_length_metrics_cache_test.v`, `css/computed_values.v` |
| `a79d432bdfc684c5843eb57571215fa8494e6721` | `ea0f3fd936d1eaa3a92cc78586afc2ed8644172c` | Seed shared intrinsic containing block chains once per probe | `layout/intrinsic_containing_block_seed_test.v`, `layout/intrinsic_sizing.v` |

Each intervening commit is authenticated as part of a linear descendant chain.
Its changed paths, Git modes/blob identities and physical byte SHA256 values are
retained separately in the proposal manifest, with no test or parity credit.
The record is `Build/audit-fixes/native-media-drag-handlers-audit-doc-proposals-v3/manifest.json`; its foreign-commit map digest is
SHA256 `b81072fa0e015a5526f91abc0efb25fe9468f3d800d1a30eb48c3ebafa78f457`.
All three owned feature paths and six audit paths match their feature-pin bytes;
proposals insert this slice's evidence into the current documentation Git base.
The old private validation source remains at its verified feature commit. No
foreign source is reset, removed, rewritten or credited by this evidence.

## Actual verification and frozen revisions

| Run | Outcome |
| --- | --- |
| Parent baseline | 2 files compile; 6 initial availability guards fail; later assertions uncredited |
| Final focused | 6 files / 20 cases pass, including all 6 new cases |
| Default / GC disabled | 15 files / 52 cases pass in each mode |
| Optimized | 2 new files / 6 cases pass with -prod -gc none |
| Production | Signed startup, two pixel-exact public drag-handler pages, eleven smoke cases pass |

| New focused test file | Actual functions in committed code |
| --- | ---: |
| `browserjs/media_element_drag_handler_host_test.v` | 3 |
| `main_media_drag_handler_owner_test.v` | 3 |

Successful runs follow the sealed plan and final frozen map. Case counts are
recounted from exact committed test functions and completed receipts. The
compiled parent baseline checks only the six public availability guards; later
assertions earn no parent baseline credit. Every attempted frozen revision and
its original logs/manifests/terminal receipts remain preserved.
Final implementation hashes match the earliest captured implementation freeze. Changed owned paths across the initial/final freezes: `browserjs/media_element_drag_handler_host_test.v`.

| Retained failed attempt | Actual result | Recorded reason |
| --- | --- | --- |
| `focused-v1` | 6 files / 20 cases; test exit 1, actual runner exit 1; 5 files pass / 1 fail | Five files pass and one binding fixture fails after trusted native dispatch. Repeated definition of a readonly nonconfigurable native export global retained the first event, so thirteen later expected event identities were stale. The failed source, logs, manifests and actual exit receipt remain preserved without successful batch or later-assertion credit. |



| Retained failed production | Actual partial result | Recorded reason |
| --- | --- | --- |
| `native-media-drag-handlers-production` | 7 attempted stages; 6 exit zero; `drag-handlers-defaults-pixel` exits 1; child exits `[0, 1]` | The original run completed with actual child exits [0,1] after the defaults pixel check. Its page expected an exact false return to leave a noncancelable Event uncanceled, while pinned upstream and V EventHandler processing directly set the canceled flag. The retry changes only that page expectation, preserves every original input/result/binary and both original14/intermediate16 preparation archives, and rebuilds in a separate private output. No feature implementation or V test changes or reruns result from this production-only fixture correction. The original failed batch and its unexecuted later stages receive no passing credit. |

The original production defaults fixture expected an ordinary handler's false
return to leave a noncancelable Event uncanceled. The pinned source sets the
canceled flag directly for actual false, without testing cancelable; this differs
from preventDefault's cancelability gate. The fixture's page therefore stays red
and its defaults pixel stage fails. Its original prepared-v3 packet, fourteen-file
initial input archive, sixteen-file intermediate archive, complete partial-stage
logs, manifest and actual failed supervisor/child receipts remain authenticated.
This failed attempt receives no complete production or later-stage pass credit.
The corrected retry changes only independent ignored production inputs. Feature
implementation and committed tests remain unchanged at `a503c977`.

The selected independent production retry passes all 10 internal stages and actual
prepare/production/provenance child exit codes [0, 0, 0].
Its output directory is `Build/audit-fixes/native-media-drag-handlers-production-retry-private` and its supervisor
receipt prefix is `native-media-drag-handlers-production-retry`; every successful record above
comes from this selected retry rather than the failed original directory.
The actual drag-handlers-defaults and drag-handlers-dispatch pages stay non-green
until all native public descriptor, handler, payload, slot and cancellation checks
succeed. Both rendered pages are pixel-exact. All eleven configured screenshot
smoke cases pass: 8 are exact and 3 retain their established tolerance
residuals. Public script dispatch remains untrusted; trusted embedding delivery is
verified by the focused V fixtures separately.

Tests use the pinned old compiler with enable-globals in the clean committed
private source. All 5,061 exact Git input bytes and
3,817 preceding artifact hashes remain verified.
Five earlier private sources remain authenticated: `fdc13cca` (5058 Git inputs), `e3ff95fd` (5050 Git inputs), `bbe330a8` (5046 Git inputs), `e775be45` (5042 Git inputs), `b59e211c` (5032 Git inputs).
Test compiler identity contains two inputs; production adds its V_BIN wrapper.
Production uses exact committed recipes with isolated source/output/capture
substitutions, shared authenticated native/Rust inputs, strict signing and source
markers. Its historical frozen bundle is `Ladybird.app`; canonical Vox branding and
tooling working changes stay independently preserved. Cleanup detaches only the
verified owned RAM volume and retains private sources, binaries and all logs.

## Evidence, physical inventory and remaining work

Consolidated sealed evidence: `Build/audit-fixes/native-media-drag-handlers-evidence.json`,
SHA256 `9af390887fee838c6b470e7194e122cfc9aeedcab5ab17f6bc9b2f7cfbe5a2f7`. It authenticates final and earlier frozen maps,
plan, actual successful and optional failed terminal receipts, signed production
provenance, preserved prior artifacts and the owned cleanup receipt.
Inventory: `Build/audit-fixes/native-media-drag-handlers-inventory-current.json`, SHA256 `9dc686e6ab4186f3d7a1bd4e137bf657ccad63e8b1d89f7d424a66b29b9da2bc`.

The independent recount preserves 78 owners / 2,227 assigned files,
433,263 implementation / 160,393 test V LOC.
All three feature paths are excluded browser/root support: the registry changes
by +1 implementation line and the two new test files contain
595 physical lines. Assigned implementation and test LOC both change
by zero. Every assigned byte hash, newline count and owner row equals the prior
`fdc13cca` entry inventory and actual feature parent; no intervening assigned slice
is counted. Physical counts include comments/blank lines and establish no runtime
or parity credit. A separate inventory commit refreshes only the current pin and
retains the previous entry paragraph/counter as dated history. The e3ff95fd,
bbe330a8, e775be45 and b335958e paragraphs, CPP source-unit counts, mapping labels,
README's historical table and historical finding ledger remain unchanged.
EntriesAPI's status/workspace and dated table/transcript are unchanged in this slice.

| Retained record | SHA256 |
| --- | --- |
| `Build/audit-fixes/native-data-transfer-entry-inventory-current.json` | `f3062da8a0c0354822688a690594c6497ce8771933ef566068f0229a61e35a26` |
| `Build/audit-fixes/native-data-transfer-entry-inventory-recount.py` | `9079a2c6ce8a952728f54575185782c1c102d2edd97ed89eacb34d6421e419c1` |
| `Build/audit-fixes/native-media-drag-handlers-baseline-v1-exit-receipt.json` | `292cf0077a4a974c4cc4f7cb7cc241becc22faccf09a0c7d39d156d1fb13f253` |
| `Build/audit-fixes/native-media-drag-handlers-baseline-v1-manifest.json` | `41fb5d6c79366d07b5c3c751574e64904137ae06e81bc0dd0baf4b9c0cdcb3e0` |
| `Build/audit-fixes/native-media-drag-handlers-default-exit-receipt.json` | `2d3844f521610080519c515ece77e5fa9a2e7087b5816a602e32748d4794dd14` |
| `Build/audit-fixes/native-media-drag-handlers-default-manifest.json` | `913dc7136cabe3859911ff02228435045a2b711e686df0bc8fe136954a3a9e9d` |
| `Build/audit-fixes/native-media-drag-handlers-evidence.json` | `9af390887fee838c6b470e7194e122cfc9aeedcab5ab17f6bc9b2f7cfbe5a2f7` |
| `Build/audit-fixes/native-media-drag-handlers-failed-production-closure-v1.json` | `6b5ae9b37869d8053b863f9e06b066a4a3002b728f9250f58d7288e651329e7a` |
| `Build/audit-fixes/native-media-drag-handlers-focused-v1-exit-receipt.json` | `0443e4004c944ab2ca8d239a61be6a3da4d420f7401141172af9d3e08913da00` |
| `Build/audit-fixes/native-media-drag-handlers-focused-v1-manifest.json` | `2ddf51fd4a22ad56dc14cb2253fba77cc4cf33d327934fe08a9a5c98c602cd94` |
| `Build/audit-fixes/native-media-drag-handlers-focused-v1.log` | `626ff2475485c7f263cec88a6f758a85fe2b9ca8e740bb3364efe2e8e4d549a8` |
| `Build/audit-fixes/native-media-drag-handlers-focused-v2-exit-receipt.json` | `e4dce72b9f4598d01b79874a8fbfb8d961a479361640c5ee47dcaf65e430077e` |
| `Build/audit-fixes/native-media-drag-handlers-focused-v2-manifest.json` | `da6aaccb1d479cc0b62fe4331567cb945c76ed0f781d1f4257d9a8d9a1f72920` |
| `Build/audit-fixes/native-media-drag-handlers-frozen-v1.json` | `4c75f0eb48f75028212b03fc743fbfc647c2db4070b20683c8bd2edf5e517f44` |
| `Build/audit-fixes/native-media-drag-handlers-frozen-v2.json` | `cb0b06f6776406dcd73d1c38efe734f4115659a86802bb088fb21b83efe93db0` |
| `Build/audit-fixes/native-media-drag-handlers-gc-none-exit-receipt.json` | `1d6090edab87fca90e9a4a9d6d1ba2f6b57f5c3959502b6355fae49363c6f02c` |
| `Build/audit-fixes/native-media-drag-handlers-gc-none-manifest.json` | `01e5a017f9118c8dea0d6cc62110b0bb59869d86777f34b952f5a6f8a4ec876c` |
| `Build/audit-fixes/native-media-drag-handlers-inventory-actual-exit.json` | `a93aff9d1e17bb602760e33d8e73f37178e9d93e1f61a8ff07adb92ba7e4a94b` |
| `Build/audit-fixes/native-media-drag-handlers-inventory-current.json` | `9dc686e6ab4186f3d7a1bd4e137bf657ccad63e8b1d89f7d424a66b29b9da2bc` |
| `Build/audit-fixes/native-media-drag-handlers-inventory-recount.py` | `c4f7588a35257cb08914d294cd126b4b5930b2b3ad19d06daff4ceaefba9220c` |
| `Build/audit-fixes/native-media-drag-handlers-optimized-exit-receipt.json` | `7534323a5e24b896210ed7d092c9c7c97416994f7cc2cc3e8a260cf0d3bbcd0a` |
| `Build/audit-fixes/native-media-drag-handlers-optimized-manifest.json` | `12afb91e14e23e2600a756a58a90f018acb898daa3fa1511b11e645a3d31387f` |
| `Build/audit-fixes/native-media-drag-handlers-prior.json` | `4ca441e935d82dea3040a072e3d5a226a19ea289311b21f8e0fe6f4b56e713e1` |
| `Build/audit-fixes/native-media-drag-handlers-production-initial-inputs/preservation-record.json` | `c0ea9363f182a47ad00f5f8e0201d39594427df03aaef16f8bd4625bca175a46` |
| `Build/audit-fixes/native-media-drag-handlers-production-inputs-v2/preservation-record.json` | `af596b609be030f15377e8896746498e00460f928a31952a203affab31d53a95` |
| `Build/audit-fixes/native-media-drag-handlers-production-private/archive-cache-precheck.log` | `4abf31a757eeb99a769410eb5dbaaa8e0be810b22e26c6b62d61379c1df8d4d8` |
| `Build/audit-fixes/native-media-drag-handlers-production-private/build.log` | `c9e84b14952d649bd9b3125f8ad4f7179ff64bf4583a9dae4af115dd18d85bd1` |
| `Build/audit-fixes/native-media-drag-handlers-production-private/codesign.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `Build/audit-fixes/native-media-drag-handlers-production-private/completion-receipt.json` | `9393c01dc750792961a75a2555dd8660c1789a959261addc620465760e0608db` |
| `Build/audit-fixes/native-media-drag-handlers-production-private/drag-handlers-defaults-pixel.log` | `20f45c2b8bad041db292578174074baf9329984208b76790fb19dc008a364c8d` |
| `Build/audit-fixes/native-media-drag-handlers-production-private/drag-handlers-defaults.log` | `11db610ae86656f0786a321d44d3125bfbba2690488d3a9389a2c4dc3070ef22` |
| `Build/audit-fixes/native-media-drag-handlers-production-private/expected.log` | `02f023225cf0706df0bb00906789f3b7318733e472dcf8d145e90a485deb7ef9` |
| `Build/audit-fixes/native-media-drag-handlers-production-private/manifest.json` | `4848c37f2dcd02be69d0fe05aa1e997c82aa20f84f393726590257a5b9454077` |
| `Build/audit-fixes/native-media-drag-handlers-production-private/prepared-inputs-v2.json` | `1824e860f8a955512f1dc724265c9933bda51d3e7b6ae0b996cfe60b76d4e954` |
| `Build/audit-fixes/native-media-drag-handlers-production-private/prepared-inputs-v3.json` | `db60b49e962593ef718a6007e5842efd42487b19631e49355f3a334b80f90afd` |
| `Build/audit-fixes/native-media-drag-handlers-production-private/prepared-inputs.json` | `d6652e5b027f38a95e57dd7bb39e412ad6d431f142e36987bd55c502df381ca4` |
| `Build/audit-fixes/native-media-drag-handlers-production-private/startup.log` | `c0969a29380548754e94e6fcc3bdc1816e8537bc7ea920434027ccf2a3436baf` |
| `Build/audit-fixes/native-media-drag-handlers-production-retry-private/drag-handlers-defaults-pixel.log` | `09966c78a2bd9f40532b5075797304e6f6977efb2bef02a1a59d099a109be07b` |
| `Build/audit-fixes/native-media-drag-handlers-production-retry-private/drag-handlers-dispatch-pixel.log` | `70ba934dd5ea26dc1f03609199e52c26e0e971fa26f14d3c0ddcc9d8747b5fb8` |
| `Build/audit-fixes/native-media-drag-handlers-production-retry-private/manifest.json` | `a3dde61036621e685858358bcf42019ba28b70b1fdebcc87f05962034c8b51f7` |
| `Build/audit-fixes/native-media-drag-handlers-production-retry-private/prepared-inputs.json` | `39b3abc8eb7179c34cf8db9adffa2c6328ab05668238cb3091e017df0bacfe31` |
| `Build/audit-fixes/native-media-drag-handlers-production-retry-private/provenance.json` | `07a519615f6b6f3d38ebc1c7f071b098e5129bd469f4d2be92643f5e1f58c5ef` |
| `Build/audit-fixes/native-media-drag-handlers-production-retry-private/smoke-screenshots.log` | `b959bf58e8901de8e5ee9131b72eb4a8c26e64a1efde46cc5c6292561ea5b301` |
| `Build/audit-fixes/native-media-drag-handlers-production-retry-supervisor-completion.json` | `7ff5fe562c8bbbe41102640ba97e07957205edd0e82d468fd9442cc08d44dac9` |
| `Build/audit-fixes/native-media-drag-handlers-production-supervisor-completion.json` | `2253b410161f2e13d67e5e53e8c9129012feebb272aeaa6c5189e3e034f3f3bf` |
| `Build/audit-fixes/native-media-drag-handlers-scratch-cleanup.json` | `709fe44783b258912f6f348abff45a687d5b0dcb9fea3cd269e015289a8e396d` |
| `Build/audit-fixes/native-media-drag-handlers-source-preparation.json` | `1eef033bab3e417d26ba2264754a88007acae8e78ca9df493ecc8401151b3b4d` |
| `Build/audit-fixes/native-media-drag-handlers-source-review.json` | `6054c16ec2a26ddbd61bb8390239ba98bb4cc79584c56d3ae648485e9aefc372` |
| `Build/audit-fixes/native-media-drag-handlers-verification-plan-v2.json` | `557dd3a92f888864f8c546524e4465822a464f35397f413015377e967724a440` |
| `Build/audit-fixes/prepare_native_media_drag_handlers_audit_docs_v2.py` | `0b629140ba32a4b2ab6f603df1714a31b4d639bc28dd780d0c59f1bc8bd31127` |
| `Build/audit-fixes/prepare_native_media_drag_handlers_audit_docs_v3.py` | `95ff91f274f2516cb9b9d4a23c9ef11bbcf6bf1410cdd885227416a7c238e4c4` |
| `Build/audit-fixes/supervise_native_media_drag_handlers_v1.py` | `c53a2333dd74b499dacf4011b9648a37d6a17fb99db19a13b9533cd4193baab9` |
| `Build/audit-fixes/supervise_native_media_drag_handlers_v2.py` | `f6225e67b93d3a3bfcda2c97e65862c1f136180cf3421b62931e6d20236fcb77` |
| `Build/audit-fixes/verify_native_data_transfer_entry_evidence_v2.py` | `297374b56963a2a24cfec74737cf7904d13c95d76f6acb834d2e9dcaa8873a68` |
| `Build/audit-fixes/verify_native_media_drag_handlers_evidence_v1.py` | `f0efd70889f81d7f9060e3e63397b1aaec4394f7a595f8f1bb38a97ef8af1c14` |
| `Build/audit-fixes/verify_native_media_drag_handlers_v1.py` | `f63cc33d1c907608e1b1f9192132d992cf89a3d8cbc288f9657cba0488422407` |
| `Build/audit-fixes/verify_native_media_drag_handlers_v2.py` | `3e1879b3a062c767716d06851e567af453a44f19be94e171d4a3ccb16b83fb3a` |

Earlier sections retain their own code pins and then-open media drag-handler
statements as history. Physical Cocoa/Page drag production, automatic store
transitions/default actions, weak and foreign WindowProxy/function-realm dispatch,
the complete HTMLElement handler hierarchy and upstream FIXME setDragImage remain
open. Generic EntriesAPI callbacks and directory/path traversal retain their
previous limitations. Existing native play() Promise work stays completed under
its earlier evidence. The browser still uses JavaScriptCore. This slice establishes
no full LibJS, EntriesAPI, FileAPI or drag-and-drop parity. The historical finding
ledger remains 32 fixed / 25 partial / 9 open.
