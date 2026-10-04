# Shift_JIS, URL origins, WebGL and production memory checks

This continuation integrates separately committed Source corrections. The 24 clean canonical focused runs below were executed incrementally during integration, not on one frozen whole checkout. Their commands, counts, elapsed times and log SHA256 values are retained in `Build/audit-fixes/source-shift-jis-origins-webgl-memory-focused-manifest.json`, SHA256 `00e17fbe07c3f65f585368717f02f1b985de2d0e9e554bdc42362e001fe4e9b3`.

| Canonical focused scope | Passing files | Elapsed seconds |
| --- | ---: | ---: |
| Actual Fetch response policy factory/history | 2/2 | 59.186 |
| Shift_JIS Common/retained UTF8 owner | 4/4 | 17.315 |
| Raw UTF16 and decoder neighbors | 4/4 | 8.631 |
| Shared UTF16 owner/raw/UTF8 neighbors | 3/3 | 18.358 |
| Actual direct TextDecoder caller/owner/Common | 3/3 | 15.592 |
| Blob entry owners and whole Shift_JIS helper | 3/3 | 7.062 |
| Selected Shift_JIS BOM caller and native FileReaderSync | 2/2 | 39.700 |
| AttachShader CPU/loss and updated aggregate owners | 6/6 | 131.996 |
| DetachShader CPU/loss | 4/4 | 66.117 |
| BindAttribLocation CPU/loss and updated aggregate owners | 6/6 | 57.075 |
| GetUniformLocation CPU owner | 2/2 | 58.788 |
| GetUniformLocation generated lost return/owned records | 2/2 | 40.534 |
| Resource URL origin/actual response owner | 2/2 | 9.973 |
| Actual CSP self-origin and matching neighbors | 3/3 | 39.830 |
| Process-wide file-origin policy and actual settings owner | 2/2 | 42.717 |
| File-origin policy production repeated-set guard | 1/1 | 7.433 |
| Memory fill production guards | 1/1 | 16.078 |
| Memory copy_from production guards | 1/1 | 16.382 |
| Memory overwrite production guards | 1/1 | 40.118 |
| Memory move_data production guards | 1/1 | 13.448 |
| Memory resize production guard | 1/1 | 5.682 |
| Memory capacity resize production guards | 1/1 | 7.934 |
| Memory reverse-chunk production guard | 1/1 | 7.966 |
| Memory span/cage-pointer production checks | 2/2 | 9.273 |

All runs use GC disabled; the production rows additionally use `-prod`. Individual Source mapping documents retain the actual pre-fix failures and private default/GC-none checks. Source MemoryBuffer and its byte-span VERIFY sites now execute explicitly even when ordinary V assertions are stripped. Genuine safe production failures were reproduced for offset/count, resize, reverse-chunk and empty-span operations. The cage-base fatal branch is preserved but has no natural failing valid-owner witness; its tests exercise real reachable pointer masking/growth. There is no claim of complete PrimitiveStorage/allocator, interpreter dispatch or collector equivalence. The package now has 114 test files; frozen 103-file proof predates these later methods.

Both original native profiles reproduce each new canonical Shift_JIS fixture exactly. The retained evidence manifests are:

- Raw UTF16/mixed calls/four artifacts: `source-shift-jis-utf16-raw-canonical-fixture-evidence.json`, SHA256 `315bf25f4939048c384297cd1a5db1e6fffc2675ace54eb9bd3f92f1e66ba072`.
- Shared UTF16 owner/real FFI/three artifacts: `source-shift-jis-utf16-owner-canonical-fixture-evidence.json`, SHA256 `851027e18484b60ce5742d001f42a4452bf2751848161a4a2a6e755604a18777`.
- Original u16 FFI with inspected TextDecoder reset schedules: `source-text-decoder-shift-jis-canonical-fixture-evidence.json`, SHA256 `432d94b17188a9ce4d20e3a7278b0e41718accefce3f2da93c7945d9cd1828a5`.
- Original whole FFI and separately observed Source body: `source-shift-jis-whole-canonical-fixture-evidence.json`, SHA256 `52f233f56daf8ae48fc9800c21e0a04eb47cfcfbb77a52da4e9387e00f8f3e20`.

These cover 524,288 raw result/state/unit records,1,704 direct UTF16 sequences and568 mixed actual FFI owners,852 caller schedules/3,124 calls, and4,140 whole-input cases. The whole cases contain 938 actual native ASCII Cow borrows and zero naturally reached reserve calls. Physical Cow/Vec allocation, OOM and public native Realm/holder/controller graphs remain explicit boundaries. The final private exact `a205292db816966217898417a106e76905693033` passes34/34 Encoding files in both GC modes with all 4,174 tracked contents unchanged; that private dependency snapshot is not the current canonical whole checkout. [Decoder evidence](SHIFT_JIS_DECODER_SOURCE.md) records its manifests and commands.

URL/CSP repairs retain actual typed origins through resource URLs, self matching, the false-default one-shot file policy and copied BlobURLEntry values. Genuine Blob-store/settings/partition resolution and native Policy/Response/GC ownership remain separate. WebGL repairs preserve Source handle-gate ordering, unconditional post-command retained updates and exact generated lost return defaults; these focused runs do not certify every GL family or complete wrapper/transport ownership.

The earlier frozen `a85c3b92` production bundle and103-file Wasm proof exclude this continuation. A new whole-checkout native/package proof is recorded separately. The audit ledger remains32 fixed/25 partial/9 open: these supporting slices do not close its broad runtime and ownership findings.
