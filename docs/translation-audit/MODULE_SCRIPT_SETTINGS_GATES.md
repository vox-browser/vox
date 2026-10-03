# JavaScript module script settings gates

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`HTML/Scripting/ModuleScript.cpp`.

The JavaScript module script adapter now uses the actual source settings
decision when creating an ordinary script and when running an existing one.
Ordinary creation substitutes an empty source only when `is_scripting_disabled`
is true. Existing pre-parsed, parsed-program, compiled, and bytecode-cache
constructor paths retain their original source, as the corresponding pinned
source constructors do.

The run gate checks `can_run_script` before context entry or stored error
handling. Its blocked result is the adapter's fulfilled evaluation with
undefined, corresponding to the source's resolved promise. Actual Page-backed
settings use the Document's activity, Page preference, exact WebUI exemption,
and sandbox flags. Standalone realm flags remain compatibility adapters rather
than substitutes for an actual owner.

Four focused cases use actual Page-backed Document settings and cover normal
source substitution, WebUI/sandbox behavior, retained constructor source,
disable/re-enable transitions, activity checks before errors/context entry,
and actual-owner independence from standalone realm flags.

Validation in `Build/audit-fixes/worktrees/06-canvas-animation/Build/audit-fixes/`:

- `source-module-script-owner-final-default.log`: four focused cases passed.
- `source-module-script-owner-final-gc-none.log`: the same four cases passed
  without GC.
- The initial default runtime neighbor passed; the initial GC-none ClassicScript
  and module-fetching neighbors passed. The initial focused file had a test-only
  optional-field annotation error, corrected before the final successful runs.

`ModuleEvaluation`, parser/compiled hooks, and requested-module extraction are
existing runtime adapters. Source promise identity/reactions, module records,
the temporary module execution context, linking, and full evaluation remain
separate audit work. This slice does not claim native browser module execution.
