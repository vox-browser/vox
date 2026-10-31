# Cached Hacker News home-page instructions

The target is a Vox instruction count at most 80% of Brave's, while preserving
the complete home page. It has **not passed** the initial comparison.

`Tests/Browser/Brave/hn-home-instructions/` contains the original home-page
response downloaded on 2026-10-31 and its five referenced resources. The sealed
archive records URL, response headers, body hashes and download provenance.
Original author scripts are retained. Repeated comparisons replay these bytes
over loopback HTTP; they do not download the changing live home page again.
The loopback origin differs from the original HTTPS origin.

The unchanged Brave reference is
`Tests/Browser/Brave/expected/hacker-news-home-instructions.png`. It uses a
1024×768 CSS viewport and the display's native 2× scale, with sRGB output.
Each observation verifies every pixel, all 30 story IDs in source order,
document readiness, URL, viewport, exclusive resource-coalition membership,
and successful process exit. Both browsers use fresh private app copies,
processes, profiles and caches, with alternating trial order.

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
    -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py \
    --lock Build/hn-home-comparison.lock \
    --report Build/hn-home-comparison-guard.json -- \
  python3 tools/hacker_news_browser_instructions.py \
    --output Build/hn-home-comparison \
    --home-archive Tests/Browser/Brave/hn-home-instructions \
    --diff-tool Build/hn-home-instructions-20261031/pixel_diff
```

Use a new evidence directory and guard-report filename for each run. The
home-page default threshold is 0.8; the discussion-page default stays 0.9.
The gate compares the largest Vox count with the smallest Brave lower bound,
using integer arithmetic. Every attempt is retained. Missing counters, failed
loads, omitted stories, pixel mismatches and abnormal exits cannot pass.

The endpoint is navigation request through encoded PNG availability. Native
markers precede the file write; Brave's endpoint includes CDP base64/IPC
delivery and readiness polling. Vox requests navigation before its first
native window frame, whereas Brave creates and resizes a blank window before
navigation. Counts include filtering, native window work, layout, paint,
settlement and capture inside those boundaries. They are not an isolated
internal rendering comparison. Resource-coalition counters include owned
helpers, exited tasks, and coalition-owned Metal compiler and CascadeSets
update services, but exclude GPU execution and outside services. The two
system service executables are accepted only at their exact system paths and
pinned when present. Other unaccounted executables still invalidate a run.

The initial valid three-pair comparison is retained under
`Build/hn-home-instructions-20261031/baseline-v2/`, with browser identities,
logs, raw counters, sampling bounds, content audits and exact pixel results.
Vox's median is 4,278,112,550 retired instructions. Brave lower bounds are
3,432,753,188; 3,384,594,163; and 1,499,422,091. The conservative ratio is
2.8621, exceeding the 0.8 target. The wide Brave variation must remain visible;
the slower Brave trials cannot be selected to claim success. The earlier
`baseline/` retains rejected Vox attempts caused by ambient proxy controls
and receives no complete-pair credit.

The baseline harness originally described its historical discussion fixture
as script-free. This home-page archive retains scripts; the subsequent shared
harness description and input metadata explicitly record that distinction.
No Vox optimization savings are credited by this cross-browser baseline.

## Rejected pixel-length projection experiment

A general fast path for projecting computed pixel lengths passed 36 focused
regressions in each memory mode, including fractional scales, source ownership
and property flags. The signed production candidate passed startup and had
stable build inputs. Its sole runtime source difference from the pinned
completed control was `css/device_layout_style.v`.

Five alternating matched trials did not show a repeatable improvement:

| Trial | Vox control | Vox candidate | Brave lower bound |
| --- | ---: | ---: | ---: |
| 1 | 13,392,288,152 | 13,588,867,416 | 3,377,259,363 |
| 2 | 4,252,428,764 | 4,201,602,490 | 3,348,724,152 |
| 3 | 4,261,465,367 | 4,245,284,513 | 1,338,719,067 |
| 4 | 4,218,982,048 | 4,226,092,956 | 1,444,786,185 |
| 5 | 4,225,965,040 | 4,261,672,682 | 1,335,935,369 |

All 15 observations exited successfully and matched the unchanged reference
pixels and every story ID. The candidate improved two of five pairs and
regressed three; paired savings were −196,579,264, +50,826,274, +16,180,854,
−7,110,908 and −35,707,642 instructions. The median difference was only
7,144,251 instructions (0.168%), while the median paired saving was negative.
The early large counts remain included; their cause has not been isolated.
The conservative candidate/Brave ratio was 10.1718, failing the 0.8 gate.

The speculative runtime change and its temporary test were removed. They earn
zero optimization credit, so the retained-savings broad-verification ledger
does not advance. The prior completed control bundle was restored atomically
after verifying that the installed executable still belonged to this
experiment. This experiment queued no further production build. Its executable SHA-256
is `233fbd2fac67f2695d49435fb6ea84f91c7fe958bfb83b24ac93a89fe125de86`.

Complete commands, build receipts, all counts and failures, host load records,
audits, PNGs, the rejected patch and restoration receipt remain under
`Build/hn-home-instructions-20261031/`. The successful cohort is `matched-v2/`.
The earlier `matched/` cohort remains rejected: its unexpected macOS
`SetStoreUpdateService` member triggered the old ownership gate, and one Vox
process finished before the observer could establish live membership.
The harness now explicitly accounts for that exact service and includes its
instructions in both browsers' totals. These are still full capture-workflow
counts, including startup and system-service variation within the recorded
boundaries. They do not isolate rendering or establish the requested 20% win.

The retained benchmark's 18 focused Python tests pass, including the new
service's exact membership and path checks. A subsequent shared production
build replaced the installed bundle after restoration. A fresh startup check
(PID 12740) passes for that later executable,
`dd50e4e7a7475a9b752ae1a09587e40f35f887f4e2f6dae9f7dea4d78c8f1d2d`;
the performance and pixel observations above belong to the pinned copies in
their evidence directories.
