# ChatGPT instruction comparison

The requested 5% advantage over Brave remains **unmet**. The latest complete
cohort uses production executable `95bb7c3db15e05f49facaac092c1e83c012adddaed3c24c3ad74d4a452b21240`
and seven alternating fresh Vox/Brave pairs. All fourteen observations exited
successfully and matched the retained document PNG exactly, with complete content,
readiness, bootstrap and ownership audits.

It uses the authorized replacement fixture, now committed under
[`Tests/Browser/Brave/archives/chatgpt-home-20261104-v2`](../Tests/Browser/Brave/archives/chatgpt-home-20261104-v2).
Its reference was established once and validated in two additional fresh Brave
replays before measurements. Raw evidence is also packaged in version control
so another `Build/` cleanup will not remove it.

| Launch through document PNG encoding | Retired CPU instructions |
| --- | ---: |
| Vox median | 33,643,398,375 |
| Brave median lower bound | 20,843,396,122 |
| Highest Vox upper bound | 33,852,620,702 |
| Lowest Brave lower bound | 16,834,385,510 |

The conservative observed ratio is 2.0109. The exact gate fails:
`100 * 33852620702 > 95 * 16834385510`. Every sample is retained, including the
lower-count seventh Brave observation. All browser/kernel exits are zero; driver
and guard child exits are one solely because the requested threshold fails.
Exact counts, commands, identities, ownership audits and boundaries are in the
[replacement receipt](performance/chatgpt-baseline-20261104-v2.json), with
[complete controlled-job evidence](performance/chatgpt-baseline-20261104-v2-evidence.zip).
No qualifying entry is added to `OPTIMIZED_SITES.md`.

The workload replays the new anonymous homepage captured through SOCKS; all
measurement runs use disk replay without forwarding. Original author scripts remain
enabled under JavaScriptCore; the homepage bootstrap executes. Both engines
use a 1024×768 CSS viewport, scale 2, unfocused documents, five-second settle
period and fresh private profiles/caches. OS filesystem and shader caches are
retained. Exclusive resource-coalition counters include startup and exited
helpers; GPU execution and outside services are excluded. Brave's endpoint
also includes CDP PNG delivery. These are startup/capture workflow counts,
with no live-site, signed-in conversation, isolated-render-time or FPS claim.

The earlier `401745782b25...` cohort recorded Vox/Brave medians of
32,363,448,715 / 16,375,554,889 and a conservative ratio of 2.0535. Its raw
`Build/` inputs were deleted by disk cleanup; historical counts survive in the
[earlier receipt](performance/chatgpt-instructions-20261104.json). The replacement
does not reconstruct those deleted source bytes. Its reference PNG happens to
have the same `6e81a153...` byte hash, but differing archives prevent crediting
instruction changes across these workloads.

The first replacement attempt timed out at the CDP socket's generic fifteen-second
limit before recording any response. The corrected watchdog completed the page
and saved 311 response URLs. The raw capture remained unsealed because the
homepage and two preparation endpoints varied during that navigation. Disk-only
sealing preserved the first response for each URL and all alternate bodies;
no further fetch or body substitution was used. This frozen-response fixture
does not emulate request-dependent APIs or establish chat-submission behavior.

The capture fixes pass 34 tooling tests and a real loopback Brave check of HTML,
module JavaScript, binary bodies and redirects. Browser profiles remain in
`Build/`; the source fixture, reference and capture provenance are committed.

The probed native ink scan showed a 144,206,062-instruction conservative saving
in its matched component-library page trials. Its broad checkpoint passed ten
native scripts, SVG ASan, 100 exact upstream AST cases and twenty screenshot
checks with unchanged references/tolerances. Literal media-query caching and
primitive URL string projection are committed and execute in the production
page. Their focused checks pass in both GC modes, including controls. URL
projection improves the isolated component test, but whole-page trial ranges
overlap, so it receives no conservative page-level instruction credit.

An earlier seven-pair attempt failed because a preexisting interactive Brave
window spawned a new renderer during measurement. Commit `9dfcb790e` verifies
the new helper's pinned ancestry, creation times, executable and separate
coalition before excluding it; ninety counter/harness tests pass. The failed
cohort is retained. This audit correction earns no engine optimization credit.

## V compiler profile

The requested `v -profile` diagnostic now completes on the same saved page with
the original scripts, bootstrap marker and **zero differing pixels**. It uses
`-profile - -profile-no-inline -profile-fns main__main`, an instrumented `-O1`
standalone executable, and the canonical installed native libraries. Generated
compiler inputs and the executable are pinned; the shared source checkout
changed during generation, so this identifies an executable rather than a clean
source commit. No app bundle or source tree was copied.

| V function boundary | Calls | Inclusive ms | Self ms |
| --- | ---: | ---: | ---: |
| `end_chromium_text_scroll_layer` | 43 | 3,779.516 | 3,779.516 |
| `array.get` | 166,018,177 | 1,592.800 | 1,592.800 |
| `ModuleHost.supply` | 265 | 12,975.292 | 1,157.963 |
| `Runtime.call_engine_function` | 2,887 | 8,312.833 | 924.719 |
| `BrowserApp.draw_command` | 609 | 1,198.354 | 836.845 |

These are instrumented elapsed times. Self time includes native/JavaScriptCore
calls, waits and instrumentation overhead; it cannot separate CPU work from
GPU or OS waits. Inclusive rows overlap, and a recursive function's aggregate
inclusive time can exceed the run's wall time. The main-thread scope excludes
V module initialization and unscoped background-thread counters.

Short-settle captures ended before the author bootstrap and are retained as
failures. The successful diagnostic explicitly uses a **30-second settle**,
versus five seconds for acceptance. Its standalone filter-worker entry also
differs from the production minimal helper. It earns no instruction or Brave
acceptance credit. The [profile receipt](performance/chatgpt-v-profile-20261104.json)
records all attempts, rankings from the 11,269-function report, input identities,
compiler flags, memory guards and the raw report hash. The original 5% goal remains open.

Summarize the retained raw report with:

```sh
python3 tools/summarize_v_profile.py \
  Build/chatgpt-v-profile-20261104-1230/current-settled/profile.txt \
  --output Build/chatgpt-v-profile-20261104-1230/current-settled/summary.json
```

The summary tool's eight tests cover units, independent rankings, mixed-process
duplicate rejection, malformed counters and negative-self diagnostics.

## Selective performance collection experiment

An offline audit of 292 saved scripts found four review candidates. Existing
EasyPrivacy rules already block ChatGPT's event endpoints. The analytics module
has eight static importers, and native telemetry also performs service-worker
cleanup and lifecycle work, so a filename-based block would remove required
behavior. The [tracking audit](performance/chatgpt-tracking-audit-20261104.json)
retains the dependency graph and rule decisions.

The comparison tool now accepts `--script-policy chatgpt-home-performance` for
an explicit experiment on the sealed anonymous homepage. It verifies the exact
manifest and script hashes, creates an independent derived fixture, and bypasses
performance collection while preserving the module's exports, promise contract,
queue/observer cleanup and original fallback for other pages and authenticated
users. The HTML and other scripts retain their original bytes. Both browsers
receive the same changed script policy; this supplies no engine optimization
credit or live-site result. Default production filtering is unchanged.

A separate `--policy-diagnostics` run confirms that the guard executes in both
engines, with bootstrap completion and exact pixels in all four captures. Eight
uninstrumented observations then alternate original/suppressed/suppressed/original
policy pairs, using production executable
`19356cf6d7702f408fcb22c0a4a9ebdd40d069d6c3da630ecdd3af77ff80619e`.

| Two-trial diagnostic median | Original instructions | Suppressed instructions |
| --- | ---: | ---: |
| Vox | 33,536,277,314.5 | 33,139,297,591 |
| Brave lower bound | 16,369,831,910 | 16,358,415,242.5 |

The observed Vox median reduction is 1.184%; the small cohort's conservative
reduction is 205,996,983 instructions (0.616%). Brave's ranges overlap. All eight
browser/kernel exits are zero and every content/pixel check passes, with stable
inputs. Each one-pair API invocation retains its ordinary summary error because
that summary requires two pairs. Aggregating the two retained pairs per policy
provides diagnostic statistics only; the seven-pair acceptance minimum remains
enforced. Host load is 42–45 on 18 logical CPUs, limiting attribution.

Both original trials request the performance module twice and web-vitals once;
suppression requests neither, while native telemetry and service-worker cleanup
remain requested in both engines. Complete original web-vitals execution in Vox
is unproven. Visible homepage correctness does not establish signed-in or chat
submission behavior. Suppressed Vox still costs about twice Brave. The
[experiment receipt](performance/chatgpt-performance-policy-20261104.json)
preserves exact counts, all attempts, hashes, ownership audits, commands and guard
exits. The original 5% goal remains open.

## URL ASCII classification

The next engine change replaces repeated character-array scans with bounded
64-bit membership masks. It covers forbidden host characters and all nine
percent-encode sets. Unicode, invalid code-point values and the boundary between
the two ASCII words retain their original behavior. The earlier V profile
recorded 1,057,335 host checks and 2,798,357 extra-character membership checks.
The original implementations remain available with
`VOX_DISABLE_URL_ASCII_MEMBERSHIP=1` for matched controls; a separate
`VOX_URL_ASCII_MEMBERSHIP_DIAGNOSTICS=1` run verifies both optimized paths.

All 103 URL cases pass in both GC modes with both implementations, including an
independent exhaustive comparison across U+0000–U+10FFFF and large invalid
values. Candidate verification combines twenty passing files with the recovered
file-origin test. That preexisting test required sum-type method dispatch before
narrowing for the current compiler; every assertion is retained. The initial
cached bridge-link failures and original narrowing failures remain recorded.

A separate optimized component benchmark parses and serializes the saved
archive's 305 response URLs one hundred times. Its matched
control/candidate/candidate/control trials preserve the same result checksum.

| 30,500 URL parse/serialize operations | Retired CPU instructions |
| --- | ---: |
| Control median | 1,957,572,915.5 |
| Candidate median | 1,817,028,482 |
| Conservative reduction | 134,270,407 |

The component median falls 7.18%. These counters cover the parsing loop only,
excluding launch and input loading; they do not establish a page or Brave gain.
Original author scripts remain unchanged. The
[URL optimization receipt](performance/chatgpt-url-ascii-20261104.json)
records the exact commands, raw counts, checks and production validation status.

The initial production page validation was pending. The first shared replacement failed at
linking when the disk filled; the next attempt also failed with insufficient
space and could not finish its guard receipt. Space later became available and
another shared build began. The completed bundle available during the bounded
wait lacks the URL masks, so it cannot validate this code. The failed attempts
and the pending build are recorded; one earlier failed receipt disappeared
during external disk cleanup, and the receipt distinguishes its captured
transcript from original files. No page instruction saving, broad-cadence
advance or Brave acceptance credit is claimed for this change yet.

Production executable
`0994c97bdcaddf9dedbcbcea73c1b6c97e1d41323c10b0324df0867284787d7f`
now contains the URL masks. A fresh process passes the embedded JavaScript DOM
mutation/click checks and native wheel-routing checks with stable executable and
runtime input identities. This is startup evidence, not a ChatGPT page result.

The first page-test preflight found that cleanup had also removed the old
pixel-diff helper. Its replacement passes independent exact/mismatch controls.
A recovery survey then found the original sealed archive and retained PNG/audit
missing, with no matching copy in the surveyed repository manifests, document
PNGs, named ChatGPT directories or default Vox page caches. No browser comparison
launched, no page was downloaded again, and no reference was regenerated.

The comparison driver now verifies retained input files and archived body hashes
before creating an output directory or starting browser setup. Twenty-eight
focused tooling tests pass, including missing inputs, corrupt/deleted bodies,
the audit's companion PNG, executable checks and input preservation. The
[production follow-up receipt](performance/chatgpt-url-ascii-production-20261104.json)
records the startup, recovery, preflight failure and exact missing-input hashes.
The original single-download restriction requires authorization before replacing
the lost fixture with a fresh SOCKS capture and a separately labelled baseline.

That authorization was subsequently supplied by the user's continuation. The
replacement above now completes production page validation. A separate two-pair
diagnostic confirms both URL mask paths execute on this exact production build.
All four diagnostic captures and eight uninstrumented matched captures pass the
same pixel/content checks with stable inputs.

| Two matched Vox trials per implementation | Launch-to-PNG instructions |
| --- | ---: |
| Scanning control median | 33,693,295,061.5 |
| Mask candidate median | 33,621,009,236.5 |
| Conservative reduction | −115,247,033 |

The median point reduction is 72,285,825 instructions, but the trial ranges
overlap. The URL masks receive zero conservative page credit, and the cumulative
5,000,000-instruction broad-check cadence does not advance. Their isolated 7.18%
component gain is not a whole-page gain. The replacement receipt retains every
control, candidate and diagnostic observation separately from the seven-pair
Brave comparison. No reference or tolerance was changed to obtain credit.

## Contoured compositor leaves

Commit `6d335d14a` avoids a redundant leaf raster when an isolated compositor
picture already owns the complete contoured fill, border or shadow. The existing
clip, ink-bound and deferred-publication guards retain the ordinary fallback,
including a full redraw if publication fails. The focused native checks cover
162 exact scenes and guard/failure cases, plus 24 existing exact Brave
picture/native cases, at both raster scales.

Two separate page diagnostics verify that each capture records 32 contour calls
and defers three eligible leaves: two shadows and one border. Loader logs verify
the candidate native library. Four uninstrumented captures then alternate
control/candidate/candidate/control in the same installed executable and candidate
bridge. All twelve Vox/Brave diagnostic and matched captures retain the original
author scripts and pass unchanged pixel/content checks, with stable inputs.

| Two matched Vox trials per implementation | Launch-to-PNG instructions |
| --- | ---: |
| Ordinary leaf control median | 33,255,021,540 |
| Deferred leaf candidate median | 33,050,893,475 |
| Conservative reduction | −127,861,982 |

The median point reduction is 204,128,065 instructions, but the ranges overlap.
This change receives zero conservative whole-page credit and does not advance
the 5,000,000-instruction broad-check cadence. The selected library is unpublished;
these fresh production-executable processes establish component validation, not
production-bundle acceptance. The original 5% Brave goal remains open.

The [contour receipt](performance/chatgpt-contour-defer-20261104.json) retains
every count, command, guard exit and identity, including the two preflight failures
that occurred before compilation/browser launch. Its linked evidence archive
preserves raw logs, counters, audits and PNGs independently of `Build/` cleanup.
No additional live download or reference/tolerance change was made.
