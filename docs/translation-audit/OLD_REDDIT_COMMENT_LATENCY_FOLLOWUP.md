# Old Reddit comment latency follow-up

This follows [the original latency audit](OLD_REDDIT_COMMENT_LATENCY.md). The user’s reference is Brave’s immediate response. The optimizations below reduce synchronous work in the original Reddit handler and the following layout/paint pass. They do not establish Brave performance parity.

| Commit | Change |
| --- | --- |
| `283c8a1a` | Carry private recording scratch across document relayouts, while preserving published command snapshots. |
| `b0761605` | Read live collection versions as native numbers, with exact fallback above JavaScript’s safe integer range. |
| `7b6f4048` | Build paint transport boxes in one stable arena instead of allocating a wide child vector for every parent. |
| `5232b3b8` | Reuse private phase headers and bucket capacity across relayout and full invalidation. Clear records before regeneration. |
| `2ccecfd8` | Expose real, non-constructible native selector functions. Reddit’s Sizzle can use the browser selector implementation. Receiver checks, conversion, exceptions, scope and saved methods remain covered. |
| `ecdfc793` | Cache rendered UTF-16 lengths with rendered text, including invalidation after text edits, transforms and source-range changes. |
| `f0e55dc7` | Reserve hit-test phase storage from the already counted paint boxes. |

A diagnostic native-selector probe reduced dispatch from roughly 47 ms to 11 ms before the actual native binding was implemented. Subsequent production replays confirm that dispatch improvement. CPU samples also identified collector work during paint-tree, phase-vector and hit-test-vector allocation, plus repeated full Unicode decoding during caret projection. An experimental collector-policy probe did not justify a production policy change. The final application uses the normal C-O2/Boehm build and one marker.

Final production measurements use an ABBA sequence: old build, new build, new build, old build, with 12 native clicks per launch. The first action is measured after a 20-second startup settling period. All 48 actions alternate the JavaScript facade and actual native DOM state correctly, without navigation.

| Native mouse-down to completed layer update | Previously installed build | Verified production build |
| --- | ---: | ---: |
| First action in each fresh process | 919.8 / 1,242.2 ms | 366.0 / 426.4 ms |
| Median, all 24 actions | 191.0 ms | 134.3 ms |
| Median, 22 actions excluding the first of each process | 181.8 ms | 134.0 ms |
| 95th percentile, all 24 actions | 890.6 ms | 355.4 ms |
| Median JavaScript dispatch | 40.6 ms | 8.6 ms |

The first-action observations improve substantially; repeated actions improve by about 26% at the pooled median. There are only two fresh-process samples per build, and host load varies, so these observations do not establish a general latency bound. All four final collapsed document captures are pixel-identical, with RGB SHA-256 `c8bd010142efbb8e4a721f080c55465f909812e3944fcfefa822d6ccee3771bb` for the 800×488 document viewport. Browser chrome is excluded.

The native comparison replays a private cached thread and its original nine scripts, using the original `togglecomment()` implementation. A fixed native proxy control supplies reproducible coordinates. The page has no external assets and includes the collapse CSS needed for the replay; it is not a complete live-site rendering benchmark. Every workload has fixture SHA-256 `3e5f620477bedd2f6c391db19591977a9925291d95e61daeab4cd61296cc8e40`.

The native endpoint runs from injected mouse-down through the returning native layer update. It excludes physical display scanout. Handler state and the actual native DOM class are checked after each action/frame; both must alternate between expanded and collapsed. Final runs have no engine phase-timing logging, diagnostic selector replacements or collector overrides. The read-only native state check runs after the frame timestamp.

Brave’s fresh reference run uses the same cached input with real CDP mouse events. Six actions measure a 1.95 ms median for the handler plus forced layout, and 28.1 ms through two animation frames. Brave reports Chromium `155.0.8059.85` through CDP. The native and Brave endpoints differ, so these observations are not a percentage comparison between engines. Vox remains slower. Whole-document formatting, DOM attachment, paint transport and command generation remain substantial native costs.

Focused checks passed in both ordinary and no-GC configurations for each implementation slice. The ten-fix checkpoint (three prior fixes plus these seven) additionally checked all tracked sources in five selected packages: 1,244 source test files and 4,741 distinct test functions per GC configuration. Original bodies were aggregated with import aliases and run in a fresh process per original file. Selection controls verify that unselected bodies do not run and that assertion failures and returned errors retain failing exits. This is not a claim that the entire repository or the current moving HEAD passed.

After the separate fixture repairs, 4,727 of 4,741 selected functions pass per configuration. Fourteen failures also reproduce at the pre-follow-up baseline `b3b375f5` in both GC modes, with identical test-source hashes: three viewport resize cases, two browser media namespace cases, and nine root cases covering media ownership/source namespaces, animation frames, page-cache metadata, track handlers and view transitions. The raw broad test exits remain nonzero. The accepted checkpoint receipt means that coverage completed with no new failed functions; it explicitly records `all_tests_passed: false`.

One no-GC XHR file originally stopped after its local timeout server panicked. A fresh process running the unchanged binary and source passes its three functions. Both the original incomplete attempt and the successful retry remain recorded. Broad execution completes this ten-fix batch at `f0e55dc7` plus the fixture repairs; those fourteen baseline failures remain open.

The unchanged LibJS source union comprises 236 files/782 functions per configuration, and the official AST driver matches all 100 upstream inputs exactly. Browser execution continues to use JavaScriptCore. The native bundle passes strict signing, headless startup, real-script comment interaction without navigation, all eight required SVG mutation comparisons exactly, and eleven default screenshot comparisons (eight exact, three within their existing allowances).

Fixture corrections are separate commits: `5b09819e` updates the compact arena metadata assertion; `c022b485` checks cleared phase records while retaining private storage; `4e9a452a` uses the native PNG typedef; `4f4a4fca` uses the current context-creation arguments; and `08255e48` gives the transition fixture an active document timeline and an explicit clock. Existing behavioral assertions remain intact, except storage assertions that now check the implemented private-buffer lifetime contract.

Broad unit validation is fixed at `f0e55dc7` plus these fixture repairs. Production was built from the frozen `source-round7` snapshot, taken at HEAD `5db7d05f` with concurrent working-tree changes, including the CSS property-page copy-on-write improvement `ca92ef73`. Its manifest records 6,348 copied files. All 44 focused integration cases (28 layout, 14 root, two browser bindings) pass in both GC modes on this exact snapshot. Before installation, all 4,237 recorded code and build-script inputs still match the working tree. Later edits and newly added files are outside this validation pin. Timings compare the old installed build with this integrated production build and do not isolate savings attributable to each individual commit.

The old measured executable has SHA-256 `9d6286d94254e1a2b19098f6e7c633f3f67573856c7212dad34db22db6b3536f`. The measured, signed and installed executable has SHA-256 `6347f743634d651c562a2b2d10de63a97649cdc30d9840ad4462627cbe64f456`. The production C input has SHA-256 `04421dfe63520f4264b787a5b5f5110bcdc185780dc062e8cacb586fefe91931`.

Failed and cancelled attempts remain under the private `Build/reddit-comment-latency/` directory. They include superseded builds, aggregate import collisions, test harness corrections, an interrupted native launch, and pre-repair fixture failures. None receives wholesale passing credit. The receipts retain actual compiler, process and test exits; diagnostic completion status is distinguished from test success.

The verified bundle is installed at `Build/v/Vox.app`; strict signing and headless startup pass after installation. The previous bundle is retained privately, and installation verifies that the executable is byte-identical to the timed candidate. Existing browser processes were left running; restarting Vox loads the new executable.

Private evidence lives under `Build/reddit-comment-latency/`: `round7-final-timing.json`, `round7-brave.json`, `round7-final-pixels.json`, `round7-snapshot-manifest.json`, `round7-focus-{layout,root,browserjs}-{default,none}.json`, `round6-broad-verified.json`, `round7-generated-source.json`, native/screenshot receipts and `installed-round7.json`. Original failure logs and baseline reproductions are retained alongside them.
