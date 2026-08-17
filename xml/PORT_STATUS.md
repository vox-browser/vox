# XML module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/XML`

Translation workspace: `~/code/libweb_v/xml`
Audited: 2026-08-17

Both upstream implementation units and both headers were audited. There are no
WebIDL files in this source area.

| Upstream implementation | V implementation |
| --- | --- |
| `XMLDocumentBuilder.cpp` | `document_builder.v` |
| `XMLFragmentParser.cpp` | `fragment_parser.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `XML/` | 2 | 534 | 244 | 83 | Complete |

Associated declarations: 2 headers / 83 LOC and 0 IDL files. Mapping
completeness is 2/2 implementation units and 2/2 headers audited.

The port covers namespace-aware element/attribute construction, UTF-8 text,
CDATA, comments, processing instructions, XML and numeric references, the full
generated HTML named-reference table (including two-code-point values),
DocumentType public/system identifiers, readiness, well-formedness failures,
and XHTML fragment parsing with inherited namespaces and temporary-document
ownership. The shared translated XML tokenizer/tree builder is the LibXML
listener boundary. Script preparation/execution and browsing-context load-event
spins remain HTML event-loop platform boundaries.

Verification: `v test xml` passes 2/2; formatting and scoped diff checks pass.
