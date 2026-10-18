# Native window resize

Maximizing `https://old.reddit.com` reproduced a segmentation fault in
`gg__gg_event_fn`. LLDB stopped at its write to `ft.scale`, with a null font
pointer and fault address `0x90`. Vox's native Cocoa initialization intentionally
leaves the unused FreeType atlas unallocated.

The Cocoa context now installs a resize adapter that updates the display scale
and both cached window sizes without accessing that atlas. The general event
callback still precedes the size update and optional resize callback. Other
events retain GG's existing keyboard and pointer dispatch. Portable rendering
keeps its original lifecycle and event callbacks.

The eight cases in `main_native_window_test.v` passed against an isolated
snapshot of `8092ae1c` with this fix and against the current working checkout.
They include maximize/restore sizes,
callback ordering, the legacy `on_event` callback, absent resize hooks, and
keyboard and pointer routing with the font atlas still null. Artifacts are under
`Build/maximize-crash/`; failed attempts caused by unfinished concurrent edits
and initial fixture/setup errors are retained separately.

The signed isolated production bundle passed `--headless-smoke`. A native
AppKit driver then loaded live old Reddit, completed two maximize/restore
cycles (800x712 to 1728x1085 window frames), entered and left fullscreen, and
exited zero. Its executable SHA256 is
`fcc583c0948efef9c55f1822bb1b506ad69160b91cf825e775e2d4a36a565795`.
Two initial launches were externally terminated with SIGTERM before startup;
the successful check used the same executable under the distinct process name
`resize-check`.

This entry records one completed crash fix for the non-optimization verification
cadence. It does not reset a broad-test baseline.
