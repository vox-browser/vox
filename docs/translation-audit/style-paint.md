# CSS, layout, painting, animation, and view-transition translation audit

Audit date: 2026-10-02. Upstream reference: Ladybird commit
`963d46a829f3e1b79f44dba9d02afb70654300fa` in `/Users/alex/code/3rd/ladybird`.
The V worktree was inspected directly, including its browser and DOM bridges;
`PORT_STATUS.md` claims and symbol mappings were used only to locate code.
The V checkout was at `692d54bc642a5ceac601e2f47e7f5e9e6e2d0642` when this report
was written. Other agents were writing audit documentation in the shared
worktree. This audit changed no implementation files.

There are **15 current upstream C++ sources of at least 1,000 physical lines**
in the assigned directories, totaling **26,127 lines**. All 15 have body-level
comparisons recorded below. This is a targeted review, with deeper tracing of
suspect paths, **not an exhaustive line-by-line equivalence proof**. In
particular, this does not establish that every V algorithm originated in
Ladybird or that the translation has no other stubs or missing logic. No
runtime tests or screenshot comparisons were run for this documentation audit.

In references below, `CSS/...`, `Layout/...`, `Painting/...`, `Animations/...`,
and `ViewTransition/...` designate files beneath upstream
`Libraries/LibWeb/`. Other paths designate files in this V repository unless
explicitly prefixed with upstream `Libraries/LibWeb/Rust/`.

## Coverage

“No verified defect in sample” means only the listed algorithms were examined.
It is not a parity certification for the remaining file.

| Current C++ source | LOC | V counterparts actually read | Compared algorithms and review depth | Result |
| --- | ---: | --- | --- | --- |
| `CSS/CSSStyleProperties.cpp` | 1,871 | `css/style_declarations.v`, `dom/shadow_mutation_misc.v` | Sampled computed custom-property lookup (`cpp:777` / `v:899`), used content/border-box dimensions and logical edge resolution (`cpp:1021` / `v:1576`), sticky inset handling (`cpp:1046` / `v:1779`); traced AbstractElement lookup. | SP-12; used-size and sticky-inset branches have recognizable translated bodies. |
| `CSS/ComputedStyleWorkingSet.cpp` | 1,129 | `css/computed_interpolation.v`, `css/style_computer.v` | Sampled base-property writes/flags/font-cache invalidation (`cpp:371` / `v:2167`), animated writes (`cpp:428` / `v:2182`), inherited specified-value preservation (`v:1108` in style_computer); inspected Rust storage boundary (`cpp:83`). | No verified defect in these samples; current Rust storage and drive boundary remains unverified below. |
| `CSS/ComputedValues.cpp` | 2,043 | `css/computed_values.v`, `css/computed_interpolation.v` | Sampled base versus animated effective-value reads (`cpp:1859` / interpolation `v:2201`), mutable inherited-field copying (`v:1660`), document-dependent font/color materialization (`v:386`); inspected immutable/grouped source representation. | No verified defect in the sampled important/transition precedence; broad typed-value and Rust materialization parity not established. |
| `CSS/FontComputer.cpp` | 1,173 | `css/font_face_values.v` | Compared family candidate assembly and width/style filtering (`cpp:397` / `v:4262`), weight range selection and the three weight-search branches (`cpp:458` / `v:4321` onward); traced face registration keys. | SP-07. Several weight-search branches preserve source ordering; full font backend equivalence not checked. |
| `CSS/FontFace.cpp` | 1,141 | `css/font_face_values.v` | Compared CSS-connected versus manual parsed descriptors (`cpp:373` / `v:2038`), style setter/cache (`cpp:722` / `v:2347`), URL loading and completion (`cpp:986` / `v:2522`), and registration consumers. | SP-05, SP-06. Connected CSS rules have their own working slope parser. |
| `CSS/StyleComputer.cpp` | 6,258 | `css/computed_interpolation.v`, `css/style_computer.v`, `css/screen_animation.v` | Compared monospace font-size recascade (`cpp:5302` / `v:10872`), computed-style entry and current cascade-input boundary (`cpp:4330` / `v:13405`), and traced the separate live CSS custom-property sampler/publisher (`v:11269`, `v:11528`). | Positive recascade and custom-animation samples; current Rust style-engine architecture not certified. See review boundary. |
| `CSS/StyleEngineInput.cpp` | 1,883 | `css/dom_css_bridge.v`, `css/style_scope_cache.v`, DOM mutation hooks | Compared publication of selector features/relations (`cpp:289`), attribute-text handling (`cpp:516`), element-state recording (`cpp:1734`), and old/new namespaced-attribute journaling (`cpp:1837`) against V imperative invalidation (`bridge v:262`) and pending relational-selector candidates (`cache v:1174`). | Current identity/journal architecture has no direct V body correspondence established; V has a different active invalidation architecture. See review boundary. |
| `CSS/StyleScope.cpp` | 1,157 | `css/style_scope_cache.v`, `css/cssom_rules.v`, `css/custom_function_evaluation.v`, `css/selectors.v` | Compared constructed-sheet sharing (`cpp:283` / cache `v:438`), origin sheet selection (`cpp:494` / `v:527`), function resolution/layers/outer scopes (`cpp:1038` / function `v:195`), and candidate bucket semantics. Limited associated Rust folding code read. | SP-08, SP-09. Ordinary origin sheet enumeration and connected sheet caching exist. |
| `CSS/UpdateStyle.cpp` | 1,357 | `css/style_computer.v`, `css/dom_css_bridge.v` | Compared document update entry, animation-only fast path, transaction settlement/feedback (`cpp:783`, `cpp:835`), V animation-only samples (`v:1342`), recursive style update and registry refresh (`v:1471`, `v:1589`). | Live V style and animation invalidation are implemented; current transactions/feedback are outside verified correspondence. See review boundary. |
| `Layout/Node.cpp` | 1,136 | `layout/node.v`, `css/image_color_values.v` | Compared image observers and notifications (`cpp:467` / `v:1185`, `v:1126`), root-element check (`cpp:640` / `v:697`), containment checks (`cpp:1096`), and style attachment (`v:1109`). | SP-10. HTML-root check and several source containment limitations are retained rather than new stubs. |
| `Layout/TreeBuilder.cpp` | 1,386 | `layout/document_tree_builder.v`, `layout/dom_layout_bridge.v`, `css/style_computer.v` | Compared first-letter slices/wrapper factory (`cpp:466`, `cpp:481`), V ordinary text/child construction (`v:819`, `v:928`), marker factory, anonymous contents handling and SVG child bypass. Traced current Rust caller of first-letter factory. | SP-11; overall tree-construction algorithm now resides in Rust upstream. |
| `Painting/DisplayListPlayerSkia.cpp` | 1,458 | `painting/display_list.v`, `main.v`, native renderer glue | Compared rounded outer/inner shadows (`cpp:737`, `cpp:753` / `main v:4253`, `v:4284`), text-shadow silhouette/blur (`cpp:778` / `main v:5203`), command dispatch and real native calls; inspected source grouped-compositing commands and no-op metadata. | SP-13 applies to portable fallback. Native calls are present; complete current command/isolated-group equivalence remains unverified. |
| `Animations/Animation.cpp` | 1,784 | `animations/animation.v`, `animations/animation_timeline.v`, DOM animation event queue | Compared cancellation (`cpp:684` / `v:588`), finished-state hold/start-time logic and notifications (`cpp:1345` / `v:1020`), observation getters (`v:493`), event timestamp/dispatch consumers. | SP-02, SP-03. Basic end/zero hold-time branches are translated; task timing differs. |
| `Animations/KeyframeEffect.cpp` | 1,297 | `animations/keyframe_effect.v`, `animations/animatable.v`, separate `css/screen_animation.v` and CSS sampler | Compared missing offsets (`cpp:263` / `v:270`), indexed keyframe sorting/merging/easing (`cpp:451` / `v:384`), property parsing (`cpp:560` / `v:341`), resolved-frame installation (`cpp:1008` / `v:444`); traced separate CSS custom-property execution. | SP-04 is limited to the `animations` Web Animations record, not the live CSS sampler. |
| `ViewTransition/ViewTransition.cpp` | 1,054 | `viewtransition/view_transition.v`, `dom/document.v` | Compared old/new captures (`cpp:230`, `cpp:373` / `v:196`, `v:254`), live DOM adapter (`dom v:10870`), animation lifetime (`cpp:759` / `dom v:3729`), and dynamic stylesheet updates (`cpp:950` / `v:383`). | SP-01, SP-14. Isolated transition state model exists; live capture/pseudo animation integration is absent. |

## Concrete findings

### SP-01 — Live view transitions do not populate or render captured elements

**Classification:** untranslated integration; high impact.

Upstream `ViewTransition/ViewTransition.cpp:259` traverses actual document
elements. At `:312` it captures images, and at `:317` it reads committed layout
geometry. New-state capture updates layout at `:373`; frame handling at `:759`
examines animations belonging to transition pseudo-elements.

V's isolated model reads caller-supplied `TransitionDocument.elements` in
`viewtransition/view_transition.v:196` and `:254`. The actual
`Document.start_view_transition()` at `dom/document.v:10870` constructs that
document with only snapshot width/height; it never supplies elements or captured
images. `sync_document_state()` at `dom/document.v:3704` copies two flags rather
than the generated pseudo tree, styles, and images into the live document.
`handle_transition_frame()` at `dom/document.v:3729` explicitly passes `false`
for active animations because those pseudo animation objects are not exposed.

Consequently, model tests can capture manually supplied elements, while a live
document transition has no corresponding captured-element pipeline and cannot
remain active for its generated animations. The adapter also drains its model
tasks synchronously at `dom/document.v:3724`; this is not evidence of a real
DOM-manipulation task queue.

**Remediation target:** `dom/document.v` and view-transition layout/painting
integration. Populate both captures from the live tree, retain actual images,
install generated pseudo nodes and rules, and obtain their animation state from
the live animation system. Validate with a live named-element transition, not
only `TransitionDocument` fixtures.

### SP-02 — `Animation.cancel()` loses cancel-time capture and invalidation

**Classification:** untranslated steps in the standalone Animation record.

Upstream `Animations/Animation.cpp:747` saves the effect's active time with fill
mode `Both`; `:751` invalidates its effect when needed. V
`animations/animation.v:588` resets promises/events and clears time state, but
does neither operation. Its `saved_cancel_time_` field (`:60`) is only released
at `:1006`; no assignment was found in the V package.

This omits data consumed by CSS cancellation-event handling and can leave the
cancelled effect's style invalidation unrequested for this record. The separate
CSS-owned animation model has its own cancellation path; this finding does not
assert that every CSS animation cancellation uses the faulty record.

**Remediation target:** `animations/animation.v:588`. Port the source effect
active-time capture and invalidation ordering, and test the stored cancel time
and target invalidation on cancellation.

### SP-03 — Finish notification resolves immediately and uses the wrong event time

**Classification:** substituted task/event timing in the Animation record.

Upstream `Animations/Animation.cpp:1424` queues a finish closure which rechecks
the play state. `:1449` derives its scheduled event time from the effect end;
`:1473` distinguishes synchronous finish notification from queued notification
and tracks cancellation/de-duplication. If no document owns the event, `:1459`
queues a task.

V `animations/animation.v:1064` resolves the finished promise and emits the
event immediately in `update_finished_state()`. `emit_playback_event()` at
`:1091` schedules all events using the sampled timeline time, not the converted
effect-end time; `:1095` dispatches immediately without an owning document.
Observation getters such as `finished_for_bindings()` (`:493`) reach the same
updater. A late sample or a seek away before a queued notification would run can
therefore produce different promise settlement and event ordering.

**Remediation target:** `animations/animation.v:1020` and `:1074`. Translate the
finish-notification closure, task identity/cancellation and source timestamp
calculation; test late sampling and seeking away before task delivery.

### SP-04 — The Web Animations `KeyframeEffect` drops custom-property keyframes

**Classification:** untranslated property kind; explicitly scoped to the
`animations.KeyframeEffect` record.

Upstream `Animations/KeyframeEffect.cpp:560` accepts custom property names, and
`:1019` installs them in the target-property set. V
`animations/keyframe_effect.v:326` resolves names solely to `css.PropertyID`.
At `:353`, `process_keyframes()` skips names without an ID. Resolved frames at
`:70` and installation at `:444` also use `map[css.PropertyID]...`, so `--x`
cannot survive that processing. `animations/animatable.v:274` constructs this
record for its animate API.

**The CSS path does implement custom-property animation.** Its separate
`css.KeyframeEffect` stores named custom values in `css/screen_animation.v:505`;
`css/style_scope_cache.v:789` installs them. The real style sampler at
`css/computed_interpolation.v:11269` collects their names, computes underlying
values, composites and interpolates them, then `:11315` publishes a DOM custom
property overlay. Normal style computation reaches it at `:11528`, and the
animation-only update reaches it through `css/style_computer.v:1342`.
Accordingly, this is not a claim that `@keyframes` custom values are missing.

**Remediation target:** `animations/keyframe_effect.v` property representation
and its handoff to live style sampling. Preserve `PropertyNameAndID`-equivalent
custom names through parse, offsets, initial/final frames, composition and
sampling; exercise the Web Animations record separately from CSS animation.

### SP-05 — Manually created `FontFace` objects always register a normal slope

**Classification:** explicit placeholder with a traced consumer.

For a non-CSS-connected face, upstream `CSS/FontFace.cpp:382` uses the cached
slope; `:722` computes that cache from the parsed/absolutized style descriptor.
V `css/font_face_values.v:2050` instead returns `slope_: 0 // FIXME: slope`, and
`set_style_impl()` at `:2347` only saves its string. `register_font_face()` at
`:3946` consumes this parsed descriptor through
`font_face_key_for_parsed_font_face()` (`:3601`), so this is not an unused
metadata field. An italic/oblique manually created face is keyed as normal.

CSS-connected faces take a different branch at `css/font_face_values.v:2039`
and use `CSSFontFaceRule.font_face()`, whose style parser computes the slope
around `:1619`. The finding does not apply to that connected-rule branch.
Other feature/variation placeholders around `:2058` are also present upstream
in `CSS/FontFace.cpp:392` and were not counted as V omissions.

**Remediation target:** `css/font_face_values.v:2347`, `:2050`. Translate cached
style/slope computation for manual faces and test registration/matching of
normal, italic and oblique `FontFace` instances added to a `FontFaceSet`.

### SP-06 — URL font loading completes synchronously

**Classification:** substituted asynchronous completion semantics.

Upstream `CSS/FontFace.cpp:1020` states that request kickoff is synchronous but
loading and completion remain asynchronous. Completion is queued on the font
loading task source at `:1028`. V `css/font_face_values.v:2533` explicitly chooses
synchronous loading. Its load callback at `:2553`, completion at `:2634`, and
platform loader at `:3709` directly complete the promise/face and notify sets.

Platform font decoding is a legitimate backend adaptation; completing the URL
load during `load()` is an observable timing change, especially for promise
state and FontFaceSet loading events. Upstream's separate binary-constructor
FIXME is not the URL path being reported.

**Remediation target:** font loading completion in `css/font_face_values.v`.
Retain synchronous request kickoff but queue completion/status/event steps on
the translated task source. Test pending status during `load()` and subsequent
font-loading event order.

### SP-07 — Font matching mixes installed faces with author family faces

**Classification:** altered family-candidate algorithm.

Upstream `CSS/FontComputer.cpp:397` assembles registered family candidates; it
enumerates installed platform typefaces only when that set is empty (`:408`).
V `css/font_face_values.v:4262` assembles registered candidates and then
unconditionally appends installed faces at `:4276` before width/style/weight
filtering. When a registered family's descriptors do not exactly match the
request, an installed face can enter and win a fallback search which excludes
it upstream. The exact-key fast path can conceal this difference.

The source itself has incomplete style/width matching and first-match FIXME
comments; carrying those limitations was not counted as a fresh defect. The
weight range and 400–500 / below-400 / above-500 search sequences were sampled
and preserve recognizable source ordering.

**Remediation target:** candidate assembly in
`css/font_face_values.v:4262`. Match the upstream empty-set condition before
adding platform fonts; test a downloadable family that collides with an
installed family and requests a non-exact descriptor combination.

### SP-08 — Dashed CSS function lookup omits layers, origins and enclosing scopes

**Classification:** replaced lookup algorithm.

Upstream `CSS/StyleScope.cpp:1038` resolves global tree-scoped references.
Within a scope it compares layer indices (`:1045`) and considers user-agent,
user and author origins (`:1071`). The fallback walks enclosing shadow-host
trees (`:1122`) and explicitly stops a detached host's ordinary-root chain
(`:1148`).

V `css/custom_function_evaluation.v:195` looks only through the current scope's
author sheets and lets the last effective preorder matching rule win
(`:200`). There is no layer comparison, other-origin search, or enclosing-scope
fallback in that resolver; `css/style_scope_cache.v:555` supplies current-scope
author sheets. Thus source order can override layer rank, and an otherwise
visible function defined in an enclosing scope is not found.

**Remediation target:** `resolve_custom_function_definition()` and its scope
result in `css/custom_function_evaluation.v`. Port source origin/layer
precedence and tree-scope inheritance; test reordered layer declarations and
nested/detached shadow-host lookup.

### SP-09 — Quirks-mode class/ID candidate lookup does not fold case

**Classification:** missing selector compilation/candidate semantics; limited
supporting Rust trace included.

Upstream `CSS/StyleScope.cpp:288` explains that quirks scopes fold class and ID
bucket keys and at `:290` excludes them from caches lacking a mode key.
Current source implements folding in
`Libraries/LibWeb/Rust/src/css/style/compiler.rs:221` and
`Libraries/LibWeb/Rust/src/css/style/mod.rs:1011`: both selector and element
names are keyed by their lowercase form.

V `css/style_scope_cache.v:202` stores exact ID/class names; bucket lookup at
`:257` uses exact element class/ID strings. Live rule collection at `:2108`
only evaluates those candidate buckets. Although `css/selectors.v:1699`
implements case-insensitive class matching in quirks mode, `.foo` never reaches
that matcher for `class="FOO"`. ID comparison itself remains exact at
`css/selectors.v:1696`. The constructed-sheet sharing branch at
`css/style_scope_cache.v:443` also lacks the upstream quirks guard, and its
cache at `css/cssom_rules.v:2236` has no document-mode key.

**Remediation target:** selector-name normalization, rule bucket creation and
lookup, and constructed-sheet sharing. Port quirks ID/class folding
consistently and apply the source cache guard or equivalent mode isolation;
test both differently cased IDs/classes and a constructed sheet adopted into
standards and quirks documents.

### SP-10 — CSS image observation omits cursor/border images and reverses replacement order

**Classification:** untranslated observer inputs and ordering.

Upstream `Layout/Node.cpp:479` observes background/mask layers, cursor images
(`:483`), border-image source (`:485`) and list images (`:486`). It registers
new observers before releasing old ones (`:489`) to preserve resource
continuity. V `layout/node.v:1185` unregisters every old client first, then
adds backgrounds, list images and masks; it never adds cursor or border-image
source observers. Searches of image-client registration in CSS/layout did not
find an alternate route for those two CSS inputs.

V does have actual notifications: `layout/node.v:1126` requests repaint, and
style application reaches the rebuild at `:1109`. The finding is the missing
input classes and lifecycle ordering, not a claim that all CSS image updates
are absent. Whether releasing the last V client causes a refetch was not
runtime-tested.

**Remediation target:** `layout/node.v:1185`. Translate the complete observer
slot set and build/register replacements before unregistering old clients;
test delayed/animated border and cursor image resources and resource continuity
across style reassignment.

### SP-11 — Styled `::first-letter` has no translated layout construction

**Classification:** untranslated rendered pseudo-element algorithm.

Upstream `Layout/TreeBuilder.cpp:466` splits text into first-letter/remainder
slices. `:481` constructs and styles the wrapper, attaches its resources, and
records a synthetic `FirstLetter` pseudo node. This bridge is used by current
Rust tree construction at
`Libraries/LibWeb/Rust/src/layout/tree_builder.rs:1270`; its search and wrapper
placement are at `:3088` and `:3215`.

V `layout/document_tree_builder.v:819` makes the full ordinary text node;
child attachment at `:928` and fixup at `:959` never split or wrap its first
letter. The only layout-package `first_letter` reference found is enum
conversion at `layout/dom_layout_bridge.v:518`. CSS does recognize its style
filter (`css/style_computer.v:635`), but that is not rendered layout creation.

**Remediation target:** V layout tree construction and pseudo-node ownership.
Translate text targeting/slicing and wrapper insertion from the current Rust
caller plus the C++ factory; test punctuation, generated text, inline ancestor
wrapping and ordinary first-letter style.

### SP-12 — Computed pseudo custom-property lookup lacks originating-element fallback

**Classification:** untranslated lookup fallback.

Upstream `CSS/CSSStyleProperties.cpp:789` handles a pseudo-element with no own
custom-property data by looking on `element_to_inherit_style_from()` before
registered initial fallback (`:799`). Its comment explicitly covers a rule
targeting the originating element through `::slotted(...)`.

V `css/style_declarations.v:899` asks only `owner.get_custom_property()` and
immediately falls back to a registration initial value. The computed direct
property branch at `:1296` delegates to this function. Its DOM helper at
`dom/shadow_mutation_misc.v:4332` only reads that pseudo's own custom-property
data (`:4321`); it does not implement the omitted fallback. Thus
`getComputedStyle(el, "::before").getPropertyValue("--x")` can return no value
or the registered initial instead of the originating element's value in this
specific no-own-data state.

**Remediation target:** computed custom-property branch in
`css/style_declarations.v:899`. Port originating-element lookup before
registered initial fallback and test the source's slotted-pseudo case.

### SP-13 — Portable shadow replay uses sharp/rectangular approximations

**Classification:** deliberate semantic replacements in the portable backend;
not a missing native macOS implementation.

Upstream `Painting/DisplayListPlayerSkia.cpp:737` paints a rounded outer shadow
with difference clipping and blur sigma `radius / 2`. `:753` subtracts rounded
paths for the inner shadow; `:778` draws blurred glyph silhouettes, including
color-glyph tint/alpha handling.

V's native macOS branches make real calls, e.g.
`main.v:4284`–`:4297` and `main.v:5211`, to native shadow/glyph renderers. The
portable fallback instead documents its approximation at `main.v:4253` and
`:4299`: rectangular strips replace the rounded path difference and omit blur.
At `main.v:5220`, text shadow is explicitly drawn as sharp text. These bodies
do not translate the source raster algorithm and can change output whenever
the native path is unavailable. Shared native Skia/platform glue is a backend
adaptation; the reduced fallback is an observable deviation.

**Remediation target:** portable shadow playback in `main.v` or a portable
renderer bridge. Implement equivalent rounded difference/blur and glyph-layer
semantics; validate portable blurred/rounded shadows separately from the
native browser screenshot path.

### SP-14 — View-transition dynamic rules are replaced instead of updated as upstream

**Classification:** source-behavior deviation; no claim that this is a user-visible
regression in isolation.

Upstream `ViewTransition/ViewTransition.cpp:950` creates a rule once, and on
subsequent calls only changes its selector (`:981`). V
`viewtransition/view_transition.v:383` rebuilds the full CSS string including
width/height and replaces it in `dynamic_style_rules` (`:409`). The state
model therefore changes declaration contents on subsequent frames where the
current source does not, and string replacement is not CSSOM rule identity.

Some view-transition values remain literal serialization placeholders in both
implementations: upstream `:559` and `:963`, and the identity old-transform
FIXME at `:328`. Those were not counted as V stubs. Changing such upstream
limitations may improve behavior, but it cannot be described as an exact
translation without recording the intentional deviation.

**Remediation target:** `viewtransition/view_transition.v:383`. Preserve source
rule mutation behavior/identity, or explicitly document and test the intentional
departure once live transition integration is implemented.

## Current-source and provenance review boundary

The current upstream is no longer a purely C++ layout/style implementation.
`Layout/TreeBuilder.cpp:1332` calls `RustFFI::rust_build_layout_tree()`;
`Layout/Node.cpp:1132` delegates arena layout-update bookkeeping. There are no
current large C++ `BlockFormattingContext.cpp`, `FlexFormattingContext.cpp`,
`GridFormattingContext.cpp` or `TableFormattingContext.cpp` files to pair with
V's large formatting-context files. Their current implementations are:

| Upstream Rust source under `Libraries/LibWeb/Rust/src/layout/` | Physical LOC | Review here |
| --- | ---: | --- |
| `block_formatting_context.rs` | 3,433 | Identified; body equivalence not audited. |
| `flex_formatting_context.rs` | 3,288 | Identified; body equivalence not audited. |
| `grid_formatting_context.rs` | 4,952 | Identified; body equivalence not audited. |
| `table_formatting_context.rs` | 3,306 | Identified; body equivalence not audited. |
| `tree_builder.rs` | 4,359 | Only first-letter call/search/placement traced for SP-11. |

Additional logic is distributed across `line_builder.rs`, `inline_content.rs`,
intrinsic-sizing, absolute-position, SVG, used-value and fragment-tree modules.
These were not exhaustively audited here. In CSS, current working sets use
Rust longhand tables and animated overlays (`CSS/ComputedStyleWorkingSet.cpp:83`,
`:428`). `CSS/StyleEngineInput.cpp:289`, `:1734`, `:1837` publishes stable
identities, selector data and old/new mutation journal entries.
`CSS/UpdateStyle.cpp:835` consumes style-engine transactions and feedback;
`CSS/StyleComputer.cpp:4358` obtains engine cascade input.

V instead uses an active imperative rule cache/cascade and recursive update
(`css/computed_interpolation.v:13405`, `css/dom_css_bridge.v:262`,
`css/style_computer.v:1589`). Its `:has()` invalidation candidates and CSS
animation-only update are real implementations, so absence of upstream FFI
names is not proof of a stub. However, no body-level equivalence was established
for the current source's identity/journal/transaction/feedback architecture,
and no source-history proof establishes the provenance of every older V
algorithm. Those areas require a Rust-aware audit and an explicit upstream
revision/deviation record before claiming an exact current translation.

Likewise, the painting report does not certify every current grouped-compositing
command: `DrawCompositedContext` (`Painting/DisplayListPlayerSkia.cpp:277`) and
`DrawIsolatedGroup` (`:1107`) belong to a changed source architecture, while V
uses its own retained nested-effect playback. A name search cannot establish
their equivalence. Upstream's empty `BackdropFilterRegion` command at `:1031`
and metadata commands are source no-ops, not evidence of new V stubs.

The mapping helpers do not close these gaps. `tools/libweb_translation_audit.py:1091`
collects V function names and excludes facade owners; it does not compare
algorithms. `tools/upstream_function_delta.py` matches C++ bodies across source
revisions to build a review queue; it does not prove that the V body implements
the matched C++ body. Existing module status tables were treated in the same
way.

The findings above establish concrete missing or changed steps in the reviewed
paths. They also show why symbol coverage, model tests and source TODO counts
cannot establish the requested absence of untranslated or invented logic.
