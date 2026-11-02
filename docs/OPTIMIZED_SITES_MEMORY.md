# Optimized site RAM measurements

The RAM columns in [the optimized sites table](../OPTIMIZED_SITES.md) use
separate measurements from 2026-11-02 on the completed canonical production
bundle. Each value is the **median observed peak simultaneous process-tree
physical footprint**, expressed in MiB (1,048,576 bytes). The instruction counts
and their original cohorts remain unchanged.

| Frozen workload | Complete pairs | Vox RAM MiB | Brave RAM MiB |
| --- | ---: | ---: | ---: |
| Lobsters homepage | 2 | 535.2 | 992.4 |
| Old Reddit /r/programming/ | 2 | 607.1 | 608.3 |
| Hacker News homepage | 2 | 559.7 | 639.2 |
| CNN homepage | 2 | 1,234.0 | 1,031.5 |
| Wikipedia portal | 2 | 515.1 | 614.2 |
| vlang.io | 3 | 709.6 | 668.9 |

## Metric and scope

An external observer samples `proc_pid_rusage/RUSAGE_INFO_V4/ri_phys_footprint`
every nominal 20 ms. Each observation sums **current footprints in the same
sampling pass**, including the root and observed live browser descendants.
Discovered children remain tracked after reparenting; PID/start-time identities
exclude reused PIDs. Observed GPU, renderer, utility, filtering and other browser
helpers are included. Replay, observers, other user browser instances and
services outside the observed process tree are excluded.

The maximum of these simultaneous sums supplies each run's peak. The table
takes the median of complete pairs' per-browser peaks. This is macOS charged
physical memory, rather than summed RSS, a sum of different tasks' lifetime
maxima, or a settled working set. Shared clean mappings are treated differently
by macOS physical-footprint accounting than by RSS.

Sampling begins after discovery of a fresh root and runs through its normal
exit, including PNG encoding and semantic audit allocations. These are observed
polling lower bounds: earlier startup, short-lived unsampled children, and
helpers reparented before discovery can be missed. Root discovery times, actual
sample gaps, peak task identities and individual footprints are preserved.
This does not measure total system RAM or memory allocated by external services.

Each selected browser exits zero and passes a source-derived complete-content
audit. Generic fixtures require the title, URL, readiness, viewport, full
normalized body-text hash and image-source/srcset inventory. Lobsters and CNN
reuse their detailed story/headline and visible-image audits. All raw native
ownership and actual exit records remain retained. Historical pixel mismatches
set the original observation status to nonzero even when browser exit, memory
sampling and semantic audits succeed; that distinction is retained explicitly.

## Workloads and browser identity

The tests reuse the saved instruction fixtures at a 1024×768 document viewport:

- Lobsters and CNN use their original-origin sealed TLS replay, prepared closed
  full-uBO profiles and encoded-resource caches, scale 1 and five-second settling.
  Brave uses full uBO with automatic updates disabled and empty user filters;
  Vox uses its bundled filtering. Frozen author scripts remain removed and
  normal scripting/scriptlets are retained.
- Hacker News uses the existing archived 30-story homepage, loopback replay,
  fresh profiles/caches, native scale 2 and two-second settling. Original script
  bytes are retained, as in its instruction workload.
- Old Reddit uses the same frozen programming page and 120-response TLS replay,
  fresh profiles and independent encoded-cache copies, scale 1 and two seconds.
  Normal scripting policy is retained on its script-free DOM.
- Wikipedia uses its 15-response sealed archive, fresh profiles/caches, scale 1
  and two seconds; author JavaScript is disabled in both browsers.
- vlang.io uses the same initialized script-free local fixture, archived assets,
  fixed poster, disabled animations, fresh profiles/caches, scale 1 and two seconds.

Brave uses the original headless scale-1 setup for Reddit, Wikipedia and
vlang.io; Hacker News uses native inactive windows on the display away from the
pointer. Vox uses inactive native capture windows. Source manifests, resource
bytes, template files, references and runtime hashes are checked after each
trial. OS filesystem and shader caches are retained; ambient proxy and runtime
overrides are removed.

All selected runs reference `Build/v/Vox.app` directly. Its executable SHA-256 is
`e9b1cdeb2197ef69aacf701bb0e12149aecfabed3f2c68cb675d34631c3f681e`;
the existing successful production receipt records source HEAD
`d8714ad8c4f6efb15c165bae94f632f7f89eeafa` with dirty inputs. Brave is
156.1.98.60. All cohorts use identical browser/native-library bytes. No source
tree or browser bundle is copied and no new build is requested.

Lobsters, Reddit and Hacker News match their original references exactly in all
selected runs. Vox's Wikipedia captures also match its reference. CNN in both
engines, vlang.io in both engines, and Brave's Wikipedia captures differ from
their historical references. Those differences remain recorded, with unchanged
references and tolerances. Complete semantic audits establish loaded workload
identity; these memory observations do not establish renewed pixel conformance
or instruction acceptance for the historical builds.

## Retained attempts and checks

The first cohort supplies the complete Lobsters, Hacker News and CNN pairs.
Its native scale-1 Brave setup cannot match the scale-2 display for the other
three sites. A subsequent emulated but windowed diagnostic supplies no final
headless-cohort credit. Both sets of raw results remain retained.

The corrected headless cohort supplies the Reddit and Wikipedia pairs. Its
first vlang.io pair is complete; its second fails the helper-ownership check
and receives no pair credit. Two additional complete vlang.io pairs use the
same final protocol. **All three complete final-protocol vlang.io pairs enter
the median**, including the earlier pair. The incomplete pair remains recorded.
No completed pair in the selected final protocol is removed for its memory value.
The durable receipt retains all **52 observations**, including the **26** used
in the table, failed setup/ownership attempts and windowed diagnostics.

Each cohort runs under the default 12 GiB guard with its own lock and adoption
registry. Both browser roots and observed helpers are accounted for. Guard RSS
includes the benchmark tools and is retained only as safety evidence; it never
supplies the browser RAM columns. Original nonzero cohort/controller exits and
final successful exits remain recorded. No instruction or runtime optimization
credit is claimed, and the broad-test savings cadence does not advance.

The host has 18 logical CPUs and one-minute loads of **4.53–5.93** across the
selected observations, with independent canonical builds and other sessions
active. Samples, host timestamps and variability remain in the evidence. All
**113 focused tests pass**, covering simultaneous peak calculation, reused
identities, complete-content requirements, invalid samples, counter ownership,
full-uBO acceptance and memory-guard behavior. Tooling commit: `f75f2e153`.

The [durable receipt](benchmark-results/optimized-sites-memory-2026-11-02.json)
contains every per-run byte value, selected-pair identity, content/pixel status,
peak process breakdown, browser/library hashes and raw artifact hashes. Commands,
guard receipts, complete gzip memory samples, PNGs, audits and actual exits are
under `Build/optimized-sites-memory-20261102-104349/`.

To repeat all sites with new paths:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/sites-ram-UNIQUE.lock --report Build/sites-ram-UNIQUE-guard.json \
  --adopt-pids-from Build/sites-ram-UNIQUE-pids.json -- \
python3 tools/optimized_sites_memory.py \
  --output Build/sites-ram-UNIQUE \
  --memory-guard-registry Build/sites-ram-UNIQUE-pids.json
```

Use repeated `--site` arguments to select workloads. The driver requires at
least two alternating pairs and the existing fixture/cache inputs listed in
`site_config()`. Missing inputs, changed hashes, incomplete content, abnormal
browser exits and sampling errors prevent a complete memory summary. Pixel
differences remain explicit and do not silently replace historical references.
