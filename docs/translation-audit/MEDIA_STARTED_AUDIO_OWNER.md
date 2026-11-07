# Started playback and owning-page audio notifications

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and focused tests: `ee1714cc341a9b17dfb0ffb0d081361ec43e16b1`.

Waiting playback no longer reports audible output merely because paused became
false. The media owner now tracks whether playback has started, combines that
state with an enabled audio track and effective volume, and reports each actual
transition to the PageClient attached to its current Document before notifying
that Document's timer/lifecycle machinery.

## Source mapping and boundary

HTMLMediaElement.h:389 supplies the initially false started-playback field.
cpp:2893–2918 queues the existing playing task and captured promise batch, invokes
manager play, then sets started state and updates audio immediately. Its queued
event does not later restart audio. cpp:2921–2935 suppresses unchanged reports,
updates the remembered audible state, notifies the actual PageClient, and then
notifies Document. cpp:2948–2968 clears started state before manager pause and
updates audio after that hook, before the existing dimension/repaint path.
Transitioning to unpaused does not itself update audio. Same-value paused
assignments retain the Source early return.

cpp:2354–2366 re-evaluates audio after resource-specific tracks are removed and
before clearing the manager; it does not clear started state. The V failure
caller and later enabled-track replacement preserve that distinction. Existing
AudioTrackList removetrack delivery and playback-manager setup/teardown remain
separate translation boundaries.

The dom.Page bridge forwards a boolean state to its actual page.Page owner,
which calls the existing PageClient method with playing/paused transport labels.
Page.h:677 defines the Source enum-valued virtual. The V PageClient still records
this call through its existing embedder boundary; this change does not implement
IPC transport, native tab chrome, or physical audio output. The existing no-Page
and no-associated-element adapters remain available without synthesizing an owner.

Document.cpp:4817–4828 and Page.cpp:841–850 supply the document-audibility query
and Window timer notification. The V Page's existing media-ID registry and
Document lifecycle callbacks remain their explicit boundary. Active adoption
transfers document registry state without inventing PageClient transitions;
subsequent start/pause uses the element's current Document and Page.

Effective volume retains the existing per-media page-muted adapter. Actual
Page-wide mute propagation/lookup, manager callbacks and track membership checks,
CSS paused invalidation, screen wake locks, physical clock/decoder/pipeline
execution, public native play Promise creation and permission/error gates,
complete resource/fetch/ready-state algorithms, media/MSE and full GC/bindings
remain open. main.v and the native media host are unchanged; compact JavaScript
play retains its existing resolved-Promise stub. JavaScriptCore remains the
browser backend. This slice translates the selected started-state and audio
notification responsibilities, not all of notify-about-playing or set-paused.

## Focused verification

Six actual-DOM model cases and one actual native-page case verify waiting state,
immediate start before deferred event/promise delivery, manager start/stop hook
order, unconditional queued playing after pause without audio restart, balanced
mute/volume/track changes and duplicate suppression, reentrant pause-hook volume
changes, actual resource failure and track replacement, hidden-timer deadlines
and unchanged throttling grace, and routing after adoption between actual Pages.
The native case uses actual parsed audio owners and native volume/mute/pause
bindings and EventTarget listeners, including trusted target/currentTarget
identity, receiver isolation and balanced realm state. Playback enters through
the actual V caller; it does not replace the native JavaScript play stub.

Initial manifests retain Option/Result, TimerHandler and mutable-node fixture
compiler diagnostics, plus the unsupported audio/mp4 response fixture. The final
fixture uses the existing supported video/mp4 response adapter with a real audio
track. After those corrections all seven new cases fail at runtime on unchanged
old implementation bytes, without compiler errors. Final tests are byte-identical
to that retained runtime baseline. The initially failed focused run preserves the
remaining mutable-node diagnostic. Final focused verification passes all three
files, including the neighboring media fixture updated to enter through the
actual playing notification.

| Run | Exit code | Seconds |
| --- | ---: | ---: |
| baseline | 1 | 34.091 |
| baseline-corrected | 1 | 37.440 |
| baseline-final | 1 | 34.109 |
| focused-model | 1 | 19.871 |
| focused-final | 0 | 45.204 |
| default | 0 | 328.385 |
| gc-none | 0 | 318.073 |

Both full affected batches pass 27/27 files on clean committed ee1714cc,
including the 66-case main regression, prior play/pause/clock/seek/end/property
owners, native media/EventTarget/DOMException/SourceBuffer paths, actual hidden
Window timers, and Page/PageClient runtime neighbors. Commands use the retained
compiler dispatcher with -old-compiler -enable-globals, VJOBS=2 and an isolated
repository-owned VTMP; the second batch adds -gc none. All 4,918 tracked inputs,
29 Source references and both compiler executables remain unchanged during each
run. No full HTML, LibJS or Wasm sweep is claimed.

## Production and inventory

The same clean implementation snapshot builds and signs the native macOS bundle
with -prod -gc none, passes signature verification and --headless-smoke, and
passes the ordinary-branch production probe independent of V assertions. The
probe exercises actual V play, native property/pause/event bindings, waiting
silence, hook ordering, owning-client notifications, deferred captured promise
resolution, receiver isolation and balanced execution context.

Both prior public pause pages remain pixel-exact against their 800×600 references
with zero tolerances. They are compatibility checks; the new audio path is
verified by model/native tests and the production probe. All 11 canonical smoke
comparisons pass with unchanged bounds. The separate SVG mutation set is not
repeated because main.v and the native media host are unchanged. Production
retains 52 Source input/reference/font hashes, exact probe/page bytes, logs,
captures and artifact hashes, and its binary stays unchanged through capture.

Consolidated evidence: Build/audit-fixes/media-started-audio-evidence.json.
SHA256: `393176a04cc6898b9ac90eb4764ff141ce9f327577832c1a4e2cbe03e7e17dc6`.
Production binary SHA256: `d4cfa41d00b9df74ce0ca33a9a1d16ec0942b42f984051aae76e510ee9c4bece`.
baseline-final manifest SHA256: `9f9ff5a67d8eb4c09adee20565b00a85830f8af78c97dd93860f24eb8689324f`.
focused-final manifest SHA256: `19243d0ee35188c56da5922466e18f4076e70864f43535dc9c8360c2c8507a34`.
default manifest SHA256: `6ac72863486f9d3304d8e5a329f66ce10aa9d1abcd80801a314f20912b649dc7`.
gc-none manifest SHA256: `35b88c46d38921bce791afd5b47cb2d8616bbac07104728dfba3634d96141e75`.
production manifest SHA256: `6c90dc63e0183916ea888f38b96f8106ee314b76dbfa4474a37c86f19deee8ae`.

The 78-owner inventory contains 432,419 implementation / 155,923 test V LOC
across 2,194 owned files. New owned code is one HTML test; implementation changes
belong to HTML, DOM and Page, with the older media fixture updated. Root/native
support remains excluded. Inventory:
Build/audit-fixes/source-current-module-loc-ee1714cc.json;
SHA256 e891036b36164e94f22610d142695a3e1f4f77a31bf91e610423848c2548be83.
Physical LOC does not measure parity. The ledger stays 32 fixed / 25 partial /
9 open because wider runtime and ownership findings remain unresolved.

Implementation: [media](../../html/html_media_element.v),
[DOM Page bridge](../../dom/document.v), [Page owner](../../page/page.v).
Tests: [model](../../html/media_started_audio_owner_test.v),
[native page](../../media/started_audio_owner_test.v).
[Prior internal-play evidence](MEDIA_PLAY_TASK_OWNER.md) retains its earlier snapshot.

Follow-up: [media screen wake locks](MEDIA_SCREEN_WAKE_LOCK_OWNER.md) translates
the retained Page handle and selected lifecycle updates at `ca0036d2`. The
screen-wake-lock boundary above describes this document's earlier snapshot;
native power-management transport and automatic GC finalization remain open.
