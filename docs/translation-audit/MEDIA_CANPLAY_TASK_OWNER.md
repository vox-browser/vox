# Canplay notification from the actual media readiness owner

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and focused tests: `f3fde94f`.

A nonempty-network media owner now queues canplay when readiness crosses from
HAVE_CURRENT_DATA or less into HAVE_FUTURE_DATA or HAVE_ENOUGH_DATA. It captures
its current pending play batch immediately, before queued listeners can call
play(). First-data delivery precedes canplay, and the captured playing task
follows it. Readiness and playback-manager state commit before event delivery;
listeners read the live media state.

## Source mapping and boundaries

HTML/HTMLMediaElement.cpp:2374–2475 defines the immediate state/style update,
network gate, metadata and first-data branches, and the selected canplay branches.
Source queues canplay and immediately calls notify_about_playing when unpaused.
The V implementation applies these exact network and old/new state guards to
canplay and its readiness-driven playing notification. It retains the existing
ended-state, wake-lock, natural-dimension and style updates. This slice does not
apply Source's global network gate to the remaining readiness adapters.

Canplay has no per-load suppression flag. Unchanged future/enough states,
future-to-enough and enough-to-future do not repeat it. A later current-or-less
to future/enough crossing queues another event. A direct nothing-to-future/enough
crossing queues canplay without fabricating a metadata event. NETWORK_EMPTY
still commits readiness and style state without canplay or notify_about_playing.

The existing owner queue records its task source and Document. Reload cancels
only that media owner's pending event. Tasks queued after adoption use the new
Document; inactive delivery is discarded, and repeating the unchanged state
after reactivation does not reschedule it. Automatic weak-node ownership and GC
finalization remain open.

Source HTMLMediaElement.cpp:2893–2920 and the existing V notify_about_playing
take the original pending promises and playback start position before listeners
run. They queue playing with that captured batch and position, then immediately
start the manager and update the existing started/audible state. A promise created by a
canplay listener is handled by its own later task, even if the manager clock
has advanced. This does not complete public native play promises: the compact
native play operation retains its prior resolved-promise adapter. The browser
still uses JavaScriptCore.

Canplaythrough, the buffering-drop waiting adapter and full enough-data/autoplay
behavior remain unfinished. Complete load/reset/readiness/seek algorithms,
resource timing, permissions, physical decoder/playback integration and native
play promises remain open. Existing synchronous fetch/metadata adapters and
synthetic readiness transitions do not establish physical decoding.

## Focused evidence

Five model cases cover the exact transition across all four network states,
unchanged and direct-jump gates, first-data-before-canplay ordering, live state
at delivery, trusted target/currentTarget identity, owner task source/Document,
microtask versus task timing, captured pending promises and start position,
manager start before listeners, owner-specific reload cancellation, repeated
crossings, adoption and inactive delivery. Both future and enough destinations
are exercised.

A native page case calls actual audio/video load(), uses native live getters and
EventTarget.prototype.addEventListener, verifies trusted wrapper identity and
non-bubbling/non-cancelable flags, then checks reload cancellation and balanced
execution contexts. The ordinary production probe additionally crosses video
to future and audio to enough before both owners oscillate back to current data.
These listeners exercise the actual DOM binding; the compact bridge's prior
ready-video fallback remains unchanged.

The seventh new case appends real minimal WebM initialization and coded-frame
segments through a SourceBuffer attached to a concrete DOM video owner. The
append task reaches future data with a selected video track. The owner's queued
loadeddata arrives before canplay; another append without a readiness crossing
does not repeat either notification. SourceBuffer.cpp, SourceBufferProcessor.cpp,
WebMByteStreamParser.cpp and MediaSource.cpp are frozen caller references.

All three baseline files compile against unchanged e66b656b and expose the seven
new cases at runtime. The original implementation fires canplay synchronously,
violates first-data ordering and lets the listener observe an uncaptured pending
batch; the inactive owner case cannot find its missing task. The same new test
bytes pass after the translation. Existing first-data and playing-task fixtures
now account for the legitimate additional canplay task while retaining their
original assertions about once-per-load data and captured promise batches.

## Retained verification

Both final neighbor runs pass all 36 affected files on unchanged committed
implementation and test bytes, including the 66-case main regression. Each is
one complete frozen run; neither uses a recovery composite. The tests use
-old-compiler -enable-globals, with -gc none for heap-ownership coverage. Single-job
runs bound compilation pressure. Every run retains its command, environment,
log, before/after tracked-tree hashes, Source references and compiler hashes.

| Run | Result | Manifest SHA256 |
| --- | --- | --- |
| Validated runtime baseline | 3 files fail after compiling | `4cc71182740b732b7feabb7b43dad2cb981d84342862e026e0b68bcb8fed88d8` |
| Focused canplay/data/play callers | 5 files pass | `a7d93abe03b46b6350aabc18ed84c4c74453cf6d374f1a74450710c13ea780e8` |
| Default-GC neighbors | 36 files pass | `a8641f03052287906f0673def1f82f09a7e2d3e055817f1d7f77d502f0c9e718` |
| GC-disabled neighbors | 36 files pass | `7ac52dbe0ccc52c6bc692bb971f85dfe9fbb0cd1316b2b4e90781cb07e296e46` |
| Production build/probe/captures | Probe/startup/viewports and 11 smoke cases pass | `128220c35398d5315644cc24a2374e46fe5a3b047140135fb9c9280f882e4ced` |

The ordinary production probe compiles with -prod -gc none independently of test
branches and passes through actual audio/video native bindings. The signed
bundle passes non-windowed startup. Both prior load regression viewports match
their green reference exactly, and all eleven canonical smoke comparisons pass
under the repository's per-case pixel tolerances on the unchanged binary. No new
browser launch diagnostic reports were recorded.

The two captured viewports exercise earlier native-load and load-rate-task
regressions against an exact green reference. They are not screenshots of a new
physical canplay decode. Logs, frozen input/reference hashes, production probe
source, compiled probe and comparison artifacts remain under the
Build/audit-fixes/media-canplay-task prefixes.

Consolidated evidence: `Build/audit-fixes/media-canplay-task-evidence.json`, SHA256
`7e897a58d775946503d6000bee28e47e16e1973f9f9acdacf59d9561a78f5616`.
Production binary SHA256: `720c5a08eae7c08c9246c2db52863927369fafe015ede44a24ee3c87e3723ce2`.

Physical inventory: `Build/audit-fixes/source-current-module-loc-f3fde94f.json`,
SHA256 `203006055cae9788e94ada2629301dba08249212699fefdeed2e240121fff0c2`.
Its 78 owners contain 432,777 implementation and 157,346 test V lines across
2,202 assigned files. The root native caller test is excluded from these package
counts. Physical counts do not measure parity; the historical ledger stays
**32 fixed / 25 partial / 9 open**.
