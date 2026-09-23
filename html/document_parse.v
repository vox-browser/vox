module html

import dom

// Top-level "HTML string -> DOM" entry points. These live in the html module (not dom) because the
// dom module cannot import html — it would be an import cycle. This module installs the callback
// used by the standard dom-side Document.parse_html_from_a_string and Element.set_inner_html APIs.

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#parse-html-from-a-string
// Parse `markup` into `document` (a full-document parse, not a fragment). Runs the tree
// construction stage to completion.
pub fn parse_html_from_a_string(document &dom.Document, markup string) {
	install_document_fragment_parsing_hook(document)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.parse_html_from_a_string(markup)
	// Parser-created HTML elements currently enter the tree through DOM's base
	// lifecycle hook. Refresh document metadata once tree construction has
	// completed so an initial color-scheme meta element takes effect just as a
	// dynamically inserted or modified one does.
	mutable_document.obtain_supported_color_schemes()
}

// Convenience: parse an HTML string into a fresh (about:blank) html Document and return it.
pub fn parse_document(markup string) &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	_ = CustomElementRegistry.create(document)
	// Documents created by navigation allow declarative shadow roots. This
	// convenience entry point is the browser/navigation parse path.
	document.set_allow_declarative_shadow_roots(true)
	parse_html_from_a_string(document, markup)
	return document
}
