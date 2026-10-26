# Chromium menu sizing and theme

Commit `c49ef553` measures every option label for native menu intrinsic sizing,
including unselected options and optgroups. The Chromium policy rounds the
complete label in native layout coordinates, retains the persistent UA shadow
label, and paints the menu arrow while preserving authored geometry and colors.

The seven-control fixture in `Tests/Browser/Brave/input/chromium-select.html`
has **zero differing RGBA pixels** against Brave 156.1.98.60 at 800×600 CSS
pixels and native scale 2. The unchanged reference PNG SHA256 is
`a95bb3699723ee520e8b3905ed873ce29190783d95825b8b068965a9537de870`.
The executed comparison is retained in
`Build/4chan-catalog-20261026-menu/select-pixels.json`.

The three sizing/theme cases committed in `layout/chromium_select_test.v`
and the UA shadow case in `layout/chromium_select_shadow_test.v` executed
without assertion failures in
`Build/4chan-catalog-20261026-shadow/focused.log`. That combined run exited
**1** because a separate option-label mutation case retained its old width.
The failed aggregate receives no whole-run pass credit. The mutation hook and
its regression test remain a separate pending fix.

This is the fourth completed catalog fix after retained broad baseline
`f2e223c9`. It does not reset the shared ten-fix regression cadence. Full
catalog pixel parity remains open. Fresh live navigation passed with the
available production bundle; the remaining pixel differences and pending
validation are recorded in [the catalog comparison](CHROMIUM_CATALOG_PARITY.md).
