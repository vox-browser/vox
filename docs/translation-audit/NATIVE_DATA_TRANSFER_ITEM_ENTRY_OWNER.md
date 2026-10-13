# Native Window DataTransferItem.webkitGetAsEntry / FileSystemEntry

Implementation: `fdc13cca49e6004577c78e6148677b7a2d742bf4`. Immediate parent and compiled availability baseline:
`fffc5c57354dba7bd1a6ec3236cc7a5a6fcb40a3`. Upstream source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

## Source behavior and native identity

DataTransferItem.idl declares webkitGetAsEntry with no arguments and a nullable
FileSystemEntry return. The generated operation brands its actual item receiver
first. The native function has length zero and writable/enumerable/configurable
metadata, rejects construction and ignores extra arguments without conversion
or author property access. Read/write or read-only file items produce a fresh
base FileSystemEntry object per call. Protected, text, removed and disassociated
items return null. Removing earlier items reindexes surviving items while their
actual wrapper identity remains stable. Entry snapshots retain their own name
after later store protection, removal or disassociation.

The pinned producer unconditionally selects EntryType::File, including empty and
directory-looking filenames. It performs UTF-16 to UTF-8 to ByteString, then
FileSystemEntry stores UTF-16 again. The source conversion defaults allow lonely
surrogates in both directions. The generated USVString return path wraps this
stored primitive directly, without input-style scalar-value normalization.
Accordingly, raw stored lone surrogates, NUL units and valid pairs remain exact
through create_utf16/name_utf16 and the native getter. Existing public new File
construction separately normalizes its filename input before that file enters
the drag store; this slice does not change that earlier conversion.

FileSystemEntry is a Window interface with native readonly isFile/isDirectory/name
getters. Getter length is zero; descriptors are enumerable/configurable with no
setter. The interface constructor is unavailable. Its captured error factory
uses Runtime's original intrinsic TypeError even if an author replaces TypeError
before the late Window installation. File/directory metadata is mutually exclusive.
The actual-record registry caches one rooted wrapper per typed entry record;
fresh DataTransfer producer records receive distinct wrappers. Public constructors,
File instance/prototype getters, globalThis replacement and toPrimitive hooks
cannot substitute for these native identities. Exact receiver lookup rejects
prototype spoofs, proxies and foreign wrappers without unwrapping or property
traps. Close clears record/wrapper maps and releases actual JavaScript roots;
direct embedding calls after close reject before touching a dead engine context.

FileSystemEntry fullPath, filesystem and getParent are marked FIXME upstream.
The generated engine's private diagnostics do not install public JS members.
They therefore remain absent from the prototype, and reads are undefined; the
translation adds no throwing public stubs or invented filesystem/path behavior.
Direct typed directory fixtures check metadata only. Generic entry callbacks,
directory traversal and physical filesystem entry production remain open.

The real owner fixtures attach a translated Page and parsed video, create audio
through author script, dispatch a trusted native DragEvent and redispatch its
same actual wrapper from JavaScript. They retain cancellation, currentTarget,
timestamp, native DataTransfer/list/item identity and Window event state. Public
File and string additions exercise the real producers; native V store inputs
exercise raw names and protected/read-only modes. Host probes inspect relevant
and incumbent settings, callback/script depths and the actual translated VM
context, with balanced cleanup. BrowserApp flushes the resulting live DOM changes.

Source references: HTML/DataTransferItem.{idl,h,cpp}, HTML/DragDataStore.h,
EntriesAPI/FileSystemEntry.{idl,h,cpp}, generated operation/attribute/JS-value
conversion paths and AK UTF-16/UTF-8/ByteString defaults. Exact selected upstream
source hashes remain authenticated in the run manifests. Foreign WindowProxy
and function-realm dispatch and weak WrapperWorld ownership remain separate
runtime work; the checked wrappers belong to real strongly cached owner registries.

## Actual verification and frozen revisions

| Run | Outcome |
| --- | --- |
| Parent baseline | 2 files compile; 6 initial availability guards fail; later assertions uncredited |
| Final focused | 7 files / 21 cases pass, including all 12 new cases |
| Default / GC disabled | 15 files / 49 cases pass in each mode |
| Optimized | 5 new files / 12 cases pass with -prod -gc none |
| Production | Signed startup, two pixel-exact entry pages, eleven screenshot smoke cases pass |

| New focused test file | Actual functions in committed code |
| --- | ---: |
| `browserjs/data_transfer_item_entry_binding_test.v` | 4 |
| `main_data_transfer_item_entry_owner_test.v` | 2 |
| `browserjs/file_system_entry_binding_test.v` | 2 |
| `entriesapi/file_system_entry_utf16_test.v` | 2 |
| `html/data_transfer_item_entry_test.v` | 2 |

The successful runs follow the sealed plan and final frozen map; every case
count is recounted from exact committed test functions and completed receipts.
The compiled parent baseline checks only its public availability guards. The
new typed/core adapters and later assertions earn no parent baseline credit.
Initial and later frozen source archives retain their own hashes and receipts.
Final implementation hashes match the earliest captured implementation freeze. Changed owned paths across the initial/final freezes: `browserjs/file_system_entry_binding_test.v`.

| Retained failed attempt | Actual result | Recorded reason |
| --- | --- | --- |
| `focused-v1` | 7 files / 21 cases; test exit 1, actual runner exit 1; 6 files pass / 1 fail | One direct native registry fixture checked the generic V JavaScriptValueException adapter message instead of its actual typed JavaScript value; all original inputs and failed results are preserved without batch or later-assertion credit. |

The original focused-v1 run passes 6 files and fails
1 FileSystemEntry registry fixture (7 total), with no passing batch
credit. Its foreign-wrapper assertion expects the native TypeError text through
IError.msg(), but JavaScriptValueException.msg() supplies a generic bridge message.
The corrected fixture inspects the retained actual JavaScript exception value,
checks the saved intrinsic TypeError and exact message, and releases that root.
The original frozen source, complete log, manifest and actual failed terminal
receipt remain preserved. Final implementation hash changes, if any, are reported
separately by the initial/final frozen comparison above.

Private production passes all 10 internal stages and actual
prepare/production/provenance child exit codes [0, 0, 0].
The two actual browser pages remain non-green until public native entry reads,
metadata, identity, retained snapshots, poisoned globals/receivers and owner
drag listener/redispatch checks succeed. Both rendered results are pixel-exact.
All eleven configured smoke cases pass: 8 are exact and 3 retain their
established tolerance residuals. The pages use actual JSC/native records and
public APIs rather than a FileSystemEntry shim or synthetic entry model.

Tests use the pinned old compiler with enable-globals in the clean committed
private source. All 5,058 exact Git input bytes and
3,525 preceding artifact hashes remain verified.
Four earlier private sources remain authenticated: `e3ff95fd` (5050 Git inputs), `bbe330a8` (5046 Git inputs), `e775be45` (5042 Git inputs), `b59e211c` (5032 Git inputs).
Test compiler identity contains two inputs; production adds its V_BIN wrapper.
Production uses exact committed recipes with isolated source/output/capture
substitutions, shared authenticated native/Rust inputs, strict signing and source
markers. Its historical frozen bundle is `Ladybird.app`; canonical Vox branding and
tooling working changes stay independently preserved. Cleanup detaches only the
verified owned RAM volume and retains private sources, binaries and all logs.

## Evidence, physical inventory and remaining work

Consolidated sealed evidence: `Build/audit-fixes/native-data-transfer-entry-evidence.json`,
SHA256 `d2fb80d3298f1714ab42ecdee1feccaee2ab06bf8979c28cef7a0a35cb8cb99f`. It authenticates the final frozen map, earliest
source revisions, plan, actual successful and optional failed terminal receipts,
signed production provenance, previous artifacts and owned cleanup receipt.
Inventory: `Build/audit-fixes/native-data-transfer-entry-inventory-current.json`, SHA256 `f3062da8a0c0354822688a690594c6497ce8771933ef566068f0229a61e35a26`.

The independent recount records 78 owners / 2,227 assigned files,
433,263 implementation / 160,393 test V LOC.
Only four assigned paths contribute to this slice: EntriesAPI
+21 implementation / +27 test lines
with one added focused test file; HTML +0 implementation /
+53 test lines with one added focused test file. The HTML producer's
same-line replacement changes its hash while adding no implementation lines.
The other 9 browser/root implementation and test paths remain excluded.
The prior e3ff95fd inventory and actual feature parent have identical assigned
hashes/counts; no intervening assigned feature is counted. Physical counts include
comments/blank lines and establish no runtime or parity credit. A separate
inventory commit refreshes current totals. Historical e3ff95fd, bbe330a8, e775be45,
b335958e paragraphs and dated tables remain pinned to their original records.

The EntriesAPI status document now names the canonical vox2 workspace, keeps its
2026-08-16 table (44 implementation / 32 test lines) and transcript as explicit
history, and appends current committed counts and native binding evidence.

| Retained record | SHA256 |
| --- | --- |
| `Build/audit-fixes/native-data-transfer-entry-baseline-v1-exit-receipt.json` | `8c1b410b0b9bf8bf17ffda4075e9536deaed229f6b37f3350d4d4caba1fb388b` |
| `Build/audit-fixes/native-data-transfer-entry-baseline-v1-manifest.json` | `38af05f4a04c26fb76cd8f4bfe1aa561d5280010ad1e636aecfef22a82e1a75b` |
| `Build/audit-fixes/native-data-transfer-entry-default-exit-receipt.json` | `0585caaacfdc9861419d9436997d4b4f28960c9e6ad98d74ce69c9268fb885c0` |
| `Build/audit-fixes/native-data-transfer-entry-default-manifest.json` | `08d290756d7091166fcca7ec970c1ac9940e8f0436565ef3c9046da7df688990` |
| `Build/audit-fixes/native-data-transfer-entry-evidence.json` | `d2fb80d3298f1714ab42ecdee1feccaee2ab06bf8979c28cef7a0a35cb8cb99f` |
| `Build/audit-fixes/native-data-transfer-entry-focused-v1-exit-receipt.json` | `38283ea8145a82887b3dadd521baf19c6fd9aaff2cbfb5190ddc5eaa97d879a1` |
| `Build/audit-fixes/native-data-transfer-entry-focused-v1-manifest.json` | `29bd1274d0a8cf905bb12f3c4b1f21bce142b02fc7392db9bf8584132ed46894` |
| `Build/audit-fixes/native-data-transfer-entry-focused-v1.log` | `1b7c583708456cf5c25d94d207f51a9ebc5b1262ded8f64948f1e198c813647f` |
| `Build/audit-fixes/native-data-transfer-entry-focused-v2-exit-receipt.json` | `bd8deff0c78edab4960b689015a1df77bca02213d21b71dfd4b565e2cccf34fb` |
| `Build/audit-fixes/native-data-transfer-entry-focused-v2-manifest.json` | `201556d85dc45de7e3158742d5b86ca9ff5144f44e9af7cbfd82b30f174bfdb0` |
| `Build/audit-fixes/native-data-transfer-entry-frozen-v1.json` | `84c753419f96f3ac152523a8d4212cbf241dedfdfc5bbab5046bb424be325fc7` |
| `Build/audit-fixes/native-data-transfer-entry-frozen-v2.json` | `b10927c1860dc53a0c1f481454a3a69d57b46abe9bbeeff47d81b0600950b6bb` |
| `Build/audit-fixes/native-data-transfer-entry-gc-none-exit-receipt.json` | `cfa778555cd4208a44a5672f87be318a13bbe067dd0354f1fdcecd81a21bb808` |
| `Build/audit-fixes/native-data-transfer-entry-gc-none-manifest.json` | `1f7334b6bc140987ea85aa7b1eeab979af281cce06d425bcec05af77a50e260b` |
| `Build/audit-fixes/native-data-transfer-entry-inventory-actual-exit.json` | `e785f41ed891f720bf42e5f4486bb9fba40ebe6f7806e3d9ec5a722af3193478` |
| `Build/audit-fixes/native-data-transfer-entry-inventory-current.json` | `f3062da8a0c0354822688a690594c6497ce8771933ef566068f0229a61e35a26` |
| `Build/audit-fixes/native-data-transfer-entry-inventory-recount.py` | `9079a2c6ce8a952728f54575185782c1c102d2edd97ed89eacb34d6421e419c1` |
| `Build/audit-fixes/native-data-transfer-entry-optimized-exit-receipt.json` | `cf9f2ac3e9fc0c3c6dd6f9f84bf917a5507e4ef3f5984bd73952b715257c5488` |
| `Build/audit-fixes/native-data-transfer-entry-optimized-manifest.json` | `5658621b5bb2bbd70109612b792e703e1d8f635d95b620a8ce622562946ac821` |
| `Build/audit-fixes/native-data-transfer-entry-prior.json` | `b1c4e72989ee5570a76a5efcbf068685d3a0e09cecf0da80ed69331311f85b78` |
| `Build/audit-fixes/native-data-transfer-entry-production-initial-inputs/preservation-record.json` | `8143bc6477537c8ca53ae88615e8719cb9377e0b93ab9ddbc4b4e4307e67b825` |
| `Build/audit-fixes/native-data-transfer-entry-production-private/entry-defaults-pixel.log` | `0d43baa1806b821d4e4e18493f1262878efef2ecf330d460aa0ecf24445f2093` |
| `Build/audit-fixes/native-data-transfer-entry-production-private/entry-dispatch-pixel.log` | `767e6ecb8b5c4b7a6e213cbb1d8bcfea897bed0700dff683b57bd0f955761c22` |
| `Build/audit-fixes/native-data-transfer-entry-production-private/manifest.json` | `40519f70b82076ae3de334f3e28d27a0c9d5d7a97abfe087030e0acbfa37c99b` |
| `Build/audit-fixes/native-data-transfer-entry-production-private/prepared-inputs-v2.json` | `351989dd9d738cc446c87b35ab9285fabc6909b0b38f12c74ecd8a5e6bffead6` |
| `Build/audit-fixes/native-data-transfer-entry-production-private/prepared-inputs.json` | `d325d5994e31cb9c944c9cc77aecb433ffe24f07d79d8c4f4aa3c473db6cf7dd` |
| `Build/audit-fixes/native-data-transfer-entry-production-private/provenance.json` | `a0837369951c11fac9b9bb9476f7459ab939a142e4d6cfa802a2665d1807f49e` |
| `Build/audit-fixes/native-data-transfer-entry-production-private/smoke-screenshots.log` | `7ab94cb817cffbeb320b987c3fb78d9ea6278d6f153c799f15d70791ccb4caf6` |
| `Build/audit-fixes/native-data-transfer-entry-production-supervisor-completion.json` | `00eb9ed9f5fefd5f5937bae129cf60536f0a89590c927838c9987a0f8682052e` |
| `Build/audit-fixes/native-data-transfer-entry-scratch-cleanup.json` | `a2952441ba44ad55c916a83bcb594bfa3882e5c346852411d903f5542109692e` |
| `Build/audit-fixes/native-data-transfer-entry-source-preparation.json` | `be23a7c86c72e003552bcb1cce2b51e5f2b57baf82f94d77e95a2d5615498f1c` |
| `Build/audit-fixes/native-data-transfer-entry-verification-plan-v2.json` | `b49c5247ba209cf95dbc79c172551c62cb7ca948c40b5917e5c5ec323bb54c61` |
| `Build/audit-fixes/native-data-transfer-string-callback-inventory-recount.py` | `50efab66169eee529050bc2e02bf09fb1f134b417f9f8a28f2a65bf35810b3b5` |
| `Build/audit-fixes/prepare_native_data_transfer_entry_audit_docs.py` | `9fd8fb9d5295bd19b84d4308ba3f17055ee77e60f6bd8c293c3a672750f2239c` |
| `Build/audit-fixes/prepare_native_data_transfer_string_callback_audit_docs_v2.py` | `72cfdf17afdaa37a18f3afb35536740df91e475987e1f7986b004daaea9d858d` |
| `Build/audit-fixes/supervise_native_data_transfer_entry_v1.py` | `0363730dbe0fb93d86eb716d7212a627d8677b36125bb2e1498dba5190c0bb26` |
| `Build/audit-fixes/supervise_native_data_transfer_entry_v2.py` | `8179b69cf5f1491dc06e2b59a29273ac92c74c3de409b6647570fa188600ae1d` |
| `Build/audit-fixes/verify_native_data_transfer_entry_evidence.py` | `bc711ae43d2f419aec433f21a5c7b2ff7954369add4e705363a38b213ce39684` |
| `Build/audit-fixes/verify_native_data_transfer_entry_v1.py` | `723f7d87116ff27e9b9138230c424e1a216e584d056567b5f36c2b038d2b5dcb` |
| `Build/audit-fixes/verify_native_data_transfer_entry_v2.py` | `c309fa694f04c21114a6e5f0fb14392b9011a842d9d442a1f31c603b03cb5cb5` |
| `Build/audit-fixes/verify_native_data_transfer_string_callback_evidence_v2.py` | `1d282fad6c8bfeeb1b481350737fcdeafe600b13633ddda1a2387ff0cf6b97ee` |

Earlier callback/addition/files sections retain their old code pins and then-open
entry statements as history. Upstream FIXME paths/filesystem/getParent operations,
generic EntriesAPI callbacks, directory traversal, setDragImage, physical Cocoa/Page
drag generation, automatic store transitions/default actions, media ondrag handlers,
foreign WindowProxy/function-realm dispatch and weak WrapperWorld ownership remain
open. Existing native play() Promise work stays completed under its own earlier
evidence. The browser still uses JavaScriptCore. This slice establishes no full
LibJS, EntriesAPI, FileAPI or drag-and-drop parity. The historical finding ledger
remains 32 fixed / 25 partial / 9 open.
