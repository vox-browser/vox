# Source optional extern-cache lookup

Pinned `LibWeb/WebAssembly/WebAssembly.h:74` returns
`m_extern_values.get(address)`, an optional value. The former V direct map
access wrapped a default value when the address was absent. An absent entry
must differ from a present cached `undefined` value.

`7199c7ed` changes `WebAssemblyCache.get_extern_value` to preserve the missing
map-entry branch explicitly. The focused test distinguishes absence, cached
undefined, replacement by an actual platform-object record, its inverse key
and a missing maximum-u64 address. The complete extern-cache file fails the
new absence assertion before the correction and passes afterward in default
GC, with original and final logs retained under canonical `Build/audit-fixes/`
as `source-extern-cache-optional-private-{baseline,default}.log`. Source is
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

Production compilation separately exposed three existing annotation errors:
the already checked argument allocation called C malloc outside `unsafe`, and
two already validated import namespace lookups cloned pointer-bearing maps
outside `unsafe`. `524275d6` adds only the required unsafe annotations to those
existing operations. It preserves allocation ordering, errors, namespace
ownership and cloning behavior. Existing cache/module test map reads also
required explicit presence guards; `0be25abe` changes only those fixtures.

The corrected cache/module files pass **2/2 production GC-none** in
`source-cache-module-private-prod-gc-none-recheck.log`, after the original
six-file production batch had passed arguments/store/memory/frames and failed
these two fixture compilations. This proof is scoped to the private checkout
`root-source-memory-store`; no full production package pass is claimed.
Actual JS engine values, collector and wrapper-world cache ownership remain
separate runtime boundaries.
