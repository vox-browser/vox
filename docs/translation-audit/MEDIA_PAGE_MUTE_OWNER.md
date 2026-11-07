# Page mute and actual media ownership

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and focused tests: `72210f57cf349800020a10f22eed282ca243221a`.
Legacy timer adapter correction and final verification snapshot:
`b80844bb8a49baeae0460e21c506b27e7188c613`.

Page mute now reaches each registered concrete media owner. It updates the
existing manager-volume hook and then the owner's audible state, with actual
PageClient and Document timer notifications only when that state changes. Public
volume/muted values and playback state stay intact; Page mute queues no
volumechange and does not change video screen wake locks.

## Source mapping and remaining boundaries

Page.cpp:820–839 registers media IDs, unregisters them and dispatches through live
DOM media owners. Page.cpp:1003–1013 returns early for unchanged mute state,
commits the new state and invokes each owner's page_mute_state_changed.
HTMLMediaElement.cpp:712–716 updates volume and audio; cpp:719–735 queries its
current Document's actual Page before element mute and clamped volume.
AudioPlayState.h defines the Source enum. The V DOM/Page bridge carries its
muted/unmuted query as a boolean and forwards changes to the concrete Page.

HTMLMediaElement.cpp:194 registers at construction and cpp:225 unregisters at
finalization. The V model registers its actual callbacks when materialized with
an associated DOM element and an installed Page; explicit finalize releases its
wake handle and unregisters through the current Document's Page. A repeated
finalize is harmless. Standalone or unconfigured Page adapters create no owner.
The existing set_page_muted convenience method forwards to a configured actual
Page; its cached fallback remains only for standalone/unconfigured adapters.

Page.cpp:841–848 queries each actual media owner's current Document and audible
flag. The V concrete-owner path now does the same, rather than masking all
owners immediately after the Page mute flag changes. A manager-volume hook sees
the preceding audible state; the later owner update notifies PageClient before
Document. Synthetic media state records retain their separate compatibility
adapter, including their counters and muted query. An explicit retained-state
adapter with cached audible media reschedules only its matching attached document.
Concrete owners use their own state-transition notifications; unrelated attached
documents receive no invented broadcast.

Concrete callbacks use retained targets at the DOM/Page package boundary. They
are not a completed Source weak-ID directory: physical weak-node lookup,
automatic collector finalization and reclamation remain open. Explicit
unregistration removes these retained callbacks. Models created before a Page
is installed remain the existing standalone adapter boundary. Source adoption
does not migrate its constructor's Page ID registration; this slice likewise
does not invent registry migration between Pages. Its adoption case verifies
that effective volume queries the current Document's Page and that callbacks
from the original registered Page use that current owner. General cross-Page
registry/collector integration remains open.

Complete Base/manager/timer/control finalization, manager membership gates,
CSS media-state invalidation, permission/error gates, full resource/readiness
algorithms, native play Promise creation, physical decoder/audio/pipeline and
native wake-lock power transport remain open. main.v and the native media host
are unchanged. The browser still uses JavaScriptCore and native JavaScript play
retains its existing resolved-Promise stub.

## Verification

Five model cases and one native page case cover two actual media owners across
separate documents on a Page, pre-muted Page construction, other-Page isolation,
volume/mute precedence, duplicate suppression, actual manager callbacks,
pre-update audibility ordering, no volumechange, retained video wake locks,
actual hidden-document timer deadlines/grace, disconnected silent registration,
explicit finalization/unregistration, current-Page lookup after adoption and
standalone adapter behavior. The native case uses real parsed elements, native
property and pause bindings, trusted EventTarget identity, deferred delivery and
balanced execution contexts. Playback enters through the actual V caller.

The initial baseline exposes five runtime failures; strengthening the timer
case to inspect the actual media audible flag produces six failures on unchanged
old implementation bytes, without compiler errors. Final model/native test
bytes match that second retained baseline. The initial focused compile retains
the displaced existing dom.Page heap annotation diagnostic; restoring that
annotation makes all three focused files pass. The final commit additionally
preserves Source's clamped-volume leaf and explains the callback lifetime
boundary. The initial affected runs pass 35/36 in each GC mode and expose the older
synthetic-ID timer fixture. Follow-up b80844bb restores its scoped adapter
notification and strengthens that fixture to reject unrelated-document updates.
The two-file adapter check passes; both final full batches below verify the
committed correction.

| Retained run | Seconds | Result |
| --- | ---: | --- |
| Initial old-implementation baseline | 51.826 | 5 runtime failures; 2 failed files |
| Final old-implementation baseline | 53.334 | 6 runtime failures; 2 failed files |
| Initial focused compile | 64.083 | Heap annotation diagnostic; 3 failed files |
| Corrected focused batch | 71.885 | 3/3 files passed |
| Initial affected, default GC | 690.877 | 35/36 files passed; legacy timer failure |
| Initial affected, GC none | 678.353 | 35/36 files passed; legacy timer failure |
| Scoped legacy timer correction | 48.447 | 2/2 files passed |
| Final affected, default GC | 610.417 | 36/36 files passed |
| Final affected, GC none | 596.660 | 36/36 files passed |

The affected batch includes the 66-case main regression, previous media play,
pause, clock, seek, end, properties, started-audio and wake-lock tests, hidden
Window timers, Page/PageClient and compositor lifecycle records, native volume,
EventTarget/DOMException and SourceBuffer paths. Commands use
`-old-compiler -enable-globals` and `-gc none` for the second mode. Initial
runs use VJOBS=1; final affected batches use VJOBS=2. VTMP is
repository-owned, with its final compiler scratch linked to an isolated temporary
RAM volume after disk space falls to about 1 GB. Compiler TMPDIR likewise uses
that volume; signing and capture retain the normal system TMPDIR. The volume is
detached after verification. Each test manifest hashes all 4,924 tracked inputs,
37 Source references and both retained compiler executables before and after.
Production verification covers 60 Source references. No full LibJS, HTML or
Wasm sweep is claimed.

## Production and inventory

The clean committed b80844bb snapshot builds and ad-hoc signs the native
macOS production bundle with `-prod -gc none`. Strict/deep signature verification,
headless startup and an ordinary-branch production probe pass. The probe uses
real parsed media, the owning Page mute operation and existing native property
and pause bindings; it checks manager-volume and audible-state transitions,
duplicate suppression, wake-lock independence, current volume on unmute, no
invented volume events and explicit unregistration. It enters play through the
actual V caller. main.v and browserjs/media_element_host_darwin.c.v are unchanged.

The two prior public pause and script-created-pause viewports are pixel-exact:
both comparisons have zero differing pixels and zero maximum channel error.
These viewports verify those public paths, while the probe verifies Page mute.

Full native smoke verification is **incomplete**. The initial 10.776-second run
passes inline-node, ordered-list and text-decorations within their existing
upstream bounds, then both line-clamp-properties launches trap during graphics
initialization. Its initial inline-node launch also traps before a successful
retry. A separate 1.487-second recovery on the unchanged binary and input
snapshot traps on both initial inline-node launches and completes zero
comparisons. These are launch failures; no failing pixel comparison is observed.
Neither run completes the 11-case smoke set.

All five retained reports show EXC_BREAKPOINT/SIGTRAP with the libdispatch
semaphore-deallocated-while-in-use diagnostic. Their stacks pass through
_dispatch_semaphore_dispose, the ARC struct copy helper,
gg__gg_init_sokol_window and the MTKView draw path. This matches the earlier
screen-wake-lock batch's graphics startup failure, but this batch's recovery
does not succeed. Read-only inspection of the fallback gg/Sokol initialization
records the dependency hashes; the exact trigger remains unresolved and the
external compiler/dependency sources are unchanged. Do not treat the new media
slice as complete native startup or weak-owner parity.

Production artifacts live under Build/audit-fixes/media-page-mute-owner-production/;
recovery artifacts under media-page-mute-owner-smoke-recovery/; reports under
media-page-mute-launch-reports/. The consolidated evidence retains all commands,
logs, snapshots, compiler hashes, current binary hash and five crash reports.
The temporary compiler-only RAM volume was verified by device, name, mount point
and size, then detached; its repository scratch symlink was removed. Other RAM
volumes and all seven original untracked entries were preserved.

Consolidated evidence: Build/audit-fixes/media-page-mute-evidence.json;
SHA256 `ac4faffd6f10c5baf9a7e36ab9d71d1dedb04326153630d4dbb7eb205adfe1d9`.

Retained manifests (all under Build/audit-fixes/):

- media-page-mute-owner-frozen-baseline-manifest.json: `eb184e5a11b579d2bb5c6c5c20577cb66db26686b0247c8e2230c6422ebb524a`.
- media-page-mute-owner-frozen-baseline-final-manifest.json: `bceccd29b13331c6a7ab949f04d0bba8d4d748622f4eff8f45e9f0a043f40ddd`.
- media-page-mute-owner-frozen-focused-final-manifest.json: `495d42f5008fd42514e744629548468a56f1e323d43808047b3e68480d268d44`.
- media-page-mute-owner-frozen-focused-verified-manifest.json: `bfdfb2c75b2c2d6fd3582073c90d747f18c2211cc9f0d24560c36bb3d67e4d51`.
- media-page-mute-owner-frozen-focused-adapter-manifest.json: `8c610d50612b6c16e8949bf9ed4b5bbe95a17e661b7005aa4210af6131487e40`.
- media-page-mute-owner-frozen-default-manifest.json: `4903a53bfc895faa8cb6584ad9189eaab199a2fae25646e193111882a41b33ba`.
- media-page-mute-owner-frozen-gc-none-manifest.json: `49f17276249f5720817b90e1a4ece4ff6713db1adcbf6a5983559853b1f99dab`.
- media-page-mute-owner-frozen-default-fixed-manifest.json: `50de074d00f351309f9b09c5101ebdb96899fbbec11a17f38b7b16c8080d68de`.
- media-page-mute-owner-frozen-gc-none-fixed-manifest.json: `7e1428e6661b8f15db4bb326f78a7ea5804c9c7d6e54e58fc5a687ec43d1efaa`.
- media-page-mute-owner-production-manifest.json: `fbe2d47844bbe5fbee84c33dbb85061179c702128b6780c7d0e55dbef7b7b454`.
- media-page-mute-smoke-recovery-manifest.json: `a7263d796d2ef659d6d07a875d0c8bef87f7d09863944a14186efde36ece7efc`.

Production binary SHA256: `35c9d1eb61edcf2daf233ece1062df6ef92948682dd30682fb2266660eba946f`.
Launch failure record: media-page-mute-native-launch-failures.json;
SHA256 `3ed5bb5497ab36bc04e3298def3aabf0cf1d23550f6db2ea8a0aa0de02b90562`.
Compiler RAM cleanup: media-page-mute-ram-cleanup.json;
SHA256 `64cb6e8cc2382541832312f78787f82cba7b5c0696afab4b9d1c51c95bc2614d`.

Retained launch reports:

- Ladybird-2026-10-08-224313.ips: `271fc17aefab3b4a619ad6c098666dcf73b3a7590de3bb5c0f9aeebd8bd55121`.
- Ladybird-2026-10-08-224314.000.ips: `8df287b69d8ef558ea1c6dd55e0734bdbbdbe06ff343c5015fb43ef0a32aff4c`.
- Ladybird-2026-10-08-224314.ips: `4c085dd00f37437ae91b4e5da5bf1fdd810e089cdb360b989ebb6162b5f7ace6`.
- Ladybird-2026-10-08-224705.000.ips: `95ec22bbda0ad3770a3bd15c1a840ea6eecfe9b2de7b6f7465da539b4bd932b5`.
- Ladybird-2026-10-08-224705.ips: `736087aef542f61d3b32af41da4087fb16e98b7fd771dd42e95b17ed19584111`.

The 78-owner physical inventory contains 432,614 implementation / 156,375 test
V LOC across 2,196 owned files. One new HTML test and the corrected older
Window timer fixture contribute owned tests; implementation changes belong to
HTML, DOM and Page, including its media audibility query and legacy adapter.
Root/native support is excluded. Inventory:
Build/audit-fixes/source-current-module-loc-b80844bb.json;
SHA256 7fdbc96e795dcc72cbd4374e964d7ba4551bd855aa6f56f7047379844ae4c612.
LOC is not a parity measure. The ledger remains 32 fixed / 25 partial / 9 open
because broader runtime and ownership findings remain unresolved.

Implementation: [media](../../html/html_media_element.v),
[DOM Page bridge](../../dom/document.v), [Page](../../page/page.v),
[audibility query](../../page/composited_resource_lifecycle.v).
Tests: [model](../../html/media_page_mute_owner_test.v),
[native page](../../media/page_mute_owner_test.v).
[Prior wake-lock evidence](MEDIA_SCREEN_WAKE_LOCK_OWNER.md) retains its snapshot.

## Subsequent media CSS slice

The later [actual media CSS state slice](MEDIA_CSS_STATE_OWNER.md), implemented
in 32139bfc and corrected in 728faa99, addresses the selected CSS matching and
invalidation boundary left open by this Page-mute snapshot. Element `:muted`
remains independent of Page mute. Its unchanged 9101b5b7 verification snapshot
passes native production startup/probe, two media-state viewports and all 11
smoke cases. These later results do not replace this document's retained failed
launch attempts or claim their graphics initialization cause was fixed. The
weak-owner, native play, full media and physical transport boundaries remain open.
