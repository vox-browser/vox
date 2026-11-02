# Recorded Old Reddit Linux measurement protocol

This directory preserves the exact observer scripts, contracts, observer
corrections and build receipts used for the 2026-11-02 Vox typeface-cache
experiment. `manifest.json` identifies every copied file by its original
repository path, byte length and SHA-256. The frozen `Build/` originals were
not modified when these files were copied. `make_results_ledger.py` is a
post-run receipt exporter, not part of the measured browser or counter.

The [report](../../OLD_REDDIT_LINUX_TYPEFACE_CACHE.md) defines the workload,
measurement boundary and limitations. The [ledger](../old-reddit-linux-typeface-cache-2026-11-02.json)
contains exact counts, independently recomputed acceptance gates, source and
runtime identities, test receipts, and the evidence archive's identity.

## What is preserved

- `compare.py` orchestrates three matched pairs, seals input identities,
  validates document/pixel equality and applies both conservative gates.
- `capture.py` runs the separate diagnostic capture; `network_audit.py`
  inventories local and external fixture references.
- JSON contracts pin the post list, audit selectors, source-proven native
  diagnostic, original fixed image, retained failed-cohort control and counter
  selection. The correction directories retain before/after observers,
  patches, reasons and negative-validation results.
- Build helpers and receipts preserve the supported split V-C/native build
  route, exact compiler flags, native archive change and byte-identical
  original-control relink. The runtime/test implementation is tracked in
  `skia/` and `tools/`; it is not duplicated here.
- `font-validation-summary.json` and the selected V check receipts record
  Skia, portable-shadow layout and platform-font checks in Boehm and no-GC
  modes. They report 56 active Linux test-function invocations, with two
  known macOS-only early returns. These checks are separate from the
  benchmark-only archive and do not claim a repository-wide test run.
- The separate evidence archive preserves accepted raw Cachegrind profiles,
  capture reports/audits/logs, the fixed PNG and earlier failed attempts.
  Executables, generated C, system fonts and system libraries are excluded;
  their required identities are recorded.

## Inspecting the recorded result

Verify the archive and manifest hashes in the ledger before extraction. Its
manifest identifies original member paths and uncompressed hashes; files keep
their `Build/reddit-optimization/...` layout. Extract into an empty directory
to preserve existing attempts. The repository's unchanged
`tools/linux_instruction_counts.py` supplies the strict Cachegrind parser.
The final observer summary, each raw profile/report and the independent audit
are available together, so inspection does not depend on the original machine.

The recorded metric is Cachegrind guest instruction references (`Ir`). The
diagnostic Callgrind count must not enter the accepted Cachegrind statistics.
The invalid first cohort remains invalid; its unmodified 6,842,705,460-Ir
control is an additional conservative constraint, never a paired-median member.

## Replaying the experiment

The archived scripts are location-sensitive: they expect their original
`Build/reddit-optimization` directory. Historical reports and contracts also
contain absolute paths from the measured workspace. Copying these scripts to
another checkout and executing them unchanged is not a portable replay.

For a replay in the recorded workspace, restore the scripts/contracts to their
original paths from `manifest.json`, restore the raw evidence layout, and
verify the recorded fixture, fonts, compiler, native dependencies, binaries and
runtime-library identities. Use a **new** output directory and the exact
`compare.py --counter-backend cachegrind --pairs 3` command in the report or
outer guard receipt. The observers refuse to replace prior evidence. All
builds and measurements require `tools/run_memory_bounded.py`; V invocations
retain `-memory-limit 10G`. The measured Linux mode is current V
`-new-compiler -glibc` with native `-O2`, without V `-prod`.

For a fresh machine or different checkout path, rebuild both controls with
the pinned toolchain and the same native flags, then prospectively reseal
local paths, input identities and an unchanged control reference before any
candidate measurement. Preserve that protocol and its failures as a new
cohort. Historical absolute paths and their hashes must not be silently
rewritten while describing the result as this original experiment. Different
toolchains/fonts, host state or input identities establish a new result, even
when the same optimization is being tested.

The standalone `tools/test_shadow_typeface_cache.py` regression runner is
portable across compatible pkg-config Skia environments and has no dependency
on the historical benchmark archive. It builds an uncached control adapter
from current source; explicit input fonts and either fontTools or a two-face
TTC are required.

After restoring the original receipt layout, the durable ledger can be
regenerated to a **new** filename with:

```sh
python3 Build/reddit-optimization/make_results_ledger.py \
  --cohort Build/reddit-optimization/cachegrind-cohort-02 \
  --output Build/reddit-optimization/results-ledger-recheck.json \
  --evidence-archive docs/benchmark-results/old-reddit-linux-typeface-cache-2026-11-02-evidence.tar.gz \
  --evidence-manifest docs/benchmark-results/old-reddit-linux-typeface-cache-2026-11-02-evidence-manifest.json \
  --independent-audit Build/reddit-optimization/independent-acceptance-audit.json \
  --validation-summary Build/reddit-optimization/font-validation-summary.json
```

This exporter reads receipts only, cross-checks reported counts and exits,
verifies archive/audit identities, and recomputes both integer gates. It does
not rerun browsers or replace the strict raw-profile parser.
