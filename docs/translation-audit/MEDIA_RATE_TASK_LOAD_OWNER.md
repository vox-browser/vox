# Media rate setters and load reset

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Rate implementation/tests: `96a8c005ece0b8106ca5e43a948a552ac20d4a11`.
Load caller implementation/tests: `9dbdb6f52d0554419a1f0b0114c23e90be4d54c0`.

Default and current playback-rate changes now queue ratechange through the
owning media task. Current-rate validation accepts Source's finite range from
0 to 64 inclusive and rejects unsupported values before changing state or
queuing an event. Field assignment remains immediate, even when equality
suppresses an event, preserving the sign of zero.

The explicit and automatic load paths reset the current rate through the
validated setter. Loading removes the owner's old tasks first, then queues a
rate event only if the reset changes its value. An unsupported default rate
propagates the setter error before resource selection. This is the selected
load step-8 caller fix; the remainder of the existing load algorithm is not
certified as a complete Source translation.

## Source boundary and cases

Pinned HTMLMediaElement.cpp:2980–3021 queues ratechange before assigning the
new default/current value. The default setter performs no internal range
validation; playbackRate rejects non-finite, negative and greater-than-64
values. Load calls that setter with defaultPlaybackRate and propagates failure
before selecting a resource. The V caller now follows those selected branches.
Internal default NaN/Infinity tests bypass native double conversion; they do
not claim those values are accepted by native WebIDL setters.

Six rate model cases cover live values after microtasks, accepted boundaries
and unchanged/invalid inputs, equal signed-zero assignments, the existing
compatibility advance_playback clock, listener non-reentrancy and actual
document/task ownership. The inactive case extracts and directly executes a
task only to verify its negative guard; positive delivery uses the real loop.
The clock case proves the existing V compatibility path responds to accepted
rates, including zero. It does not prove Source pipeline consumption.

One native wrapper case uses an actual navigation Document and its existing
Window, actual DOM audio/video models and native EventTarget callbacks. Model
setters queue three trusted rate events with the correct this/target/currentTarget,
branding, flags, unrelated-owner isolation and currentTarget cleanup. No
callback runs synchronously or at a microtask checkpoint. Realm and VM depths
balance afterward. The test drives V setters; native rate property operations
remain unexposed by this slice.

Three load cases cover canceled old events versus the newly queued reset,
unrelated owners, equal-value no-ops, automatic load, and unsupported default
values propagating before the actual existing fetch hook is called.

Source also forwards every accepted playbackRate assignment to an existing
PlaybackManager, including unchanged values and paused media. PlaybackManager
then updates its clock and pipeline. V has no equivalent actual manager;
this tail remains unimplemented and is explicitly marked in the setter.
No new synthetic manager or rate hook is offered as evidence of that runtime.

## Executed verification

Both rate baseline files execute runtime failures: synchronous delivery,
unsupported valid rates, lost signed-zero assignment, recursive listener
delivery and the missing queued task. All six model cases execute; no fixture
compilation error is used as baseline evidence. After the rate commit, the
separate load baseline executes all three caller failures. Failed and passing
logs/manifests and exact private baseline input bytes are retained.

| Run and result | Seconds |
| --- | ---: |
| Rate baseline: both files fail at runtime | 70.458 |
| Rate focused: 3/3 pass | 101.881 |
| Load baseline: all three caller cases fail | 43.106 |
| Load focused: 2/2 pass | 55.055 |
| Frozen default: 23/23 pass | 1511.310 |
| Frozen gc-none: 23/23 pass | 1472.038 |

Commands use `/Users/alex/code/v/v -old-compiler -enable-globals`, VJOBS=2;
the second broad batch adds `-gc none`. Both final batches pass all 23 selected
files on the same clean, committed `9dbdb6f5` snapshot, including
all ten new cases, the 66-case main regression, native media state/completion/
duration neighbors, adoption, seeking, step-1 scheduling and MediaSource/
SourceBuffer neighbors. All 4,886 tracked files, six Source
references and both compiler executables remain unchanged through each run.
Feature hashes match their separate commits. This is an affected-file batch,
not a full HTML, LibJS or Wasm sweep.

## Production checks

The same snapshot builds the macOS bundle with
`-old-compiler -enable-globals -prod -gc none` in 1177.146 seconds.
A separate rate probe compiles with those production flags in
396.013 seconds. Its setters, loop processing and explicit
failure branches execute outside removable assertions. It uses an actual
active navigation Document and DOM audio owner to verify deferred/live rate
events, trusted target/currentTarget, range and signed-zero behavior, load reset
and invalid-load propagation. Its input hash is frozen alongside the production
snapshot. This probe proves selected V model/caller execution with assertions
stripped; it does not expose native rate setters or implement a decoder.

Bundle signature verification and --headless-smoke pass. The existing public
MediaSource duration-task page still matches all 480,000 pixels with zero
tolerances. It is a duration/owner regression, not a public rate-operation
proof. All 11 configured smoke screenshots pass; eight are pixel-exact.
The three previous residuals remain identical: inline-node 13 differing pixels
(maximum channel error 1), text-decorations 1,341 (2), canvas-text 1,994 (8).
No tolerance changes. The earlier 13 SVG mutation pairs are not rerun because
main.v, the native media host and EventTarget bridge remain unchanged from the
previous verified snapshot.

Production retains 31 Source inputs/references/font
files, both compilers, the probe input and output binary, generated page and
screenshot/log hashes, and an unchanged signed browser binary.

Binary SHA256: `a8414bb7f1405ac4995e22e11f6d2ed2ed0d9318e9c62d3cb2aa4116e48b6224`.
Production manifest SHA256: `8a5957127f0320232d55e9d753f7bfad09567f9db106cb40ba3c2837d3f5de92`.
Default manifest SHA256: `5bf0ee0754b8e1fea5ab67f67c4652ea22b18eb2794f1be3c40de5499e9db0c2`.
GC-none manifest SHA256: `83da4d1f2c8658eb2909efc1fcdb0f3d55112450032159a15aa1de95f675eaba`.
Consolidated evidence: `Build/audit-fixes/media-rate-tasks-evidence.json`.
SHA256: `d92b1af6e20570600088ed2dd8e5f0c4f7ec74bf984494cc8438abcda4802992`.
Private manifests/logs use the media-rate-tasks prefix; production artifacts
are under Build/audit-fixes/media-rate-tasks-production/.

## Remaining scope

Actual PlaybackManager rate/clock/pipeline delivery and decoder Ended state,
native defaultPlaybackRate/playbackRate and other media property operations,
native conversion/DOMException fidelity, autoplay-policy pause, muted-style
invalidation, other event scheduling, full load/MSE algorithms, native play
promises, ordinary compact listeners, unique task sources, full prototypes,
foreign realms, WrapperWorlds, IPC and physical GC remain open. The browser
uses JavaScriptCore.

Implementation: [media lifecycle](../../html/html_media_element.v).
Focused tests: [rate model](../../html/media_rate_task_owner_test.v),
[native target](../../browserjs/media_rate_task_owner_test.v),
[load caller](../../html/media_load_rate_owner_test.v).
[Duration/volume evidence](MEDIA_PROPERTY_TASK_OWNER.md) records the preceding
slice and its historical snapshot.

The 78-owner physical inventory contains
432,331 implementation /
154,721 test V LOC across 2,187
owned files. Browser/root support is excluded. Counts do not measure parity;
the ledger remains 32 fixed / 25 partial / 9 open.
