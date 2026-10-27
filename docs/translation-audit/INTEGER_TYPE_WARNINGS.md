# Deprecated V integer type cleanup

2026-10-27, implementation `82e2caf5`.

Replaced 2,446 `usize` spellings with `uint` and 13 `isize` spellings with
`int` in 464 tracked V files. The CSS metadata generator now emits `uint` too.
The staged implementation was checked against saved originals: every change
is an exact type-spelling substitution. A cast in the existing untracked worker
host was updated while leaving that file untracked; concurrent edits were
excluded from the commit.

Validation used current V (`V 0.5.2 3f41e4b`), with
`V_MACOS_V3_NO_FALLBACK=1` and `-memory-limit 10G`. All jobs used the memory
guard; runtime checks used its 3 GiB limit.

- The baseline LibGC suite passed with 294 integer deprecation warnings.
- Eight focused files pass with default GC and `-gc none`: LibGC's external
  entity table, primitive storage and allocator; LibJS's array-buffer operations,
  string length and typed-array creation; WebAssembly's memory span guard and
  memory storage identity. Both configurations emit zero integer deprecation
  warnings.
- `platform/prealloc_arena_test.v` passes with `-prealloc -gc none`, including
  native arena layout checks. The browser root syntax check also passes.
- No `usize` or `isize` tokens remain in repository V sources outside `Build/`.
  Generator comparison confirms its output changes only the type spelling;
  existing metadata drift against current upstream inputs predates this change.

Four CSS-dependent files could not compile: `source_string_darwin_test.v`,
`cascaded_property_entry_storage_test.v`, `measurement_chunk_pool_test.v`, and
`phase_command_storage_test.v`. A read-only source snapshot of the original
`b56dc349` reproduces the recursive sum-type errors, so these checks do not
establish runtime validation for those modules. Other warning categories remain.
No production browser rebuild was needed for this cleanup.

Raw commands, logs, guard reports, source manifests and diagnostic comparisons
are retained in `Build/integer-type-warnings-20261027-191501/`, with results in
`checks-summary.json`. Rejected unsupported-flag attempts and the canceled
CSS-dependent no-GC batch (exit 143) are retained and excluded from passing
results; the eight runnable no-GC files were checked separately.

This entry adds one completed fix to the non-optimization cadence after broad
baseline `aa6f0246`; it does not reset the existing tally or claim instruction
savings. Broad suites were not repeated.
