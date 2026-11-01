# Stack Overflow versus Brave, 2026-11-01

Seven alternating fresh-process pairs measured **27,723,596,574** median
observed retired CPU instructions for Vox and **10,379,419,729** for Brave.
Vox uses **2.6710× as many instructions**, or **167.10% more**, for this frozen
Stack Overflow questions-page workload. Stack Overflow does not qualify for
the optimized-sites table. No engine changes or optimization credit result
from this measurement.

| Pair | Vox observed instructions | Brave observed instructions |
| --- | ---: | ---: |
| 1 | 29,261,686,482 | 10,307,787,696 |
| 2 | 28,622,532,946 | 10,358,041,668 |
| 3 | 27,465,872,311 | 10,301,011,896 |
| 4 | 26,909,794,622 | 10,418,589,002 |
| 5 | 27,723,596,574 | 10,570,103,840 |
| 6 | 26,844,031,487 | 10,379,419,729 |
| 7 | 27,733,262,369 | 10,409,458,431 |
| Median | **27,723,596,574** | **10,379,419,729** |

The highest observed Vox count divided by the lowest observed Brave count is
**2.8407**. The observed 10% reduction gate fails:
`10 × 29,261,686,482 = 292,616,864,820` exceeds
`9 × 10,301,011,896 = 92,709,107,064`.
These are comparisons of observed counts; neither browser's sampled tree is
a proven upper bound. Cross-browser pixel equality also remains unmet.

The [portable ledger](benchmark-results/stackoverflow-brave-2026-11-01.json)
retains exact counts, process identities, commands, executable/library pins,
validation results and hashes of the raw evidence. The earlier
[three-variant diagnostic](STACKOVERFLOW_MACOS_PR_COMPARISON.md) remains a
separate historical measurement with different builds and script policies.
Its before/after figures do not establish savings in this cohort.

## Workload and checks

Both browsers load `https://stackoverflow.com/questions` through the same
sealed original-origin replay of `Tests/Browser/Brave/sites/stackoverflow/`.
The archive contains **56 responses**, including a **282,540-byte** guest DOM
snapshot with author scripts removed. Its manifest SHA-256 is
`86a9d1fc61aeebf0c382e15105a0aaec5926ddef0a4841ca6c8be077622d55e6`;
the HTML SHA-256 is
`592d214f1f87bc26c3aa98ca70bb609dd03e0dad76b5558828e967d7ada7a8e1`.
The acquisition used POST; replay serves the frozen document with GET. This
measures the archived questions page, without live scripts or interaction.

Author JavaScript is disabled in both browsers. Each launch has an empty private
profile and cache; ambient proxy, injection, scripting and heap overrides are
removed. Both use a **1024×768 CSS-pixel viewport** and capture scale **1**.
OS filesystem and shader caches are retained. There is no additional fixed
settle delay: capture follows complete document readiness and font readiness,
with the native browser's capture scheduling retained. Vox is windowed on the
test display; Brave uses its headless CDP document capture.

Every capture passes document URL, title, readiness, viewport, all **15 ordered
question IDs**, font, required stylesheet and visible-image checks. All full
body texts are **50,138 UTF-8 bytes** with SHA-256
`bad7d041cd4ea2ff3023e9c6f31aac08b2a0451ced7c9ef3edf1a79adcdce016`.
The replay serves every required resource without transport errors and never
forwards missing requests. Vox's missing favicon returns 404; Brave's auxiliary
proxy requests are denied. Those blocked requests remain in the raw logs.

Two separate preflight captures establish fixed per-engine references before
the seven-pair cohort. All **14 measured captures match their respective
references at every pixel**. Across engines, **2,061 of 786,432 pixels differ**
(0.2621%, maximum channel error 156). Both screenshots were inspected. This is
rendering stability within each engine, without cross-browser pixel parity.
No reference, pixel tolerance, sample or attempt is changed to obtain a result.
The preflight counts, retained separately, are Vox **30,038,217,153** and Brave
**10,572,678,367**. No measured pair was retried or excluded.

## Counter, build and host

The backend for both engines is macOS
`proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions`, including charged kernel
execution, sampled every **5 ms** over each freshly launched browser tree.
Startup and native window/target setup are included for both. Vox's endpoint
is root exit after native PNG capture, semantic audit and teardown, with its
final counter read from the unreaped zombie. Brave's endpoint is the last
completed polling pass before its first PNG CDP response, including PNG encoding
and delivery but excluding subsequent semantic audit and shutdown. Its polling
gaps are **1.31–5.87 ms**. Observer-side cropping, replay work, GPU execution and
services outside the observed process tree are excluded.

Both totals are polling lower bounds: short-lived unsampled children and final
helper work may be missed. Exited observed tasks retain their latest readings.
All seven Vox roots have final readings; the observed adblock helper remains
part of the sum. Brave's missing-final-sample counts are **2, 1, 2, 1, 3, 2, 2**.
No counter reads are denied. These endpoints measure browser launch/capture
workflows, without isolating layout work, rendering latency or scrolling fps.

The latest available completed, signed `Build/v/Vox.app` is copied to
`Build/stackoverflow-brave-20261101-5dz2a5h8/measured/Vox.app` and pinned before
launch. No production build is requested. The executable SHA-256 is
`abc8a9fe092d85775314114a161159c864e2a8abdca3d09cb352cc727633eaca`;
the Skia text library is
`d7f3425345833b74290a3b4e4ff7b9c814a989ab3044f1436c264bcc39d3b17f`.
The mutable source checkout's HEAD is not asserted to identify this bundle's
source revision. Native dependencies, the adblock helper/snapshot, Brave's
framework/helpers, the fixture and measurement sources stay pinned through
the run. Brave is **156.1.98.60**, reporting Chromium **156.0.8078.48**.

The macOS arm64 host has **18 logical CPUs**. Per-observation one-minute load
averages span **5.27–7.03**, with independent compilation active. The default
**12 GiB** memory guard records **1,581.34 MiB** peak aggregate RSS and **37.77 s**
for the complete job. Both browser roots launch directly as guard descendants;
LaunchServices adoption is not needed. All 16 browser exits, including
preflights, and the benchmark and guard exits are zero. The pinned bundle's
headless startup check and **60 focused measurement/audit/counter tests** pass.

Raw commands, per-process counts/PIDs, audits, screenshots, fixed references,
replay requests, host timestamps, verification and guard receipts are retained
under `Build/stackoverflow-brave-20261101-5dz2a5h8/`. Its `measure.py` records the
protocol; a reproduction must use a new output directory with the same pinned
bundle and unchanged references. No runtime optimization advances the broad
regression verification ledger. These macOS hardware counts must remain
separate from [Linux Cachegrind results](STACKOVERFLOW_LINUX_PERFORMANCE.md).
