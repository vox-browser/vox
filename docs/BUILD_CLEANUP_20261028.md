# Build cleanup — 2026-10-28

The requested cleanup removes the entire `Build/` directory from the canonical
`master` checkout at `/Users/alex/code/vox2`. Canonical implementation files and
pending changes remain in place. Historical source variants are recoverable;
they were not blindly applied over the current implementation.

Recovery data is outside the checkout at
`/Users/alex/code/vox2-build-preservation/20261028/`. Its `README.md` explains
single-file restoration using `preserve.py`, `objects.zip`, and the numbered
`segments/NNN/manifest.jsonl.gz` files. Keep the manifests with the object archive.

## Preservation evidence

- The original object archive is 30,598,507,391 bytes (28.50 GiB), SHA-256
  `86fb0008ce28b2467e1bb1c4d2607fca899ced8d73349d77247e63abcddccf4c`.
- Full decompression, CRC, and SHA-256 verification passed for all 400,323 unique
  objects. Manifests preserve 6,339,150 file paths and 3,616,473 symlinks, including
  historical sources, patches, fixtures, generated source, and nested Git data.
  Repeated snapshots account for much of the path count.
- Only 55,317 positively identified ELF/Mach-O compiled products were discarded
  from the original tree. Unknown formats and Git files were retained. Two
  unused FIFOs were moved intact with identity receipts; changed Finder metadata
  was saved separately.
- No file from the canonical checkout's 7,648-file initial inventory was missing.
  Independent sessions changed five inventoried files during cleanup; those
  changes were retained. Canonical Git connectivity passed.
- Recovery checks restored a patch, a V source file, and the unique-source-variants
  tarball with exact saved hashes. All 114 regular tar members were fully read
  and hashed, including checking the gzip trailer.
- Final audit and recovery checks both completed with exit code zero under the
  3 GiB memory guard. See `final-verification.json`,
  `recovery-verification.json`, and their guard reports in the recovery directory.

The original tree was absent at the audited checkpoint of 18:31:11 UTC. Another
session subsequently recreated Build for a browser build and measurement. Both
later trees were also preserved, fully verified, and removed. Their separate
`recreated/` and `recreated-2/` archives contain 5,190 and 869 file paths and occupy
301,657,698 and 85,310,730 bytes respectively; these are additional to the original
archive's counts and checksum. Their move records and `receipt.json` files retain
the preservation and removal evidence.

`post-cleanup-verification.json` records the successful final audit at
2026-10-28 18:42:02 UTC: Build absent, no missing canonical files, all eight
referenced guards successful, and exact restoration of source scripts from both
later archives. `post-cleanup-audit-2-guard.json` records audit exit code zero.
The earlier post-cleanup audit failed because another session recreated Build;
its log is retained alongside the subsequent successful audit.

Future builds and tests normally recreate `Build/` according to the repository's
build workflow. This cleanup does not change that workflow or remove code needed
to rebuild. No browser rebuild was needed to validate removal of generated files.
