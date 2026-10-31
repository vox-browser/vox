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
helpers and exited tasks, but exclude GPU execution and outside services.

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
