# Compact class-name collections

Wikipedia's portal fundraising script calls
`document.getElementsByClassName("overlay-banner-toggle")` during startup,
then uses `.length` and numeric indexes to register button listeners. The
compact JavaScript document omitted that method despite the translated DOM
already providing class-name matching.

The compact document and Element facades now expose `getElementsByClassName`.
Collection reads replay pending mutations and use the owning native DOM's
class-name filter. Matching retains ASCII whitespace tokenization, all-token
matching, literal punctuation, empty-query behavior, tree order, descendant
scope and quirks-mode case handling. Saved collections support live length,
indexes, `item`, `namedItem`, named properties and iteration while preserving
element facade identity.

The translated native collection cache currently versions tree changes rather
than attribute-only changes. The bridge therefore recreates its native filter
on each read so class edits remain visible, including direct native DOM edits.
This introduces no global cache-invalidation or performance claim.

Six focused cases in `main_class_collection_test.v` pass with the compatibility
compiler in both normal Boehm and no-GC builds. They cover Wikipedia's lookup
and listener-registration loop, token matching, quirks mode, live class and
tree mutations, WebIDL argument conversion and Element receiver checks, and
native class-attribute mutations. Seven existing compact Element, replay and
lazy-content cases also passed. The initial cached implementation failed two
live-update cases; those failed results receive no whole-selection pass credit.

Named access still follows the compact facade's cached ID/name attributes;
native-side ID/name changes are a remaining synchronization limitation.
The separate `browserjs` document bridge and the complete native
HTMLCollection prototype surface are outside this slice. This is one
compatibility fix; it does not reset or claim completion of the independently
pending media-reflection broad-test batch.
