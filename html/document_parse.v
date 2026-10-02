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
	old_base_url := document.base_url()
	mutable_document.parse_html_from_a_string(markup)
	// Parser-created elements currently enter through DOM's generic lifecycle
	// hook. Complete HTMLBaseElement's insertion steps once tree construction
	// has established tree order and the document URL is already final.
	mutable_document.update_base_element()
	if first_base := document.first_base_element_with_href_in_tree_order() {
		html_base_element_set_the_frozen_base_url(first_base, old_base_url)
	}
	// Parser-created HTML elements currently enter the tree through DOM's base
	// lifecycle hook. Refresh document metadata once tree construction has
	// completed so an initial color-scheme meta element takes effect just as a
	// dynamically inserted or modified one does.
	mutable_document.obtain_supported_color_schemes()
}

// Parse an HTML string into a fresh html Document whose URL is already known.
// Navigation uses this entry point so parser-time URL consumers, including a
// parser-inserted <base>, observe the final document URL.
pub fn parse_document_with_url(markup string, document_url dom.URL) &dom.Document {
	return parse_document_with_url_and_optional_origin(markup, document_url, none)
}

// Navigation creates the Document with its response origin before parsing.
// Keep standalone string parsing's fresh opaque origin in the entry above.
pub fn parse_document_with_url_and_origin(markup string, document_url dom.URL, origin dom.Origin) &dom.Document {
	return parse_document_with_url_and_optional_origin(markup, document_url, origin)
}

fn parse_document_with_url_and_optional_origin(markup string, document_url dom.URL, origin ?dom.Origin) &dom.Document {
	mut document := dom.Document.create(document_url)
	if response_origin := origin { document.set_origin(response_origin) }
	document.set_document_type(.html)
	_ = CustomElementRegistry.create(document)
	// Documents created by navigation allow declarative shadow roots. This
	// convenience entry point is the browser/navigation parse path.
	document.set_allow_declarative_shadow_roots(true)
	parse_html_from_a_string(document, markup)
	return document
}

// Native navigation has an actual relevant Window/settings before any parser
// resource or CSS state is initialized, following Document.cpp's source graph.
pub fn parse_navigation_document(markup string, document_url dom.URL, origin dom.Origin, previous ?&dom.Document) !&dom.Document {
	mut document := create_navigation_document(document_url, origin, previous)!
	document.set_document_type(.html)
	document.set_allow_declarative_shadow_roots(true)
	parse_html_from_a_string(document, markup)
	return document
}

// Convenience: parse an HTML string into a fresh about:blank html Document.
pub fn parse_document(markup string) &dom.Document {
	return parse_document_with_url(markup, dom.url_about_blank())
}
