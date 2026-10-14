# Wikipedia CSS transition crash

Implementation: `bc014738` (2026-10-14 UTC).

Opening `https://wikipedia.org` in the production browser exited with
`PropertyID background_position is not a translated longhand property`.
Wikipedia declares `transition: background .1s ease` on its controls. Transition
registration expanded `background` into its immediate components, leaving the
nested `background-position` shorthand in a list consumed as computed longhands.
`border` and other nested shorthands had the same problem.

`ComputedProperties.transitions()` now uses the generated recursive expansion,
matching upstream `Libraries/LibWeb/CSS/StyleComputer.cpp`'s
`expanded_longhands_for_shorthand()` call. Existing logical-to-physical mapping,
list cycling and later-entry precedence remain in the same path.

Three new focused cases check all generated shorthands, timing/logical mapping
and later-entry precedence, and actual background/border transition interpolation.
The animation fixture explicitly attaches an active Navigable. Its original
inactive-document failure is retained in the initial test logs.

The new cases and five existing transition timing cases pass in both Boehm and
no-GC builds using `v -old-compiler -exclude @vlib/time/zoneinfo.native.v
-enable-globals`, with the matching `-gc` flag (and `-cflags -DLARGE_CONFIG=1`
for Boehm). Logs are under `Build/v/wikipedia-transition-*`. The original native
panic is retained in `Build/v/wikipedia-crash-repro.log`.

This records one additional completed fix after broad baseline `05655652`.
Only directly relevant tests and native browser checks are selected for this fix;
the existing broad-suite cadence and independent fixes retain their own records.

Production validation uses the rebuilt, ad-hoc-signed `Build/v/Vox.app`:

- `sh build-prod-browser.sh` succeeds; `codesign --verify --deep --strict`
  succeeds.
- `Vox --headless-smoke` passes JavaScript DOM mutation, click and native wheel
  checks (`Build/v/wikipedia-crash-startup-smoke.log`).
- The native Wikipedia viewport capture succeeds at 1000x700
  (`Build/v/wikipedia-fixed.png`, `Build/v/wikipedia-crash-screenshot.log`).
- LaunchServices opens the bundle with `--args https://wikipedia.org`; the
  process remains alive for 45 seconds without a panic and is left open.
  `Build/v/wikipedia-crash-open-result.json` records the process and binary hash.

These checks establish the reported crash is fixed; the capture is not a
pixel-conformance or complete Wikipedia feature-parity assertion. Unrelated
working-tree changes and earlier failed fixture logs are preserved.
