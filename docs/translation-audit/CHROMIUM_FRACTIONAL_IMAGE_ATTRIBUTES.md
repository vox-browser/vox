# Fractional image attributes in native Chromium layout

Commit `7e9076a9` preserves parsed floating point HTML image width and height
attributes until native coordinate projection. Rounding to a CSS layout unit
before multiplying by the backing scale shifted fractional thumbnail edges.
The LibWeb policy retains its original rounding.

The three focused cases in `layout/chromium_replaced_dimensions_test.v` cover
scale changes, live attribute changes, author CSS precedence and LibWeb behavior.
They executed without assertion failures in the retained
`Build/4chan-catalog-20261026-menu/focused-fixed.log`; their source hash matches
`focused-slice-manifest.json`. That combined run exited **1** because of two
separate select and bidi fixture failures. Its compiler and runtime guard reports
are `focused-fixed-guard.json` and `device-select-focused-memory.json`.
The failed aggregate receives no whole-run pass credit.

The previous production candidate reduced the matched-policy archived catalog
comparison to seven differing native pixels, each one channel level, while other
pending fixes were present. This does not establish isolated pixel improvement,
full catalog parity or successful live navigation. Further validation is queued
under `Build/4chan-catalog-20261026-shadow/`.

This is the second completed catalog fix after the retained native-reflection
broad baseline `f2e223c9`, following hidden embedded-content precision. It does not
reset the shared ten-fix broad-test cadence.
