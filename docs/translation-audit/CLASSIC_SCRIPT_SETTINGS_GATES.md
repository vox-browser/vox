# ClassicScript settings gates

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`HTML/Scripting/ClassicScript.cpp` and `HTML/Scripting/Environments.cpp`.

Feature commit `72323a89` replaces two remaining standalone realm-flag checks
with the source algorithms already translated for actual settings objects.
Ordinary `ClassicScript::create` substitutes an empty source when scripting is
disabled before its parser hook runs. `ClassicScript::run` calls
`can_run_script` before entering its execution context or reporting a stored
parse error. That decision checks the actual owning Document's fully-active
state, its Page's scripting preference, the exact internal WebUI URL exemption,
and its sandboxed-scripts flag.

The pinned source's pre-parsed, pre-compiled, and bytecode-cache constructors
do not perform disabled-source substitution. Their V adapters now preserve
the original source too, including failed cache materialization. Each run
still checks current settings. An ordinary script created while disabled
continues to hold its empty source after the Page is enabled; an existing
compiled script retains its original source and can run after re-enabling.

Five focused tests use real Page-backed navigation documents and their actual
settings, not hand-written replacements. They cover disabled parsing, exact
WebUI membership and sandboxing, preserved compiled/pre-parsed/cache source,
fully-active and preference checks before stored errors/context entry, and
the independence of actual owners from standalone realm adapter flags.

Validation in `Build/audit-fixes/worktrees/06-canvas-animation/Build/audit-fixes/`:

- `source-classic-script-owner-default.log`: 2/2 files passed, including the
  focused cases and existing script lifecycle/error-mode neighbors.
- `source-classic-script-owner-gc-none.log`: 3/3 files passed, adding the actual
  scripting settings/adoption/parser owner cases.

Parser, compiled-program and bytecode-cache hooks are still explicit runtime
adapters. This commit does not supply missing LibJS executables, Source error
objects, module execution, or the complete ClassicScript registry and GC graph.
The browser's compact script entry needs a separate application of the same
source gate because it executes through JavaScriptCore's host boundary.
