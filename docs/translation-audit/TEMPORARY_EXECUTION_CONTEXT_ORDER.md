# Temporary execution context cleanup

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`HTML/Scripting/TemporaryExecutionContext.cpp:15–30`.

The source constructor prepares a script and then an optional callback. Its
destructor cleans up the script first and then the callback. The V helper had
reversed that destructor order, removing the backup incumbent realm before the
script cleanup's microtask checkpoint.

The helper now follows the exact source order. Checkpoint jobs can observe the
prepared callback and its owning incumbent settings after the script context
has been removed. Callback cleanup then drops that ownership. The existing
idempotent explicit-close behavior is preserved.

Three focused cases verify incumbent settings and callback depth during the
checkpoint, removal of the actual bound VM context before checkpoint work, and
the callbacks-disabled case retaining an outer callback's incumbent. Default GC
passes `source-temporary-context-cleanup-default.log`; the five-file GC-none
batch passes `source-temporary-context-cleanup-gc-none.log`, including native
handler invocation, navigation interception, script cleanup, and scripting
runtime neighbors. Logs are under
`Build/audit-fixes/worktrees/06-canvas-animation/Build/audit-fixes/`.

This change concerns the source temporary-context destructor. Other callback
algorithms keep their own source preparation and cleanup sequences.
