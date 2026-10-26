# Maximized UkraineRussiaReport rendering

The production bundle containing the canvas and image-layer fixes matches the
archived Brave reference exactly: **0 of 6,918,912 physical pixels differ**. The document
viewport is 1728×1001 CSS pixels at native backing scale 2. This is an exact RGBA comparison of the complete
viewport, without excluded regions or channel tolerances. Browser chrome is
outside the comparison.

The requested URL is `https://old.reddit.com/r/UkraineRussiaReport/`.
A frozen input keeps post scores, timestamps and resources identical between
fresh browser processes. This result covers that captured document and
viewport in the preserved production bundle. Three fresh Brave references
differ by 0, 1 and 1 pixels from the archived reference. The production Vox PNG
is byte-for-byte identical to the earlier passing isolated capture. Live-page
and general browser parity remain unverified.

## Implemented rendering fixes

The Chromium compatibility renderer now preserves:

- Verdana style selection and device-coordinate inline precision.
- The local NativeTheme geometry of unchecked checkboxes.
- The inner radii and corner miters of single-sided rounded borders, including
  transparent adjacent border widths.
- Tile-wide multisampling caused by diagonal border clips.
- Bitmap filtering across repeat boundaries, including one-axis repetition.
- Shared multisample coverage for a rounded background color, repeated image
  and its adjacent uniform border.
- Root raster bounds that include the full painted canvas background.
- Independent image-layer tile coordinates, including fractional origins and
  scroll offsets, so image interpolation uses the complete raster extent.

Shared background/image/border coverage is committed in `1f9184c2`. It reduced the maximized frozen
comparison from 14 differing pixels to 5. The canvas-bound fix (`900b5e44`)
removed the checked-control difference by preserving its surrounding raster
context. The independent image-layer fix (`87f27f5f`) removed the remaining four
image-edge differences. A separate checked-checkbox geometry candidate had
left the result unchanged and was removed.

Public synthetic fixtures and Brave references live in
[`Tests/Browser/Brave`](../Tests/Browser/Brave/README.md). Ten focused comparisons
were exact in the new production run: canvas bounds, large-origin checked
controls, border-miter raster tiles, repeating sprite boundaries, single-sided
rounded borders, background sprite placement, broken-image fallback, inline
precision, checked checkboxes and display density. A separate canvas control
also passed exactly. The rounded border/solid-fill fixture has 15 differing
pixels, each with a maximum channel error of one; that comparison still fails
the strict gate. Its viewport is 1728×969 CSS pixels at scale 2, and the earlier
production control has zero differences at that same size.

## Evidence

Private account-bearing inputs, screenshots, cache data and numeric diagnostics
remain in ignored, restricted `Build/urr-visual-maximized-20261025/`. They are
not committed or reproduced in this document.

The normal production build completed with no source-manifest changes during
the build. All 87 required rendering inputs also remained unchanged through
capture. Its preserved bundle is:

```
Build/urr-visual-maximized-20261025/current-edges-1792998975184197000/Vox.app
```

Its executable SHA-256 is
`65cceaf15ce9a1ece46f3e28feff4b4af94d0adbb985290e0983d8df6f375ab8`.
The adjacent `provenance.json` retains the build-time source manifests, native
library hashes, signing checks, child exit codes and identity checks. Each
capture records its fresh PID, private profile, cache digest and executable
identity before and after capture. The bundle identity remained unchanged.

The production bundle passed signing verification and headless startup.
Focused layout/runtime and native image-cache checks passed. The broader
screenshot smoke command returned nonzero: `inline-node`, `ordered-list` and
`text-decorations` fail, as they did on the earlier control. The previously
failing `default-ignorable-code-points-not-painted` case now matches exactly.
The smoke set is not reported as passing.

The strict comparison can be repeated against the archived captures with:

```sh
python3 tools/check_pixel_equality.py \
  Build/urr-visual-maximized-20261025/isolated-images-1792997490476363000/brave-frozen.png \
  Build/urr-visual-maximized-20261025/current-edges-1792998975184197000/captures/vox-after.png \
  Build/urr-visual-maximized-20261025/recheck.diff.png \
  --result Build/urr-visual-maximized-20261025/recheck.result.json \
  --diff-tool Build/pixel-equality/pixel_diff
```

The command returns zero only when every pixel matches. Comparing the new
production capture with its fresh Brave reference instead returns nonzero for
one differing pixel. The separate `maximized-common` comparison also has one
difference with both browser outer windows filling the available display.
The equal-viewport comparison above retains the complete Vox document viewport.

At physical coordinate (2846, 521), both isolated and production Vox captures
contain RGBA (0, 117, 255, 255), matching the archived Brave reference. The fresh
Brave reference contains (6, 120, 255, 255). The audited geometry and capture
dimensions are unchanged. This reference difference is retained as a failure,
without changing tolerances or excluding the pixel. Three additional fresh
Brave processes produced 0, 1 and 1 differences against the archived reference,
confirming reference variation under the retained capture conditions.

Component crossover checks retained both the full-page and rounded-control
results. Disabling the root edge optimization, restoring the previous Graphite
library, restoring both previous native libraries, and using the isolated
bundle all retained the 15 rounded-control differences. The previous production
bundle retained zero rounded-control differences and five full-page differences.
These controls narrow the rounded regression to the V rendering path; they do
not establish which V change causes it. Each control used a fresh process, and
the signed bundle identities remained unchanged. Receipts are retained in
`Build/urr-visual-maximized-20261025/component-crossover-1793000433192815000/`.

A separate public-fixture diagnostic observed one nonempty Brave content layer
covering the full 3456×1938 physical-pixel viewport. This supports the new
full-canvas grouping, but does not explain the rounded-control raster mismatch.
The layer snapshot requests failed, so this diagnostic establishes layer bounds
only. Its successful guard receipt and numeric layer records are retained in
`Build/urr-visual-maximized-20261025/public-layer-tree-1793001593630522000/` and
the adjacent `public-layer-tree-1793000860257112000.guard.json`.

The earlier isolated run is retained in
`Build/urr-visual-maximized-20261025/isolated-images-1792997490476363000/`.
It replaces only the native image bridge in a preserved bundle containing the
canvas-bound fix, and records its diagnostic status, exact native input hashes,
fresh process identities and unchanged bundle hashes. Both its maximized frozen
comparison and its public canvas control have zero differing pixels. This
controlled result is not a current production-build acceptance run.

The expanded native image-region test passed all 2,592 exact comparisons across
root and independent layers, scale factors, destination clips, repeat modes,
fractional origins and scrolling. Running the same test against the pre-fix
bridge failed, establishing a negative control. The current-source focused
renderer test group also passed, including the canvas-bound regression test.
Raw test and guard receipts are retained beside the isolated run.

## Remaining acceptance work

Resolve the rounded-control fixture differences and establish a stable fresh
Brave reference. The production build and full fixture comparisons completed;
their failures remain recorded. The broader screenshot smoke failures also
remain open. An earlier mixed run containing a concurrent RGBA glyph experiment
and an unsuccessful Dawn configuration attempt are retained separately from
the successful production build.

Fresh live validation with an empty private profile redirected to Reddit's
login page, so the requested listing was not validated. The live browser also
exited with status 139 during document cleanup. Neither a redirect nor a
successful frozen capture counts as live-page acceptance. Cookie import was
not performed by this validation.
