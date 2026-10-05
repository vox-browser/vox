# Native URLSearchParams records and page caller

Source pin: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `6f92c2ca`, with implementation, the actual page caller and
three focused test files committed together.

Source `DOMURL/URLSearchParams.{cpp,h,idl}` and
`DOMURL/URLSearchParamsIterator.cpp` supply the real translated records.
`Meta/Generators/libweb_bindings/{constructors,arguments,to_idl_value,iterables}.py`
supplies the binding contract. The previous native global has no
URLSearchParams constructor; its executed baseline returns `undefined`.
Page-script startup now installs a constructor, all declared operations,
the size getter, stringifier, live iterators and forEach backed by those V
records. The browser continues to execute JavaScript through JavaScriptCore.

Generated conversions select iterable objects before records and primitive
strings. They cache iterator methods/next, finish all nested sequence
conversions before pair-length validation, and preserve the pinned conversion
failure path without IteratorClose. Actual UTF-16 engine strings become USV
strings before entering the typed list. Normalized duplicate record keys keep
their original insertion position and latest value. Enumerable Symbol keys
throw during key conversion. The newTarget prototype is read before input
conversion; same-realm subclasses and default-prototype recovery are checked.
Captured intrinsics and indexed internal array access resist later author
changes to Array iteration, Object.defineProperty, Reflect helpers and String.

Wrappers use actual protected engine values and a native-record lookup table.
Receiver validation precedes argument conversion. Typed and JavaScript
mutations reach the same record. Wrapping a DOMURL's actual lazy query object
keeps its identity and writes mutations back to that URL. An iterator follows
later URL query replacement at its current index and can observe an append
after exhaustion, matching the pinned Source implementation. forEach calls
the actual function with value, key, wrapper and thisArg, observes live list
changes, preserves thrown object identity and does not adopt the callback's
return value. Runtime close removes the wrapper tables.

The actual page-script caller verifies constructor exposure, decoding,
filtered deletion, append, native record contents, document text replay, load
ordering and final HTML/VM context cleanup. A separate test reads the two
unmodified upstream sort fixture scripts and compares their complete output
with their upstream expected files, replacing only the external test harness.
These are native API comparisons through JavaScriptCore, not LibJS execution
or screenshot comparisons.

| Run | Result | Seconds |
| --- | --- | ---: |
| Original native global | Constructor absence assertion fails | 183.528 |
| First binding run | Three fixture failures; original diagnostics retained | 149.796 |
| Final host plus page caller, default GC | 2/2 files PASS | 229.275 |
| Unmodified Source sort fixtures, default GC | 1/1 file PASS; 2 exact outputs | 139.738 |
| Combined focused/neighbor batch, GC-none | 6/6 files PASS | 275.547 |

The first binding fixtures incorrectly expected a size of five after
duplicate removal, made an iterator Symbol enumerable while expecting record
conversion to ignore it, and called entries on the unbranded prototype. They
were corrected against Source. Review also replaced an internal `for...of`
with indexed access before the final runs, and the author-mutation check passes.
The final default coverage spans two commands. The GC-none batch includes the
three new files, Blob constructor neighbor, actual script-environment owner and
the existing **66-case** main browser regression, using `VJOBS=3`.

Exact argv/environment overrides, log hashes and final feature hashes are in
`Build/audit-fixes/source-urlsearchparams-host-manifest.json`, SHA256
`914db5ffdff20024df7bd76ef8286185f06739f3583e8c65c25cdb15c1b4a44c`.
The associated code snapshot has SHA256
`02e24274a362e94341ae15ed8145b9c7ca5a16790c87e4f87d614f40934f6998`.
It was captured during the two-file default compilation and before the fixture
and GC-none commands. After completion, all **3,162 V/native-helper files**,
**12 Source implementation/generator/fixture references**, and both compiler
executables match that snapshot. External native libraries and the whole
toolchain are not frozen by this scoped record.

Public URL and its object-URL static methods, foreign-realm constructor and
receiver behavior, Worker startup exposure, full WrapperWorld/GC edge ownership,
allocation limits and complete generated diagnostic text remain separate.
Pair-length errors preserve the pinned Source message; general binding failures
currently preserve the TypeError class rather than every Source diagnostic.
The [previous frozen production bundle](FROZEN_F273F1EF_BLOB_URL_CONTINUATION.md)
predates these changes. The audit remains **32 fixed / 25 partial / 9 open**.
