# Native Window DataTransfer files getter

DataTransfer.files now returns genuine native FileList/File snapshots through
the existing FileAPI wrappers. This bounded translation adds the public getter;
HTML/FileAPI producer algorithms and the browser's existing host startup remain
unchanged.

Implementation: `b59e211c601f1e9abf922e823c5bc8d6dfeb3b83`.
Actual immediate parent: `062a6f46f43dfa119bafdd54cd99a3fa90c3ffa3`.
Initial baseline/focused source: `85d775683ea55b90eeac72844917caecc52b1138`.
Upstream pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

## Source behavior and ownership

Pinned DataTransfer.idl annotates files with [SameObject]. Its actual C++ files()
implementation creates a fresh FileList and fresh Files on every call, and the
binding generator does not cache this annotation. The translated getter follows
those actual implementations. It preserves the existing adapters' fresh-record
behavior; no SameObject cache or live list is invented.

The native getter is named get files, length zero, nonconstructable and installed
as an enumerable/configurable read-only prototype attribute. Native DataTransfer
branding precedes FileAPI dependency lookup; fake/prototype-only/Proxy receivers
fail without author Gets, traps or conversion of ignored arguments. Genuine
records retain their identity through DragEvent.dataTransfer and late Window
attachment. Public globals and author fields cannot substitute native records.

FileListHost requires FileHost, then BlobHost and ReadableStreamHost from the same
document/settings owner. Browser startup already installs this chain. Partial
runtimes expose the getter but report its unavailable FileList dependency until
the existing hosts are explicitly installed; late installation reuses the
original transfer identity and getter. No automatic competing host is created.

File snapshots copy raw bytes and preserve UTF-16 filenames, including NUL and
lone surrogates. Existing File construction normalizes MIME types and supplies
the source current-clock lastModified default. Within one list, index/item reads
reuse the same File record and embedded Blob; another getter creates distinct
records. Existing owning file-reading tasks settle inherited Blob byte reads.

Read/write and read-only modes expose file items; protected and disassociated
stores return fresh empty lists. Text items never enter the file list. Subsequent
reads reflect native additions, removals, payload changes and mode changes;
older snapshots retain their contents. Distinct runtimes keep separate native
wrapper registries. Runtime close releases its existing strong FileList/File/
Blob caches, while independent native records and other runtimes remain usable.

## Focused and integrated validation

Five new binding cases cover metadata/partial dependencies, payloads and owner
tasks, native modes/snapshots, late Window/host installation, retained globals,
foreign registries and close. Two actual owner cases use parsed video/created
audio listeners with nonempty native file records and genuine DragEvents.

| New test file | Cases | SHA256 |
| --- | ---: | --- |
| `browserjs/data_transfer_files_binding_test.v` | 5 | `f120e94fcbacbae3e18bcec569b4e7e8dc7d5a8c6af65a79a1c9508482563425` |
| `main_data_transfer_files_owner_test.v` | 2 | `01e3a0a9241dfd63610b54e007df849b974c2f96c7ff42b71a868db5c8504659` |

The corrected parent baseline compiles both new files and fails their seven
initial getter-availability guards. Later assertions are unexecuted. The focused batch
adds the existing five string-store cases, for twelve cases across three files.
Baseline/focused snapshots retain their initial source; final GC/optimized runs
verify the actual feature commit, including recorded intervening commits.

The actual parent includes independently committed performance documentation and
flex implementation/tests after the initial validation parent. Those exact Git
paths are synchronized into the clean final checkout. A first launch guard exits
one before mutations or supervisor launch because the parent changed; it earns
no test/build credit. The retained code record records both parents and the
actual source input map. Final validation belongs to the committed source.

The original JS fixture fails compilation on two direct host-registry references;
its five functions are unexecuted. The owner file compiles and fails its two
initial availability guards. Those original logs, actual terminal receipts,
test bytes and six-path freeze remain preserved with zero passing-file credit.
Only three fixture expressions change: use host.files and files.blobs, and
store the late getter on the saved actual global. Implementation bytes do not
change. The corrected parent baseline and final passing runs remain separate.

| Run | Outcome | Manifest | SHA256 |
| --- | --- | --- | --- |
| baseline | 2 files compile; 7 initial getter-availability guards fail | `Build/audit-fixes/native-data-transfer-files-baseline-final-manifest.json` | `8e2ce6e7115150e1f119cc683c38b4c110f692790ddc002d82bd686942684adc` |
| focused | 3 files / 12 cases pass with the final implementation | `Build/audit-fixes/native-data-transfer-files-focused-manifest.json` | `a8dea19aca6dd8cea1e0beaa2fa05b3dae693e3cff3d4cc7a3a5e8b9917d04c9` |
| default | 14/14 selected files pass at the exact feature commit | `Build/audit-fixes/native-data-transfer-files-default-manifest.json` | `db8293dfedb67136dbf34b66db3fb43481fc0b81a16406c6cd70159176685572` |
| gc-none | 14/14 selected files pass with GC disabled | `Build/audit-fixes/native-data-transfer-files-gc-none-manifest.json` | `e587c72318dbbbe1ab266561eb5f9aea82b07112e0241a40cd1cb0c76e614923` |
| optimized | 2 new files / 7 cases pass with -prod -gc none | `Build/audit-fixes/native-data-transfer-files-optimized-manifest.json` | `6f3ce46f309e73dbb2354bd84e23d9621ef5573de11a83cbade8220997806be6` |
| production | Signed startup; 2 exact empty-list pages; 11 smoke cases | `Build/audit-fixes/native-data-transfer-files-production-private/manifest.json` | `a8b49cf894c62e63ac40fcb6827a7e0adcfd8313b1b4c0f3d90efa93b5e9deca` |

Actual terminal child receipts and full logs accompany these manifests. The
isolated source is `/Users/alex/code/vox2/Build/audit-fixes/native-data-transfer-files-validation-source`. Exact Git input hashes,
upstream references, compiler inputs, native archives and before/after snapshots
are retained. The final proof verifies 5,032
source inputs and preserves 2,487 prior hashes.

## Production, preservation and boundaries

The private signed browser passes startup, two pixel-exact pages and all eleven
smoke cases. Both feature pages use genuine EMPTY FileLists from public new
DataTransfer records. There is no browser nonempty file producer in this slice;
focused native/actual-owner tests establish nonempty payload and mode behavior.

All ten original production stages pass. The later provenance checker exits one
on its stale contiguous flag search: the actual Git build recipe places
-exclude @vlib/time/zoneinfo.native.v between compiler and globals flags. Its
original helper/log and actual 0/0/1 supervisor receipt remain unchanged with
zero checker pass credit. A distinct provenance-only recovery verifies logged
flag tokens against the Git recipe, the same binary and strict signature,
then records its actual zero exit. Source, image, pages and settle settings stay
unchanged; no new compilation, GUI capture or production rerun is claimed.
The flattened build logger does not preserve literal compiler argv quoting.

The first full-proof invocation exits one before cleanup: it incorrectly
compares the production compiler map's three inputs with the tests' two, omitting
the separately pinned stable V_BIN wrapper. Its original proof/cleanup helpers,
trace and execution receipt remain unchanged with zero full-proof/cleanup credit;
the volume stays mounted at that attempt. A separate verifier authenticates all
three production inputs, including the historical wrapper pin. No source, test,
build, startup or GUI capture changes accompany this verification correction.

The pinned recipes retain the historical Ladybird bundle name; current
canonical Vox build instructions and later concurrent work remain outside this
validation pin.

Signed binary: `Build/audit-fixes/native-data-transfer-files-production-private/browser-build/Ladybird.app/Contents/MacOS/Ladybird`
(SHA256 `5a7ed85f12e1aef66f90018e77d8e7917efc9e93122ab35ba6f7872e857a8788`).
Skia dylib: `Build/audit-fixes/native-data-transfer-files-production-private/browser-build/libLadybirdVSkiaText.dylib`
(SHA256 `58caaa4f153941b1e941f2d73498dfe6582151a03a8e063a2aafc84c606b670e`).
Only the verified owned scratch volume is detached. Persistent source, signed
images and evidence remain retained; earlier audit/inventory artifacts remain
unchanged. Canonical concurrent work and staging are preserved independently.

| Evidence | Path | SHA256 |
| --- | --- | --- |
| Consolidated evidence | `Build/audit-fixes/native-data-transfer-files-evidence.json` | `63a99a822705b4b2eda68dbac9c2e6518e1c18255c6adb036272051e8b3ca492` |
| Independent proof | `Build/audit-fixes/native-data-transfer-files-verified-report.json` | `ffc3a8d9108b1b09437f08626a074625145ecd57825f221cca1b1a938ccee066` |
| Frozen feature inputs | `Build/audit-fixes/native-data-transfer-files-frozen.json` | `7e8dba4283127287b75d16a8ed62b2e5acf17aae4cf60afbf31007603ad6508a` |
| Initial source preparation | `Build/audit-fixes/native-data-transfer-files-source-preparation.json` | `512e2c3313c6ad7bb73751d2f2e24a0a221808404e2075002572176d8a845276` |
| Actual feature integration | `Build/audit-fixes/native-data-transfer-files-code.json` | `741834edfad40f0d3d6200b9aeb6f971ded9b299763216fbb0a3ff1beec727ab` |
| Prior evidence index | `Build/audit-fixes/native-data-transfer-files-prior.json` | `ff8d73208feaf2620bc3355e88fba0eced3073f0ca6943240fce1ce3dbf0c39e` |
| Production manifest | `Build/audit-fixes/native-data-transfer-files-production-private/manifest.json` | `a8b49cf894c62e63ac40fcb6827a7e0adcfd8313b1b4c0f3d90efa93b5e9deca` |
| Scratch cleanup | `Build/audit-fixes/native-data-transfer-files-scratch-cleanup.json` | `aa464c6de06635fdea00f5fca7dd025add9cf16dfc38e1745ce474f8bed3577c` |
| Original failed baseline | `Build/audit-fixes/native-data-transfer-files-baseline-manifest.json` | `b38580f3e765ea4b07a6dc65b08766ac6320a5187d271ea00174a88210d932d0` |
| Original fixture archive | `Build/audit-fixes/native-data-transfer-files-test-before-fixture-correction.v` | `4fa65c19e4b61c19c5f8446ec8d2948f5424990afed713a5defdb94443565257` |
| Original six-path freeze | `Build/audit-fixes/native-data-transfer-files-initial-frozen.json` | `31b8b2883641020c6e7ad7bd73714f36affb5f75fcc3275805b906ab49279716` |
| Original failed provenance checker | `Build/audit-fixes/native-data-transfer-files-production-private/provenance.log` | `49ad935dcb154a93614ee2d276ff6bac78ddb25ea2bb4a7739cde94526ffa9f7` |
| Original checker preservation | `Build/audit-fixes/native-data-transfer-files-provenance-recovery/preserve_original_failure.json` | `19f53835dded37a2e9e4175a40e92dfebc67bed24401b81f668af3a9f1ca72a2` |
| Provenance recovery child exit | `Build/audit-fixes/native-data-transfer-files-provenance-recovery/completion-receipt.json` | `497dbb616cb9c67ead2c47a21a64a82116749f4e646e44975be68c05d3db3de9` |
| Prepared provenance recovery | `Build/audit-fixes/native-data-transfer-files-provenance-recovery/prepared-inputs.json` | `6a048f2095e24aef81feba1c632f9d5dd41eaf88828f5ed30fede70bc192a2db` |
| Recovery preservation | `Build/audit-fixes/native-data-transfer-files-provenance-recovery/preserve_original_failure.json` | `19f53835dded37a2e9e4175a40e92dfebc67bed24401b81f668af3a9f1ca72a2` |
| Initial full-proof execution | `Build/audit-fixes/native-data-transfer-files-initial-proof-execution.json` | `47c105af9916ba6ef1e5687bf77df4b7e25c07f9e968a3b216dc381f82ac803b` |
| Initial full-proof trace | `Build/audit-fixes/native-data-transfer-files-initial-proof-trace.log` | `9537f4fcf833fb631812aae2b9ff6536bc649ee78055cdf92323a9bed42ff984` |
| Original proof helper | `Build/audit-fixes/verify_native_data_transfer_files_evidence.py` | `929f5ed50004492bae51152125be1fa32e43c4d891524713ca190f493357e405` |
| Original cleanup helper | `Build/audit-fixes/cleanup_native_data_transfer_files_scratch.py` | `cd6f3c095c50aaecdc81ed8bd19cd2ae3e605a2b6d6de3e45a22724c43037fea` |
| Production completion | `Build/audit-fixes/native-data-transfer-files-production-private/completion-receipt.json` | `60bc47286edf01e993665cb026d84a96bee3b8de99178310cd5fe6fe5c2f8070` |
| Binary provenance | `Build/audit-fixes/native-data-transfer-files-provenance-recovery/provenance.json` | `42cfd2b1f3c1beb21ad46e9680fd417f0b7560ceda23c634ae666338b468b9df` |
| Private recipes | `Build/audit-fixes/native-data-transfer-files-production-private/recipe-preparation.json` | `bb4bb54ee18ea0ef6b3a7881fe0cff9d7753c97d479f6999ddaceb7d06b657fc` |
| Prepared production inputs | `Build/audit-fixes/native-data-transfer-files-production-private/prepared-inputs.json` | `f83decd725fac6d534094c75a81182b910d492d5f6f3bfa180172423d04cc335` |
| Original production child exits (0/0/1) | `Build/audit-fixes/native-data-transfer-files-production-supervisor-completion.json` | `4c012a2b407978bd4cb5d1a19cf9efbc455dafd495d45aaa51d428c66fcfca2f` |

All six feature paths are excluded root/browser support/test files. The feature
changes no assigned package bytes and refreshes no physical inventory. Foreign
canonical package changes belong to their own commits and validation pins.

Public DataTransferItem/List, setDragImage, hardware file delivery, physical
Page/Cocoa drag dispatch, store-mode transitions/default actions and media ondrag
handlers remain open. Foreign WindowProxy/realms and weak WrapperWorld ownership
remain pending. JavaScriptCore remains the browser engine. This bounded getter
does not establish full LibJS, FileAPI, drag/drop or media parity. The historical
ledger remains 32 fixed / 25 partial / 9 open.
