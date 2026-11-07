# Media screen wake locks and retained Page ownership

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and focused tests: `ca0036d2ff32626042ed4b3f1e275246a8175a14`.

Eligible playing video now retains the actual ScreenWakeLockHandle supplied by
its current Document's Page. Playback, readiness, ended state and track changes
re-evaluate eligibility; pause, resource failure and explicit finalization
release only the media owner's handle. Adoption releases the old Page handle
and re-evaluates against the new Page. Multiple owners share the Page counter,
so its client receives acquired/released only at zero/nonzero transitions.

## Source mapping and selected boundary

HTMLMediaElement.h:428 retains an Optional ScreenWakeLockHandle. cpp:1720–1742
requires an actual video element, a selected video track, an enabled audio track
and potentially-playing state. It does not depend on effective volume or the
has-started-playback flag. Audio elements and videos without either track role
cannot acquire a lock; muted or zero-volume video can still acquire one.
cpp:3025–3058 supplies the same readiness/paused/ended predicate, retaining
Source's stopped-due-to-errors and paused-for-user/in-band FIXME boundaries.

cpp:2640–2696 calls set_paused(false) before notify_about_playing. For high-ready
video the lock is therefore acquired before manager play and the later audio
notification. For waiting video the lock remains absent until future data;
notify_about_playing at cpp:2893–2918 starts the manager, updates audible state,
then updates the lock. cpp:2948–2968 pauses the manager and updates audio before
releasing the lock and updating dimensions/repaint. A later queued playing event
neither acquires a lock nor restarts audible state. Same-value paused/ended
assignments keep their Source early returns.

Selected calls also map cpp:2380–2388's ready-state scope guard after ended-state
processing, cpp:2971–2979's ended setter, cpp:1775's audio-track callback,
cpp:1877's video-track callback, cpp:2366's resource-track cleanup,
cpp:366–368's adoption transfer and cpp:201's finalization release. Source
adoption clears and recreates a held handle even between documents on the same
Page; the implementation and test preserve that behavior.

The previously inert on-video-track-added selection callback now reaches the
actual media owner, enabling live VideoTrack.set_selected changes to re-evaluate
the lease and update the retained selected sink. Existing explicit follow-up
calls are removed so automatic selection reaches the manager adapter once.
VideoTrack.cpp:47–79 supplies the selection-to-media handoff. Actual manager
membership/early-return gates, video-sink/decoder transport and queued TrackList
change/add/remove events remain their existing translation boundaries. In
particular, AudioTrackList's current clear-before-disable/removetrack behavior
and VideoTrackList's detach-before-deselect behavior are unchanged; this slice
does not claim full list-clearing or manager teardown parity.

The DOM Page callback creates the existing concrete page.ScreenWakeLockHandle
on its actual Page target and returns that retained handle through the existing
opaque DOM/package boundary. No top-level or per-model fallback Page is created.
No-associated-element, no-Page and unconfigured dom.Page adapters acquire no
handle. ScreenWakeLockHandle.cpp:11–30 acquires/releases the retained Page and
visits its GC edge. The translated explicit release/finalize API retains the
Page and its existing idempotent release guard. The new media finalize entry
translates its selected handle-clear responsibility only; remaining Base,
manager/timer/control/registry finalization and physical collector dispatch stay
open. No automatic GC finalizer or native power-management transport is claimed.
Page client notifications still cross its existing recorded embedder boundary.

Actual Page-wide mute propagation, public native play Promise creation and
permission/error gates, complete media resource/fetch/ready-state algorithms,
physical clock/decoder/pipeline execution, media/MSE and complete bindings/GC
remain open. main.v and the native media host are unchanged; compact JavaScript
play retains its resolved-Promise stub. JavaScriptCore remains the browser
backend. The selected predicate, retained Page handle and lifecycle update calls
are translated without claiming completion of their enclosing algorithms.

## Focused verification

Five actual-DOM model cases and one native page case check acquisition timing
before manager play on high-ready media, waiting/future-data transitions,
manager/audio/pause ordering, queued playing after pause, video and both track
roles, muted/zero-volume eligibility, audio-track toggles, actual selected-video
callbacks and switching, buffering and ended state, duplicate suppression,
shared Page ownership, resource failure/load reset, cross-Page adoption and
same-Page clear/reacquire semantics. The native case uses actual parsed video
owners and native volume/mute/pause bindings, verifies other-owner isolation,
trusted EventTarget receiver/target/currentTarget identity, deferred pause events
and balanced realm state. It enters playback through the real V caller.

A further focused case in html_media_element_test.v checks explicit finalization
with another active handle on the same Page, repeated release, and a real
standalone media element attached to an unconfigured dom.Page. This new finalize
API case is verified after implementation; the six other final cases reproduce
runtime failures on unchanged old implementation bytes without compiler errors.
The final baseline retains byte-identical model/native test copies.

The initial focused run passes native and older media/finalization files but
catches an incorrect new fixture assumption: manager play observes an already
acquired lock for high-ready video. Reviewing the actual internal-play caller
corrects only that expectation and the acquired-before-audio sequence. The
failed focused manifest and original baseline remain retained. The corrected
focused run passes all three files without implementation changes.

| Run | Exit code | Seconds |
| --- | ---: | ---: |
| baseline | 1 | 26.696 |
| baseline-final | 1 | 31.513 |
| focused-final | 1 | 56.617 |
| focused-verified | 0 | 105.761 |
| default | 0 | 908.331 |
| gc-none | 0 | 872.506 |
| smoke-recovery | 0 | 97.848 |

Both affected batches pass 31/31 files on clean committed ca0036d2, including
the 66-case main regression, previous play/pause/clock/seek/end/property owners,
started-audio and actual hidden timers, media tracks and video/control models,
Page/PageClient runtime neighbors, and native media/EventTarget/DOMException/
SourceBuffer paths. Commands use the retained compiler dispatcher with
-old-compiler -enable-globals, VJOBS=2 and isolated repository-owned VTMP;
the second batch adds -gc none. All 4,921 tracked inputs, 37 Source references and
both compiler executables remain unchanged during each run. No full HTML,
LibJS or Wasm sweep is claimed.

## Production and inventory

The same clean implementation snapshot builds and signs the macOS bundle with
-prod -gc none, passes signature verification and --headless-smoke, and passes
the ordinary-branch production probe independent of V assertions. The probe uses
actual DOM/fetch/V-play/native property/pause/event callers, checks acquired
state at manager start, two retained owners, muted-volume eligibility, immediate
per-owner release before deferred events, captured fulfillment, explicit
finalization while another handle remains active and balanced realm state.
Native JavaScript play Promise creation is not substituted.

Both prior public pause pages remain pixel-exact against their 800×600 references
with zero tolerances. These are compatibility checks; model/native cases and
the production probe exercise the new wake-lock path. The initial smoke run
passes inline-node, then stops when both ordered-list launch attempts trap in
native window initialization. Both retained crash reports identify SIGTRAP and
libdispatch's semaphore-disposal failure, with gg__gg_init_sokol_window and
MTKView draw frames. The reports, failed manifest, log and partial screenshots
remain intact; this media slice does not repair that existing intermittent
AppKit/Metal initialization issue.

After both test compilers finish, a separate recovery run on the same committed
snapshot and unchanged production binary passes all 11 canonical smoke
comparisons with unchanged bounds. Its manifest and screenshots use separate
paths. The separate SVG mutation set is not repeated because main.v and the
native media host are unchanged. Production retains 60 Source input/reference/
font hashes, exact probe/page bytes, logs, captures and artifact hashes; the
binary remains unchanged through both capture runs.

Consolidated evidence: Build/audit-fixes/media-screen-wake-evidence.json.
SHA256: `3c1f42f55ea82829adde174f240c8f5f1be847c74663b4d0b783e69dd7e37ac1`.
Production binary SHA256: `5dc663eb74032fd4cd61dfaa1b432e4a21558eccdc60a82e04d1ba381c36eca5`.
baseline manifest SHA256: `a7d727f2c8bfb8ec945bd27f6343e706e60a32709b266d4ff76e2a24db37854d`.
baseline-final manifest SHA256: `3acf8486fe8be8c5b68879532a0b8a3699ae9b7fad242d0b2652f57638f5469d`.
focused-final manifest SHA256: `a7d24affa115402f9bb36ed6f09789a7627a91e3ab393ee4058ba6d38eba5657`.
focused-verified manifest SHA256: `7b9694bc502f74e2b31e2321b8be780b4d0bafe15dee796270594bba181962ca`.
default manifest SHA256: `a417db61c8e9cc85a00921925613d783bd412fbbde9093b19eaff876c458c36f`.
gc-none manifest SHA256: `5b57bbe039bcc7dd96b06615a1d84daad36d8701c1dfbd6fe64e4d9e8c13430a`.
production manifest SHA256: `5e76657da3d98e5370b40d5e30c4511481f68b637c829661cb574da208b15ccc`.
smoke-recovery manifest SHA256: `dcd5a8eda65a77639957c6727eefc5cb87c7ec5734060b30e41851a00bc88bad`.

Retained launch reports:

- Build/audit-fixes/media-screen-wake-launch-reports/Ladybird-2026-10-08-141704.000.ips; SHA256 `61e590d991e5e4c2c5e31da1a6abff1d352ce12e971172c834696f6bfd231fe1`.
- Build/audit-fixes/media-screen-wake-launch-reports/Ladybird-2026-10-08-141704.ips; SHA256 `2aa269f4ccf26975315752f1e78c073e8072037938caa485bcbb31d1b32c19eb`.

The 78-owner inventory contains 432,494 implementation / 156,144 test V LOC
across 2,195 owned files. One new HTML test and the older media fixture contribute
owned tests; implementation changes belong to HTML, DOM and Page, including its
existing retained handle. Root/native support remains excluded. Inventory:
Build/audit-fixes/source-current-module-loc-ca0036d2.json;
SHA256 e561d847079643bb05f05a9da59133fbb6051e8153bcca058706967864b41e9c.
Physical LOC does not measure parity. The ledger stays 32 fixed / 25 partial /
9 open because broader runtime and ownership findings remain unresolved.

Implementation: [media](../../html/html_media_element.v),
[DOM Page bridge](../../dom/document.v), [Page owner](../../page/page.v),
[retained handle](../../page/screen_wake_lock_handle.v).
Tests: [model](../../html/media_screen_wake_lock_owner_test.v),
[finalization](../../html/html_media_element_test.v),
[native page](../../media/screen_wake_lock_owner_test.v).
[Prior started-audio evidence](MEDIA_STARTED_AUDIO_OWNER.md) retains its snapshot.

Follow-up: [Page mute and actual media ownership](MEDIA_PAGE_MUTE_OWNER.md)
translates the selected Page mute propagation that was open at this snapshot.
Its final 36-file batches pass in both GC modes, production startup/probe and
two exact public pause viewports pass, but its native smoke run and unchanged-
binary recovery remain incomplete after five graphics initialization traps.
This earlier document's successful 11-case recovery remains historical evidence
for its own snapshot.
