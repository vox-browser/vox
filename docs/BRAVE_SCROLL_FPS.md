# Brave scrolling FPS

Brave now has two completed measurements for each frozen catalog page. The
new [tool](../tools/measure_brave_scroll.py) uses DevTools wheel injection and
Chromium-reported scroll presentations. It works with the installed signed app
without library injection, screen recording or native-event posting permission.

**These are instrumented observations, not an unprofiled optimization acceptance
cohort.** Input enters Chromium’s widget through CDP and bypasses Cocoa. Its
presentation-feedback endpoint is later than Vox’s changed-layer publication
endpoint. Frame-event tracing is enabled. The table labels that distinction; a
direct Vox/Brave FPS ratio would require matched input and observation boundaries.
Neither endpoint proves physical display scanout or smooth 60 FPS.

The [durable receipt](benchmark-results/brave-scroll-2026-11-01.json) retains
commands, browser/tool hashes, exact counts, host load, timestamps, readiness and
content audits, pixel hashes, actual exits and every trial. The
[compressed raw records](benchmark-results/brave-scroll-2026-11-01-raw.json.gz)
contain the exact trace events needed to recompute every result and the protocol
send/ack timestamps. Full traces, screenshots and profiles remain private under
`Build/brave-scroll-20261101/`; archived account-bearing Reddit HTML/PNGs are not
published. The earlier [failed injection attempts](OPTIMIZED_SITES_SCROLL_FPS.md#earlier-brave-probe-failure)
and the original Vox data remain preserved.

## Results

| Page | Trial | Scroll FPS | Input Hz | Counted changes / completed presentations | Input window (s) | Interval median / p95 / max (ms) | Intervals >16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | ---: | --- | ---: | --- | ---: | --- |
| Old Reddit /r/programming/ | 1 | 59.78 | 59.98 | 597 / 600 | 9.986 | 16.667 / 25.000 / 33.333 | 18.26% | 39.547 / 9.409 |
| Old Reddit /r/programming/ | 2 | 59.56 | 59.96 | 595 / 597 | 9.990 | 16.667 / 25.000 / 33.334 | 32.27% | 39.426 / 0.277 |
| Hacker News homepage | 1 | 59.79 | 59.99 | 597 / 600 | 9.984 | 16.667 / 25.000 / 25.001 | 9.05% | 37.259 / 5.259 |
| Hacker News homepage | 2 | 59.78 | 59.98 | 597 / 600 | 9.987 | 16.667 / 16.667 / 25.001 | 3.02% | 43.142 / 10.470 |
| Wikipedia homepage | 1 | 59.57 | 59.97 | 595 / 598 | 9.988 | 16.667 / 25.000 / 58.335 | 14.79% | 70.135 / 13.388 |
| Wikipedia homepage | 2 | 59.79 | 59.99 | 597 / 600 | 9.985 | 16.667 / 25.001 / 33.334 | 26.47% | 42.398 / 13.144 |
| vlang.io (CLI protocol) | 1 | 59.79 | 59.99 | 597 / 600 | 9.985 | 16.667 / 25.001 / 25.012 | 18.59% | 43.987 / 12.118 |
| vlang.io (CLI protocol) | 2 | 59.49 | 59.99 | 594 / 597 | 9.985 | 16.667 / 25.001 / 33.334 | 32.66% | 43.029 / 13.270 |

All eight trials completed **600 wheel inputs**, retained their initial document
content and viewport, and exited normally. Each page’s two starting screenshots
match exactly in decoded RGBA pixels. The first screenshot was fixed before
input began and remained the second trial’s reference. Every Reddit trial retains
all 25 expected post IDs in order; Hacker News retains all 30 story IDs. Root
scroll positions move approximately 0–252 CSS pixels and return to zero. No
attempts were retried or excluded. The cohort memory guard also exited zero.

Intervals above use a literal **16,670 µs** threshold. Chromium trace timestamps
are integer microseconds: a nominal 60 Hz interval can round to 16,667 µs. The
receipt also retains the tool’s stricter 1/60-second deadline counts, including
these rounding crossings. Throughput uses the complete first-to-last Chromium
input timestamp window; the first presentation supplies the reference and all
tail presentations are excluded from the FPS numerator. Leading/trailing gaps
are reported rather than trimming the window to the fastest frames.

## Workload and identity

Brave is **156.1.98.60 / Chromium 156.0.8078.48**, with executable SHA256
`9d53e182ab59b7c430abea0233088cb452694b96843d62ccccbc6c0902b98fe5`
and framework SHA256
`f3c180e20cb50e055e3e4279e4663d79b457ede64f4d2f38e5b58cd92dbf6971`.
The tool pins helpers, native libraries and resource packs too, and checks all
identities again after each trial. The app signature, sandbox and rendering
settings are unchanged. Each trial uses a fresh process, empty private profile
and cache; no cookies or saved proxy settings are imported. OS filesystem/shader
caches are retained. Native windows use the recorded test-display placement.

Every page uses a **1024×768 CSS-pixel document viewport at native scale 2**,
without device emulation. Readiness requires the expected title, complete
document and loaded fonts, followed by 20 seconds of settling. The input
schedule is 600 CDP wheel events, nominally 60 Hz, delta **4.2 CSS pixels**,
reversing every 60 events. This matches the intended CSS displacement of Vox’s
native delta-2 schedule; it does not reproduce the Cocoa adapter or Vox’s late
input timestamps. Protocol send/ack times and Chromium input timestamps are
retained, together with root-position checkpoints every 60 inputs.

The frozen bytes and author-script policies match the corresponding Vox rows:
Hacker News’s six-response archive is served on loopback HTTP with scripts
enabled; Reddit uses the same script-stripped `/r/programming/` file and its
sealed original-origin resources, with normal script policy enabled; Wikipedia
uses its 15-response original-HTTPS archive with author scripting disabled;
vlang.io uses the same initialized DOM/local assets, scripts removed, animations
disabled and video poster fixed, with normal script policy enabled. Inspector
evaluation supplies measurement audits independently of author-script policy.
These are neither live-site nor JavaScript-engine performance claims.

Original-origin resources come from a sealed SOCKS/TLS replay with a private
certificate SPKI pin. File/loopback cases use a closed loopback SOCKS port for
non-loopback requests; no route forwards to the live network. All document
resources loaded without recorded HTTP or transport errors. Reddit’s separate
application-install manifest reports `net::ERR_FAILED` in both file-origin
runs; this non-document limitation is retained in the receipt. Host CPU count,
load averages and start/end times are recorded for each trial.

## Frame observer validation

CDP’s [wheel API](https://chromedevtools.github.io/devtools-protocol/tot/Input/#method-dispatchMouseEvent)
provides CSS-pixel deltas. The tool enables only `input.scrolling`,
`disabled-by-default-devtools.timeline.frame` and `blink.user_timing`, with all
other categories disabled. No CPU samples, screenshots or rendering overrides
are collected during the input window. A unique inspector performance mark
identifies the intended renderer; other renderer events cannot count.

The parser joins nonzero, `DAMAGING` `ScrollJankV4` records to their `Presentation`
events by exact frame-result ID and verifies their input IDs. Chromium’s
[tracing recorder](https://chromium.googlesource.com/chromium/src/+/HEAD/cc/metrics/scroll_jank_v4_tracing_recorder.cc)
emits that event at the damaging frame’s reported presentation timestamp.
Each counted feedback timestamp must also match a complete, non-missing-content
presentation from the independent
[compositor reporter](https://chromium.googlesource.com/chromium/src/+/HEAD/cc/metrics/compositor_frame_reporter.cc).
The parser rejects missing inputs, an unconfirmed final input, unknown or
duplicate frame/input IDs, incomplete presentations and invalid timestamps.
Coalesced inputs can legitimately yield fewer presented frames.

A separate animation-only control produced **302 presented compositor frames
and zero damaging scroll frames**, with root scroll position stationary at zero.
The positive 180-input diagnostic recorded 180 scroll presentations. Nine focused
tests also cover animation/foreign-renderer rejection, coalescing, exact large
signed IDs, boundary stalls, missing completion and invalid feedback. The new
method adds frame-event instrumentation, so its overhead is not established as
zero and these results carry no unprofiled optimization credit.

Upstream HEAD sources document the observed trace contract; the installed
`Browser.getVersion` revision was unavailable from upstream Gitiles. The receipt
pins the downloaded reference-source hashes and installed browser identities,
and preserves the empirical controls instead of claiming an exact source-build
match.

## Reproduce

Start the recorded sealed fixture replay, then run two trials with fresh output
directories. Preserve the first trial’s initial PNG as the second’s reference:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/brave-scroll-UNIQUE.lock --report Build/brave-scroll-UNIQUE-guard.json -- \
  python3 tools/measure_brave_scroll.py \
    --url FIXTURE_URL --require-title EXPECTED_TITLE \
    --output Build/brave-scroll-UNIQUE \
    --network-policy "Describe the sealed replay and lack of live forwarding"
```

Defaults select the recorded viewport/scale, schedule and 20-second settle.
For Reddit/Wikipedia supply `--proxy-server` and `--certificate-spki` from their
private replay. Wikipedia additionally needs `--script-policy disabled`.
For the second trial supply `--reference FIRST_TRIAL/initial.png`. Exact commands
and the orchestration source are in the durable evidence. Tooling commit:
`2e956b65`.
