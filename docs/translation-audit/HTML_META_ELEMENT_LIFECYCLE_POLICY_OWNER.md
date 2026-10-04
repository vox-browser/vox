# Actual HTMLMetaElement lifecycle and policy append

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/HTMLMetaElement.cpp:34–248`,
`HTML/HTMLMetaElement.h:22–28` and
`ContentSecurityPolicy/PolicyList.cpp:105–109`.

The real DOM factory allocated `dom.HTMLMetaElement`, but ordinary insertion,
removal and attribute mutation dispatched only generic Element hooks. The HTML
Meta helper was reachable only through explicit calls; its CSP path stored a
filtered compatibility string without appending a policy to the actual Window
settings container. Genuine Fetch, Base and document inline checks consequently
could not observe parser-created or dynamically inserted Meta policies.

The actual Meta object now owns Source insertion, removal-context and attribute
methods. Node and Element virtual dispatch select that factory-allocated HTML
type; foreign namespaces retain generic Element handling. The existing HTML
wrappers delegate to these same methods. Parent steps execute once, removal
forwards the original subtree-root/ancestor/root arguments, insertion updates
metadata before pragma handling, and attribute mutation updates metadata
without enforcing another CSP policy.

Source metadata/referrer handling remains in its existing HTML body through a
typed Document callback, avoiding another parser or dependency cycle. The real
Window constructor installs both metadata and CSP callbacks before parsing;
the normal parser installer retains them. Referrer processing now uses Source's
Document-tree guard rather than mere shadow-including connectivity. The actual
classifier and shared enum use exact ASCII case-insensitive keywords, without
trimming. Encoding remains parser-owned, the cookie/X-UA-compatible states
retain Source's no-effect behavior, and default-style retains Source's FIXME.
Language candidate collection uses Source ASCII whitespace, including its
vertical-tab distinction; refresh delegates to the existing translated shared
declarative refresh algorithm. After setting a pragma language, Meta invokes
the independently translated shared Element language-publication method on
the actual document element, matching Source's explicit invalidation call.

The CSP insertion path requires a real Document tree, an actual HTML Head parent
and nonempty content. Its typed HTML callback uses the existing CSP parser,
removes `report-uri`, `frame-ancestors` and `sandbox`, and sets the actual current
Document origin through the existing native Origin conversion. The filtered
directive record is appended to the same actual settings container, preserving
prior header policies and order. Source, enforce disposition, original raw input
and actual tuple/opaque origin snapshot are retained. Source appends even a
policy whose directive list becomes empty after filtering. Removal does not
undo an enforced policy; reinsertion/adoption append a new policy for the
current Document as Source requires. The separate single-owner CSP prerequisite
prevents compatibility strings from contributing a duplicate policy to genuine
settings owners.

Nine focused cases in `html/meta_csp_lifecycle_test.v` exercise actual Pages,
navigation Documents, Windows, settings, factory elements and DOM mutations.
They cover header/Meta order and container identity, parser-before-Base policy
enforcement with one deferred violation, actual Fetch blocking before transport,
inline enforcement, Source duplicate-directive filtering/raw input retention,
Document-tree/shadow/foreign Head/foreign Meta/missing content/empty content and
untrimmed keyword guards, attribute/removal persistence and current-owner
adoption, actual opaque origin storage, live language/referrer/color-scheme
updates, refresh insertion and exact removal context for descendant/direct
removal. A standalone full parser retains its explicit filtered-string adapter.
Genuine insertion cases use constructor-installed callbacks before any parser
or manual CSP installer; inline checks later install their ordinary embedding
hook explicitly.

Two further cases in `layout/meta_language_publication_test.v` use genuine
Page/navigation Document/Window construction and a real full parser, then
insert a factory-created language Meta into its retained actual Head. They
prove warmed light/shadow language caches and style flags update through that
insertion itself. The layout case retains a genuine attached TextNode and
proves English-to-Turkish uppercase invalidation on the same owner and after
normal layout, without invoking the publication method manually.

The first fixture compile diagnostic incorrectly accessed Fetch's policy
sentinel instead of its actual client projection
(`Build/audit-fixes/source-meta-lifecycle-original-default.log`). The subsequent
pre-fix run failed all six original cases
(`source-meta-lifecycle-clean-original-default.log`). An intermediate metadata
fixture mutated a temporary chained `head()?.as_node()` result; diagnostic logs
showed its nodes absent from the real Document traversal. Retaining stable
actual Head/Body objects corrected the fixture without changing metadata logic
(`source-meta-lifecycle-actual-color-tree-diagnostic-default.log`). The then
seven-case constructor/default run passed in 14.78 seconds
(`source-meta-lifecycle-constructor-default.log`). These diagnostics are retained
instead of treating fixture errors as translation fixes.

The final nine-case Meta file and nine neighboring files passed GC-none in
304.00 seconds: Meta, single CSP owner, inline CSP bridge, real global Trusted
Types bindings, document elements, Base CSP owners, full-parser Base ordering,
native Base lifecycle, declarative refresh and raw handler attributes
(`source-meta-lifecycle-clean-gc-none.log`).

The initial language-insertion fixture diagnostic was Option propagation inside
a Result-returning helper (`source-meta-language-original-default.log`). The
clean pre-caller run failed both real insertion cases: descendant language
remained English and the attached casing text was not marked for layout
(`source-meta-language-clean-original-default.log`, 133.76 seconds). Invoking
the shared Source method then passed both caller cases together with all nine
Meta cases in the default two-file run
(`source-meta-language-default.log`, 189.63 seconds).

The final GC-none run passed all four files in 272.86 seconds: the nine Meta
cases, both genuine language-insertion cases, existing Window/context tests and
Page/document ownership tests (`source-meta-language-final-gc-none.log`).

This is bounded concrete Meta dispatch and settings-policy append. HTML still
stores serialized policy records and consumers materialize CSP engine lists;
cached request policy snapshots remain a separate boundary. The separately
reviewed CSP origin-copy feature `4d90ca4e` (canonical `f99b9f29`) closes the
existing projection's reconstruction loss by retaining the actual typed origin
record, including genuine opaque nonce/file type and tuple data. That is
independent of this feature's actual Meta origin snapshot. The native
`Document.policy_container()` placeholder and actual referrer-policy field
update remain untranslated;
existing metadata referrer-string behavior is preserved. Bare DOM construction
without the HTML embedding has no installed Meta policy/metadata implementation,
while standalone HTML parsing retains its explicit adapter. Generic
HTMLElement parent behavior, theme-color service availability, final full-parser
color-scheme refresh and CSP violation global/reporting limitations retain their
existing scope. Source Rust language-input publication and complete synthetic
pseudo/text enrollment retain the shared publication prerequisite's explicit
boundary. No full HTMLMetaElement, policy-container or CSP parity is claimed.
