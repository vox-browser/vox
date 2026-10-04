# Full parser uses the actual Base insertion freeze

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/DOM/Document.cpp:10123–10141`,
`HTML/Parser/HTMLParser.cpp:222–262,570–630`, and
`HTML/HTMLBaseElement.cpp:26–40,77–110`.

The V full-document parser wrapper retained a final Base cache refresh and
frozen-URL replay added while concrete Base insertion did not dispatch.
Actual insertion now performs those Source Base steps. Replaying after
parsing called the CSP check twice for one inserted Base, and could replace
its frozen URL when a real parsing/readiness handler changed the Document URL.

Source Document parsing creates and runs the parser; it does not replay Base
freezing afterward. Source Base insertion freezes immediately, and parser
completion dispatches the real interactive readiness event after insertion.
The V wrapper now relies on that same actual insertion path. Its unrelated
final supported-color-scheme refresh remains unchanged.

Two focused cases in `html/parser_base_lifecycle_test.v` use actual
Page/Window/navigation Document constructors and full-document parsing. The
CSP case supplies a real response-derived enforce policy and proves exactly
one deferred violation from the inserted Base. The frozen-snapshot case uses
a genuine `readystatechange` listener: at interactive readiness it records
the already-frozen Base and changes the actual Document URL. Parsing retains
that frozen Base and relative-resource resolution. A subsequent ordinary
`href` mutation still refreezes against the new fallback URL. Actual
Window/Document/Page identities remain intact. No lifecycle hook is manually
invoked and no synthetic script source is inserted.

Both cases failed before replay removal. The retained diagnostic
`Build/audit-fixes/source-parser-base-replay-original-default.log` shows two
violations instead of one, and `changed/assets/` instead of the original
frozen `root/assets/`. The clean focused default run passed both cases in
13.93 seconds (`source-parser-base-replay-default.log`). The clean GC-none
batch passed all eight files in 104.95 seconds, covering the new full-parser
cases, actual Base CSP owner, creator snapshot, document elements, navigation
registry, parser end state, full existing HTML parser suite and real replacement
fragments (`source-parser-base-replay-gc-none.log`).

This removes only the obsolete post-parse Base replay. Full HTML parser
parity, Source Meta lifecycle and genuine policy append, the remaining
color-scheme final refresh, standalone frozen-URL compatibility and inherited
CSP Violation record/initialization/reporting boundaries remain separate.
