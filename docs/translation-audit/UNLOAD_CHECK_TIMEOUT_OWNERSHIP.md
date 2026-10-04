# Unload-check state deadline and timer ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/LocalNavigable.cpp:3979–4003,4149–4166`,
and `Platform/Timer.cpp:14–21,58–71,90–94`.

The translated unload-check state had no Source deadline. A real phase-one
global task can retain a Document that navigation later makes inactive, leaving
the task unrunnable and its check unfinished. Pinned Source starts a 15000 ms
single-shot Platform timer in the state constructor. If the state remains
unfinished, that timer reports the Source FIXME and finishes with Continue.

Both translated check entry points now construct the state through one helper
that creates and starts that exact existing Platform.Timer. The timer callback
retains the actual state, and the existing Platform timer activity root retains
the callback while active. Completion first checks its once-only guard, marks
the state completed, stops the timer, and only then invokes the retained
completion callback, matching Source ordering. The timeout returns Continue
even if a partially processed phase already recorded a canceled status; it
does not erase the retained prompt-shown flag.

Four cases in `html/unload_check_timeout_owner_test.v` use real navigation
Documents, Pages, Windows, native Navigables and actual beforeunload/Navigation
listeners with the existing Platform.Timer dispatch seam:

- Empty phase completion observes the timer stopped and activity root released
  before the completion callback; later timer dispatch and finish attempts
  cannot call it again.
- Real navigation replacement makes a queued phase-one task unrunnable. Timer
  dispatch completes that check with Continue. Restoring the actual owner makes
  the retained task runnable again; its genuine canceled Navigation event
  cannot produce a second completion.
- A completed beforeunload cancellation preserves canceled-by-beforeunload,
  stops the deadline before callback delivery, and ignores later timer firing.
- A two-Document phase records an actual canceled beforeunload result and shown
  prompt before timeout. The deadline still returns Source Continue, preserves
  prompt state, and does not complete again when the second task executes.

The tests assert the actual timer's 15000 ms interval, single-shot flag, active
state and activity-root ownership. They call the existing `Timer.fire()` seam
to deliver the deadline without waiting fifteen seconds. This proves state
ownership and callback ordering through the real translated timer; native
Platform timer/run-loop scheduling is separately covered by existing platform
tests and the root production workflow.

Default GC passed the focused deadline file and actual active Window owner
tests, 2/2 files, in
`Build/audit-fixes/source-unload-check-timeout-owner-default.log`. GC-none passed
10/10 files in `source-unload-check-timeout-owner-gc-none.log`, adding phase-two
tasks, current-entry/origin gates, complete Traversable, prompted-close,
beforeunload, event-loop, native Platform timer and Platform state-transition
coverage. Commands use `v -old-compiler -enable-globals test`, adding `-gc none`
for the ownership batch. The expected Source timeout FIXME is printed by the
two deadline-delivery regressions.

Source does not discard already queued phase callbacks when the timer fires;
that behavior is retained. The same completion guard suppresses later callback
delivery. This does not translate the remaining bare-host Traversable creation,
complete native Navigable input vector, session-history graph/current-step
protocol, Page history executor, remote transport or public JavaScriptCore
bindings.
