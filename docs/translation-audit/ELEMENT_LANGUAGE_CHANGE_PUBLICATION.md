# Shared Element language-change publication

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/CSS/Invalidation/LanguageInvalidator.cpp:22–61` and
`HTML/HTMLMetaElement.cpp:190–191`.

The existing V Element `lang`/`dir` attribute branch already published inherited
changes through shadow-including descendants, cleared cached language values,
marked element styles, invalidated retained casing text and scheduled inherited
pseudo-class dependencies. That body was private to attribute mutation. Meta's
Source pragma-language algorithm also requires the language publication call
on the actual document element after changing the default language; its
Document setter previously invalidated only the root cache.

The existing publication body is factored into a concrete Element method and
shared private publisher. `lang` and `dir` mutations retain their previous
behavior and ordering, including directionality state updates and existing
dependency scheduling. The language method provides the actual Source callee
for the separate Meta lifecycle/caller feature. No language matcher, text
transform or invalidation walk is rewritten.

Two focused cases in `layout/language_change_publication_test.v` use actual
Document, Element, author ShadowRoot and Layout owners. They warm language
caches in light/shadow descendants before changing the default language and
verify that the shared method refreshes those caches and marks descendant
styles. The text case creates a real layout through
`layout_document_typed_in_viewport`, retains its genuine attached TextNode,
warms uppercase English rendering, then verifies cache invalidation, layout
dirtiness and Turkish uppercase rendering both in that same retained TextNode
and after normal layout. There are no synthetic layout records or test-only
callback owners.

The focused default run passed both cases in 126.11 seconds
(`Build/audit-fixes/source-language-publication-default.log`).
The GC-none batch passed all four files in 362.73 seconds: the new shared
publication cases, existing real DOM-layout bridge, light/shadow inherited
attribute invalidation and CSS inherited `:has()` dependency tests
(`source-language-publication-gc-none.log`).

This commit provides the shared concrete callee and preserves the existing
attribute path; Meta's Source caller is committed separately with its own
genuine insertion regression. The V publisher retains its existing style
flag/dependency bridge. Source Rust StyleEngineInput language/direction
publication and complete synthetic-pseudo/text enrollment are still separate
translation boundaries; this factor does not claim to implement them.
