# Linux render instruction measurements

`tools/measure_browser_instructions.py` can measure the Linux Vox executable
through a native window screenshot. It has three separate counters:

| Backend | Metric | Scope |
| --- | --- | --- |
| `linux-perf` | Hardware-retired user-space instructions | The launched task and inherited threads/children, enabled at `exec` |
| `callgrind` | Valgrind Callgrind `Ir` guest instruction references | Main process, including its threads and instrumented libraries |
| `cachegrind` | Valgrind Cachegrind `Ir` guest instruction references, cache/branch simulation off | Main process, including its threads and instrumented libraries |

The default `auto` selects Linux hardware counters on Linux and the existing
libproc counters on macOS. It never falls back to a software counter. Linux hardware
counts exclude kernel and hypervisor execution; macOS libproc counts include
charged kernel execution. Compare each backend only against itself on the
same host and binary architecture.

Callgrind and Cachegrind are useful when a container has no accessible
performance-monitoring unit. Both use software instrumentation; their counts
and elapsed time must not be reported as native hardware efficiency or native
render latency. Their absolute Ir totals can differ for the same program, so
never mix them in one comparison. Callgrind preserves call-graph attribution
in `.callgrind.PID`; Cachegrind retains flat costs in `.cachegrind.PID` with
cache and branch simulation disabled. The driver pins the selected Valgrind
engine, executable and standard installed runtime files, and retains its
version and exact launch command. Runtime overhead depends on the workload.

## Capture contract

The Linux endpoint includes executable startup, native window work, document
readiness, any requested settle interval, PNG capture and process teardown.
It excludes external services such as Xvfb and GPU execution. The perf backend
attaches before the target can execute, enables its event at `exec`, retains
the target as a zombie until the final read, and rejects zero, unavailable or
multiplexed counts. Nonzero exits, timeouts, and running children invalidate
that endpoint. Callgrind requires a successful process exit and a complete,
positive `Ir` total belonging to the launched process, with exactly one part
and the `Program termination` trigger. Interactive dumps reset segment
counters, so both manual dumps and later termination segments are rejected
as incomplete measurements. Cachegrind requires one Ir event, one final
positive summary, and matching flat cost rows. Its format has no PID or
termination marker, so the driver selects only the launched root PID's file
and requires a successful process exit before parsing it. A terminated process
can leave a valid-looking Cachegrind summary; that summary is never sufficient
proof of completion. Both software backends reject running child processes
and deliberately do not sum child profiles, which can inherit earlier costs.

Each Linux observation uses a fresh private browser profile and an empty
cache, or a fresh copy of `--cache-template`. The window is 84 pixels taller
than the document viewport: 60 pixels of tabs/toolbar and a 24-pixel status
bar. `--screenshot-viewport-height` pins the document layout height. Pillow
crops the native PNG after measurement; macOS continues to use `sips`.

The native capture audit must show the requested URL and viewport, a complete
and active document, and nonempty paint commands. `--expect-title` adds an
exact title check. `--capture-audit-config` supplies additional native
selectors, attributes and layout audits. `--expected-png` requires exact
decoded RGBA pixels, independent of PNG compression or metadata.
Sokol panic/error messages also invalidate a capture, even when the process
exits successfully and writes a PNG. The log and screenshot remain available
for diagnosing missing images or invalid sampler bindings.

Linux rendering is not pixel-equivalent to the macOS renderer. Use a Linux
reference captured with the same renderer, fonts, viewport and scale.

## Example

Build the browser and dependencies using [LINUX.md](LINUX.md). Install
Valgrind only for the explicit software backend, and install Pillow for the
portable PNG checks. Xvfb, xauth and xdotool are used by the existing Linux
browser checks.

For the sealed Stack Overflow fixture, use the complete orchestrator. It
starts the original-origin replay in a separate process, creates fresh Xvfb
displays, pins executable/dynamic-library identities, and checks all question
IDs in their original order, body text, fonts, visible images, required
resource responses, and exact pixels against the first baseline capture:

Fonts must finish loading. The sole failed-font allowance is a local-only
fallback declared in the sealed CSS (for example, Windows Segoe UI faces that
are absent on Linux). The fixture must identify every declared local source;
any ambiguous or URL-backed face in that family disables the allowance.
Unavailable local faces remain recorded in the result, and font identities
and decoded pixels must match across all observations.

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/stackoverflow-linux-baseline.lock \
  --report Build/stackoverflow-linux-baseline-guard.json -- \
  python3 tools/stackoverflow_browser_instructions.py \
    --binary Build/linux/vox \
    --counter-backend cachegrind --pairs 1 \
    --output Build/stackoverflow-linux-baseline \
    --timeout 1800
```

For a matched comparison, supply `--candidate PATH`, use `--pairs 3` or more,
and select a new output directory. Keep the same explicit backend for all
observations; `callgrind` remains available when call-graph attribution is
needed. Baseline/candidate order alternates. The
summary retains every count, paired change, median, failed observation and
resource-replay discrepancy. The default 15% gate compares the largest
candidate count to 85% of the smallest baseline count. An unmet target or
invalid observation returns nonzero; a baseline-only run has no improvement
gate. `--use-display` explicitly reuses the caller's display instead of
starting Xvfb. The complete controlled environment is recorded, including
`GC_MARKERS=1`, `LIBGL_ALWAYS_SOFTWARE=1`, `GALLIUM_DRIVER=llvmpipe`,
`LP_NUM_THREADS=1`, and disabled Mesa shader disk caching.

The generic driver is also usable directly:

Start the existing archive replay in a separate process. Its `ready.json`
contains the loopback proxy URL and a process-private CA certificate:

```sh
python3 tools/page_archive.py replay \
  Tests/Browser/Brave/sites/stackoverflow \
  --output Build/linux-stackoverflow-replay
```

Supply those exact `proxy` and `ca` values as `VOX_PROXY` and `SSL_CERT_FILE`.
The replay preserves the original HTTPS URL, verifies archived body hashes,
and rejects missing requests instead of forwarding them to the live site.
Clear ambient HTTP/HTTPS/ALL proxy settings and both no-proxy variables so
they cannot bypass the sealed route. For example, with the two replay values
already assigned:

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
    -u all_proxy -u http_proxy -u https_proxy \
    NO_PROXY='' no_proxy='' \
    VOX_PROXY="$replay_proxy" SSL_CERT_FILE="$replay_ca" \
    GC_MARKERS=1 LIBGL_ALWAYS_SOFTWARE=1 \
  python3 tools/run_memory_bounded.py \
    --lock Build/linux-stackoverflow-control.lock \
    --report Build/linux-stackoverflow-control-guard.json -- \
  xvfb-run -a -s '-screen 0 1280x1024x24' \
  python3 tools/measure_browser_instructions.py \
    --engine vox --counter-backend=callgrind \
    --binary Build/linux/vox \
    --url https://stackoverflow.com/questions \
    --width 1024 --height 768 --settle-seconds=0 \
    --expect-title 'Newest Questions - Stack Overflow' \
    --output Build/linux-stackoverflow-control/capture \
    --timeout 1800
```

The repository archive
`Tests/Browser/Brave/sites/stackoverflow/` describes a frozen guest DOM with
author scripts removed and original resource bytes. Preserve that workload
description when reporting results. A frozen fixture does not establish a
live script-enabled page result.

The browser already waits for the document's capture-readiness checks before
scheduling the Linux screenshot. An explicit zero settle interval avoids
adding a speed-dependent number of extra frames under instrumentation. If a
workload needs settlement, keep `--settle-seconds` identical and disclose it.
The default is the Linux browser's two-second settle interval.

Run baseline and candidate in alternating order with identical binaries'
build flags, fixture bytes, cache, display, GC configuration, and runtime
libraries. `--runtime-library PATH` pins additional non-system libraries and
can be repeated. Point candidate runs at a verified baseline viewport with
`--expected-png`; retain content audits as well. Preserve every sample and
failure, and use a new output prefix for every trial. The software counters refuse to
reuse a prefix that already has instruction evidence.

The JSON output names the metric explicitly. `median_instructions` is a
within-backend summary; report both medians, paired differences, all sample
counts, and the exact endpoint. A 15% reduction requires candidate counts at
most 85% of the matched baseline for the stated metric, together with
unchanged rendered output and relevant correctness checks. Do not credit
elapsed-time differences as instruction savings.

Focused tooling checks:

```sh
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/linux-counter-tests.lock \
  --report Build/linux-counter-tests-guard.json -- \
  env PYTHONPATH=tools python3 -m unittest \
    linux_instruction_counts_test measure_browser_instructions_test \
    process_instruction_counts_test stackoverflow_browser_instructions_test
```

On a Linux container, these process tests and real Valgrind runs require an
execution environment exposing normal `/proc` and process APIs. A PMU error
is retained as a failed hardware observation; explicitly select a software backend
only when that different metric is appropriate for the investigation.
