# Optional stylesheet media and HarfBuzz initializer compatibility

Two syntax fixes preserve existing runtime values while preparing a separate
current-source browser diagnostic. They have zero instruction-count credit.
The accepted optimization control and broad baseline remain round 179.

Commit `51421166` unwraps optional stylesheet media through an `if` expression
before constructing the sheet in the preallocation branch. A supplied media
list keeps its identity and associated stylesheet; omission creates an empty
list owned by the new sheet. The previous inline `or` expression failed to parse
under the legacy frontend even when this compile-time branch was inactive.
The standalone legacy syntax probe now passes. Current V passes all five
stylesheet workspace cases in Boehm mode (1,080 observed assertions) and in
preallocation mode (1,221), including the new media-owner case and the existing
retained-rule, deferred-declaration and scratch-retirement checks. Two
preallocation-only cases have empty bodies in the Boehm configuration.

Commit `f90ccbe2` spells the HarfBuzz cache-generation initializer as `u64(1)`
with inferred type instead of a typed initializer. Its value remains one.
The four native retirement/refill cases pass with both Boehm and GC disabled,
184 observed assertions per configuration. The first case checks the initial
value before exercising generation changes, retained glyph runs, retired
native faces and refills.

All checks use the immutable current-source snapshot at
`Build/instructions/normal-sealed-current4-20261023/source`, manifest SHA256
`f7bf7bd7ceab2e3294c7145380406167a05f1c50675536b05730b7fa7b3932d0`.
The snapshot includes independent geometry work; these selected checks cover
only the two fixes. Both owned implementation/test pairs match its bytes.
The compiler is `/Users/alex/code/v-latest/v -new-compiler`, with
`-memory-limit 10G`. Preallocation workspace and both HarfBuzz configurations
use C-only generation, actual Clang `-O2`, separate 12 GiB build guards and
3 GiB runtime guards. Every frontend, native compilation and runtime exits zero.
Their `generated.c.gz`, native arguments, logs, binary/C hashes and receipts
are retained under `focused-separated-{workspace-prealloc,harfbuzz-boehm,
harfbuzz-none}` in that evidence directory.

The earlier Boehm workspace command embedded execution under its 12 GiB build
guard: current V ignored `-skip-running` in a capability probe. Its completed
cases were retained without replay. That command's requested `-cflags` do not
establish native C-O2, so no optimization or C-O2 claim rests on that check.
The later separated jobs use the compiler's dumped native arguments and
explicit `CFLAGS`, verified by a standalone capability probe.

Full current Root still fails legacy checking after the syntax fixes, including
font-global resolution, map-copy and union-mutability errors. The original
failed preparations, parse/checker logs and actual nonzero exits remain in
`normal-sealed{,-current2,-current3,-current4}-20261023`; none receives a pass.
These fixes do not establish full legacy compatibility or Chrome parity.
No broad suite was triggered by these two non-performance fixes. They count
as two completed fixes after the preceding broad-test checkpoint; completed
broad checks were not repeated. The canonical app, GUI browser and independent
working-tree changes were preserved.
