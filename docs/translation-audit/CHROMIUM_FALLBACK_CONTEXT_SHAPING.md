# Word shaping after fallback symbols

Commit `24f2afcd` preserves contiguous Latin and Cyrillic shaping contexts on
either side of a fallback font symbol. Chunk offsets remain UTF-16 offsets,
including after a supplementary character. Unsupported scripts, incompatible
bidi paths, discontinuities and multi-glyph clusters retain ordinary shaping.

The ten context tests in `layout/chromium_context_shaping_test.v` executed
without assertion failures in
`Build/4chan-catalog-20261026-shadow/focused.log`. The source hashes in
`focused-slice-manifest.json` match the committed implementation and tests.
The compiler completed successfully; the combined runtime exited **1** because
an unrelated select label mutation retained its old width. The aggregate run
does not receive pass credit. The runtime guard recorded a 69,238,784-byte
sampled peak under its 3 GiB budget.

This is the third completed catalog fix after the retained broad baseline
`f2e223c9`. It does not reset the shared ten-fix broad-test cadence. Full catalog
pixel parity and live navigation remain open; the next prepared pipeline is
`Build/4chan-catalog-20261027-label/`.
