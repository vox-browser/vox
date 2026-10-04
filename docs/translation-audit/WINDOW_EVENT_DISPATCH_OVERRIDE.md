# Window virtual event dispatch

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
`DOM/EventTarget.cpp:483–498` invokes virtual `dispatch_event` from the binding
method. `HTML/Window.cpp:518–521` overrides that virtual method to call the
dispatcher with the legacy target override flag set, bypassing the base
EventTarget's user-activation path.

Feature commit `0c20d1bb` preserves this source distinction in V's tagged
EventTarget dispatch. An actual Window dispatch retains Window as currentTarget
and listener receiver, while the associated Document becomes the event target.
It applies to the public binding as well as native dispatch. The binding still
sets `isTrusted` false. A trusted activation-triggering event dispatched directly
to Window does not enter the base activation path, matching the pinned source.

Three focused DOM cases validate target/currentTarget, binding trust state, and
the unchanged activation timestamp. Both GC modes pass in
`Build/audit-fixes/worktrees/06-canvas-animation/Build/audit-fixes/`:

- `source-window-dispatch-core-default.log`.
- `source-window-dispatch-core-gc-none.log`.

The public Window accessor cases also pass with this corrected Document target;
raw compiler and handler invocation neighbors pass without GC. The shared
`source-window-dispatch-public-gc-none.log` records 4/4 passing files. The initial
default DOM file had a test-only Option propagation error in its anonymous
observer; the corrected focused DOM runs above pass.

The source override is unconditional, including ordinary Window-dispatched
events. This translation retains that pinned behavior rather than applying a
different dispatch rule. Standalone unclassified EventTarget/Window adapters
remain outside the actual Window tag's path.
