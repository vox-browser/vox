# Media buffered ranges after coded-frame removal

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature: `cc9b1e78c2c526eeb0965b4140417350b1b5c167`.

SourceBuffer range removal now refreshes its actual HTMLMediaElement's cached
range adapter before ready-state evaluation and queued update/updateend events.
Previously the demuxer lost the removed frames while media.buffered() kept the
last append's ranges. Existing snapshots remain unchanged.

Pinned Source performs ready-state evaluation after removal from every track;
its playback manager reads current demuxer scan-state ranges. The V bridge
keeps a cached fallback instead of that complete manager. It now copies the
processor's current ranges at the same completion boundary. The append path
still enters process_media_data; removal updates the cache and ready state
without entering that progress-event path. Actual playback hooks keep their
existing precedence over the fallback.

The focused regression attaches a constructor-created source to the video
owned by an actual Page/Window document. Controlled coded frames enter the
actual track demuxer and the normal coded-frame completion adapter. Removal
is asynchronous: the earlier two-range snapshot remains readable before and
after removal, and the updateend callback observes the surviving range.

## Checks

| Run | Result | Seconds |
| --- | --- | ---: |
| baseline | Changed task-owner file fails C generation; removal neighbor passes | 70.477 |
| baseline-corrected | New updateend assertion fails at runtime; neighbor passes | 45.407 |
| default | 2/2 files PASS before formatting restoration | 54.440 |
| gc-none | 2/2 files PASS before formatting restoration | 51.957 |
| scoped-default | Final committed files, 2/2 PASS | 96.977 |
| scoped-gc-none | Final committed files, 2/2 PASS | 94.326 |

The original callback combined fallible range reads with short-circuit boolean
expressions, triggering compatibility-compiler C-generation errors. Reads
were split into locals. Before runtime verification, the fixture also widened
the frame gap beyond Source's coalescing threshold. Both representations are
retained separately. The corrected baseline fails because updateend sees the
old cached ranges, not because the removal algorithm kept the frames.

Unrelated whole-file formatting was restored after the initial eight-file
native sweeps. The retained comparison checks literal values and code tokens;
SourceBuffer's optional struct-field comma is the sole token separator
exception. The final two files pass again in both GC modes afterward. Native
getter, actual page callbacks and the 66-case main regression also pass in
both modes on the earlier equivalent formatting snapshot.

Commands use `/Users/alex/code/v/v -old-compiler -enable-globals`, `VJOBS=2`,
and add `-gc none` for that mode. They execute the eight-case task-owner file
and the existing removal file. Final paired manifests retain identical
4,865-file snapshots, seven selected Source references and two compiler hashes.

The consolidated `Build/audit-fixes/media-removal-ranges-evidence.json` has SHA256
`9cc15ed1abbec3bbbf5861fb1c24a42e46820f37c0b72c7a98a01cfcc6d2e3fa`. It records manifest/log hashes, retained failure
representations, compiler/reference checks, feature file hashes, formatting
restoration and the subsequent frozen production runs. Manifests and logs
use the `Build/audit-fixes/media-removal-ranges-<mode>` prefix.

## Boundaries

This fixes the existing per-buffer cached fallback. It does not complete
playback-manager pipelines, selection/aggregation across multiple source
buffers, codec execution, foreign realms, WrapperWorlds, IPC or physical GC
ownership. The native getter and production verification are recorded in
[NATIVE_MEDIA_ELEMENT_BUFFERED_OWNER.md](NATIVE_MEDIA_ELEMENT_BUFFERED_OWNER.md).
The audit remains 32 fixed / 25 partial / 9 open.
