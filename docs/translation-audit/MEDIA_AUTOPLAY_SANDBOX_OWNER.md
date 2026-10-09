# Live document sandbox guard for media autoplay eligibility

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and focused tests: `6099af96`.

Actual audio/video owners now refuse autoplay eligibility when their current
Document has the sandboxed automatic-features flag. With autoplay and
preload="none", automatic selection stays deferred instead of fetching and
starting playback. Explicit load() still fetches; the sandboxed owner stays
paused. Adoption and later flag changes use the current Document on each check.

## Source mapping and scope

HTML/HTMLMediaElement.cpp:3060–3077 requires can-autoplay, paused, an autoplay
attribute, absence of the automatic-features sandbox flag and permission to use
autoplay. The V owner now reads Document.active_sandboxing_flag_bits() through
the existing typed HTML SandboxingFlagSet and checks that exact flag before the
existing feature-policy adapter. Other sandbox flags do not independently
change this eligibility result. Muting or zero volume cannot bypass the guard.
Existing can-autoplay, paused, attribute and allow_autoplay_ adapter checks remain.
Owners without an associated Document retain their prior compatibility behavior.

The resource-selection preload caller at Source:1320–1336 and the existing V
fetch/resumption callers consume the shared eligibility result. Explicit load
continues to bypass optional preload deferral. The native load operation reaches
the same owner; the guard does not prohibit explicit model play.

This completes only the sandbox predicate. Document's autoplay Permissions
Policy decision remains its existing adapter. Source is_allowed_to_play at
3081–3100 uses sticky user activation, origin settings and effective volume;
its integration is still unported. Enough-data autoplay substeps, fetch-adapter
autoplay timing, viewport observation, full resource/reset/readiness/seek,
public native play promises, physical decoding/playback and automatic weak-node
ownership remain open. The browser continues to use JavaScriptCore.

## Focused evidence

Three model cases use actual DOM media owners. The audio/video matrix checks
all 17 sandbox flags, automatic-features combined with forms flags, muted and
zero-volume media, live flag removal, and the preserved can-autoplay, paused, attribute and
legacy allow_autoplay_ gates. Adoption checks the new Document's flags and
confirms that later changes to the old Document do not override the new owner.

The actual selection caller verifies that sandboxed autoplay plus preload="none"
emits suspend, releases its Document load delay and performs no fetch. Reapplying
autoplay cannot resume it. Explicit load fetches enough data and delivers first
data/canplaythrough without play/playing. A later automatic selection defers
again; removing the flag allows resumption to consult the live eligibility.

The native Page case exercises real audio/video load() bindings, live
paused/readyState/duration getters and EventTarget.prototype listeners. Load
fetches while preserving paused state and never delivers play/playing. Explicit
model play still completes its model promises and reaches the native event
listeners. Actual execution contexts balance. This does not verify public native
play promises or the unported playback-policy gate.

All four new cases fail at runtime against unchanged `0da973a6`; both files
compile without errors. The same test bytes pass after the guard is added.

## Retained verification

The original default-GC run stopped after three observed passing files when
the client interrupted the turn. No summary or final snapshot manifest was
produced; its log and interruption record are retained as partial evidence.
The complete default-GC recovery run and GC-disabled run each pass all 11
selected files in one complete single-job run on unchanged committed code and
tests. Neither uses the partial run to compose its passing coverage. Coverage
includes eligibility, autofocus's existing sandbox behavior, preload and load,
pause/play, first-data,
canplaythrough, the native load caller and the 66-case main regression file.
This is selected coverage; the complete repository suite was not run.

| Run | Result | Manifest under Build/audit-fixes | SHA256 |
| --- | --- | --- | --- |
| Compiled runtime baseline | 2 files fail; all four new cases expose old behavior | `media-autoplay-sandbox-frozen-baseline-manifest.json` | `60b334957811d9a3981510d4be46e5d4d69ce30e27f3561c1f58061433a9070a` |
| Focused implementation | 2/2 files pass | `media-autoplay-sandbox-frozen-focused-manifest.json` | `2dfacbe612349e8142f8c36d5bf651faa79b8fa56d2fa1826569833727e8f7ef` |
| Default-GC complete recovery run | 11/11 files pass | `media-autoplay-sandbox-frozen-default-recovery-manifest.json` | `58d156ec33184acb5a949528f96ae87f93de44fee0d4a85a91c92d142a28a530` |
| GC-disabled selected callers | 11/11 files pass | `media-autoplay-sandbox-frozen-gc-none-manifest.json` | `ddff8bd61a30d7f0dedb6c17b7dc25ffc6a96de6af5deede8c57416b4e0b16f9` |
| Initial standalone probe check | Compiler failure retained; no bundle build attempted | `media-autoplay-sandbox-production-manifest.json` | `aa3073a6e163e21bab1e2294b0c8a46c090cce62a78c883c0eede5985520dfc2` |
| Validated native production | 12 steps pass; 11 screenshot cases pass | `media-autoplay-sandbox-production-validated-manifest.json` | `c5822a0ffbdb47608d716ead0c8933dba87efefdfb13cb74da83d355f93f1ba2` |

The initial standalone probe incorrectly used helpers available only to root
tests and failed its compiler check before building the bundle. Its source,
manifest, pages and log are retained. The corrected standalone probe uses
MediaElementHost directly, compiles as ordinary code with -prod -gc none, and
passes native audio/video load and event-binding checks. It uses concrete DOM
owners and synthetic fetched media; physical decoding is outside this evidence.

The signed production bundle passes strict codesign verification and headless
startup. Both earlier native-load regression viewports match the green reference
pixel-exactly; all 11 canonical smoke cases pass with their existing tolerances.
The binary stays unchanged throughout successful verification, SHA256
`65be76807ea8e758f71b804a1fa33828063c5824644de6211ed24829b86b52d7`.
All successful and failed artifacts remain under their separate production
prefixes. No launch diagnostic report was generated.

Consolidated evidence: `Build/audit-fixes/media-autoplay-sandbox-evidence.json`,
SHA256 `63a3600780fae90ae45098431582088a4e7cf0d249b7bacae1f278b940c88208`.
The interrupted default run is retained in
`Build/audit-fixes/media-autoplay-sandbox-default-interruption.json`; its log
records three observed passes without claiming a complete run or equality of
before/after file hashes.
The GC-disabled runner uses a separate process session so client interruption
does not cancel verification.
Manifests record commands, environment, logs, Source references, toolchain hashes
and before/after file hashes. Prior canplaythrough evidence and artifacts remain
unchanged. Only this slice's compiler scratch is removed after verification.

Physical inventory: `Build/audit-fixes/source-current-module-loc-6099af96.json`,
SHA256 `59b6a6caaab87df398efc810cc9d6b9f9c3f5a2460e2d2000f5e49346db3eb16`.
The 78 owners contain 432,786 implementation and 157,697 test V lines across
2,204 assigned files. The root native test is excluded from package counts.
Physical LOC does not measure parity. The historical finding ledger remains
**32 fixed / 25 partial / 9 open**.
