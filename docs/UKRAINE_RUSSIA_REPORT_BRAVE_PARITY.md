# Maximized UkraineRussiaReport rendering

The isolated canvas and image-layer fixes match the maximized frozen page
exactly: **0 of 6,918,912 physical pixels differ from Brave**. The document
viewport is 1728×1001 CSS pixels at native backing scale 2. This is an exact RGBA comparison of the complete
viewport, without excluded regions or channel tolerances. Browser chrome is
outside the comparison.

The requested URL is `https://old.reddit.com/r/UkraineRussiaReport/`.
A frozen input keeps post scores, timestamps and resources identical between
fresh browser processes. This result covers that captured document and
viewport in the isolated renderer bundle. It does not establish live-page,
current production-bundle or general browser parity.

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
[`Tests/Browser/Brave`](../Tests/Browser/Brave/README.md). Nine focused comparisons
were exact in the production run: repeating sprite boundaries, border-miter
raster tiles, single-sided rounded borders, rounded border/solid-fill controls,
background sprite placement, broken-image fallback, inline precision, checked
checkboxes and display density. These earlier fixture results are retained
separately from the isolated full-page result.

## Evidence

Private account-bearing inputs, screenshots, cache data and numeric diagnostics
remain in ignored, restricted `Build/urr-visual-maximized-20261025/`. They are
not committed or reproduced in this document.

The last completed production background validation still had five differing
pixels. Its immutable bundle is:

```
Build/urr-visual-maximized-20261025/current-edges-1792979246302807000/Vox.app
```

Its executable SHA-256 is
`79a98870e49cb2fe167628b3e9257078da2516bc17bbba2595a6d57e47b748f9`.
The adjacent `provenance.json` retains the build-time source manifests, native
library hashes, signing checks, child exit codes and identity checks. Each
capture records its fresh PID, private profile, cache digest and executable
identity before and after capture. The bundle identity remained unchanged.

The production bundle passed signing verification and headless startup.
Focused layout/runtime and native image-cache checks passed. The broader
screenshot smoke command returned nonzero: `inline-node`, `ordered-list`,
`text-decorations` and `default-ignorable-code-points-not-painted` also fail on
the matched pre-change control. Those failures remain open; the smoke set is
not reported as passing.

The strict comparison can be repeated against the archived captures with:

```sh
python3 tools/check_pixel_equality.py \
  Build/urr-visual-maximized-20261025/current-edges-1792979246302807000/captures/brave-after.png \
  Build/urr-visual-maximized-20261025/current-edges-1792979246302807000/captures/vox-after.png \
  Build/urr-visual-maximized-20261025/recheck.diff.png \
  --result Build/urr-visual-maximized-20261025/recheck.result.json
```

The command must return nonzero while any pixel differs. In that production
run, the separate `maximized-common` comparison also had five differences with
both browser outer windows filling the available display. The equal-viewport
comparison above retains the complete Vox document viewport.

The newer isolated run is retained in
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

Repeat the complete maximized and public fixture comparisons against a normal
production build containing both fixes, and retain its build-source continuity,
native library identity and broader smoke results. The comparison gate remains
strict. A concurrent RGBA glyph experiment caused additional one-channel pixel
differences in an earlier mixed renderer run; the isolated image fix excludes
that experiment. A subsequent production build attempt stopped during Dawn
configuration after CMake reset options on a compiler-path change. Its retry
must complete before current production parity can be claimed.

Fresh live validation with an empty private profile redirected to Reddit's
login page, so the requested listing was not validated. The live browser also
exited with status 139 during document cleanup. Neither a redirect nor a
successful frozen capture counts as live-page acceptance. Cookie import was
not performed by this validation.
