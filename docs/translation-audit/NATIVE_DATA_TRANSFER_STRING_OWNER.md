# Native Window DataTransfer string store

Window-owned runtimes now expose DataTransfer construction, effects, string
operations and immutable types over actual HTML DataTransfer records. Existing
private identity wrappers gain the public prototype without changing identity;
DragEvent.dataTransfer continues to share the same live native record.

Implementation: `b335958e826ffa239b94768ef9998bcd6e617c6e`.
Immediate parent: `87e3e2a5a69670caeab3d1388944d2671f5c4315`.
Upstream pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

The eight feature paths contain six excluded root/browser support/test files,
the assigned HTML string model and one new focused HTML test. The compact main
bootstrap, DOM event dispatcher and Page drag dispatcher remain byte-identical
to the previous pinned evidence.

## Source and implementation

Pinned HTML/DataTransfer.{idl,h,cpp} exposes this interface only on Window.
The zero-length constructor requires new, reads newTarget.prototype once and
ignores all arguments. Custom object/function/subclass prototypes survive;
primitive/null values use the retained owner prototype. Both effects start "none".

Effects, types and operations use native nonconstructable JSC functions with
source metadata. Native receiver lookup precedes arity/conversion; fake/Proxy
receivers fail without author inspection. Ordered DOMString conversion uses the
string hint and preserves original exceptions without partial store changes.
clearData(undefined) means absent format; null becomes "null".

UTF-16 formats/data preserve NUL, astral characters and lone surrogates. Text/URL
aliases ignore ASCII case and become text/plain/text/uri-list. Other formats
retain case; exact-case replacement removes then appends. Lookup/clear ignore
ASCII case, preserving distinct non-ASCII case. The upstream getData URL-list
parsing FIXME remains visible: the whole stored URI-list string is returned.

Types preserve text order and one trailing Files marker for native file items.
Each list update advances the record revision. Frozen intrinsic arrays cache by
record/revision/runtime: repeated reads share identity; updates create fresh
snapshots. No-op clears, blocked mutations and effects retain the array. Old
snapshots remain frozen; separate runtimes have distinct wrappers and arrays.

Protected stores hide data but retain types; read-only stores reject mutation;
disassociated stores return empty data/types. Conversion precedes mode checks.
effectAllowed changes only in read/write mode; dropEffect remains writable.
Retained factories/intrinsics/maps survive public-global and author-slot changes.
Runtime close releases strong wrapper/array roots. Upstream weak WrapperWorld
caching and foreign-realm ownership remain pending.

## Validation and diagnostics

Five binding cases cover exposure, constructor/descriptors, conversions, brands,
UTF-16 storage, modes, frozen revisions, retained intrinsics, owners and close.
Two main owner cases share genuine nonnull constructor/native transfer records
through parsed-video and created-audio DragEvents, listeners, cancellation,
redispatch, current-event identity and inherited initializers. Two HTML cases
verify exact native UTF-16/case/revision behavior and mode/item preservation.

| New test file | Cases | SHA256 |
| --- | ---: | --- |
| `browserjs/data_transfer_binding_test.v` | 5 | `d7e82f380572acdd98844330d2f334333241f8fca0d1340c1e3d3ddae8b6136f` |
| `main_data_transfer_owner_test.v` | 2 | `38a4373fbf41cc6e12032340a5d95ff3e7905d571067bd5418505c6fa3866834` |
| `html/data_transfer_string_binding_test.v` | 2 | `5f3ec88cdaa863b929051eb1636bc0ddae02ece70b4f47d9a7e5f03cb89aa703` |

The final parent baseline compiles both guarded JS/owner test files and fails
all seven initial DataTransfer availability guards; later assertions remain
unexecuted. The core UTF16/revision API test is not compilable against the
parent and is first exercised in focused validation. All nine cases pass after
implementation.

The original JS fixture does not compile because two option-mode comparisons
omit unwrapping; its five test functions are not executed. The owner file
compiles and fails its two initial availability guards. The exact original
manifest, log, supervisor receipt and test bytes remain unchanged and earn no
passing-file credit; only the two comparisons are corrected before the
complete parent baseline rerun.

The first private checkout failed with Git exit 128 after "No space left on
device"; its orchestrating command exited one. Git removed that failed checkout.
The retained preparation diagnostic verifies the successful isolated parent
checkout and gives the failed attempt no test/build credit.

| Run | Outcome | Manifest | SHA256 |
| --- | --- | --- | --- |
| baseline | 2 files compile; all 7 initial availability guards fail; later assertions unexecuted | `Build/audit-fixes/native-data-transfer-string-baseline-final-manifest.json` | `bb6119efe295e436c9eea4580863860589f60edc6e0ec5713ca6c383b6b716da` |
| focused | 3 files / 9 cases pass with final source and test bytes | `Build/audit-fixes/native-data-transfer-string-focused-manifest.json` | `a0ef8eaa921bdbaee31d7f135c15bf465a17f78397fc064f278a1a153e2b0a8d` |
| default | 13/13 selected files pass at b335958e | `Build/audit-fixes/native-data-transfer-string-default-manifest.json` | `5aa7d0de09739c7c49acea8722229b118c3c394c3de5f2ee8913fa1c08fed4fc` |
| gc-none | 13/13 selected files pass with GC disabled at b335958e | `Build/audit-fixes/native-data-transfer-string-gc-none-manifest.json` | `0a7cbedf5d33d92c9e0ec0634a40144842692a36f9504ce6f6224cd08855e604` |
| optimized | 3 files / 9 cases pass with -prod -gc none at b335958e | `Build/audit-fixes/native-data-transfer-string-optimized-manifest.json` | `85e78624f6b2a9dfce441833c064b67bde03125902addb722061c55918c79e54` |
| production | 10 fresh verification stages; retained signed build; 2 exact pages; all 11 smoke cases | `Build/audit-fixes/native-data-transfer-string-production-final/manifest.json` | `a8561d674b0cf99320dac41e13d4ce74d7dccb9ed676bdd2544ccbdf1376f89b` |
| production-original-failed | Actual child exit 1; first 5 smoke cases pass; capture failure; zero full-smoke credit | `Build/audit-fixes/native-data-transfer-string-production-private/manifest.json` | `12444280e447201d1e445ed5de08dbb9e0d7a3382256a1c1ad0eed0df3bc3dad` |

Actual terminal test receipts are retained alongside every settled log.
The isolated source is `/Users/alex/code/vox2/Build/audit-fixes/native-data-transfer-string-validation-source`.
Final proof verifies 5,025 exact Git
inputs, 60 selected / 175
production upstream references, 3 compiler inputs and
3 native archives; before/after snapshots match.

## Production and preserved evidence

The private image passes strict signing/startup, two pixel-exact pages and all
eleven canonical smoke cases with the explicit
`-old-compiler -enable-globals -prod -gc none` diagnostic override. Both pages
use genuine nonnull new DataTransfer and native DragEvent records, checking
strings/descriptors/conversions and actual owner dispatch.
Protected/read-only/disassociated stores use focused native owner tests.

The original optimized build, signing/startup and feature pages passed; its
smoke child exited one after five passing cases when selection-focus produced
no viewport screenshot. All 61 artifacts/receipts remain sealed, with zero
full-smoke credit. Ten fresh recovery stages include retained-build-precheck,
signature/startup, identical pages/pixel checks and all eleven smoke cases.
Source, pages, settle settings and the signed binary/dylib remain unchanged.
The recovery performs no new compilation and claims no additional build pass.

Frozen b335958e recipes retain the historical Ladybird bundle; current canonical
instructions use Build/v/Vox.app and Vox. Later branding/work is outside this pin.
Private signed binary: `Build/audit-fixes/native-data-transfer-string-production-private/browser-build/Ladybird.app/Contents/MacOS/Ladybird`
(SHA256 `6219010cd66f88e25d731cf5ed1cba93d3f55bd63430f295dc97ff7319f65ea9`).
Private Skia dylib: `Build/audit-fixes/native-data-transfer-string-production-private/browser-build/libLadybirdVSkiaText.dylib`
(SHA256 `58caaa4f153941b1e941f2d73498dfe6582151a03a8e063a2aafc84c606b670e`).

Only the verified owned scratch UUID is detached after completion. Persistent
source, signed images and evidence remain retained; final proof repeats after
cleanup. The verified closure retains 128
current and 2,249 prior artifact hashes.

## Receipts and inventory

| Receipt | Path | SHA256 |
| --- | --- | --- |
| Consolidated evidence | `Build/audit-fixes/native-data-transfer-string-evidence.json` | `1f0e60d7a96ed1734a5d2d5c8b2765e9b914bf6d364b73a583d46104b128ef22` |
| Independent verification | `Build/audit-fixes/native-data-transfer-string-verified-report.json` | `a08f2de59401f40659d54df484b3d659b21eca3812750145520e76ddee1cb326` |
| Production completion | `Build/audit-fixes/native-data-transfer-string-production-final/completion-receipt.json` | `d4545cfda9749648112da5fca6f9084af13c4b99d822901fb4f345444a31e954` |
| Actual production child exits | `Build/audit-fixes/native-data-transfer-string-production-final-supervisor-completion.json` | `3fb18952f4d2d39f9dd788f05d070ce534a1c937c76e7a5304130a930ca0e98d` |
| Private recipes | `Build/audit-fixes/native-data-transfer-string-production-final/recipe-preparation.json` | `9c88c78e983b2fa0bb19ce8efeddff7fe5d76fcd679b0675817bc5fe4f2d4fb2` |
| Binary provenance | `Build/audit-fixes/native-data-transfer-string-production-final/provenance.json` | `4f2580f7a25c28fdf955992972bd3cb1c856c3eae1078e6e77fc2b3d71bcc668` |
| Scratch cleanup | `Build/audit-fixes/native-data-transfer-string-scratch-cleanup.json` | `9b7e4bd27fbebac6ee10f291e3b162fe98fc33dab71f40dc96b4a10e4f636bc8` |
| Physical inventory | `Build/audit-fixes/source-current-module-loc-b335958e.json` | `d1312ce3780a77a3ebcab3a487d3052ebbdedb51cfdd0e60a4992134892dea81` |
| Original baseline diagnostic | `Build/audit-fixes/native-data-transfer-string-baseline-manifest.json` | `4875b673a19b54d70449b5afea008d4855a86df64500a17a434a20d0fb6a5f4c` |
| Original test archive | `Build/audit-fixes/native-data-transfer-string-test-before-mode-fixture-correction.v` | `a17a5689da248673ba579b3e2fdcbd9f60edca7ef9ac8ccc3b138846c782bb75` |
| Source preparation diagnostic | `Build/audit-fixes/native-data-transfer-string-source-preparation.json` | `0bc719a1811a2d8ce4658bd245998fd21ba5eb70994a85b690871e6e71035e78` |
| Failed production preservation | `Build/audit-fixes/native-data-transfer-string-production-final/failed-attempt-preservation.json` | `b718309be4fbf6973e041d5c470b870d13b5390e0e39e0196aa525ae49eee3e1` |
| Actual failed production child exit | `Build/audit-fixes/native-data-transfer-string-production-supervisor-completion.json` | `dc6f6f7e67f3b5c8c5097d7bd89404e48be67d9f7773ced3d85a03d4100feebf` |

The disjoint inventory has 78 owners / 2,217 assigned
files with 433,002 implementation /
159,798 test V physical LOC. The only assigned
feature delta is HTML: +42 implementation / +114 test lines and one new test
file. The intervening documentation commits change no assigned bytes, physical
newlines or ownership. Inventory doc updates belong to a separate commit.

## Boundaries

Public DataTransferItem/List, files and setDragImage remain separate translations.
Physical Page/Cocoa drag generation, store-mode transitions, default actions and
media ondrag handlers remain open. Owner-local strong caching does not implement
weak WrapperWorld or foreign WindowProxy/realm ownership. JavaScriptCore remains
the browser engine; full LibJS execution and media/MSE parity remain open.

All earlier audit documents and prior inventory artifacts remain unchanged.
This bounded slice leaves the historical ledger at 32 fixed / 25 partial / 9 open.
