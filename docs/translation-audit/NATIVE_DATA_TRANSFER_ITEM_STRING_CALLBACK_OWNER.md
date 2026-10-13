# Native Window DataTransferItem.getAsString

Implementation: `e3ff95fd10217c6c7b1ee54d6a0e2c8c79ca875f`. Immediate parent and baseline: `967d189168f670b746057488e962965f68fca1e8`.
Upstream source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

## Source behavior and native ownership

DataTransferItem.idl declares a required nullable FunctionStringCallback with
one DOMString argument and an undefined return. The operation has the native
name getAsString, length one, writable/enumerable/configurable metadata and no
constructor behavior. The generated binding validates the actual item receiver
before its required argument check. Null and explicit undefined convert to a
null callback; no argument throws a fresh TypeError with the source message
"getAsString() needs one argument". A non-null argument must be callable before
the implementation checks mode or kind. Primitives, handleEvent objects,
prototype spoofs and non-callable proxies are rejected without coercion or
property/prototype traps. Callable proxies, including revoked callable proxies,
are accepted; their invocation behavior is deferred until the actual task.

A null callback returns immediately. Read/write and read-only text items expose
raw UTF-16 data through the added string_data_utf16 snapshot operation. Protected,
removed, disassociated and File items do not schedule a call. Empty text still
schedules a callback. The legacy V get_as_string byte-string callback body remains
unchanged. No file data is converted into text and no public constructor or
mutable callback property participates in native receiver identity.

The pinned C++ queues Task::Source::Unspecified with neither a specific EventLoop
nor a Document. The translation therefore queues the global main-thread loop,
with document none, and snapshots data before queuing. Later setData replacement,
removal, protection or disassociation cannot cancel or replace this captured
value. The task invokes the existing actual WebIDL callback adapter once, with
one raw DOMString argument and an omitted this argument: strict callbacks see
undefined, while sloppy callbacks receive their own global object.

The existing callback adapter prepares the relevant runtime's script realm and
the incumbent settings captured at registration, then balances both contexts.
There is no added can_run gate at task execution. Native owner fixtures check
current/incumbent settings, the real translated VM execution context, balanced
script/callback depths. Standalone browser fixtures make realm.can_run false;
real MAIN Page-owned fixtures disable their actual owner's scripting preference
with Page.set_is_scripting_enabled(false), verify the do_not_run decision and
still execute the generic callback. The owner preference is restored before
BrowserApp flushes state. These fixtures carry
actual native DragEvents from parsed video to script-created audio listeners,
retain cancellation/identity through redispatch and flush asynchronous callback
DOM mutations through BrowserApp.poll_javascript_tasks.

Source get_as_string discards the callback completion. The task likewise ignores
ordinary returns, thenables, returned Promises and thrown values without Promise
Resolve, then access or exception reporting; an abrupt callback does not stop
later queued calls. Pending native records keep actual JSC functions rooted
until task completion, then release both callback and result/exception roots.
The generic webidl_callback abrupt path now transfers its original JSC exception
root into the retained WebIDL value instead of leaving a second protect behind.
Repeated throwing callbacks return the actual runtime's protected-value count
to its baseline. Runtime.close clears pending records and all roots; later
queued tasks skip the closed runtime before touching its released context.

Source references: HTML/DataTransferItem.{idl,h,cpp}, HTML/DragDataStore.h,
HTML/EventLoop/Task.h, WebIDL/CallbackType.h, WebIDL/AbstractOperations.cpp,
LibJS/Runtime/ErrorTypes.h and the binding generator's operations, arguments,
nullable/callback conversion and JS-value conversion paths. Exact selected
upstream source hashes remain authenticated in the test manifests.

The public JSC error formatter describes non-callable objects as [object Object],
where the upstream engine uses native class names. This diagnostic spelling is
an explicit bounded deviation. Foreign-global callback function realms and weak
WrapperWorld ownership remain unimplemented; the checked callbacks belong to
one real owner runtime and its strongly cached native registry.

## Actual verification and retained failures

| Run | Outcome |
| --- | --- |
| Parent baseline | 2 files compile; 6 initial availability guards fail; later assertions uncredited |
| Final focused | 6 files / 15 cases pass, including all 8 new cases |
| Default / GC disabled | 15 files / 47 cases pass in each mode |
| Optimized | 3 new files / 8 cases pass with -prod -gc none |
| Production | Signed startup, two pixel-exact asynchronous pages, eleven screenshot smoke cases pass |

The first parent baseline uses a non-raw V literal containing JavaScript
surrogate escapes and fails browser fixture compilation. The next revision
corrects that literal but exposes a private html.TaskQueue.tasks access in a
browser fixture helper; it also fails compilation. The public task-selector/
cutoff fixture correction permits the actual compiled availability baseline.
All original freezes, sources, logs, manifests and completed failed terminal
receipts remain preserved (`baseline-v1`, `baseline-v2`); no failed batch earns passing
credit. A later read-only fixture review replaces a captured local array header
with a heap recorder in the public selector helper before the first focused
execution. Parent availability guards never reach that deferred selector; this
change is not described as a runtime failure. Final successful runs use their
authenticated frozen revision from the plan. Implementation hashes are unchanged
from the first freeze. The new
core fixture requires the added V snapshot operation and earns no parent
baseline credit.

The original focused-v4 run passes 5 files and fails 1 owner file
(6 total); it has no passing batch credit. Its first owner case sets the
standalone realm.can_run flag to false and incorrectly expects Page-owned
can_run_script_for_settings to return do_not_run. The actual result is run:
real owner settings intentionally ask the Page preference and ignore standalone
realm fallback flags, as existing scripting-owner tests already establish.
The corrected fixture disables the actual Page scripting preference with the
public owner setter, restores it after task delivery and in deferred cleanup,
and keeps all implementation hashes unchanged. The original frozen-v4 source,
failing assertion, complete log, manifest and actual terminal receipt remain
authenticated through evidence.failed_attempts. Final successful tags follow the
sealed plan rather than crediting this failed batch.

Successful run tags and completed terminal receipts are selected by the sealed
verification plan and authenticated individually; each run's case counts are
recounted from this exact code's test functions. Counts are not copied from
older item-addition evidence. Original unexecuted production inputs and their
preparation records remain preserved when the final frozen fixture changes.

Private production passes all 10 internal stages, with detached
prepare/production/provenance child exit codes [0, 0, 0].
The two actual browser pages stay non-green until their native queued callbacks
run and satisfy raw-data, identity, gate and callback checks. The owner page
exercises parsed video and script-created audio drag listeners and redispatch.
The final screenshots are pixel-exact. All eleven configured smoke cases pass;
8 are exact and 3 retain their established tolerance residuals.
These pages invoke the native JSC binding and execute queued HTML tasks.

Tests use the pinned old compiler and enable-globals in the clean committed
private source. All 5,050 Git input files match their committed bytes, and
3,185 preceding artifact hashes remain authenticated,
including previous private sources and closed evidence. Test compiler identity
contains two inputs; production also authenticates its V_BIN wrapper. Production
uses exact committed recipes with isolated source/output/capture substitutions,
cached native/Rust inputs, strict signing and authenticated source markers.
Its historical frozen bundle is `Ladybird.app`; canonical Vox branding and tooling
working changes remain independently preserved. Cleanup detaches only the
verified owned RAM volume and retains private sources, binaries and all logs.

## Evidence, inventory and remaining work

Consolidated sealed evidence: `Build/audit-fixes/native-data-transfer-string-callback-evidence.json`,
SHA256 `e4f63178cdce85059971b77f5cd8b591dcf18356b72f93f05ddeb35910fdcd81`. It authenticates final frozen inputs, the
verification plan, completed successful and failed terminal receipts, signed
production provenance, prior artifacts and the exact owned cleanup receipt.
Inventory: `Build/audit-fixes/native-data-transfer-string-callback-inventory-current.json`, SHA256 `61b814a88cb00769fd88dcb29f12b4b93fd0c80e582b4a74fdbb5e33309cead5`.

The independent physical recount records 78 owners / 2,225 assigned files,
433,242 implementation / 160,313 test V LOC.
Only html/data_transfer.v (+11 lines) and its new core test (+41 lines,
one added assigned file) contribute to the feature's package delta. The other
7 browser/root paths remain excluded. Actual-parent and previous-inventory
maps separately attribute any intervening assigned changes. These physical
counts include comments/blank lines and establish no runtime or parity credit.
A separate inventory commit refreshes current totals; historical paragraphs,
older code pins and dated tables keep their own records.

| Retained record | SHA256 |
| --- | --- |
| `Build/audit-fixes/native-data-transfer-add-inventory-recount.py` | `80edd532fbca24fb51b276b5a5cf77c32e55005cc8ceafb080e78ed3ddec324f` |
| `Build/audit-fixes/native-data-transfer-string-callback-audit-helper-preparation.json` | `d35f3fc38fbbea7a92e29c561c2abbf979a13d1a03751d31af876ec35bd4e0d0` |
| `Build/audit-fixes/native-data-transfer-string-callback-baseline-v1-exit-receipt.json` | `ebc5010d17522839fbd9510225bc0aa34cf28aa0b9607d244c71e295183a2446` |
| `Build/audit-fixes/native-data-transfer-string-callback-baseline-v1-manifest.json` | `62a322f65f7b4b545d1328aab1bf4e30e628f65a986cc6181b9057a038268cf9` |
| `Build/audit-fixes/native-data-transfer-string-callback-baseline-v2-exit-receipt.json` | `542e31fa0f75af76977f86dc749947cc3d74e69f6867d805628c591fd9efe36b` |
| `Build/audit-fixes/native-data-transfer-string-callback-baseline-v2-manifest.json` | `e91c11eed86dab055ad70f0df4c73f9dae52d74e0657c2d7686ab8dcd2e4447c` |
| `Build/audit-fixes/native-data-transfer-string-callback-baseline-v3-exit-receipt.json` | `f9ed602b832d1b4f8f09e490ea838c3c6d88f13c345056cdb9d4e06e358d8596` |
| `Build/audit-fixes/native-data-transfer-string-callback-baseline-v3-manifest.json` | `5f36f6bfaea797310c3f2069aa70b1d88cf046896525281fb3e829119f8c2a13` |
| `Build/audit-fixes/native-data-transfer-string-callback-default-exit-receipt.json` | `d103e847c6b6e4f3d194042d2dd8fd9fa5e901953bfe249eac56ca5a068cbc80` |
| `Build/audit-fixes/native-data-transfer-string-callback-default-manifest.json` | `af8dd3d9fa442c535fdb541b0360b87f489822250add1489eaa32a81e9ee24c8` |
| `Build/audit-fixes/native-data-transfer-string-callback-evidence.json` | `e4f63178cdce85059971b77f5cd8b591dcf18356b72f93f05ddeb35910fdcd81` |
| `Build/audit-fixes/native-data-transfer-string-callback-focused-v4-exit-receipt.json` | `d88594d2464463604c7c10dd097ea98530127cf74a81e27dafa4fb2ab53c571d` |
| `Build/audit-fixes/native-data-transfer-string-callback-focused-v4-manifest.json` | `ac0927535264f4721e511e9a93fd515e6c28a7b4495686c067f3f2c1a1de3661` |
| `Build/audit-fixes/native-data-transfer-string-callback-focused-v4.log` | `868a2e9fece6741bb12b5f63ca5d8f8cd70746e6fb68cd0dd11c15e66f5eb4fa` |
| `Build/audit-fixes/native-data-transfer-string-callback-focused-v5-exit-receipt.json` | `2d3f334bbfe9e2dc983062a2655d0c9f9777502a83dc24b8004044e519411bc4` |
| `Build/audit-fixes/native-data-transfer-string-callback-focused-v5-manifest.json` | `115d7eeda47225c4a3038e9efb306466f4ce92fcd7fd55bf71ea27f7fa5e22b4` |
| `Build/audit-fixes/native-data-transfer-string-callback-frozen-v1.json` | `400b05e7939af5303c3139787add8b1fb261fbc74ed904d5ccd6d78cff4bb2b1` |
| `Build/audit-fixes/native-data-transfer-string-callback-frozen-v2.json` | `e19c0dbc74e220f07f1c91018a5571b1861be0f2d6576425daf1f65ffd8ae9a7` |
| `Build/audit-fixes/native-data-transfer-string-callback-frozen-v3.json` | `466ec7945a9f14b24ae6bf5f2579d95722c1962cf2349bf6c5f005f4a2d55d43` |
| `Build/audit-fixes/native-data-transfer-string-callback-frozen-v4.json` | `2a8d3f8dfebe8aedf65b4382208c2fadbd2ba5d58175a815f4bd77fa2e50bc2d` |
| `Build/audit-fixes/native-data-transfer-string-callback-frozen-v5.json` | `6959667ebd44f016e04ed735cba7a1e7c4a5f844abf658515ccbcf2f8aa6f5a1` |
| `Build/audit-fixes/native-data-transfer-string-callback-gc-none-exit-receipt.json` | `d17dc2cb2f1da65d080f2ddd914ad0d55d97648007bec611ba8dd0d5997e4b11` |
| `Build/audit-fixes/native-data-transfer-string-callback-gc-none-manifest.json` | `06bd07a69d969571d2cab867ae5f6338119af800d9f46e260756c267c8928b38` |
| `Build/audit-fixes/native-data-transfer-string-callback-inventory-actual-exit.json` | `b8a37209385e418256e4ae6dee09d1a6b77cd11517210a865c0a77351ab013e1` |
| `Build/audit-fixes/native-data-transfer-string-callback-inventory-current.json` | `61b814a88cb00769fd88dcb29f12b4b93fd0c80e582b4a74fdbb5e33309cead5` |
| `Build/audit-fixes/native-data-transfer-string-callback-inventory-recount.py` | `50efab66169eee529050bc2e02bf09fb1f134b417f9f8a28f2a65bf35810b3b5` |
| `Build/audit-fixes/native-data-transfer-string-callback-optimized-exit-receipt.json` | `354331c7d43760892daefde27d8922609a84c8d341418fb9f88498fa0b280245` |
| `Build/audit-fixes/native-data-transfer-string-callback-optimized-manifest.json` | `07d4d90f2eb3c74d71e4c9ecf376107c0b664a74e04bc579e71b7e3e923962f3` |
| `Build/audit-fixes/native-data-transfer-string-callback-prior.json` | `9fd2a238730b8ddbe69842ecc4857142d501443fb9f28b3975dec0c093d1097f` |
| `Build/audit-fixes/native-data-transfer-string-callback-production-private/callback-defaults-pixel.log` | `2a6ca0315222b6e48d4f501726a50a702cf5b0cdc4bd06baa997fdc5c1800b28` |
| `Build/audit-fixes/native-data-transfer-string-callback-production-private/callback-dispatch-pixel.log` | `ec5007f2762de9cf0e389afee38cb2512cdcc41629ec1f4fae5cc01f35f11b61` |
| `Build/audit-fixes/native-data-transfer-string-callback-production-private/manifest.json` | `3e991bbd7849d4c9cdd0d1d004a0cdae12728d5b9df4461c9cf3c68a83e77758` |
| `Build/audit-fixes/native-data-transfer-string-callback-production-private/prepared-inputs-v2.json` | `e6b30f7d05e25b8952bc8ea6a61b18f535506fab508bc32d1e1916bcfdbd282d` |
| `Build/audit-fixes/native-data-transfer-string-callback-production-private/prepared-inputs-v3.json` | `be46a112e7b5ae457bdef2ba19ae038484d8c084106251ddf79012408a37464e` |
| `Build/audit-fixes/native-data-transfer-string-callback-production-private/prepared-inputs.json` | `5f1bc169b6f1c9ef7e4503ab9606fdeca4da5e889e0b9988e2746837734b4171` |
| `Build/audit-fixes/native-data-transfer-string-callback-production-private/provenance.json` | `4a340d51fd151d74466441d6be8298726ed5a4358994cb7f6017ecf51264f69e` |
| `Build/audit-fixes/native-data-transfer-string-callback-production-private/smoke-screenshots.log` | `662cf66f8051ab1e012f93abced48c80751dcf5acd9b9460b5f931430736ff21` |
| `Build/audit-fixes/native-data-transfer-string-callback-production-supervisor-completion.json` | `4b35b89f0ac2b6834954a0500021ae73ead52f5b130ed11dcebca9663fd7c563` |
| `Build/audit-fixes/native-data-transfer-string-callback-scratch-cleanup.json` | `03acc6f223d760d782068bb5404246c2ea2f2d09bc5344d0621114f87716b0ba` |
| `Build/audit-fixes/native-data-transfer-string-callback-source-preparation.json` | `79ce8fb612a148ff85e395b937b1da39d35ffed3906b615b4398a249ad63cb66` |
| `Build/audit-fixes/native-data-transfer-string-callback-verification-plan.json` | `b794b3a70d3c2db541eb41df4c1057c19e5b047c694ac5237def6d1c165eb877` |
| `Build/audit-fixes/prepare_native_data_transfer_add_docs.py` | `f40ddaabccac1744785dfd3042f62e6ac8ccf853678339b220b1c13781dd4b29` |
| `Build/audit-fixes/prepare_native_data_transfer_string_callback_audit_docs.py` | `7294a895f67195c886493515a72c3536370760f8ccdab2c448e986cd7989a841` |
| `Build/audit-fixes/prepare_native_data_transfer_string_callback_audit_docs_v2.py` | `72cfdf17afdaa37a18f3afb35536740df91e475987e1f7986b004daaea9d858d` |
| `Build/audit-fixes/supervise_native_data_transfer_string_callback_v1.py` | `b43428262b55593a7176469320c051377cd0d8e8b55872390e34de2a6f594927` |
| `Build/audit-fixes/supervise_native_data_transfer_string_callback_v2.py` | `50de6b4f5bb9660df61563ce7d211d63dfb4058bb76de490d9ffc2730e8cdc52` |
| `Build/audit-fixes/supervise_native_data_transfer_string_callback_v3.py` | `d1faaf623c5c9a6f172bfa606034c00d678ab5533432644b18801b0bc0855b1a` |
| `Build/audit-fixes/supervise_native_data_transfer_string_callback_v4.py` | `9f1bb7d2505c4b5d841cc2c7af542da131922c086d860deafb772375eafbaea3` |
| `Build/audit-fixes/supervise_native_data_transfer_string_callback_v5.py` | `7b4c0c1756696989855aeeb95d6f0045f27f7f6f178e2949129542e7bc621cff` |
| `Build/audit-fixes/verify_native_data_transfer_string_callback_evidence.py` | `0c7d2e26888015d41f66e3c24169cd67c78ea010f8922ebd1c4c2037312bbbc6` |
| `Build/audit-fixes/verify_native_data_transfer_string_callback_v1.py` | `a7aa971f2487197426fd1d8b5eba94a69bae651b1b08ad220253b5856c066585` |
| `Build/audit-fixes/verify_native_data_transfer_string_callback_v2.py` | `1e1a24242d2bf86851674ce34e7d0d2974ada1e3480301e60cc0e62eecd468a2` |
| `Build/audit-fixes/verify_native_data_transfer_string_callback_v3.py` | `8a1ae4146d5bb56db3bff37b14465c819b56c602ae2b1c735e97ab6bf7241010` |
| `Build/audit-fixes/verify_native_data_transfer_string_callback_v4.py` | `933e052c72afe87e39a7ad765f619fb2738b3922658200619beb6d96b38955a4` |
| `Build/audit-fixes/verify_native_data_transfer_string_callback_v5.py` | `f835d59c8e532f39e749e30b16c2ba5d79515d2913f9d5dd84244f0d26edfcf7` |

Earlier item-addition sections remain explicitly pinned to `bbe330a8`; their
then-open callback statements are historical. webkitGetAsEntry, setDragImage,
physical Cocoa/Page drag generation, automatic store transitions/default actions,
media ondrag handlers, foreign WindowProxy/function-realm handling and weak
WrapperWorld ownership remain open. The browser still uses JavaScriptCore.
This slice establishes no full LibJS, FileAPI or drag-and-drop parity. The
historical finding ledger remains 32 fixed / 25 partial / 9 open.
