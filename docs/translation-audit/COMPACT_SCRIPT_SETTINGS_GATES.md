# Compact page-script execution gates

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
`HTML/Scripting/ClassicScript.cpp::run` checks `can_run_script(settings)` before
each script. `HTML/Scripting/Environments.cpp:150–167` checks the Window
Document's fully-active state before its scripting preference and sandbox.

The compact native browser now applies this existing translated decision before
installing bindings for an initially disabled owned Document, and before each
author source. A Page preference change during one script therefore prevents
later sources from running or emitting syntax diagnostics. Both the
JavaScriptCore host and the supported standalone LibJS path use the same
Document settings decision. No-Window standalone Document construction remains
the explicit compatibility adapter.

Compact JavaScript readiness dispatch checks the same owner before
`DOMContentLoaded` and again before `load`. Native effects of already executed
scripts are still replayed when later execution becomes disabled. The internal
snapshot transport continues to use its host helpers; they are not author
script entry points.

Six focused regressions cover both engines while disabled, sandboxed scripts,
inactive owned documents, re-enabling, preference changes between sources,
preference changes between readiness events, exact WebUI membership, and a real
`BrowserApp.install_loaded_page()` with `<noscript>` content and author code.

Validation in `Build/audit-fixes/worktrees/06-canvas-animation/Build/audit-fixes/`:

- `source-compact-script-owner-default.log`: the final six focused cases passed.
- `source-compact-script-owner-final-gc-none.log`: the final six cases passed
  without GC.
- `source-compact-script-owner-gc-none.log`: the earlier five focused cases and
  existing animation-frame and Page-before-parser neighbors passed (3/3 files).

The compact bootstrap's custom event objects, public Window handler properties,
element callback environments, and dispatch loop are separate source-binding
boundaries. This change does not claim complete callback dispatch, module
execution, or LibJS VM parity. In particular the source callback algorithms
must eventually replace the compact listener transport itself.
