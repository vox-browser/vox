# Maximized UkraineRussiaReport rendering

The maximized frozen-page comparison remains open: **5 of 6,918,912 physical
pixels differ from Brave**. The document viewport is 1728×1001 CSS pixels at
native backing scale 2. This is an exact RGBA comparison of the complete
viewport, without excluded regions or channel tolerances. Browser chrome is
outside the comparison.

The requested URL is `https://old.reddit.com/r/UkraineRussiaReport/`.
A frozen input keeps post scores, timestamps and resources identical between
fresh browser processes. This result covers that captured document and
viewport; it does not establish live-page or general browser parity.

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

The last group is committed in `1f9184c2`. It reduced the maximized frozen
comparison from 14 differing pixels to 5. A checked-checkbox geometry candidate
subsequently left the result unchanged and was removed.

Public synthetic fixtures and Brave references live in
[`Tests/Browser/Brave`](../Tests/Browser/Brave/README.md). Nine focused comparisons
were exact in the production run: repeating sprite boundaries, border-miter
raster tiles, single-sided rounded borders, rounded border/solid-fill controls,
background sprite placement, broken-image fallback, inline precision, checked
checkboxes and display density. These passing fixtures do not close the five
full-page differences.

## Evidence

Private account-bearing inputs, screenshots, cache data and numeric diagnostics
remain in ignored, restricted `Build/urr-visual-maximized-20261025/`. They are
not committed or reproduced in this document.

The immutable production bundle used for the completed background validation is:

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

The command must return nonzero while any pixel differs. The separate
`maximized-common` comparison also has five differences with both browser
outer windows filling the available display. The equal-viewport comparison
above retains the complete Vox document viewport.

## Remaining acceptance work

Four differences occur at a rounded repeated-image border and one at a checked
control. Matching isolated public controls indicate that their full-page paint
context needs further investigation. The comparison gate remains strict.

Fresh live validation with an empty private profile redirected to Reddit's
login page, so the requested listing was not validated. The live browser also
exited with status 139 during document cleanup. Neither a redirect nor a
successful frozen capture counts as live-page acceptance. Cookie import was
not performed by this validation.
