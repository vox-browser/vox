# Wasm compilation coordination and call records

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWasm`, with `AK/Atomic.h`, `AK/Vector.h` and `AK/kmalloc.cpp`.
These slices extend the real Store/Configuration records. They do not implement
an interpreter or supply invented compiled execution.

| Source | V implementation | Preserved behavior |
| --- | --- | --- |
| `Types.h`, `Module` compilation methods | `module_compilation_control_native.c.v`, `module_compilation_control_host.h` | One construction-owned state, mutex and condition variable; one successful starter; acquire completion reads; locked release publication and broadcast; wait only while compiling. |
| `Types.h`, `CodeSection::Func` constructor and `total_local_count()` | `binary_code_section.v` | Cache the sum once at construction, retain source `size_t` width, and use it through the actual Code record. |
| `AbstractMachine.cpp:516–557`, `ModuleInstance::compiled_fn_table` | `machine_compiled_function_table.v` | Rebuild until every actual source Module has attempted compilation; preserve resized entries; ignore host functions; acquire native publication and retain actual code, expression, module and metadata pointers. |
| `ArgumentsStaticSize`, `AK::Vector<Value, 3>` | `machine_arguments.v` | Three actual inline slots, capacity-preserving clear, owned outline storage, move construction/assignment and moved-from inline capacity. |
| `Configuration.h:178–209` | `machine_arguments.v` | First sufficient freelist entry wins; otherwise take the last and grow against the current module minimum. Keep at most sixteen allocations; a rejected allocation remains caller-owned. |
| `Configuration.h:44–105` | `machine_configuration_frames.v` | Move owned locals; resolve real Store tables; use compiled dispatch continuation when present; reserve hinted stack/label space; replace tail-call record storage. Lightweight frames borrow locals, reuse same-module tables, skip labels and preserve the record pointer for zero allocation. |
| `Configuration.cpp:14–39` | `machine_configuration_frames.v` | Restore borrowed or currently located inline-owned caller locals; resolve tables only across module changes; return owned locals to the argument freelist. |
| `Configuration.h:142–164` | `machine_configuration_frames.v` | Call handle saves record base/mark, increments depth and clears the active base; destruction releases the mark, restores the base, then unwinds. |
| `Configuration.cpp:49–89` | `machine_prepare_call.v` | Look up the actual Store function; retain the actual HostFunction reference or source Trap; append source-typed zero locals and inlined locals, move arguments into the real frame, and perform tail unwind before replacement without waiting for native compilation. |

The pinned `AK::Atomic::compare_exchange_strong` maps its requested `acq_rel`
order to release on success and acquire on failure. The native adapter preserves
that source implementation. A fresh deserialized Module receives a fresh
compilation owner, rather than aliasing the previous state.

Source tests use sixteen competing native starters and sixteen waiting threads,
real Store host/Wasm records, imported functions with their original Module,
publication of actual compiled metadata, source-width wrapping, and table
retention across repeated reads. Published numeric entry markers are metadata
probes; they are never called as fabricated executable functions.

Argument tests check inline versus outline ownership, actual pointer transfer,
first-fit ordering, the last-allocation fallback, module minimums, static and
already-allocated early returns, full-freelist retention and reset. Frame tests
check actual global records, compiled-table identity, continuations, labels,
same-module reuse, cross-module restoration, relocated inline locals,
call-handle order and bounded tail-call storage.

Call-preparation tests use actual Store code and type records. A Module already
being compiled is prepared without blocking; reference locals retain their
source null tags. A returned HostFunction pointer mutates the actual Store
record. Missing addresses retain a concrete source Trap. Tail preparation
recycles old locals and replaces the call region without inventing execution.
V 0.5.2 cannot nest Option inside Result, so a small result header contains the
actual `Optional<HostFunction&>`; the Result error channel carries the original
Trap through V's required `IError` methods.

## Validation and remaining boundaries

The compilation/table/function-body snapshot passes **74/74 files in each GC
mode** canonically: `source-module-table-wasm-canonical-{default,gc-none}.log`
under `Build/audit-fixes/`.

Argument and Configuration neighbors pass **2/2 files in each GC mode**;
frame and Configuration neighbors pass **2/2 default** and frame/argument/
Configuration neighbors **3/3 with GC disabled**. Logs reside in
`Build/audit-fixes/worktrees/09-compiled-records/Build/audit-fixes/`, named
`source-arguments-{default-recheck,gc-none}.log` and
`source-configuration-frames-{default-recheck,gc-none}.log`. Earlier compiler
and test-fixture failures remain in their original logs.

Final call-preparation checks pass **1/1 in each GC mode**, recorded in
`source-prepare-call-{default,gc-none}-pointer-recheck.log` in the same isolated
log directory. Earlier unsupported nested-Option and smart-cast C compilation
failures remain recorded separately. The completed snapshot passes **77/77
files in each GC mode** in the isolated worktree, recorded in
`source-frames-prepare-full-{default,gc-none}.log`. Canonical focused checks of
the merged argument/frame/preparation owners are recorded separately.

V owners call `destroy_compilation_control()`, argument `destroy()` and call
handle `destroy()` explicitly, with the handle normally used through `defer`.
Automatic C++ noncopyability/destruction and the full weak/ref-counted Module,
native-code and collector-root graph remain open. Compilation coordination uses
a native pthread mutex/condition adapter validated on macOS; Windows is not
validated. Outer vectors use V heap headers; source inline capacities for the
outer label/freelist vectors are not ABI equivalence claims. Outline argument
capacity follows the upstream system-allocator/instrumented exact-size branch;
the default upstream mimalloc size-class rounding is not translated here.

Frame installation does not consume labels or values on unwind, matching
source; the future execute path owns that cleanup. Constant-expression
execution, complete machine instantiation, interpreter calls, native compilation
and the browser realm/GC ownership graph remain unfinished.
