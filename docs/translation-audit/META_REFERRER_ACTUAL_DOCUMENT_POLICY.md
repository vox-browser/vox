# Meta referrer updates the actual Document policy field

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/HTMLMetaElement.cpp:77–110`,
`ReferrerPolicy/ReferrerPolicy.cpp`, and
`DOM/Document.cpp:5508–5518`.

Source's Meta referrer algorithm requires a real Document tree and a nonempty
content attribute, maps the historical aliases with exact ASCII
case-insensitive matching, otherwise parses an ordinary referrer-policy token,
and writes the typed policy to the element's current Document's own container.
It does not use Window's current settings container instead of that Document
owner. Source metadata dispatch also preserves the historical rule that
removing or renaming a referrer Meta does not undo its most recent policy.

The V metadata body retained those token/Document-tree gates but only updated
`Document.meta_referrer_policy_`, an independent compatibility string. The
actual shared PolicyContainer referrer field therefore remained unchanged,
and real settings/Fetch consumers could not observe the Meta policy.

The native Meta metadata body now writes the parsed enum directly to
`element.document().policy_container().referrer_policy`. The shared record's
field is mutable, as in Source. No container is replaced, reconstructed, or
selected through Window settings. The existing string is also updated for its
compatibility accessors and existing standalone tests; it is not the typed
policy owner used by actual settings and Fetch.

Four cases in `html/meta_referrer_policy_owner_test.v` use actual Page-created
Documents, Windows, response policy containers and factory-allocated Meta
elements. They cover full parser insertion with retained header/Meta CSP order,
serialized settings and ordinary Fetch client policy projection; historical
aliases and ordinary exact ASCII case-insensitive tokens; last-inserted and
last-modified behavior, including an unrelated attribute mutation; removal and
renaming without undo; missing, empty, invalid and whitespace-bearing tokens;
disconnected, shadow and foreign-namespace elements; old Document ownership
during Window reassociation; and actual cross-document adoption.

Two initial fixture compiler diagnostics involved V enum inference and an
unsupported typed-map literal. The corrected behavioral baseline failed all
four cases in 36.56 seconds
(`Build/audit-fixes/source-meta-referrer-owner-original-default.log`): actual
containers retained their old header policy. A subsequent record visibility
diagnostic showed that V requires one mutable field section; only the referrer
field moved into that existing section. The corrected post-fix four-case file
passed with default GC in 95.28 seconds
(`source-meta-referrer-owner-default.log`). The final GC-none batch passed all
four files in 128.04 seconds (`source-meta-referrer-owner-gc-none.log`): the new
referrer cases, genuine Meta lifecycle, existing document-element models and
native metadata, and actual Document policy-container ownership.

This is the actual Meta referrer field write. The existing detached
`HTMLMetaElementModel` remains a compatibility model, and native metadata
dispatch remains the previously translated typed callback. CSP engine policy
lists still use the shared serialized-record projection; full GC/realm edges,
response policy parsing and general policy-container parity are separate.
SourceSnapshot cloning and Document CSP initialization still require their
separate own-Document caller corrections for temporary Window reassociation.
Those callers are not closed by this referrer fix. Meta CSP append intentionally
uses the relevant settings container, as explicitly required by
`HTMLMetaElement.cpp:222`; it has a different owner from the referrer write.
