# Frozen WebGL regression at e93aaa7b

Verified on 2026-10-04 in the separate clean, detached checkout
`Build/audit-fixes/worktrees/08-webgl-e93aaa7b`, at exact canonical revision
`e93aaa7b72e56a90f71636efb2be6c3c58113b56`. Neither tracked implementation nor
fixtures changed during either sweep. No native browser bundle was built here.

| Group | Selected files | Passed | Failed | Wall time |
| --- | ---: | ---: | ---: | ---: |
| Typed: every tracked `webgl/*_test.v` | 121 | 120 | 1 | 238.198 seconds |
| Public: every tracked `browserjs/canvas_webgl*_test.v` plus `canvas_context_integration_test.v` | 91 | 91 | 0 | 720.444 seconds |

Each file was invoked independently using an argument vector, with two workers:
`/Users/alex/code/v/v -old-compiler -enable-globals -gc none -path
/Users/alex/code/vox2/Build/audit-fixes/worktrees/08-webgl-e93aaa7b|@vlib|@vmodules FILE`.
The module path was one argument. Exact selected-file manifests, TSV results,
per-file logs, group logs, snapshots and summaries are retained in the frozen
checkout's ignored `Build/audit-fixes/webgl-final-e93aaa7b/` directory.

## Checkout identity

The four typed/public before/after snapshots are byte-identical. All 4,444
tracked paths, contents and modes were included, along with HEAD, tree, index
records, tracked status and staged/unstaged diffs:

| Identity | Value |
| --- | --- |
| HEAD | `e93aaa7b72e56a90f71636efb2be6c3c58113b56` |
| Tree | `b84edbb62a59c3f590021735437c24e71c516544` |
| Whole tracked content/mode SHA-256 | `9642830c6c506804be8a4fad837a7603ad4b7ffeb54ef36ff95ecb1826de2e78` |
| Index-record SHA-256 | `47e843ac45cc11fdc3548c5ef7fd6f042e183650e7df5eb4615f3bee593f8559` |
| Each before/after snapshot SHA-256 | `a5e291d21f8d1e4bf824259ae189ff89a2467b1e92077b9a239e767b827e5058` |
| Staged and unstaged diff SHA-256 (both empty) | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

Tracked status was empty before and after both groups.

## Evidence hashes

SHA-256 values below identify the exact evidence, relative to
`Build/audit-fixes/webgl-final-e93aaa7b/`:

| Artifact | SHA-256 |
| --- | --- |
| `typed-manifest.txt` | `eb57584df19b514326eeb41e038e9c9f5135b9686fd6c26682c96ebfd17ae08d` |
| `typed-results.tsv` | `54f9ab3db3346b840c5c462d62add7a5dfdf582de6a83060b1c40df712db28ef` |
| `typed-summary.json` | `50e782d34fb9f527c123fe46a4a874ac9973400a847f39fe531e9790e6765d4f` |
| `typed-group.log` | `0f60f6a81fb5a2a28912233c5ecc046b4cadf17ae75d0e6b366f698c764da296` |
| `public-manifest.txt` | `40612cdf92f51165e7db66799286a016878b7bb09f31dffa47edc52fb245af33` |
| `public-results.tsv` | `4f7632a524d90fd0e00a34ff922cd3402171b3953d8ec4d51e5eb38af95e30c8` |
| `public-summary.json` | `e370f247be4617458743bd73256ca0fa8a647c053961f89877ee5ac949f60d3f` |
| `public-group.log` | `28f7daca72403a38f1a6b7571de7206efb9db1ae13935e8b266115ec956864f9` |
| `native-regex-dependency.json` | `6dbf7315604ba028bfb94c45c1810acaeff9c3f88ace88b055d3c929d619c05d` |

Per-file log-directory fingerprints hash sorted UTF-8 relative paths, a NUL,
and each file's binary SHA-256 digest. The 121 typed logs fingerprint to
`fcb6988ba5bad5b2c0a46faa0a72fab639b3330031c55caae0dea0937fcddc5b`;
the 91 public logs fingerprint to
`2fc9c6c34800241df1a1061bf9000bd7f1f9f16ba5ea0e83d01668c84c9853ad`.

## Dependency preparation and initial attempt

The fresh private checkout initially lacked its ignored
`Build/libregex/libregex_native.a`. An initial public attempt stopped at native
linking before JavaScript execution. Its 27 manifest/result/log/snapshot files
are preserved under `initial-missing-libregex/`, including an identical abort
snapshot. That directory's path/digest fingerprint is
`1db2208c5c624bffb40bdeec10dc2c5f8db0c1f8969d7eabc73418a3198bfe72`.
None of those initial results contribute to the completed 91-file pass.

Existing canonical build outputs were copied read-only under the shared
`Build/libregex/build.lock`; no native library was rebuilt. Ten exact pinned
native sources, the Unicode/helper inputs and Rust compiler version reproduce
the existing source stamp. The source reference is
`963d46a829f3e1b79f44dba9d02afb70654300fa`, the compiler is
`rustc 1.97.1 (8bab26f4f 2026-07-14)`, and the source fingerprint is
`5089ef74f5db4467a20a1c7d7bbd592bbf01acb658ec25948489bcd89f0fdd29`.

| Copied artifact | SHA-256 |
| --- | --- |
| `libregex_native.a` | `2c887fba2da5a1963e149f30a9b8e2cfb40d3075a9f7659e0c24976d0adba700` |
| `libunicode_rust.rlib` | `78ecc4054330f8377556dc48dd6ecb97996c5d27cdd2ea00296013833b9dae17` |
| `source.sha256` | `bda2fa7bab7e91b172afd9bd85390f2013e598c682659803953eb65d5fe109f7` |

The full public group was then restarted from its complete manifest.

## Sole typed failure and separate correction

`webgl/native_query_owner_selection_test.v` still expected an unconditional
native-owner switch after `getRenderbufferParameter(unknown)`, even though the
reviewed Source early branch correctly leaves the other native context current.
The same fixture also had that stale expectation for
`getTexParameter(unknown)` and `getAttribLocation(foreign)`.

Only those three independently Source-reviewed expectations were migrated in
separate test-only commit `78495b8ba33f04f11b99b88da42dcf688b1d3f23` in the mutable
`08-protocol-followup` checkout. The failed file passed separately in 2.2 seconds
with GC disabled, recorded in
`Build/audit-fixes/source-query-owner-legacy-reviewed-gc-none.log`; that correction
is documented by `2c8176954c9a3253df49df5570ba79876a66e508`.
Other historical method expectations remain for their individual Source reviews.

The original typed sweep remains **120/121**. This record supplies a frozen
120-file pass and a subsequent corrected focused file, without claiming a new
clean 121-file run. Public **91/91** belongs to the original unchanged frozen
revision. Passing coverage establishes the tested driver and adapter behavior;
unexamined Source bodies, remote transport, full GC/WrapperWorld and unfinished
LibJS execution remain separate boundaries.
