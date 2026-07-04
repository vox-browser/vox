module html

import dom

// Top-level "HTML string -> DOM" entry points. These live in the html module (not dom) because the
// dom module cannot import html — it would be an import cycle. The dom-side
// Document.parse_html_from_a_string is a boundary stub that uses a no-op parser; callers use these
// functions instead, the same way css owns querySelector.

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#parse-html-from-a-string
// Parse `markup` into `document` (a full-document parse, not a fragment). Runs the tree
// construction stage to completion.
//
// FIXME: the spec's "the end" steps (DOMContentLoaded, the load event, readyState transitions) are
// not run — they require the event loop / a Window, which are out of scope for this port.
pub fn parse_html_from_a_string(document &dom.Document, markup string) {
	mut parser := HTMLParser.create(document, markup)
	parser.run()
}

// Convenience: parse an HTML string into a fresh (about:blank) html Document and return it.
pub fn parse_document(markup string) &dom.Document {
	document := dom.Document.create(dom.url_about_blank())
	parse_html_from_a_string(document, markup)
	return document
}
