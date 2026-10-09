# Volume-change playback policy on the actual media owner

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and six focused cases: `46701a87`.

HTMLMediaElement.volume_or_muted_attribute_changed now queues volumechange,
checks the owner's live playback permission and runs internal pause when denied,
then updates effective volume and audio play state. This translates
HTML/HTMLMediaElement.cpp:695–713. Native volume/muted setters already enter this
helper through their actual DOM media owner; no binding implementation changes.

The existing internal pause steps disable can-autoplay even when already paused.
They avoid public pause's empty-network resource selection. For playing media,
the manager pause and paused state precede the volume update; played ranges and
official position commit synchronously. The volumechange task precedes the
existing timeupdate/pause task, which rejects its captured model promise batch
with one typed AbortError after both events. Native conversion preserves the
exception record and wrapper identity. Permission uses the current Document's
Window sticky activation, origin settings and effective volume. The separate
Page mute callback remains update-only, including Page unmute that makes media
audible. Unchanged or invalid setters do not enter the helper.

## Focused regressions and retained failures

Five model cases use actual DOM owners. Audio/video plus both volume and unmute
transitions check synchronous manager ordering, played range, deferred trusted
owner events, task Document/source identity and shared typed promise rejection.
Blocked changes on paused empty owners clear can-autoplay without fetching or
queuing a pause event. Allowed policy, origin allowlisting and consumed sticky
activation preserve playback. Actual Page mute is consulted; Page unmute and
unchanged/invalid values retain their distinct behavior. Adoption uses the new
Document rather than the old sticky Window. A native Page case reaches the
actual setter, observes synchronous paused state, ordered trusted event identity
and typed shared model rejection with balanced execution contexts.

The initial native fixture accessed a private field and did not compile. The
initial model played-range fixture omitted official clock delivery. After those
corrections, the native fixture initialized its runtime twice and failed before
reaching the setter. These logs are retained and are not treated as native
behavior baselines. The final model baseline supplies explicit official clock
samples; four independent assertions fail against unchanged parent a182f4e4.
Its permitted-policy control does not fail. The corrected native baseline uses
one initialization and fails the setter's synchronous paused-getter assertion.
Each final baseline test file has the same bytes as the passing final tests.

One focused runner disappeared after resumed user input, without a summary or
final manifest. Its before snapshot and partial logs are preserved in
media-volume-policy-focused-validated-interruption.json; the exact termination
signal was not observed and no completed/equality result is claimed for it.
The final corrected two-file run passes all six cases.

## Frozen verification

The initial default-GC batch passes 20/21 files; its old audibility fixture
expects unmute to restore audio without granting playback permission. The
test-only follow-up `1221f3da` grants an allowed policy, restores it afterward
and keeps every assertion unchanged. Both complete selected runs then pass
21/21 files on unchanged `1221f3da` code and tests. All implementation bytes
remain identical to `46701a87`. The selected files cover existing volume tasks,
pause batching/reentrancy, Page mute/audio state,
wake locks, CSS state, permission/resource callers, adoption, native bridges,
settings/activation and the 66-case main regression. Two additional existing
native volume-property files pass in each GC mode on that same snapshot,
covering receiver checks, conversion, native errors and queued owner events.
The full repository, LibJS and Wasm suites were not run for this bounded slice.

| Run | Manifest under Build/audit-fixes | SHA256 |
| --- | --- | --- |
| Initial baseline: model failures; native compiler error | `media-volume-policy-baseline-manifest.json` | `11e8bd92c584f95dd721f9b2ca87d1597627eec4888a59c0f69b60845058891e` |
| Initial check: clock fixture/native compiler failures | `media-volume-policy-focused-manifest.json` | `8c4ede566d4eff78b8c5f566e10a823f0a9edcea1664c0d76e67118c47d5f71d` |
| Model runtime failures; duplicate native initialization | `media-volume-policy-baseline-validated-manifest.json` | `f1f349adf791b62244cb21e935e7487e440b5a1e32c845be7f56f422fb6a82cb` |
| Final model baseline: four failures; old native fixture failure | `media-volume-policy-baseline-clock-manifest.json` | `2c6614aef4b6e2dc2bde10b69b7de46cb958414ebfb85564cac28ded4854ce81` |
| Five model cases pass; old native fixture fails | `media-volume-policy-focused-recovery-manifest.json` | `ea4b81cb6d6925bfcedc17591718f1da87283293098c31ba9830a6357e23e5e8` |
| Corrected native baseline: synchronous getter fails | `media-volume-policy-baseline-native-manifest.json` | `bedc627f319a339529d4139619991d59280b518953dbc6cc94fe6e9b5515f38b` |
| Six corrected cases pass, 2/2 files | `media-volume-policy-focused-final-manifest.json` | `fb0575f1f8adb460ace5a2cbccfc638670cf971d602bbce0a6515c372c7ca007` |
| Permitted audibility fixture passes, 1/1 file | `media-volume-policy-focused-fixture-manifest.json` | `14e36e853a7fd737df6e8b0f7bf25d8268f8f084eceab99c835afdbf8e95bcea` |
| Initial batch: 20/21; audibility prerequisite fails | `media-volume-policy-default-manifest.json` | `394c2aa1fa599209f85bb3a221e60b9f8de5448d608411df1eb71f3e13a0052c` |
| Complete recovery: 21/21, default GC | `media-volume-policy-default-recovery-manifest.json` | `9602dfa9d4914e032068b2379dd3fb48edc1c8c21421f69892a052d72d25a72b` |
| 21/21 files pass, GC disabled | `media-volume-policy-gc-none-manifest.json` | `6012e287f98461d5c9e7ece0e431b5c79435a746c631d435537cd4d55595067c` |
| Existing native volume properties, 2/2 default GC | `media-volume-policy-default-native-neighbors-manifest.json` | `cf76eb8d4062806cf3866652dba3a5b96242424f3f74099042cc25fb3e3fdb4c` |
| Existing native volume properties, 2/2 GC disabled | `media-volume-policy-gc-none-native-neighbors-manifest.json` | `9e9ebf137a1c18e297544cee7c8836c811bd61fae7c8ad693d2d389363973209` |
| 12 steps pass, including 11 smoke cases | `media-volume-policy-production-manifest.json` | `a85164562d3d4235d2fb8fe510452fef5eeb5574aa89ed8beb745d7c6e7a17ac` |

The ordinary production probe builds with -prod -gc none and keeps its require
checks active. It exercises native volume and muted setters on real DOM audio
and video owners, deferred trusted events, shared model rejection, native
DOMException identity and balanced contexts. Fetched media is synthetic; this
does not verify physical decoding or a native JavaScript play promise binding.

The native bundle builds and passes strict codesign, headless startup, both
pixel-exact prior load viewports and all 11 canonical smoke cases with their
existing tolerances. Binary SHA256: `d6dfbadacac3a00c2f68bbfc918ed967f213be3f21853f773412b8f97408262e`.
The same binary remains unchanged throughout production verification.
Manifests retain any launch diagnostics and all inputs, logs, Source/toolchain
hashes and before/after snapshots. Prior playback-permission evidence is intact.

Consolidated evidence: Build/audit-fixes/media-volume-policy-evidence.json,
SHA256 `8b80b01f7c52dbb98984adc54736e27aa281f63431fdd34afd76ba76299e1c39`.
Physical inventory: Build/audit-fixes/source-current-module-loc-1221f3da.json,
SHA256 `3209338a68e497f7321754606365396bdf538e65578d857d68834223c454703b`.
Across 78 owners and 2,207 assigned files,
there are 432,811 implementation and 158,409 test V lines; HTML has 69,616 and
39,892 respectively. Root/browser integration tests are excluded. LOC and
source-unit mappings do not measure parity.

Native JavaScript play promise creation/rejection, unsupported-source typed
rejection, complete enough-data autoplay, Permissions Policy, resource/readiness/
seek algorithms, physical manager/decoding and automatic weak ownership remain
open. Standalone unassociated media keeps its compatibility permission behavior.
The browser uses JavaScriptCore. The historical ledger remains
**32 fixed / 25 partial / 9 open**.
