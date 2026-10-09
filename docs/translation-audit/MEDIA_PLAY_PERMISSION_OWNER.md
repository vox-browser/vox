# Playback permission rejection at the actual V play caller

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and focused tests: `6520f81a`.
Test-only concrete removal fixture follow-up: `d624b8d3`.

The public V HTMLMediaElement.play() caller now rejects a denied request with a
typed NotAllowedError before checking unsupported media, appending its promise
or running internal play. Denied requests do not fetch, change paused/poster/
can-autoplay state, queue play tasks or disturb an earlier pending request.

## Source mapping and boundaries

HTML/HTMLMediaElement.cpp:614–639 checks is_allowed_to_play first and rejects
with a new NotAllowedError carrying the Source message. Only permitted calls
then check unsupported media, append the promise and enter play_element.
The V caller uses the previously completed live-Document permission predicate:
current Window sticky activation, current origin settings and effective volume.
The rejection is a WebIDL DOMException record carried through the existing DOM
promise value ABI. Each denied request receives its own exception record.

The existing V promise factory creates a model promise instead of accepting the
native promise passed into Source's binding. Native JavaScript play() promise
creation and rejection remain unported. Unsupported-source rejection retains
its existing string representation; this slice does not complete that separate
exception path. Source volume-change policy pause, enough-data autoplay timing,
full Permissions Policy, resource/readiness/seek, physical decoding and automatic
weak-node ownership remain open. Unassociated owners retain their compatibility
permission behavior. The browser uses JavaScriptCore.

## Focused regressions and fixture prerequisites

Four model cases use actual DOM audio/video owners. Audible requests under both
blocking policies reject before resource selection or manager start and leave
the original pending promise untouched. A separate case sets an unsupported
source error and verifies that permission rejection wins, creates distinct
exception records and leaves the older permitted unsupported-source adapter
unchanged. Adoption rejects a request in the blocked new Document despite an
allowlisted resource URL and activated old Window. Consumed activation on the
new Window retains sticky permission and allows explicit play even with the
automatic-features sandbox flag. An already-playing owner rejects a new denied
request while its earlier pending batch remains intact and later fulfills.

The native Page case invokes the actual V play caller, converts its reason
through the existing native DOMException bridge and checks class, name, code,
message and wrapper identity. Denial produces no native play events. A later
allowed request fulfills its model promise and delivers trusted play/playing
with the actual owner as this, target and currentTarget. Execution depths and
the VM context stack balance. This does not exercise a native JavaScript play()
promise binding.

Thirty-five existing task/state cases now explicitly select an allowed playback
policy and restore the previous policy/allowlist afterward. Their assertions
remain unchanged. This grants the prerequisite for testing internal task
ordering, CSS state, Page audio/mute, wake locks, reset, pause and removal without
fabricating Window activation or changing audibility. The concrete removal case
was missed in the first batch and is added in the separate test-only follow-up.
Standalone tests continue to exercise their existing compatibility behavior.

The initial HTML helper incorrectly propagated Option/Result values and failed
compilation. Both original logs are retained. After correcting the helper, both
files compile against unchanged parent implementation `a6c33582` and fail at
runtime. The model run reports a pending denied promise, then stops because its
expected NotAllowedError is absent; other model cases are not claimed as
independently observed baseline failures. The native case fails its denial
assertion. The identical corrected new test bytes then pass all five cases.

## Frozen verification

The first broad runs each observe ten passing files and the missing removal
fixture prerequisite, then are stopped before a summary/final manifest. Their
logs and interruption records are retained as partial evidence. Both complete
corrected recovery runs independently pass all 25 selected files on unchanged
`d624b8d3` code and tests. Coverage includes all changed fixture files, permission
and resource callers, settings, activation identity and the 66-case main
regression file. The complete repository suite was not run.

| Run | Result | Manifest under Build/audit-fixes | SHA256 |
| --- | --- | --- | --- |
| Initial baseline | HTML helper compiler errors; native denial fails | `media-play-permission-frozen-baseline-manifest.json` | `c18b9ca685d9f361830b4412b59d10de7ffeed58dce376f2c69a396ac94651b7` |
| Initial implementation check | HTML helper compiler errors; native case passes | `media-play-permission-frozen-focused-manifest.json` | `d83c1949c5861c4f8990b139cb0f9ccc92b3231b80088dda95d58082048805e4` |
| Corrected runtime baseline | Both files compile and fail at runtime | `media-play-permission-frozen-baseline-validated-manifest.json` | `6647e73fdadfb60ba1443072a293e673940ba63d8b62818bae62cdbeefc9c977` |
| Corrected focused implementation | 2/2 files, five cases pass | `media-play-permission-frozen-focused-validated-manifest.json` | `7ad50ccf594eeef7c3eb204ae454046a4797408aa8ae251506ef3d5fa4b6d846` |
| Concrete removal fixture | 1/1 file passes | `media-play-permission-frozen-focused-fixture-manifest.json` | `8172dee77486471bc59312e9c47486c90db2b838917bd9e826f147dceed933a4` |
| Complete default-GC recovery | 25/25 files pass | `media-play-permission-frozen-default-recovery-manifest.json` | `0b8f77e57d2a077b490df962b0cf3a3d8cfc42df58228726e00e9eb73700e3cf` |
| Complete GC-disabled recovery | 25/25 files pass | `media-play-permission-frozen-gc-none-recovery-manifest.json` | `98ecd2c0037e0276de4d263b411684c94255f1f0f4244cd9a0f17ff73e7a429a` |
| Retained native build | Bundle builds; initial GC-disabled probe fails to compile | `media-play-permission-production-validated-manifest.json` | `eeb893176fab57fd1ee46768a26383e054696c0722dfb93a628253f1341a6428` |
| Corrected native production | 12 steps pass, including all 11 smoke cases | `media-play-permission-production-final-manifest.json` | `b4a52076cb4990d078132650aa020849b7a5d279cbe336a9b0a601ffc26d242b` |

The first native attempt fails when the disk fills during build; its runner then
cannot write a final manifest. The interruption record and logs are retained,
without claiming equality of before/after snapshots. The next attempt builds
the bundle but its ordinary -prod -gc none probe requires explicit or blocks
when reading pointer-map entries. That compiler failure and probe are retained.
The corrected probe compiles and passes with checks active in production.

Final native verification uses the successful retained bundle build, checks its
binary hash before reuse, and passes strict codesign, headless startup, both
pixel-exact prior native-load viewports and all 11 canonical smoke cases with
their existing tolerances. The probe checks real DOM audio/video owners, denial
before fetching, typed/native exception identity, allowed model play and trusted
event delivery. Fetched media is synthetic; physical decoding is not verified.
The binary remains unchanged throughout final native verification, SHA256
`cdc59bba3a262d83ad4e5c1b19b39514302544f2265a3c56196d603da5b79264`.
No launch diagnostic report is generated.

Production snapshots use implementation commit `6520f81a`; only the removal test
changes afterward. Consolidation verifies that all other tracked file bytes,
including every implementation file, match the final complete test snapshot.
The final runtime implementation is therefore the same verified implementation.

Consolidated evidence: `Build/audit-fixes/media-play-permission-evidence.json`,
SHA256 `dc6997bc35a5b114304b5f0c8fa3f285505f1b58c919bbaf67d8c3a936bc2f46`.
Manifests retain commands, environment, toolchain/Source
hashes, logs, private inputs and before/after snapshots. Detached runners,
interrupted runs and earlier playback-policy evidence remain intact. Only this
slice's compiler scratch is removed.

Physical inventory: `Build/audit-fixes/source-current-module-loc-d624b8d3.json`,
SHA256 `f26193640ed60283db1ef79449a505027baa0c64675f3464bb2ad754bc8caf5c`.
The 78 owners contain 432,808 implementation
and 158,167 test V lines across 2,206 assigned files. Root/browser integration
tests are excluded. Physical LOC does not measure parity. The historical ledger
remains **32 fixed / 25 partial / 9 open**.
