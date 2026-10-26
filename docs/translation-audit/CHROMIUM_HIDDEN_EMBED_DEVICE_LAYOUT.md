# Hidden embedded content and native layout precision

Native Chromium layout now ignores embedded HTML, SVG and MathML subtrees
whose element or ancestor has `display:none` when deciding whether the
document can use device coordinates. The predicate resolves current ancestor
styles on each call, using the preload planner's existing display-box check.
Visible embedded content, `visibility:hidden`, opacity zero and
`display:contents` retain their existing coordinate fallback.

This fixes catalog pages where a cosmetically hidden advertisement frame
previously reduced the precision of all surrounding text. There is no URL or
site-specific behavior in the predicate.

## Verification

Evidence is retained under `Build/4chan-catalog-20261026/`:

- `focused-slice-manifest.json` authenticates the exact production eligibility
  and preload predicates and three eligibility tests in the compiled fixture.
  The cases cover visible embeddings, hidden HTML/non-HTML ancestors,
  exclusions and live display changes. They reported no assertion failures.
- The combined 12-case runtime selection exited **1**, with two select-width
  assertions failing. This is not a claim that the combined selection passed.
  The failures are retained in `resume-focused.log` and
  `device-select-focused-memory.json`; neither concerns eligibility.
- `device-precision-pixels.json` records **zero differing pixels** for both a
  fresh Brave capture and the native Vox capture against the unchanged
  1600×1200 expected image (800×600 CSS pixels, native scale 2).
  The fixture now includes hidden iframe, SVG, MathML and canvas descendants.
  Expected PNG SHA256:
  `9053dd0bb4e844cf26207100e577cd03d0f8a4987c943304d2daeac18cbc910b`.
- Production build, signing verification and headless startup passed for
  executable SHA256
  `1772d23bf2ad5bb607850ed9f621a289ce43a45c94c1b9089dcc9c918f0e9a4e`.
  The before/after production and focused source snapshots match the three
  files committed for this fix. Other in-progress fixes were present in that
  browser; its catalog comparison does not establish full parity.

The combined resume guard also exited 1 because of the retained select test
failures and a failed live navigation. Neither failed aggregate run receives
whole-run acceptance credit. Complete live catalog and pixel parity remain
open.

This is one completed fix in the catalog rendering work after the retained
native-reflection broad baseline at `f2e223c9`; it does not reset the shared
broad-test cadence or claim a new broad regression run.
