# Queued MediaSource events retain the original target

Source pin: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Source MediaSource.cpp queues sourceopen, sourceended and sourceclose with
its actual this pointer. V's mutable-receiver closure capture instead copied
the MediaSource. Event listeners ran, but target, currentTarget and callback
receiver referred to the copy, which acquired a different native wrapper.

A direct V regression reproduces all three wrong identities independently.
The correction captures the stable MediaSource pointer for each queued task.
The typed test compares both event targets and the callback's current target
with the original object; native tests additionally compare JavaScript event
target and callback receiver identity with the source wrapper.

The original isolated baseline fails all three executed tests. An earlier
baseline placed in the shared evidence directory fails only at compilation
because that directory contains saved V implementations; it is excluded from
runtime evidence. The corrected canonical test, neighboring typed algorithms
and native caller are verified on the final combined snapshot recorded in
[Native MediaSource evidence](NATIVE_MEDIA_SOURCE_OBJECT_OWNER.md).
Focused feature: `d397f279`, implementation and the three-case test together.
The canonical regression passes in the corrected default batch and final
GC-none batch; all final code/reference/compiler hashes remain unchanged.

This fixes event object identity. Event clock integration, physical GC edges,
worker mirroring, buffer wrappers and complete media playback remain separate.
The audit remains **32 fixed / 25 partial / 9 open**.
