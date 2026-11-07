# Actual media CSS states and dependent styles

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and focused tests: `32139bfc`.
Same-pass ancestor fanout correction and regression: `728faa99`.
Active-Navigable animation fixture correction: `9101b5b7`.

Media selectors now query the actual HTML audio/video owner through a typed
DOM/HTML callback. Parsed and created elements materialize the same lazy owner
used by native property bindings. Queries do not store a second set of CSS
media facts. HTML namespace checks reject foreign elements with audio/video
local names before a concrete DOM media cast.

`:paused` and `:playing` follow the paused flag, including resource-less V play.
`:muted` reads the element's public mute flag, independently of Page mute and
zero volume. `:seeking` reads the seek flag; `:buffering` reads blocked readiness.
`:stalled` uses the existing Source-compatible false predicate; `:volume-locked`
retains Source's explicit false FIXME. Neither implies a completed backend.

## Source mapping and boundaries

CSS/SelectorMatching.cpp:190–201 publishes the media facts consumed by Source's
current style engine. Its Playing fact is !paused, independently of blocked;
StyleEngineInput.cpp:318 publishes that element_states result. The current
upstream playing-pseudo-class-without-resource fixture likewise expects
synchronous playing=true while no resource is loaded. SelectorMatching.cpp's
legacy element_matches_state helper still additionally checks !blocked for
Playing. The V selector follows the current published engine fact and fixture.
The fixture is a source reference, not a claimed full native JavaScript pass.

HTMLMediaElement.cpp:673–681 commits element mute, runs the existing volume and
audio caller, then records its Muted CSS change. cpp:2948–2970 commits pause,
updates manager/audio/wake/dimensions/repaint, then records Paused and Playing.
cpp:479–486 records Seeking after committing the flag. cpp:2374–2385 compares
old and new blocked readiness and records Buffering immediately after commit.
CSS/Invalidation/ElementStateInvalidator.cpp:74–101 defines these paired and
threshold-sensitive state notifications.

The V media caller preserves that ordering and same-value suppression. It uses
the existing translated style engine's property invalidation plans instead of
inventing Source Rust style-node IDs or a semantic journal. Connected owners
invalidate their own computed styles and affected sibling/descendant plans;
media properties also participate in typed :has() mutation features and DOM
invalidation-set matching. Disconnected owners retain live queryable state
without scheduling a document style invalidation. A document without an HTML
query bridge has no invented media state; materializing an actual model or
installing the HTML document hooks installs the bridge.

The current Document is consulted after adoption. Shadow-root rules keep their
own style scope, and adjacent/general siblings, :has() ancestors and generated
pseudo-elements refresh through the existing CSS machinery. Page-wide mute
does not change the element's :muted state or queue a volumechange event.

Native JavaScript play still has its existing resolved-Promise stub. Playback
in the tests/probe enters the actual V caller. Full resource selection timing,
resource-less load transitions, content-attribute/defaultMuted initialization,
permission/error gates, complete readiness/seek algorithms, physical playback,
weak-node ownership/automatic GC and the Source Rust style-engine journal remain
open. This slice changes neither main.v nor the native media host. It does not
claim the whole upstream no-resource play/load fixture passes.

## Focused evidence and frozen verification

Five model cases verify initial lazy/created owners, namespace/type boundaries,
resource-less play/pause, element mute versus effective volume/Page mute,
readiness thresholds, seeking, matching typed invalidation candidates, duplicate
suppression and manager-hook-before-style ordering. Four page cases verify
native mute/pause and deferred volumechange delivery with balanced execution
contexts, actual sibling/:has()/pseudo-element computed styles, adoption into
another Document, closed-shadow-root isolation and tag-qualified :has()
media-state transitions for both audio and video.

The initial old-implementation baseline exposes five model runtime failures
and native fixture Option/insert-before compile diagnostics. After those
fixture corrections, both files compile and expose seven runtime failures.
The first implementation check exposes three further failures: the fixture's
untranslated resource-less load transition, its compact listener call instead
of the actual native EventTarget listener, and a missing media-state whitelist
in the invalidation planner. The fixture now tests the selected play/pause CSS
caller and native EventTarget directly; full resource-selection timing stays
open. An isolated native rerun retains the stale-buffering sibling and confirms
that the owner is connected and marked dirty while its sibling is untouched.
Adding media states to invalidation-plan building and :has() feature collection
fixes that failure. The corrected focused batch passes all eight cases. The first committed
28-file batches pass in both GC modes, but production verification then exposes
a stale ancestor descendant under body:has(video:muted). Its native mute owner
and sibling style update correctly. An ordinary-branch production diagnostic
confirms muted=true, dirty sibling=true, and stale ancestor opacity=.1.

The new tag-qualified regression fails on unchanged 32139bfc implementation
bytes: a formerly paused descendant keeps opacity .2 after the media owner is
unpaused. A first test setup retains a missing local helper compile diagnostic;
correcting the helper yields the runtime failure. Investigation confirms that
the :has() ancestor walk queues descendant plans after Document has drained the
original mutation plans. Applying newly queued fanout before computing styles
fixes the regression. Its final byte-identical test exercises all five changing
state facts in both directions for parsed audio and video, and passes. This is a
correction to the translated property-plan style pass, not a claimed translation
of the current Source Rust invalidation pipeline.

A final comparison uses byte-identical tests in an isolated checkout of the
unchanged parent db45fa92. Its first compile exposes the missing private regex
archive; linking the unchanged canonical archive completes compilation and
produces eight runtime failures with no compiler errors. The archive hash is
retained before/after, and only this owned private worktree is removed. One
retained tool run labeled baseline-final accidentally executes the translated
canonical checkout after a setup assertion; its real result is 2/2 passing
files and it is not old-implementation evidence. The logs and manifests are
preserved with their actual outcomes.

The first expanded 30-file batches pass 29/30 in both GC modes and expose an
older CSS default-document-timeline fixture. A private unchanged checkout of
32139bfc reproduces its inactive-timeline failure. Source
Animations/DocumentTimeline.cpp:77–81 requires an active Document, whose V query
uses the actual Navigable; the fixture had only installed a legacy
BrowsingContext pointer. Four animation fixtures now attach the active Navigable.
The default-timeline case also detaches that owner and requires an inactive
current time while the legacy pointer remains set. The focused neighbor passes;
only this new private worktree is removed, and the shared archive is unchanged.
No timeline implementation is modified.

| Retained run | Seconds | Result |
| --- | ---: | --- |
| Initial old implementation | 28.386 | 5 model runtime failures and native fixture compile errors |
| Corrected initial baseline | 32.062 | 7 runtime failures; 2 files |
| Initial implementation check | 31.260 | 3 runtime failures; 2 files |
| Native caller/planner diagnostic | 19.976 | Stale buffering sibling; 1 file |
| Corrected original focused batch | 32.943 | 2/2 files; 8 cases passed |
| Mislabeled canonical baseline | 33.327 | 2/2 passed; not old implementation evidence |
| Private baseline preparation | 77.466 | Missing private regex archive; no runtime |
| Final original old-implementation baseline | 40.193 | 8 runtime failures; no compiler errors |
| First committed affected, default GC | 232.662 | 28/28 files passed |
| First committed affected, GC none | 230.172 | 28/28 files passed |
| Tag-qualified test setup | 18.016 | Missing local helper; no runtime |
| Tag-qualified regression on 32139bfc | 21.703 | Runtime failure; stale paused descendant |
| Ancestor fanout correction | 21.628 | 1/1 file passed |
| Expanded affected, default GC | 250.087 | 29/30 passed; older timeline fixture |
| Expanded affected, GC none | 241.375 | 29/30 passed; older timeline fixture |
| Private timeline check on 32139bfc | 12.342 | Same inactive-timeline failure |
| Active-Navigable fixture correction | 8.346 | 1/1 file passed |
| Final affected, default GC | 269.620 | 30/30 files passed |
| Final affected, GC none | 256.789 | 30/30 files passed |

Final affected runs use `-old-compiler -enable-globals`, with `-gc none` in the
second mode, VJOBS=2 and repository-owned compiler scratch. Their manifests hash
all committed inputs, 44 Source references, both retained compiler executables
and the native regex archive before and after. The batch covers media task,
audio, Page mute, wake-lock and adoption neighbors, HTML parser integration,
CSS selector/invalidation/scope/shadow rules and style-pass neighbors, DOM
structural invalidation, native bindings and the 66-case main regression. No full HTML, LibJS or Wasm
sweep is claimed.

## Production and physical inventory

The unchanged committed 9101b5b7 snapshot builds and ad-hoc signs the native
macOS bundle with `-prod -gc none`. Strict/deep signature verification, headless
startup and an ordinary-branch production probe pass. The probe uses actual
parsed media, the actual Page and existing native mute/pause bindings. It checks
resource-less V play, sibling and tag-qualified :has() descendants, seeking
pseudo-element styles, buffering thresholds, Page mute independence, deferred
native events and balanced execution contexts. Source references number 67
for production verification, including the canonical screenshot inputs and font.

Both rendered media-state viewports are pixel-exact: initial body:has(video:paused)
and body:has(video:muted) after native player.muted=true each have zero differing
pixels and zero maximum channel error. The retained expected viewport is a
uniform green document, independent of either media selector. The first failed
production attempt and its diagnostics are retained separately; it built but
stopped at the stale :has() probe before screenshots, signing verification or
headless startup.

The full native smoke set passes all 11 cases within its existing upstream
bounds. This production run records no new Ladybird launch crash reports.
Earlier Page-mute snapshot launch failures remain in their own evidence.

Consolidated evidence: Build/audit-fixes/media-css-state-evidence.json;
SHA256 `3bdd41d899120c909a7da9ae8569ca08abbd1f579b59613b4818a0464c7a5e24`.

Retained manifests (all under Build/audit-fixes/):

- media-css-state-owner-frozen-baseline-manifest.json: `930347dcd8d3ec7037a23a496cca5c2a52760b132ea06d4c5ffb2631fd20e165`.
- media-css-state-owner-frozen-baseline-corrected-manifest.json: `631436d93178779850327cf50dad3091478bef7c5bb5c6ad03ef06f030b83c30`.
- media-css-state-owner-frozen-focused-final-manifest.json: `abf17913d8d1ff1765a0bea70b9b750f9d90c89cf0b3d1cbd747773897d4ecd6`.
- media-css-state-owner-frozen-focused-native-manifest.json: `615f00d8cc438aac4f7a7c130717aff3dc2c61341a1f1c98af8bd7cd923ae282`.
- media-css-state-owner-frozen-focused-verified-manifest.json: `fa31ca6b26c219352afd1a6e2f08f69876dce11af99455d5538d440eb0b68eec`.
- media-css-state-owner-frozen-baseline-final-manifest.json: `bc931e937985a464a6645a20c3ccac63c2cabc9327c0f977f3c54100a374f69c`.
- media-css-state-owner-frozen-baseline-final-private-manifest.json: `7b5b235ce37bfd40d97817dadbcf35ba3372628a1c7cbfd7b777c4bce11705eb`.
- media-css-state-owner-frozen-baseline-final-linked-manifest.json: `c71f66ca0b90192d95343ab7a8958a6aba637d38d10f02be2babbb63310b9ce3`.
- media-css-state-owner-frozen-default-fixed-manifest.json: `de3888141cee1304edfe39cd3e29f033008773af2f6571f990a3281853932fab`.
- media-css-state-owner-frozen-gc-none-fixed-manifest.json: `bc2477a64645da0e20287e17256fadb9576c5854e93cfa5c516b868fab9c7d37`.
- media-css-state-owner-production-manifest.json: `66513630625b9181692378b4f6ee508d5339520593c4467ee7ec851d52f710bd`.
- media-css-state-owner-final-production-manifest.json: `b716387886e1379df33bad1eafc0d8b01ed1af81f7b4f0fdf2424d4f9ec47fe7`.
- media-css-state-has-frozen-baseline-tag-has-manifest.json: `ba45630b62a8663f1e7996948203ea7e2549ce4277c36b0c2420036d53473af6`.
- media-css-state-has-frozen-baseline-tag-has-corrected-manifest.json: `697b3589887bf0f2da68193e29e9b9d04eb0d1bdfcba651e8ba476177a295066`.
- media-css-state-has-frozen-focused-tag-has-manifest.json: `d57155f2e80e3e4def4c1640d75b5ec21bc8a5d7ad129f6e2ba58f724903d286`.
- media-css-state-has-frozen-default-tag-has-manifest.json: `95ece6dcac443c0a98060619854c963d0734b2264a0212e62064219fad5914aa`.
- media-css-state-has-frozen-gc-none-tag-has-manifest.json: `032e6a21b3c3f59ae5ea5697e5075098a30098b6f864532279717078f7c16129`.
- media-css-state-has-frozen-baseline-style-neighbor-manifest.json: `554412e4c8d1dfdbed99c73d27e136b5c18c0c282f0f74b0235cadd915c6de66`.
- media-css-state-has-frozen-focused-style-neighbor-manifest.json: `c957ba517b7bbde33936ba115ffb0b06186330c4e7ea4706f670b41a9a04e01c`.
- media-css-state-has-frozen-default-final-manifest.json: `2ad5c2523f1406daf5e702ee1007e0cf0447b0dc0955c5439e899c317b06fee5`.
- media-css-state-has-frozen-gc-none-final-manifest.json: `babc2a711a366cd1c3aaf29de4a2f38726b120d2bcfce0475139ddc6e4243fec`.

Production binary SHA256: `eb66bc32220294795812b0eb494b5081274e6cc4ae3441a9e2687cc7017cfb95`.

Production artifacts: Build/audit-fixes/media-css-state-owner-final-production/.
Initial production failure: media-css-state-owner-production/.
Reports: media-css-state-final-launch-reports/.
Compiler-only scratch was removed after every verification process finished;
cleanup record: media-css-state-compiler-cleanup.json, SHA256 `ac70be9efea72e3d29f8ba215688d69b397c1ed53b303f87788c8ecdef036812`.
Both owned private baseline worktrees were removed; unrelated worktrees,
external compiler/dependency sources and the seven original untracked entries
were preserved. Ordinary repository scratch was used; no RAM volume was mounted.

The 78-owner physical inventory contains 432,731 implementation / 156,527 test
V LOC across 2,198 owned files. One new DOM bridge and one HTML test add owned
files; implementation changes belong to CSS, DOM and HTML. The 132-line and 60-line root
page tests and browser/native support remain excluded. Inventory:
Build/audit-fixes/source-current-module-loc-9101b5b7.json;
SHA256 `2ed3f2549a4cbc9d6a8b3e13fc68565b187152cc60db0156ab2318bce774c617`.
LOC is not a parity measure. The ledger stays 32 fixed / 25 partial / 9 open.

Implementation: [media caller](../../html/html_media_element.v),
[DOM query bridge](../../dom/media_element_state.v),
[selector matching](../../css/selectors.v),
[typed invalidation](../../css/computed_interpolation.v).
Tests: [model](../../html/media_css_state_owner_test.v),
[page](../../media/main_media_css_state_owner_test.v),
[tag-qualified ancestor regression](../../media/main_media_css_has_state_owner_test.v),
[style pass](../../css/style_computer.v).
[Prior Page mute evidence](MEDIA_PAGE_MUTE_OWNER.md) retains its snapshot.
