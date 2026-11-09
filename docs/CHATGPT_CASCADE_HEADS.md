# Dense cascade heads: ChatGPT optimization candidate

## Status and target

The requested target is at least **10% fewer instructions for the same
ChatGPT rendering workload than unmodified Vox**. This change is a candidate
for that target, not a measured whole-page result. Keep the pull request in
draft until the rendering and instruction-count gates below pass.

The control source is `9b3df2b374181102c9f621a11672d0ca5353cdca`.
The existing ChatGPT runner compares Vox with Brave at a different threshold;
passing that gate alone would not establish this change's improvement.

## Change

CSS cascade heads were stored in a hash map even though `PropertyID` is a
bounded, dense enum. Every property assignment and winning-value lookup used
that map. Reusable cascade storage also retained historical keys, so four
computed-longhand cache loops revisited properties from earlier elements.

The candidate indexes entry heads directly by property ID and records the
currently active IDs in a compact vector. It retains the existing entry
chains, cascade precedence, layer rollback, source metadata and value owners.
Scratch reset clears current heads and retains vector capacity. The public
presence bitmap still receives a complete reset, including independently set
stale bits.

Absent, explicitly empty and live heads remain distinct. Removing an active
ID repairs the moved ID's position, and re-adding a reverted property cannot
accumulate duplicate IDs. The recycled-entry path checks both entry-chunk and
active-vector capacity before writing outside its allocation arena.

The current 452 property IDs require 4,520 bytes for the inline head and
position arrays with the pinned compiler's 64-bit `int`, in addition to the
active vector. This trades a larger fixed cascade record for removal of hash
storage and hashing. Production cascade scratch records are reused; memory
and whole-page effects still need measurement.

## Local validation

Validation uses the CI-pinned V revision
`339affce1891514d11aeb7111f579845d966a138` on Linux x86-64, through
`tools/run_memory_bounded.py`. Focused runtime checks use its 3 GiB budget;
compiler invocations retain `-memory-limit 10G`.

The four head-index tests pass in all six combinations of checked C/GCC and
FastC/TinyCC with Boehm, no GC and the repository-staged prealloc runtime
(24 test executions; every compiler and runtime exit is zero). These are
isolated component executions: the production helper and test file were used
byte for byte, together with the exact `PropertyID` enum declaration from
`css/css.v`. No DOM or native stubs were used. Input hashes were verified after
every run. An initial FastC/GCC invocation was rejected because that backend
requires TinyCC or Clang; the successful FastC runs use bundled TinyCC.

The tests compare against an independent map oracle over all 452 generated
property IDs and 4,096 mixed operations, exercise 4,096 reuse cycles, and cover
the active-vector capacity guard. They establish the head index's behavior,
not full CSS runtime correctness or instruction savings.

All six focused test files also pass the genuine V semantic checker with the
complete production CSS dependency graph in no-GC mode. The scratch tests
additionally pass that check with the actual staged prealloc compiler/runtime
path: seven successful checks, with unchanged input hashes throughout. These
checks do not link or execute the native engine.

The existing independent cascade-chain oracle, scratch-lifetime and
longhand-reuse tests are retained and extended. The Linux workflow now runs
all six focused test files against actual native dependencies in both its
Boehm and poisoned-prealloc jobs. CI status is reported separately in the PR
description; CI has not been represented as a local execution.

## Why whole-page acceptance is pending

The local environment preflight on 2026-11-09 found:

- The repository's `LinuxPerfInstructions` counter fails on `/bin/true` with
  `perf_event_open` errno 2 (`No such file or directory`). There is no accessible
  hardware instruction PMU. No alternative metric is substituted.
- The sealed ChatGPT manifest contains 311 responses referring to 303 unique
  bodies, but its `archive/bodies/` directory is absent from this checkout.
- The proper Linux CSS test runner reaches native build preparation and fails
  because `Build/linux/native/platform.a` is unavailable. The required ICU,
  GLib, HarfBuzz, FreeType, Fontconfig, JavaScriptCore and Skia development
  dependencies are also unavailable. A semantic compiler check does not
  execute the engine tests.

No complete browser render, reference-image comparison, live-site check or
matched instruction cohort has been run for this candidate. Historical
ChatGPT measurements in `CHATGPT_BRAVE_INSTRUCTIONS.md` are not a baseline
for this patch. The diagnostic DOM snapshot has neither the original author
scripts nor the external CSS bodies and cannot replace the sealed workload.

## Acceptance required before claiming the target

1. Build control and candidate with identical compiler, JavaScript backend,
   C compilation mode and native libraries. Run the focused cascade, scratch
   ownership and longhand-reuse tests with the supported allocation modes.
2. Restore the exact sealed response bodies and use the existing original-origin
   replay, original author scripts, fresh private profiles/caches, 1024 by 768
   viewport at scale two, and five-second unfocused settle policy. Keep
   reference images and content/JavaScript readiness audits unchanged.
3. In a separate diagnostic run, verify that the changed cascade path executes.
   Collect at least seven alternating, uninstrumented Vox control/candidate
   pairs with a single counter backend and the same launch-through-encoded-PNG
   endpoint. Pin inputs and binaries and retain every attempt.
4. Report all counts, medians and paired changes. For conservative 10%
   separation require `10 * max(candidate upper) <= 9 * min(control lower)`
   using integer arithmetic, with valid counters, unchanged content/pixels
   and normal exits throughout. Label incomplete counter coverage accurately.
5. Follow the repository's broad-regression cadence after measured savings,
   and check live ChatGPT behavior before claiming a live-site improvement.

Whole-page optimization credit from this change is currently **zero**.
