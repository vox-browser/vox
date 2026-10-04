# Frozen native regression at e93aaa7b

Canonical revision `e93aaa7b72e56a90f71636efb2be6c3c58113b56` was held
unchanged through the production bundle build, headless startup and screenshots
on 2026-10-04. All 4,444 tracked file contents, HEAD and clean tracked status
match the before/after snapshots. Upstream remained pinned at
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

`V_BIN=/Users/alex/code/v/v ./build_ladybird.sh` produced the macOS bundle with
production compilation and GC disabled. Its executable passed
`--headless-smoke`, including the JavaScript click event.

All nine targeted SVG/selection inputs have zero differing pixels:

- `svg-image-source-switch-same-size`
- `svg-gradient-in-defs-removed-repaint`
- `selection-insert-between-boundaries`
- `svg/paint-server-id-collision`
- `svg/paint-server-html-id-collision`
- `svg/gradient-stop-move-before`
- `svg/gradient-stop-added`
- `svg/gradient-stop-color-animation`
- `svg/pattern-transform-update`

The first targeted invocation exited 1 after four exact comparisons: the fifth
input's browser process exited without producing its window PNG. Its log
contains a Fontconfig diagnostic, which does not establish the cause. The
unchanged single-case retry passed exactly, and the remaining four passed in a
separate invocation. The failed original log remains retained. This is nine
exact cases across runs, rather than a clean single nine-case invocation.

The no-argument configured screenshot smoke passed **11/11** cases under the
existing repository tolerances. Eight are pixel-exact. `inline-node` has 13
differing pixels and maximum channel error 1; `text-decorations` has 1,341 and
maximum error 2. `canvas-text` retains 1,994/480,000 differing pixels, maximum
error 8, MAE 0.0038 and RMSE 0.0928. These three are not pixel-exact.

All artifacts use `source-native-string-base-getter-` under
`Build/audit-fixes/`. The before snapshot is `snapshot.json`; `manifest.json`
contains the identical after snapshot, binary hash, log hashes and per-case
metrics. PNG directories are `targeted/`, `targeted-retry/`, `targeted-rest/`
and `smoke/`.

| Artifact | SHA-256 |
| --- | --- |
| `manifest.json` | `8f086ea8a2c3b9ff3ceb3aaa447913f6304d2daa9910f83abbdcea1c2b045531` |
| Whole sorted tracked path/content manifest | `abdcc05ab7164b1974bdf90416fdf8d05a59b16d082a625e9d546206841d5808` |
| `build.log` | `9e9f26b0ed550ca566386928827619a0465be5b0d9d2dae4969093137987bfdf` |
| `headless.log` | `c0969a29380548754e94e6fcc3bdc1816e8537bc7ea920434027ccf2a3436baf` |
| Original failed `targeted.log` | `3b89fcc4f644bf159ae01fd603f220e360db91a88d31d6cc984e78a5a03fba4c` |
| `targeted-retry.log` | `f55b90705ff7223cbb57059db37bfadfc71cdd933d2457ba7d32a89c8b95d9af` |
| `targeted-rest.log` | `01b2723264b54c37ffc4693f48611db077d267db15ba55c6378a10fa1255e470` |
| `smoke.log` | `7382f43ba9336c464c7599da759ba006c34c55136bceaf20c063432250358e67` |

This bundle includes owned unchecked-ASCII/DataURL and native synchronous
FileReader string returns, Windows-1252 decoding, retained browsing-context
identity/group/creator-base state, source Math entropy and the reviewed integer
attribute/getter owner branches. It predates the subsequent 27-table
SingleByte/UserDefined decoder expansion, live concrete Base lifecycle and CSP
violation owner changes, shader type gate and obsolete fixture migration.
Those commits retain their focused checks; they do not inherit this native
bundle proof. Complete LibJS execution, Wasm execution, remote transport and
collector/wrapper-world ownership remain unfinished.
