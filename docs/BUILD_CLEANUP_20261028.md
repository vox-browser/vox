# Build cleanup and master integration

The cleanup was corrected on 2026-10-29 (Europe/Moscow): the identified missing
implementations and pending changes were tested and committed directly on
`master` before removing the entire `Build/` directory. The earlier archive
verification established recoverability only; it did not establish that the
code was integrated into `master` and was insufficient for the user's request.

## Code integration

Source variants, patches, generated modules, and later recreated Build trees
were compared with the canonical checkout and reachable `master` history.
Semantic differences were reviewed after deduplicating repeated snapshots.
That review found three missing implementations and two pending changes:

| Commit | Implementation | Validation |
| --- | --- | --- |
| `cea29abf` | Rounded SVG ancestor compositing helper and failure handling | Native Skia and Graphite checks at scales 1 and 2, including failure paths that preserve the destination |
| `560f07c3` | Chromium rectangle prefetch integration and scratch handling | Native boundary/scratch comparisons, three V tests in Boehm and `-gc none` modes, actual browser source type check |
| `8ba6d5cc` | Checked-checkbox coordinates at large origins | Six tests in Boehm and `-gc none` modes; the added regression failed before the fix |
| `b4c80f62` | Borrowed typed CSS color values and classifiers | Four tests in Boehm and `-gc none` modes, including ownership, animation priority, text fallback, and color calculations |
| `c535622d` | Shared compositor pictures resuming after complete child effects, plus rounded border admission | Nineteen tests in Boehm and `-gc none` modes, layout fixtures at both scales, and the existing native shared-layer regression with 144 matching local pictures |

Each commit contains its focused tests. Every commit is an ancestor of `master`,
and the tested source hashes were checked against the committed files.
The compositor fixture is tracked with its implementation. Unrelated canonical
working files were retained.

Older working implementations were already present in `master` or its history,
including the DOM and Canvas fixes, font/runtime generators, native HLS media
integration, and tab-process lifetime fix. Generated C, dependency copies, test
binaries, and repeated source snapshots required no additional implementation.

Failed or explicitly rejected experiments were reviewed rather than installed
as working features: the arc-precision alternative, font-generation and
font-selection caches, private color-context caching, cascade seed slabs, and
the early CSS dependency-scope change. Their recorded failures, performance
regressions, or unsafe ownership assumptions distinguish them from the missing
working changes integrated above. They are not claimed as active master logic.

## Removal verification

At **2026-10-29 00:45:48 +03:00**, after the integration checks completed:

- The entire `Build/` directory was removed. Its final measured allocated size
  was **2,489,110,528 bytes (2.32 GiB)**.
- All **11,406** inventoried canonical files and symlinks outside `Build/` and
  `.git/` remained present and unchanged across removal, including untracked work.
- `git fsck --connectivity-only --no-dangling` passed. Git has no object-store
  dependency on `Build/`, and only the canonical master worktree remains.
- Small validation logs and JSON receipts were retained outside `Build/`;
  no new source archive was created for this correction.

The original integration receipt and validation logs were initially retained
in the recovery directory. That directory has since been deleted as described
below; the committed verification report retains the test commands, source
hashes, exit codes, and relevant memory-guard results.

An already-running Vox process still mapped its deleted bundle when removal
was checked. No new browser was launched. These checks establish source
integration and focused correctness, not fresh whole-page Brave pixel parity.
Future builds and tests may recreate `Build/` under the normal repository workflow.

## Recovery archive removal

At **2026-10-29 02:57:25 +03:00**, the entire
`/Users/alex/code/vox2-build-preservation/` directory was deleted, including
the 28.5 GiB object archive, later archives, extracted variants, patches,
manifests, and recovery utilities. The directory occupied **32,274,546,688
allocated bytes (30.1 GiB)** in total. Filesystem free space increased from
**3.4 GiB to 33.4 GiB** during the operation.

Before deletion, all five implementation commits were verified reachable from
`master`. All 16 integrated implementation and test files matched both the
committed contents and their successful focused-test source hashes. Forty
original validation receipt hashes were rechecked, and no recovery files had
been added or modified since the completed logic audit. The earlier rejected
experiments remain excluded for the reasons recorded above.

All 11,406 canonical files and symlinks outside `Build/` and `.git/` remained
unchanged across this deletion. Git connectivity passed again, with no external
object-store dependency or tracked symlink into the deleted directory.

[The verification report](BUILD_RECOVERY_REMOVAL_20261029.json) contains only
small audit metadata, commit identities, source hashes, and prior test results.
No source archive, recovered source copies, patches, or binaries were retained
by this operation. The currently generated `Build/` files were left in place.
