# Production-mode GG checks and a rebuild blocker

The stall-free 60 Hz goal remains open. The completed app is still executable
`23d3335dede25e37f908b5e4f17a0694aacf1bf314fbd453c9892eaab9b71688`;
this work supplies functional checks and fixes rebuild invalidation, with no
new scrolling FPS or whole-page pixel acceptance.

## Check the configuration automatic builds now use

Commit `4624ca1c6` adds `--prod` to `tools/test_gg_canvas_transfer.py`.
Current V, backend `c`, literal `-prod`, `-memory-limit 10G` and no compiler
fallback pass both GC-none and prealloc/GC-none checks. Each runtime passes
64 exact AA/MSAA backdrop comparisons against separate readback and emits
64 successful joined-readback markers. Compilation uses the default 12 GiB
guard; each runtime has its own 3 GiB guard. Browser/native display FPS is
not measured by these fixtures.

An initial compile is rejected when `prepare_ui2.py` changes concurrently.
The complete rerun verifies all 544 input hashes throughout compilation and
execution in both modes. A later edit to that preparer is recorded separately;
the result does not establish that the entire latest checkout was tested.
All attempts and actual exits are retained.

## Unused TSV fixtures aborted production builds

Receipt `20261109-052625-635bf0fe` exits 1 with
`Production source membership changed`. Its inventory predates new
`jpegxl/testdata/lf-quant.tsv` and `small-modular-frame.tsv`. These focused
test corpora were being treated as browser inputs.

Commit `c77be3b86` excludes package TSV corpora from ordinary production
membership. An actual current-V `-prod` compile probe then exposes a guard
gap: the compiler reports V source buffers, but omits the embedded TSV payload.
The successful compile alone cannot establish resource fingerprint coverage.

Commit `9f9d5eaff` therefore discovers explicit TSV `$embed_file` inputs before
compilation and retains their fingerprints in both the build identity and source
inventory. Relative, absolute, `@DIR`, nested `@VMODROOT` and symlink aliases are
covered. Unknown expressions/escaping or separated tokens conservatively retain
the corpora. Native testdata headers remain pinned. The real compiler probe now
confirms the payload is in the combined inventory and that editing it is rejected,
despite its absence from the compiler's own manifest. Probe compiler/tool hashes
remain unchanged.

Nineteen source-manifest tests pass. Rebuild checks report 36 passes and two
platform-specific skips (38 discovered). The initial unit fixture's missing
HEAD and `/var` alias expectation errors are corrected and retained. Managed
post-commit hooks request coalesced C/one-unit/literal-`-prod` builds for each
commit; no additional manual production build is submitted.

An intermediate build also fails the changing UI2 dependency check (installed
`192c050e...`, expected `84665929...`). A later shared attempt reaches V
compilation with the reviewed UI2 snapshot. A completed new bundle is still
needed for the live candidate/control wheel trials and unchanged full-page
references required before enabling joined readback by default.

## Local evidence and cleanup

- `/tmp/vox-reddit-gg-prod-20261109.tar.gz`
- SHA-256 `919c58d75022e774a1de0e263d30908264cbb00b8fed11d8b9abb53e2b2ed083`
- 993,454 bytes; 64 file hashes verified; mode 0600.
- Companion `-files.json`, `-report.json` and `-archive-guard.json` stay local.

The archive preserves commands, all attempts, compiler/source pins, binaries,
eligibility output, resource probes, guard exits and failed-build evidence.
Generated C and temporary module views are excluded. Own jobs, locks and
temporary drivers are removed after verification; shared bundle/runtime caches
remain. Raw dumps and archives are not committed.
