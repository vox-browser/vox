# Graphite2 removal — 2026-11-12

Commit `80883d6ba` removes the macOS browser's Graphite2 dependency. Setup and
production builds prepare pinned HarfBuzz 15.1.0 with Graphite2 disabled, keeping
OpenType, AAT, CoreText and fallback shaping. Homebrew's HarfBuzz archive is no
longer linked. The production builder rejects Graphite2 library dependencies
and unresolved `gr_*` symbols. Its HarfBuzz license ships in the bundle.

Font selection, Unicode handling and glyph-run policy remain in V. This change
does **not** implement Graphite's Silf virtual machine in V: fonts requiring
Graphite-specific shaping lose that optional backend. Native HarfBuzz remains.
Linux and Windows continue using their system HarfBuzz packages.

## Pixel results

On arm64 macOS 27.2, fresh processes captured the document viewport at 1024×768
CSS pixels, backing scale 2 (2048×1536 PNG pixels). Every comparison below has
**0 differing pixels out of 3,145,728**, maximum channel error 0, MAE 0 and RMSE 0.
No reference or tolerance changed.

| Comparison | Result |
| --- | --- |
| Baseline archived ChatGPT vs unchanged Brave reference | Exact |
| Graphite-free archived ChatGPT vs unchanged Brave reference | Exact |
| Baseline vs Graphite-free archived ChatGPT | Exact; PNG files also byte-identical |
| Baseline vs Graphite-free live `https://chatgpt.com/` | Exact; PNG files also byte-identical |

The frozen workload is
`Tests/Browser/Brave/archives/chatgpt-home-20261104-v2`, replayed at its original
origin with its private TLS CA. Both runs passed the existing content gate:
complete ChatGPT document, matching title, headings, editor, links, viewport
button identities and no script/native errors. The captured audit contains
1 heading, 1 editor, 48 buttons, 27 links and 2 images. Screenshot settling was
8 seconds; each run used a new private profile and cache.

The separate live captures used new private profiles/caches, no ambient proxy
overrides and a 12-second screenshot delay. Both reached the same complete
ChatGPT document with visible heading and editor. Both emitted the same Google
One Tap/FedCM migration warning and no native errors. These observations cover
the anonymous homepage, not authenticated conversations or other page states.

Candidate checks held a shared canonical bundle lease and verified executable
and bundled-library hashes throughout. All browser and memory-guard exits
were 0. Fresh browser PIDs were 73466/94628 for archived baseline/candidate and
81625/94864 for live baseline/candidate. Existing browser processes were not
reused.

## Identities

| Input | SHA-256 |
| --- | --- |
| Archived baseline executable | `0d14fc3afa4a01f240950faa205804e79869ddda67f0c3a37ada0e7026c35162` |
| Live baseline executable | `7162d232e7d2602fa603bf60f60ab35c317744cb9bbad88894299aafd4a0f3e3` |
| Graphite-free executable, both captures | `674a20506eaff71ed6634e1b263fafdc2a40c1c433d759113ed7b2b0bc3ad4a4` |
| Bundled AVIF library, all captures | `894ad5b1c9fe2c3f5977ed267feea5c1239f55a2760c3ef7b7a47c71ad023d4b` |
| Graphite-free HarfBuzz archive | `7b2f08d6d4e89c7cbfe232a3965c8c0c54ef413cb6dd534ebe75e319d1509a63` |
| Replay manifest | `7b13757f970e2f615267938bd52f902b852da239962fa265660db813622923f7` |
| Replay main document | `446498cdb6bca7b8d06c58bb9245168b5790315ca9ff69f64cf1318491092808` |
| Unchanged Brave reference PNG | `6e81a153394cf640168483ae1979025df0271c4886a6f44e83792d548106028e` |
| Archived baseline and candidate PNGs | `fb087b57bf4ee8b3c20375066f25bebd73bf0ad1141776805e46edfbf3920448` |
| Live baseline and candidate PNGs | `86158dc63595bbef3579e55bb2d4365c14a1a44a88020ad6f3dd2873b609a3d2` |
| Existing pixel-diff executable | `f340c01cfa7a91f03313608183160f2ecf7070edaee34ddacd47d7a5d83d9a91` |

Production receipt `20261112-135354-a99a1543` completed with compiler, build and
guard exits 0, using literal V `-prod` in one C unit. Its sealed inputs pin the
new HarfBuzz archive and the committed font-linkage source. It contains no
Homebrew Graphite2 linker path. An earlier in-flight build was rejected when
the build script changed; it did not replace the completed baseline bundle.

## Focused checks

- Five V tests passed with default GC and again with `-gc none`:
  `harfbuzz_backends_darwin`, `harfbuzz_mark_offset`,
  `chromium_harfbuzz_advance`, `variable_font`, `harfbuzz_idle`.
- The backend test requires exactly `ot`, `coretext`, `fallback`.
- Three HarfBuzz builder tests and five development-environment tests passed.
- The CoreText hyphen-cache test compiled and passed against the pinned archive.
- The production linkage check passed. The former executable was correctly
  rejected by the same check. The new archive has no unresolved `gr_*` symbols.
- A fresh `--headless-smoke` process passed (PID 95504); its dyld library log
  contained no Graphite2 library.
- Shell syntax and Git whitespace checks passed.

Archive captures used `python3 tools/test_chatgpt_pixels.py --output
Build/graphite2-{baseline,candidate}-20261112`; that tool applies its 3 GiB
memory guard. V tests used `-b c -cc clang -cflags -O0 -memory-limit 10G
-enable-globals`, with the same 3 GiB aggregate guard; the no-GC run used
`VJOBS=1`. Native dependency and production builds used the default 12 GiB guard.
Live captures used the same browser viewport arguments as the archived check,
`VOX_TEST_WINDOW=1`, `VOX_CAPTURE_DOCUMENT_ONLY=1`,
`LADYBIRD_SCREENSHOT_SCALE=2`, `LADYBIRD_SCREENSHOT_DELAY_SECONDS=12`, and the
existing capture audit selectors. The smoke check used `DYLD_PRINT_LIBRARIES=1`.
Per-job screenshots, profiles, logs, locks and guard reports were removed after
recording these results, as required by the repository's Build scratch policy.
