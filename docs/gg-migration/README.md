# Raster verification evidence

The generated migration receipts moved to [vox-browser/vox-tests](https://github.com/vox-browser/vox-tests/tree/main/evidence/gg-migration).
The import manifest there records original paths and SHA-256 hashes; imported receipts retain their exact bytes.

Keep new bulk evidence in that repository and a concise result in [the migration report](../GG_MIGRATION.md).
The CPU suite revision is pinned in `tools/raster_tests.json`; run it through `tools/raster_tests.py` or the existing `tools/gg_migration/test_cpu_raster.sh` launcher.
