# Reddit scrolling: cooperative host callback pacing

Commit `5598a9b06` fixes a reproducible starvation case in cooperative work.
Previously, the next host-event-pump deadline was set before the callback ran.
A callback longer than the interval could therefore be followed immediately by
another pump, before document work progressed. The next deadline now starts
16 ms after callback completion, retaining monotonic synthetic checkpoint times.

The callback can also finish its scope and start a replacement using the same
preallocated record. Identity plus a generation counter prevents the old
callback's defer from resetting that new scope's deadline or delivery state.
`VOX_RETAIN_COOPERATIVE_YIELD_START_DEADLINE=1` preserves the old pacing for
matched control trials, while retaining the scope-ownership protection.

The preceding installed-browser profile observed event-loop servicing among
slow-frame samples. That motivates this inspection; it does not establish how
much time the defective case contributed to this page's measured stalls.

## Executed checks

- Cooperative work: ten dispatched test functions in explicit default no-GC
  and production-style preallocation/no-GC modes. Collector-only tests remain
  skipped; preallocation-only cases skip in the default mode.
- A real 40 ms callback produces one immediate yield with the fix versus two
  with the old-pacing control. Both modes still permit the next scheduled pump.
- Scope replacement preserves the new deadline; the preallocated case verifies
  that the same address is reused with a different generation.
- The same preallocated binary also passes under the old-pacing control flag.
- Related preallocated suites pass seven native-timer, six timer-arena and
  seven zero-timer cases, including delivery order, cancellation/restart,
  coalescing, nested pumps and retired owner lifetimes.

Compiles use current V3 with `V_MACOS_V3_NO_FALLBACK=1`, `-memory-limit 10G`,
`-enable-globals`, `-cc clang`, and explicit `-gc none`; production-style
checks also use `-prealloc`. Compiler processes run under the 12 GiB memory
guard and runtime processes under 3 GiB. Final source hashes are checked before
and after the selected compile/runtime checks. Binary entry-point disassembly
records dispatch to the selected test functions; these are executed runtime
checks, not compile-only credit.

The explicit Boehm probe is rejected by the current V3 driver, which requires
no GC; no collector-policy test credit is claimed. Early artifacts named
`boehm` actually used the compiler's default no-GC mode. The final default
selection uses explicit `-gc none`.

The first standalone zero-timer compile fails because its wait helper was
defined in another test file. Separate test-only commit `5d128d8e3` makes
that helper local. Its final seven-case compile and execution both pass;
the failed attempt remains retained. No implementation change or assertion
relaxation was needed for that harness repair.

## Browser acceptance remains pending

The shared production guard is busy. The latest completed executable remains
`f26b41bdc7345c07673f9bbe6eeb9cda4308454efe8cb6a185537cc420f19d48`,
whose sealed cooperative-work source predates this change. No duplicate
production build is queued and no hours-long wait replaces useful focused work.
The old bundle cannot validate new pacing, browser input behavior, pixels or
scrolling cadence. Those checks still need a completed bundle containing it.

**The user's goal of 60 Hz without stalls remains open.** No new scrolling FPS,
physical-scanout, instruction saving or optimization acceptance is attached to
these unit/runtime checks. The earlier representative GPU waits and deadline
misses remain unresolved. References, tolerances, animation and rendering
policy are unchanged.

## Local evidence manifest

- Raw archive: `/tmp/vox-reddit-cooperative-pacing-20261108.tar.gz`; SHA256 `2cdb576e636f506fc3cb6a5b28be4452368e3505564585245bc00b2ba024d4a9`; 3,319,364 bytes.
- Per-file hashes: `/tmp/vox-reddit-cooperative-pacing-20261108-files.json`; SHA256 `9716be798fdbe8e07247d2916a44d344040cc55c3777ccafed03bdcf98294d26`; 23,074 bytes.
- Archive supervisor: `/tmp/vox-reddit-cooperative-pacing-20261108-guard.json`; SHA256 `04f11c4c5a24a0908b1500a4e00f91ce8592c245dafad6c05843ba142d1f27d8`; 370 bytes.
- Structured receipt: `/tmp/vox-reddit-cooperative-pacing-20261108-report.json`; SHA256 `1bd5d574cd3e3e5504fa754da8e28613211e54cc76875893f7b02f2fdb35227e`; 80,646 bytes.

The mode-0600 archive contains 121 individually verified files. Completed
per-job Build output, locks/reports and temporary drivers are removed after
verification. Structured diagnostic receipts stay local.
