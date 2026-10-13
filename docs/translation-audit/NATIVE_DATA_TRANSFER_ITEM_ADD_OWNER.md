# Native Window DataTransferItemList.add

Implementation: `bbe330a8d020e00358a4fc4719b351cefc727b27`. Immediate parent and baseline: `e443227c6b348cd849ff02a299e0ad5cd6438b94`.
Upstream source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

## Source behavior and native ownership

The pinned DataTransferItemList.idl declares add(DOMString data, DOMString type)
and add(File data). Its current Python generator groups effective overloads by
argument count and emits switch(min(2, argument_count)). No zero-argument entry
exists, so zero arguments throw a fresh TypeError with the exact message
"Overload resolution failed" before looking at the receiver. One argument
selects File; two or more select DOMString, DOMString even when the first value
is a genuine File. The selected function validates its native list receiver,
converts data then type using genuine string-hint ToString, and only then enters
the implementation. Additional arguments are ignored. Original thrown author
values survive. Native add has name "add", length one, writable/enumerable/
configurable metadata and no constructor behavior.

The one-argument branch requires the actual owner-local File registry entry.
Primitives, null/undefined, Blob, prototype spoofs and proxies around Files are
rejected as "Not an object of type File" without author getters, proxy traps,
prototype lookup or public-constructor inspection. Missing/closed File hosts
produce that same typed error. Input File bytes, name and type come from the
native record; poisoned properties and replaced File/Blob globals do not affect
them. A successful append copies bytes and raw native name/type into the store.
The returned item is the exact wrapper later obtained from the supported index;
adding the same File twice creates distinct actual item records.

Both implementation branches return null outside read/write mode. String
conversion and File branding precede this mode gate, including on protected,
read-only and disassociated stores. String duplicates are checked only after
the gate, only against text items, and with ASCII-insensitive type comparison.
Stored text types lowercase ASCII alone; data and non-ASCII/NUL/lone-surrogate
units remain intact. Duplicate calls allocate distinct native NotSupportedError
records and engine wrappers, code 9, with the exact message prefix "There is
already a DataTransferItem with type " followed by the original converted type.
The core's WTF-8 diagnostic mirror is decoded losslessly into the raw UTF-16
DOMException message. No store revision or item identity changes on rejection.

The new add_string_utf16 producer uses the existing DragDataStoreItem.text_utf16
slots. The legacy V add_string body remains byte-for-byte intact, preserving
malformed/overlong compatibility input bytes rather than normalizing them. This
bounded slice does not reinterpret those existing compatibility byte spellings.
File additions use the existing add_file_record producer and relevant-owner
FileAPI chain. Later getAsFile/files reads return fresh native File/Blob and
FileList snapshots with copied bytes and the source current-clock lastModified
default. Public new File uses the existing USVString filename conversion, so
lone-surrogate constructor input becomes U+FFFD; raw File-name units are tested
with typed native V records. The source clear implementation continues removing
text only and preserving File items. Removal disables the actual item and shifts
surviving native identities, including items made by either new overload.

Source references: HTML/DataTransferItemList.{idl,cpp}, HTML/DataTransfer.cpp,
Bindings/Wrappable.cpp, LibJS/Runtime/ErrorTypes.h, and
Meta/Generators/libweb_bindings/{overload_resolution,operations,arguments,
to_idl_value,to_js_value}.py. These exact source hashes are retained in the run
manifests. Runtime registries remain strongly cached within one native owner;
close cleanup and foreign registry rejection have focused coverage.

## Actual verification and retained failures

| Run | Outcome |
| --- | --- |
| Parent baseline | Two files compile; seven initial availability guards fail; later assertions uncredited |
| Final focused | Five files / 16 cases pass, including all 9 new cases |
| Default / GC disabled | 15 files / 52 cases pass in each mode |
| Optimized | Three new files / 9 cases pass with -prod -gc none |
| Production | Signed startup, two pixel-exact mixed-item pages, eleven screenshot smoke cases pass |

The initial baseline browser fixture fails compilation because an array mixes
u16 and rune literals; the original source, freeze, log, manifest and actual
failed terminal receipt remain intact. Correcting only explicit literal casts
allows the real parent baseline to compile and fail its five browser plus two
MAIN availability guards. The new core fixture requires the added V producer
and is first run after implementation; it receives no parent baseline credit.

The initial focused batch passes three files and fails two fixture assumptions:
a browser Proxy returns a value inconsistent with a nonconfigurable/nonwritable
coercion property, and a MAIN fixture expects negative public File constructor
timestamps -7/-19 to remain negative although the existing constructor tests
already record zero for that input. The corrected browser fixture makes its
coercion property configurable, and the MAIN fixture uses positive 7/19 inputs.
Their original freezes, source archives, logs, manifests and actual exit codes
remain preserved with no passing batch credit. Implementation hashes do not
change after the first freeze. The final successful runs use frozen revision 3.

The first sealing call supplies a relative cleanup path and is rejected by
reference formatting after the readonly checks. The same unchanged verifier
then completes with an absolute owned cleanup path. Both actual invocation
receipts and logs are retained; tests, production and cleanup are not rerun.

Before the first production execution, the unexecuted page inputs likewise
switch from negative timestamps to positive 7; all initial helpers/pages and
their preparation manifest remain preserved separately. Actual production
passes on its first executed run: the detached prepare, production and provenance
children all finish with exit zero, and all ten internal stages finish with zero.
The two pages create actual Files and mixed item lists through public constructors
and add, then check File metadata, fresh copies, current default clocks, raw text,
typed duplicate errors, indexed identity, removal and text-only clear. The owner
page carries that same mixed list through parsed video and script-created audio
DragEvent listeners, cancellation and redispatch. Neither page reads File bytes.

Native owner fixtures separately invoke public File.bytes promises and execute
the owning document's queued file-reading tasks, checking real Uint8Array data.
They also exercise trusted native delivery, script redispatch, raw DOMString
data/type, preserved native records, File copies, poisoned properties/globals,
access-mode gates, original conversions, disassociation and owner cleanup.
All eleven configured screenshot cases pass; eight are exact and three retain
their established tolerance residuals. The two addition pages are pixel-exact.

Tests run with the pinned old compiler and enable-globals in the clean committed
private checkout `Build/audit-fixes/native-data-transfer-add-validation-source`.
All 5,046 Git input bytes and
2,915 prior hashes remain intact, including the
earlier items/files private sources and closed evidence. Test compiler identity
contains two inputs; production additionally authenticates the V_BIN wrapper.
Private production follows exact committed recipes with only isolated source/
output/capture substitutions, cached Rust/native archives, strict signing and
verified isolated source markers. Its frozen bundle is `Ladybird.app`; canonical
Vox branding/tooling working changes remain independently preserved. Cleanup
detaches only the verified owned RAM volume, retaining source, binaries, logs
and all earlier evidence. Audit/inventory commits are separate scoped merges.

## Evidence, inventory and remaining work

Consolidated sealed evidence:
`Build/audit-fixes/native-data-transfer-add-evidence.json`, SHA256 `dab3d2b8c3e5dc1e7a21f047c86d530a39ba48195398c45b1bb6d211ed7afad3`.
It authenticates completed terminal receipts, source freezes, original failures,
production image/provenance, original unexecuted production inputs and cleanup.

The independent physical recount at this code pin records 78 owners /
2,224 assigned files, 433,231 implementation /
160,272 test V LOC. Inventory artifact SHA256 is `4872c275d35da716c0cbbfb3f86e95d85375ddb8202e84a3dd10bc28c10d4648`.
Only html/data_transfer.v (+15) and its new core test (+55, one added assigned
file) contribute to these package totals; the other six feature paths are
excluded browser/root support. Physical LOC includes comments and blank lines
and establishes no behavioral parity. Earlier inventory pins and dated tables
remain historical records; a separate inventory commit updates current totals.

| Retained record | SHA256 |
| --- | --- |
| `Build/audit-fixes/native-data-transfer-add-baseline-exit-receipt.json` | `00cafae90c209c65e491f8f1c960267fe364fe6109243f0b30e1f1bdba7557b1` |
| `Build/audit-fixes/native-data-transfer-add-baseline-manifest.json` | `f7c0b6211c216c9826ee66228ea6398c24d476abcf51503ecadf42182370b062` |
| `Build/audit-fixes/native-data-transfer-add-baseline-v2-exit-receipt.json` | `e15784f509fd19792828a5476424288e0ac86335cd5ead2c1648a7d62c2e9b69` |
| `Build/audit-fixes/native-data-transfer-add-baseline-v2-manifest.json` | `c2c675dd64706212130ea78067e1d9507a97d7882a9c5732f54e0bb6711a2d2b` |
| `Build/audit-fixes/native-data-transfer-add-code.json` | `3c1878324dc3b68ee11a957ef306131284cd1a4f27f6700230678c668167b531` |
| `Build/audit-fixes/native-data-transfer-add-default-exit-receipt.json` | `735dcb4f73341a74a80e2ea89e7a135f9213821f2f225a555a8beeadd8258bcd` |
| `Build/audit-fixes/native-data-transfer-add-default-manifest.json` | `3082a3ad6625f77cf62d0476f7e6e78770660973e121c8921a3a6ccf5988a750` |
| `Build/audit-fixes/native-data-transfer-add-evidence.json` | `dab3d2b8c3e5dc1e7a21f047c86d530a39ba48195398c45b1bb6d211ed7afad3` |
| `Build/audit-fixes/native-data-transfer-add-focused-final-exit-receipt.json` | `e5aefdeef9567f776b4810097e2ac73cf3945255dba555b489f67449e9ffc469` |
| `Build/audit-fixes/native-data-transfer-add-focused-final-manifest.json` | `ce50f99e7cc2b6c5a1ff4b8eef9aaad773a446baf0a82daf2738a1706df46d02` |
| `Build/audit-fixes/native-data-transfer-add-focused-v3-exit-receipt.json` | `b199d86e6c47277b9f367b66e2691e3890c2e7c6403b653ce9f79d01a1da7f75` |
| `Build/audit-fixes/native-data-transfer-add-focused-v3-manifest.json` | `64be380e7c96b98d4f9d7a164f15b58b1cb83f11af33fd1905b91128ab4cc902` |
| `Build/audit-fixes/native-data-transfer-add-frozen-v2.json` | `1ec4008e29861508507496369ca23bc79586e5c5244620d4b7632e11c0590885` |
| `Build/audit-fixes/native-data-transfer-add-frozen-v3.json` | `346cf1173edec965b998313622dced8a75b0fac2b31037eac3572854fb7488c7` |
| `Build/audit-fixes/native-data-transfer-add-frozen.json` | `df88f5adff5bf957257757243571af67f96306386f5ced7c951d92f37260bff1` |
| `Build/audit-fixes/native-data-transfer-add-gc-none-exit-receipt.json` | `92b881f4e6cc87113d05366fb0ee23aff013c340534e8908ab3ed60480fb9fef` |
| `Build/audit-fixes/native-data-transfer-add-gc-none-manifest.json` | `d0e582c85239996c6b3ac7c21cbdfa8103404c2b436c3af97a0c179213e7e8e0` |
| `Build/audit-fixes/native-data-transfer-add-inventory-actual-exit.json` | `fbed2fc4ad39e473c96dc05ed9874950bb173b39ecdaac9b68c5f09a98577e4a` |
| `Build/audit-fixes/native-data-transfer-add-inventory-current.json` | `4872c275d35da716c0cbbfb3f86e95d85375ddb8202e84a3dd10bc28c10d4648` |
| `Build/audit-fixes/native-data-transfer-add-optimized-exit-receipt.json` | `e60868d444517354cebc9cdda3f0160f49a636856d03ec9f4fcc71b9c03fdc1a` |
| `Build/audit-fixes/native-data-transfer-add-optimized-manifest.json` | `d9fac0b04442739a239c0592be0a0f035a8da03c53148be11f9f28d33e8e6ea0` |
| `Build/audit-fixes/native-data-transfer-add-prior.json` | `1d419d8e3a75d23eb245a81651988fe353b045b25fc5e884ffc31043576aef70` |
| `Build/audit-fixes/native-data-transfer-add-production-private/manifest.json` | `9d6e2abf84e7a96130ca4baea1b221a40fd7f72a0d60b1a1fab3a04eecbda7f6` |
| `Build/audit-fixes/native-data-transfer-add-production-private/provenance.json` | `00a35d630dcf6c0925cd33b50afa4167f761908c4bd58ac86adcae807552a0c4` |
| `Build/audit-fixes/native-data-transfer-add-production-supervisor-completion.json` | `a20c5f2ab4ec2826e4b7e58b9358e14e4b982d2d00bc2a47a9b29c4dbc691b01` |
| `Build/audit-fixes/native-data-transfer-add-scratch-cleanup.json` | `a507e63a3d36c44f9610e104a0a944b4bb2feac91838e838a29aff05ce219fa8` |
| `Build/audit-fixes/native-data-transfer-add-seal-actual-exit.json` | `28c9169976ab54532efe7755c667fc994d0a50db2980b73dbe78c1bb5c959714` |
| `Build/audit-fixes/native-data-transfer-add-seal-initial-actual-exit.json` | `e82025ec37f057e8187299c0b81f11f1578e2409cd4e840dde37b839583ccfe5` |
| `Build/audit-fixes/native-data-transfer-add-seal-proof.log` | `00cee9b9659d272d06b2a998e069ea51adf8628fbd8792a6a823c98df2ffca93` |
| `Build/audit-fixes/native-data-transfer-add-seal-v2-proof.log` | `ad3b010ab8a57d50f6b0ec5df705d6e63779878e32e6c97cb810c0d1d2b03334` |
| `Build/audit-fixes/native-data-transfer-add-source-preparation.json` | `a71bbac99de12a5ac7ca62c4e082d1bac203d9094145f92577297f9ed26c2de3` |

getAsString callbacks, webkitGetAsEntry, setDragImage, physical Cocoa/Page drag
generation, automatic store transitions/default actions, media ondrag handlers,
foreign WindowProxy conversion and weak WrapperWorld ownership remain open.
The browser still uses JavaScriptCore. This slice establishes no full LibJS,
FileAPI or drag-and-drop parity. The historical finding ledger remains
32 fixed / 25 partial / 9 open.
