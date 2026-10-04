# Continuation integration verification

Recorded at canonical `89bc8de09c8332231a2f37c5e73607669ec406fe` against Source `963d46a829f3e1b79f44dba9d02afb70654300fa`. These focused canonical checks cover UTF16 outer/Common/whole/BOM consumers, exact raw Referrer-Policy extraction and actual redirect use, SIMD lane store/load, JIS data prerequisites, CSP ASCII/byte parsing, and actual WebGL shader/program CPU gates and lost command suppression. Each feature and its tests is committed separately; documentation and tools have separate commits.

| Canonical log in Build/audit-fixes | Passed | Seconds | SHA256 |
| --- | ---: | ---: | --- |
| `source-utf16-whole-common-bom-canonical-gc-none.log` | 5/5 | 51.331 | `ae2fe4f37b518e257d305d5a26c76b73c81841b9131746999a69cce47550fd9e` |
| `source-referrer-shared-core-canonical-gc-none.log` | 5/5 | 29.976 | `dac616c7f9539f1c150f6595d6327b5255985e857b04453778ec015b58c8e7ac` |
| `source-shader-loss-program-delete-owner-canonical-gc-none.log` | 10/10 | 128.920 | `ba1a12d5fbfafe8cf0c7af12190f554f8e6f952d5a82e030193932e46b480aba` |
| `source-memory-lane-store-canonical-gc-none.log` | 4/4 | 20.775 | `3a4de5a17c263870bca38ab12fb58b602d684306c71abf95699e19b3c73edbb2` |
| `source-redirect-program-delete-lost-canonical-gc-none.log` | 4/4 | 43.913 | `a3dd869dacf296879dcd2464f790437c4d20c9fb0fb9888877a598329f51b311` |
| `source-program-link-owner-canonical-gc-none.log` | 4/4 | 33.738 | `f2c153d9c67588c8e8d30ab1d810f69e247ac4da2e1ce7e5bf10931b6df53538` |
| `source-csp-ascii-token-canonical-gc-none.log` | 1/1 | 5.790 | `9f94ffe87b0391268c5b94b668b01e4d2acea97743cdf51b07da248a87b81807` |
| `source-lane-load-jis-link-loss-canonical-gc-none.log` | 4/4 | 29.895 | `fbbf92cca2b9c883c8609902cb61cf9d69cd2f902a88d5e7b32b41521117a9ce` |
| `source-csp-byte-ascii-canonical-gc-none.log` | 4/4 | 10.584 | `3c1f502231421c987d55487a168f5b038d306e02f19aa7472b2415adc2100dd9` |

Focused manifest SHA256: `f04c43f1f55395842bb1a60a91164a1a803ccda52927cb7f16c844567d0c1bab`. Reproduced fixture evidence SHA256: `d95a38b2453a82e8ab9e8463d8eef127f38623cf38bfe765141086c099753fbf`. All ten final recorded native artifacts match canonical fixtures exactly: six UTF16 outer/Common/whole records, both JIS data/helper records, and both Wasm lane views. The original Source Rust/C++ probes pass both native profiles; whole UTF16 input has 1,504 original-FFI cases, 984 whole-fatal withholdings and zero naturally reachable reserve calls. No synthetic reserve coverage is claimed.

These are focused integration checks, not an immutable whole-checkout sweep. The early shader/program aggregate batch predates the later separately corrected linkProgram gates; both updated aggregates pass again in the four-file linking-owner batch. All commands use the old V compiler with globals enabled and GC disabled; Source native probes are independently reproduced in canonical ignored build directories. Initial diagnostics and pre-fix behavior witnesses remain retained in the individual mappings.

The nine targeted browser comparisons and 11 smoke cases last passed on frozen `9a749e4a`; that bundle excludes these later changes. Full Wasm verification last passed 101 files per GC mode at that same frozen revision and excludes the two lane helpers. A new immutable 103-file package and browser verification is next. Full Wasm opcode/dispatch/instantiation/GC, other codec implementations, native policy/realm graphs and remaining WebGL families retain their documented audit scope. Structural inventory and passing focused tests do not establish full translation parity.
