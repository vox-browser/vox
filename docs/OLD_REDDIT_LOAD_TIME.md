# Old Reddit load and render measurements

The target is `https://old.reddit.com/r/UkraineRussiaReport/` with scripting
and normal request filtering enabled. Live Brave parity remains unverified.

## Startup change

Commit `a475e724` starts the configured macOS filter helper on a background
thread while the initial HTTP(S) window is prepared. Preparation and actual
request checks share the existing lock; requests still evaluate their filters
before network access. Disabled filtering and unconfigured helpers remain
no-ops, initialization errors remain sticky, and idle release retains its
normal lifetime. Local documents and headless engine checks skip preparation.

All 12 cases in `adblock/worker_backend_darwin_test.v` passed with current V
under both Boehm and `-gc none`, including the new preparation lifecycle and
first-request race cases. Actual child exits are zero in
`worker-boehm-checked.guard.json` and `worker-none-checked.guard.json` under the
raw evidence directory below. The private-`VTMP` production build compiled
and signed successfully in
302.08 seconds, with unchanged owned-source/compiler hashes. Its following
comparison stage failed because the harness expected the older compiler's
`main__` function prefix; current V emits an unprefixed function and a relative
`src.c` compiler input. Thus `production-compatible.json` has actual build
exit 0, while `production-private-tmp.guard.json` has whole-pipeline exit 1
(12,418,596,864-byte sampled aggregate peak). The corrected comparison retains
the generated C, compiler command and 127 native link inputs, then recompiles
both candidate and control from one frozen preprocessed input.

Earlier unsuccessful attempts remain in the evidence directory: the bounded
preallocation check failed before compilation (`production-retry.json`), one
build was interrupted by the 17:34:22 MSK host reboot (no exit status), and a
post-reboot build lost a shared temporary object directory (exit 1 after
170.71 seconds). These attempts receive no production validation credit.

## Measurement boundary

`VOX_MEASURE_NATIVE_SUBMISSION=1` reports
`navigation_to_first_native_layer_submission` and
`document_install_to_first_native_layer_submission` from the existing Cocoa
submission callback. These finish after the rendered image reaches
`layer.contents` and its transaction is submitted. They do not measure physical
display scanout. The older `*_first_document_paint` draw-tail endpoint remains
separate: returning from V drawing can precede Cocoa submission.
The native-only flag leaves detailed phase/style profiling disabled.
`LADYBIRD_DEBUG_TIMING=1` also enables these endpoints, but enables profiling
and is reserved for the independent eligibility/diagnostic run.

The harness also timestamps receipt of the native-submission log from process
launch. This includes startup and log delivery, so it is an upper-bound receipt
measurement rather than an internal engine timestamp. It checks that moving
filter preparation before navigation also helps the complete startup path.
Whole-process screenshot/exit duration is recorded separately.

The existing document-submission state tests cover current installation and
navigation identity, exactly-once reporting, stale frames and independent tabs.
Their four cases passed during this investigation; raw logs and guard exits
are in `Build/urr-load-20261026-150653/submission.log` and
`validate.guard.json`. The latter also retains an unrelated failed build setup;
it is not a whole-pipeline pass.

## Validation workload

The private archive is replayed at its original HTTPS URLs through a local
CONNECT proxy and private TLS CA. Outside network access is denied. Each trial
uses a fresh process, an empty settings profile, a fresh resource-cache copy,
JavaScript enabled and a 1024 by 768 CSS-pixel viewport.
`LADYBIRD_SCREENSHOT_SCALE=2` explicitly selects device-pixel ratio 2 and a
2x capture; comparisons use the cropped document viewport at logical size.
Captures use the normal two-second delay for stable final pixels; the native
submission timestamp is recorded at the earlier first document submission.
A later screenshot does not establish the contents of that earlier frame.
Archive digest:
`8c536761e0df95512bc77ac046c52a128becde4b6a08e0baea0a0216cba310ce`.
The archive contains private page data and is not committed.

Raw commands, generated compiler inputs, executable/library identities, host
load, logs and captures are retained privately (directory mode 0700) in
`Build/urr-load-20261026-150653/`.
`diagnose.py`, `offline-replay.py`, `paired.py` and `matched.py` in that directory
record the exact local harness. All expensive work runs under the repository
memory guard; focused runtime children have a 3 GiB limit.

A matched control uses the candidate's frozen preprocessed C and captured native inputs,
with only the early filter-preparation function returning immediately. Request
filtering remains lazy and enabled in the control; its startup thread returns
immediately. This isolates the change
from concurrent edits elsewhere in the checkout. An independent eligibility
run precedes four control/candidate pairs, alternating order so each build
runs first twice. Each timed capture must match the independently identified
eligibility image exactly; every pair also compares the document pixels.
Timed trials enable only native submission timing and reject detailed
phase/style profiling.

The corrected matched run failed before compilation when the main volume ran
out of space (`frozen-validation.guard.json`, actual child exit 1). Its log and
command are retained as `frozen-candidate.*.disk-full`. Verified duplicate
generated C was replaced with a hard link; private compiler scratch moved to
the existing temporary test volume. The unchanged-source retry is queued behind
the shared guard (`frozen-validation-retry.guard.json`); no matched performance
result is available yet. The successful production build and focused
tests above do not establish a load-time improvement.

## Access limitation

Initial live checks received HTTP 403 (Vox's available proxy route and a fresh
Brave direct profile); a Brave SOCKS attempt timed out. Those are access
failures, not page-load measurements. Archived Brave FCP and full-load timings
use different transport and endpoints from native layer submission and cannot
establish parity. Earlier archived diagnostics also used the default logical
screenshot device-pixel ratio 1 and do not supply matched comparison credit.
The fresh live check launches the preserved candidate bundle directly, recording
its PID and executable hash; it does not reuse an already running application.
An independent local HTTP access check at 19:14:36 MSK on 2026-10-26 still
received HTTP 403 (`live-access-refresh.json`); it is not a browser benchmark.
No scrolling or display-presentation claim follows from these load measurements.
