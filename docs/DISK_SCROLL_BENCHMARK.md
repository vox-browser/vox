# Benchmark scrolling from a disk archive

`tools/page_archive.py` saves original response bodies and headers in a sealed,
SHA-256-checked archive. It discovers HTML resources and recursive CSS imports,
including stylesheets, scripts, images and fonts. It retains author scripts and
inline HTML without serializing or modifying the DOM. Add script-requested
resources explicitly with `--extra-url`; the benchmark rejects missing responses.

For the 4chan thread, capture once through the configured SOCKS proxy:

```sh
python3 tools/page_archive.py capture \
  https://boards.4chan.org/pol/thread/544908349/what-has-the-world-come-to \
  --proxy socks5h://127.0.0.1:1337 \
  --extra-url https://a.4cdn.org/boards.json \
  --extra-url https://a.4cdn.org/pol/thread/544908349.json \
  --extra-url https://a.4cdn.org/pol/thread/544908349-tail.json \
  --output Build/pol-disk-archive
```

Use a new output directory for each capture. `--from-cache DIR` can reuse a raw
Vox native cache, and `--from-archive DIR` can extend a sealed archive without
refetching its discovered responses. Bodies are content-addressed; provenance and
capture times are recorded per response. A partial capture has no sealed manifest
and cannot be replayed. JavaScript dependencies and changing API URLs may require
additional explicit resources for other pages.

On macOS, run two complete trials of the production bundle:

```sh
python3 tools/run_memory_bounded.py \
  --report Build/pol-disk-benchmark-guard.json -- \
  python3 tools/measure_disk_scroll.py Build/pol-disk-archive \
    --binary Build/v/Vox.app/Contents/MacOS/Vox \
    --require-title 'What has the world come to?' \
    --output Build/pol-disk-benchmark
```

The browser loads the original HTTPS URL through a loopback replay server which
reads only archived disk responses. This preserves origins and relative URLs.
Each run trusts a private replay certificate through its own environment; system
trust is unchanged. The replay server never forwards requests. The runner removes
inherited proxy settings and injects a tested native guard denying external DNS
and connections, including `connectx`. SOCKS is absent from benchmark runs.

Every trial launches a fresh process with an empty private profile and cache,
JavaScript enabled, a 1024×764 CSS viewport, twenty seconds of settling after the
required title appears, and 360 precise native wheel inputs scheduled at 60 Hz.
The delta is 12 and direction reverses every 120 events. Actual input delivery
times and backing scale are recorded; blocked main-thread input may arrive late.
`--inputs` and `--settle-seconds` override those defaults.

For an implementation with an environment disable switch, `--compare-env NAME`
runs alternating control (`NAME=1`) and candidate (`NAME=`) trials, twice each.
Establish path eligibility separately before taking optimization credit.
`--input-marker-env NAME` creates a marker after native input starts for separate
diagnostic runs; these results are marked diagnostic only.

The output retains source, executable and native-library hashes, archive and
certificate identities, commands and exit codes, host load, native logs, actual
input timestamps, per-trial replay requests, and interval/throughput summaries.
Changed builds, altered archives, missing resources, navigation failures and
incomplete input invalidate a run. Keep failed runs when retrying with a new
output directory.

Reported fps counts scroll-changing native publications after `updateLayer`
completion over the entire first-to-last input window. Assess median, p95 and
maximum intervals, deadline misses, and leading/trailing gaps alongside throughput.
This endpoint does not measure physical display presentation, and offline results
do not establish live-page performance. See [4chan evidence](4CHAN_SCROLLING.md)
for captured workload identities and measured trials.
