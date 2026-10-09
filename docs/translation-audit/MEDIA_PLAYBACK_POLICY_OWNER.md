# Live document playback permission for resource autoplay

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and focused tests: `066d31b8`.

Resource autoplay now checks the current Document's playback permission as well
as its autoplay eligibility. Audible media under the default block-audio policy
stays paused. Muted, zero-volume and page-muted media can autoplay under that
policy; block-all still prevents them. An activated owning Window or an allowed
current Document origin permits playback. Explicit load() still fetches blocked
media without automatically starting it.

## Source mapping and scope

HTML/HTMLMediaElement.cpp:3081–3100 first checks the Document Window's sticky
activation, then AutoplaySettings.decision_for_origin using that Document and
its origin. Allowed returns true, AllowedIfInaudible requires effective volume
zero, and Blocked returns false. The translated owner now follows that order.
Consumed transient activation retains sticky permission. The existing settings
translation supplies origin allowlisting and the opaque-file exception.
Effective volume includes the actual owning Page's mute state.

The preload-none deferral caller at Source:1320–1336 now requires both eligible
for autoplay and allowed to play to bypass deferral. The existing V fetched-media
autoplay caller consumes the same conjunction. Adoption re-reads the current
Document origin and Window rather than the selected resource URL or former
Document. The automatic-features sandbox flag remains an independent eligibility
gate, including for an activated Window. Unassociated owners retain their prior
compatibility behavior.

This completes the playback permission predicate and these resource callers.
The fetched-media adapter still starts autoplay at its existing point; it does
not translate the complete Source enough-data autoplay branch. Public play()
permission rejection at Source:616–622 and volume-change policy pause at
Source:705–708 remain unported. Full Permissions Policy, viewport observation,
resource/reset/readiness/seek, public native play promises, physical decoding
and automatic weak-node ownership remain open. The browser uses JavaScriptCore.

## Focused evidence

Three model cases use actual DOM audio/video owners. The policy/volume matrix
checks 24 combinations across both kinds, three policies and audible, muted,
zero-volume or actual Page-muted states. Blocked automatic selections perform
no fetch; explicit load fetches enough data while retaining paused state and
delivering no play/playing events. Allowed selections fetch and deliver both.

The sticky-activation case consumes the actual Window's transient activation,
checks the consumed timestamp and remaining sticky state, then resumes resource
selection. Adding the sandbox flag independently blocks later autoplay.
The origin case checks allowlisted network and file Documents, then adopts a
media owner into a blocked Document while retaining an allowlisted resource URL
and activated old Window. Neither old owner nor resource origin grants
permission; activating the new Window does.

The native Page case calls real load() and muted bindings on both DOM owners.
Audible video remains paused while muted audio starts. Actual
EventTarget.prototype listeners observe trusted play/playing events with correct
this, target and currentTarget identity. Updating settings to allow the current
Document origin starts video on a later load. Script/callback execution depths
and the VM context stack balance after delivery.

Both new test files compile against unchanged `b1d39292`; all four new cases
then fail at runtime. The identical test bytes pass after implementation.
The prior sandbox caller fixture also gains three lines checking that flag
removal alone still leaves audible media blocked under the default policy;
muting allows its previously tested resumption.

## Retained verification

The focused three-file batch passes. Both complete frozen single-job neighbor
runs pass all 14 selected files, including settings, Window activation identity,
Page mute ownership, sandbox eligibility/callers, resource load, play/pause,
canplaythrough, native load and the 66-case main regression file. Each GC mode
uses its own complete run. The complete repository suite was not run.

| Run | Result | Manifest under Build/audit-fixes | SHA256 |
| --- | --- | --- | --- |
| Compiled runtime baseline | 2 files fail; all four new cases expose old behavior | `media-playback-policy-frozen-baseline-manifest.json` | `752446df98631cab4bfb27d78a8d7d91def01e71fc324e51dc6da83706f32409` |
| Focused implementation | 3/3 files pass | `media-playback-policy-frozen-focused-manifest.json` | `8cd47a03273e63405ddaed7e40276ca8c78a0dfdb6860e72a28c02a8fac21c5a` |
| Default-GC selected callers | 14/14 files pass | `media-playback-policy-frozen-default-manifest.json` | `5d0bf1f4084d9da6444346a79d5077e09cb9c2921249721acb62f1ef3771f494` |
| GC-disabled selected callers | 14/14 files pass | `media-playback-policy-frozen-gc-none-manifest.json` | `fa9f2ca200d80762f4f82009e2dd4380bd159f81028ea369da9325e4f03a7292` |
| Initial native production | 11 steps pass; smoke capture stops after one case | `media-playback-policy-production-manifest.json` | `a498fb120f813956ce4fa32d1ee2c780e2004957cbb98dab799108222bdd61b9` |
| Same-binary smoke recovery | 11/11 screenshot cases pass | `media-playback-policy-smoke-recovery-manifest.json` | `dd2d9864c536e8fe4c47984ecb12be6b92b48c1bc8fcbc586839d31865845f03` |

The ordinary standalone probe compiles with -prod -gc none and retains active
checks in production. It verifies actual DOM audio/video owners and native
load, muting, trusted event identity, current-origin allowlisting and balanced
execution contexts. Its fetched media is synthetic; it does not verify physical
decoding. The signed production bundle passes strict codesign verification and
headless startup. Both earlier native-load regression viewports remain
pixel-exact against the green reference.

The initial smoke run passes inline-node, then the ordered-list launch exits
without a window screenshot. The failed log, partial images and complete
production manifest are retained. A separate full smoke recovery passes all 11
cases with the existing tolerances using exactly the same binary and unchanged
tracked/Source snapshots. No launch diagnostic report is generated. Production
verification consists of the first 11 successful production steps plus this
complete smoke recovery. Binary SHA256:
`06b694e96260627869f1ac7733b16d6c999406d4663861df62911b8124f47463`.

Consolidated evidence: `Build/audit-fixes/media-playback-policy-evidence.json`,
SHA256 `8080d5159a9ab2e67eaa4d46d3e41014ec22d6c147dff6550e4e8c03434aa87f`.
The six detached runner records retain commands and stdout; client interruption
does not cancel their separate process sessions. Manifests record toolchain and
Source-reference hashes, commands, environment, logs and before/after file
hashes. Prior autoplay-sandbox evidence, helpers and artifacts remain unchanged.
Only this slice's compiler scratch is removed after verification.

Physical inventory: `Build/audit-fixes/source-current-module-loc-066d31b8.json`,
SHA256 `51d4a77b96dd068384ec6c403af69b5ac2706675215e427df96b44dff0d67fe1`.
The 78 owners contain 432,802 implementation and 157,865 test V lines across
2,205 assigned files. The root native test is excluded from package counts.
Physical LOC does not measure parity. The historical finding ledger remains
**32 fixed / 25 partial / 9 open**.
